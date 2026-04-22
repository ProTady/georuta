from datetime import datetime

from django.utils.dateparse import parse_date
from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from apps.routes.models import Ruta, RutaParadero

from .models import Viaje
from .serializers import RutaSerializer, ViajeListSerializer


class RutaListView(generics.ListAPIView):
    """GET /api/routes/  →  todas las rutas activas con sus paraderos ordenados."""
    permission_classes = (IsAuthenticated,)
    serializer_class = RutaSerializer

    def get_queryset(self):
        return Ruta.objects.filter(estado='ACTIVA').prefetch_related('paraderos_rel__paradero')


class TripSearchView(generics.ListAPIView):
    """GET /api/trips/search/?ruta_id=&origen_id=&destino_id=&fecha=YYYY-MM-DD

    Lista viajes PROGRAMADOS con asientos disponibles para la fecha indicada.
    """
    permission_classes = (IsAuthenticated,)
    serializer_class = ViajeListSerializer

    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        ctx['origen_id'] = self.request.query_params.get('origen_id')
        ctx['destino_id'] = self.request.query_params.get('destino_id')
        return ctx

    def get_queryset(self):
        params = self.request.query_params
        qs = Viaje.objects.select_related('ruta', 'vehiculo', 'conductor__usuario').filter(
            estado=Viaje.Estado.PROGRAMADO,
            asientos_disponibles__gt=0,
        )

        ruta_id = params.get('ruta_id')
        if ruta_id:
            qs = qs.filter(ruta_id=ruta_id)

        fecha_str = params.get('fecha')
        if fecha_str:
            fecha = parse_date(fecha_str)
            if fecha:
                qs = qs.filter(fecha_viaje=fecha)

        # Validar que origen/destino pertenezcan a la ruta y que origen vaya antes.
        origen_id = params.get('origen_id')
        destino_id = params.get('destino_id')
        if origen_id and destino_id:
            # Filtra rutas cuyos paraderos incluyan ambos con origen < destino
            valid_route_ids = set()
            for ruta in Ruta.objects.filter(estado='ACTIVA'):
                ordenes = {
                    str(rp.paradero_id): rp.orden
                    for rp in ruta.paraderos_rel.all()
                }
                if origen_id in ordenes and destino_id in ordenes:
                    if ordenes[origen_id] < ordenes[destino_id]:
                        valid_route_ids.add(ruta.id)
            qs = qs.filter(ruta_id__in=valid_route_ids)

        return qs.order_by('fecha_viaje', 'hora_salida_programada')

    def list(self, request, *args, **kwargs):
        # Validaciones amigables
        fecha_str = request.query_params.get('fecha')
        if fecha_str and not parse_date(fecha_str):
            return Response(
                {'detail': 'Formato de fecha inválido. Usa YYYY-MM-DD.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        return super().list(request, *args, **kwargs)
