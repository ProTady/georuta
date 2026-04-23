from django.shortcuts import get_object_or_404
from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Conductor, Vehiculo
from .serializers import (
    ConductorSerializer,
    LayoutInputSerializer,
    VehiculoSerializer,
)


def _is_conductor(user) -> bool:
    return Conductor.objects.filter(usuario=user, estado='ACTIVO').exists()


class VehiculosListView(generics.ListAPIView):
    """GET /api/fleet/vehiculos/  → todos los vehículos ACTIVOS.
    (MVP: cualquier conductor puede verlos y editar layout; más adelante
    se añade Vehiculo.propietario / AsignacionConductorVehiculo.)
    """
    permission_classes = (IsAuthenticated,)
    serializer_class = VehiculoSerializer

    def get_queryset(self):
        return Vehiculo.objects.filter(estado='ACTIVO').order_by('placa')


class VehiculoLayoutView(APIView):
    """PUT /api/fleet/vehiculos/<id>/layout/
    body: { filas, columnas, celdas: [[cell,...], ...] }
    Solo conductores activos (MVP).
    """
    permission_classes = (IsAuthenticated,)

    def put(self, request, pk):
        if not _is_conductor(request.user):
            return Response({'detail': 'Solo un conductor puede editar el layout.'},
                            status=status.HTTP_403_FORBIDDEN)
        vehiculo = get_object_or_404(Vehiculo, pk=pk)
        ser = LayoutInputSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        data = ser.validated_data
        vehiculo.layout = {
            'filas': data['filas'],
            'columnas': data['columnas'],
            'celdas': data['celdas'],
        }
        # Sincroniza capacidad con el layout.
        vehiculo.capacidad_asientos = data['_asientos_total']
        vehiculo.save(update_fields=['layout', 'capacidad_asientos'])
        return Response(VehiculoSerializer(vehiculo).data)


class ConductoresListView(generics.ListAPIView):
    """GET /api/fleet/conductores/  → conductores activos."""
    permission_classes = (IsAuthenticated,)
    serializer_class = ConductorSerializer

    def get_queryset(self):
        return Conductor.objects.filter(estado='ACTIVO').select_related('usuario')
