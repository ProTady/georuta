from datetime import datetime

from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from django.utils.dateparse import parse_date
from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.fleet.models import Conductor, Vehiculo
from apps.routes.models import Paradero, Ruta, RutaParadero

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


# ---------------------------------------------------------------------------
# Flujo POOLING (Fase 4)
# ---------------------------------------------------------------------------

class ViajesAbiertosView(generics.ListAPIView):
    """GET /api/trips/abiertos/?ruta_id=&origen_id=&destino_id=

    Lista viajes en estado ABIERTO para que el pasajero elija cuál le conviene
    (ordenado por ETA ascendente → el que sale antes primero).
    """
    permission_classes = (IsAuthenticated,)
    serializer_class = ViajeListSerializer

    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        ctx['origen_id'] = self.request.query_params.get('origen_id')
        ctx['destino_id'] = self.request.query_params.get('destino_id')
        return ctx

    def get_queryset(self):
        qs = Viaje.objects.select_related(
            'ruta', 'vehiculo', 'conductor__usuario', 'origen_actual',
        ).filter(estado=Viaje.Estado.ABIERTO, asientos_disponibles__gt=0)
        ruta_id = self.request.query_params.get('ruta_id')
        if ruta_id:
            qs = qs.filter(ruta_id=ruta_id)
        # Validar origen<destino si vinieron ambos
        origen_id = self.request.query_params.get('origen_id')
        destino_id = self.request.query_params.get('destino_id')
        if origen_id and destino_id:
            valid = set()
            for ruta in Ruta.objects.filter(estado='ACTIVA'):
                ordenes = {
                    str(rp.paradero_id): rp.orden
                    for rp in ruta.paraderos_rel.all()
                }
                if (origen_id in ordenes and destino_id in ordenes
                        and ordenes[origen_id] < ordenes[destino_id]):
                    valid.add(ruta.id)
            qs = qs.filter(ruta_id__in=valid)
        return qs

    def list(self, request, *args, **kwargs):
        data = self.get_serializer(self.get_queryset(), many=True).data
        # Orden por eta ascendente (menor = sale antes).
        data.sort(key=lambda v: (v.get('eta_minutos') or 0, -(v.get('asientos_vendidos') or 0)))
        return Response(data)


# ----- Driver: abrir / salir / cancelar ------------------------------------

def _user_conductor_or_403(user):
    """Devuelve el Conductor asociado al user o None."""
    return Conductor.objects.filter(usuario=user, estado='ACTIVO').first()


class AbrirViajeView(APIView):
    """POST /api/driver/viajes/abrir/
    body: { ruta_id, vehiculo_id, origen_paradero_id }
    Crea un Viaje ABIERTO con el conductor autenticado.
    """
    permission_classes = (IsAuthenticated,)

    def post(self, request):
        conductor = _user_conductor_or_403(request.user)
        if not conductor:
            return Response({'detail': 'Solo un conductor puede abrir viajes.'},
                            status=status.HTTP_403_FORBIDDEN)

        ruta_id = request.data.get('ruta_id')
        vehiculo_id = request.data.get('vehiculo_id')
        origen_id = request.data.get('origen_paradero_id')
        if not (ruta_id and vehiculo_id and origen_id):
            return Response({'detail': 'Faltan ruta_id, vehiculo_id u origen_paradero_id.'},
                            status=status.HTTP_400_BAD_REQUEST)

        # No puede tener otro viaje ABIERTO o EN_CURSO.
        activo = Viaje.objects.filter(
            conductor=conductor,
            estado__in=[Viaje.Estado.ABIERTO, Viaje.Estado.EN_CURSO],
        ).first()
        if activo:
            return Response(
                {'detail': 'Ya tienes un viaje activo.', 'viaje_id': str(activo.id)},
                status=status.HTTP_409_CONFLICT,
            )

        ruta = get_object_or_404(Ruta, pk=ruta_id, estado='ACTIVA')
        vehiculo = get_object_or_404(Vehiculo, pk=vehiculo_id, estado='ACTIVO')
        # Vehículo no ocupado en otro viaje.
        if Viaje.objects.filter(
            vehiculo=vehiculo,
            estado__in=[Viaje.Estado.ABIERTO, Viaje.Estado.EN_CURSO],
        ).exists():
            return Response({'detail': 'El vehículo ya está en un viaje activo.'},
                            status=status.HTTP_409_CONFLICT)
        paradero = get_object_or_404(Paradero, pk=origen_id)
        # Paradero debe pertenecer a la ruta.
        if not RutaParadero.objects.filter(ruta=ruta, paradero=paradero).exists():
            return Response({'detail': 'El paradero no pertenece a la ruta.'},
                            status=status.HTTP_400_BAD_REQUEST)

        now = timezone.now()
        with transaction.atomic():
            viaje = Viaje.objects.create(
                ruta=ruta,
                vehiculo=vehiculo,
                conductor=conductor,
                origen_actual=paradero,
                fecha_viaje=now.date(),
                hora_salida_programada=now,
                abierto_en=now,
                estado=Viaje.Estado.ABIERTO,
            )
        return Response(ViajeListSerializer(viaje).data, status=status.HTTP_201_CREATED)


class SalirViajeView(APIView):
    """POST /api/driver/viajes/<id>/salir/  → ABIERTO → EN_CURSO"""
    permission_classes = (IsAuthenticated,)

    def post(self, request, pk):
        conductor = _user_conductor_or_403(request.user)
        if not conductor:
            return Response({'detail': 'No autorizado.'}, status=status.HTTP_403_FORBIDDEN)
        viaje = get_object_or_404(Viaje, pk=pk, conductor=conductor)
        if viaje.estado != Viaje.Estado.ABIERTO:
            return Response({'detail': 'Solo se puede salir desde estado ABIERTO.'},
                            status=status.HTTP_400_BAD_REQUEST)
        viaje.estado = Viaje.Estado.EN_CURSO
        viaje.hora_salida_real = timezone.now()
        viaje.save(update_fields=['estado', 'hora_salida_real'])
        return Response(ViajeListSerializer(viaje).data)


class CancelarViajeDriverView(APIView):
    """POST /api/driver/viajes/<id>/cancelar/  → CANCELADO (si ABIERTO)"""
    permission_classes = (IsAuthenticated,)

    def post(self, request, pk):
        conductor = _user_conductor_or_403(request.user)
        if not conductor:
            return Response({'detail': 'No autorizado.'}, status=status.HTTP_403_FORBIDDEN)
        viaje = get_object_or_404(Viaje, pk=pk, conductor=conductor)
        if viaje.estado != Viaje.Estado.ABIERTO:
            return Response({'detail': 'Solo se pueden cancelar viajes ABIERTOS.'},
                            status=status.HTTP_400_BAD_REQUEST)
        viaje.estado = Viaje.Estado.CANCELADO
        viaje.save(update_fields=['estado'])
        # TODO Fase 5: liberar reservas PENDIENTE y reembolsar boletos.
        return Response(ViajeListSerializer(viaje).data)
