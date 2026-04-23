from decimal import Decimal

from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.routes.models import Paradero, RutaParadero, TarifaTramo
from apps.trips.models import Viaje
from apps.trips.serializers import ViajeListSerializer

from .models import Asiento, Boleto, Reserva, ReservaAsiento
from .serializers import (
    AsientoEstadoSerializer,
    BoletoSerializer,
    ReservaSerializer,
    ReservarInputSerializer,
    tarifa_para,
)


def _marcar_expiradas(viaje: Viaje):
    """Marca como EXPIRADA las reservas pendientes cuyo plazo ya venció."""
    Reserva.objects.filter(
        viaje=viaje,
        estado=Reserva.Estado.PENDIENTE,
        expira_en__lt=timezone.now(),
    ).update(estado=Reserva.Estado.EXPIRADA)


def _sets_estado_asientos(viaje: Viaje):
    """Devuelve (reservados_ids, vendidos_ids) para los asientos de un viaje."""
    reservados = set(
        ReservaAsiento.objects
        .filter(
            reserva__viaje=viaje,
            reserva__estado=Reserva.Estado.PENDIENTE,
            reserva__expira_en__gt=timezone.now(),
        )
        .values_list('asiento_id', flat=True)
    )
    vendidos = set(
        Boleto.objects
        .filter(viaje=viaje)
        .exclude(estado=Boleto.Estado.ANULADO)
        .values_list('asiento_id', flat=True)
    )
    return reservados, vendidos


# ---------------------------------------------------------------------------

class ViajeDetalleView(APIView):
    """GET /api/trips/viajes/<id>/  → datos del viaje + grid de asientos."""
    permission_classes = (IsAuthenticated,)

    def get(self, request, pk):
        viaje = get_object_or_404(
            Viaje.objects.select_related('ruta', 'vehiculo', 'conductor__usuario'),
            pk=pk,
        )
        _marcar_expiradas(viaje)
        reservados, vendidos = _sets_estado_asientos(viaje)

        asientos_qs = viaje.asientos.all().order_by('numero')
        asientos_data = AsientoEstadoSerializer(
            asientos_qs,
            many=True,
            context={
                'asientos_reservados': reservados,
                'asientos_vendidos': vendidos,
            },
        ).data

        # Permitir origen/destino via query para calcular tarifa puntual
        # y además devolver todas las tarifas del tramo para que el front
        # haga lookup sin refetch.
        origen_id = request.query_params.get('origen')
        destino_id = request.query_params.get('destino')
        viaje_data = ViajeListSerializer(
            viaje,
            context={'origen_id': origen_id, 'destino_id': destino_id},
        ).data
        viaje_data['asientos'] = asientos_data
        viaje_data['tarifas'] = [
            {
                'origen_id': str(t.paradero_origen_id),
                'destino_id': str(t.paradero_destino_id),
                'precio': str(t.precio),
            }
            for t in TarifaTramo.objects.filter(
                ruta=viaje.ruta, estado='ACTIVA',
            )
        ]
        return Response(viaje_data)


# ---------------------------------------------------------------------------

class ReservarView(APIView):
    """POST /api/trips/viajes/<id>/reservar/
    body: { paradero_origen_id, paradero_destino_id, asientos: [1,2,..] }
    """
    permission_classes = (IsAuthenticated,)

    def post(self, request, pk):
        serializer = ReservarInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        with transaction.atomic():
            viaje = get_object_or_404(
                Viaje.objects.select_for_update(),
                pk=pk,
            )
            if viaje.estado != Viaje.Estado.PROGRAMADO:
                return Response(
                    {'detail': 'El viaje no está disponible para reservas.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            # Paraderos deben pertenecer a la ruta y origen < destino.
            ordenes = {
                rp.paradero_id: rp.orden
                for rp in RutaParadero.objects.filter(ruta=viaje.ruta)
            }
            o_id = data['paradero_origen_id']
            d_id = data['paradero_destino_id']
            if o_id not in ordenes or d_id not in ordenes:
                return Response(
                    {'detail': 'Origen o destino no pertenece a la ruta del viaje.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if ordenes[o_id] >= ordenes[d_id]:
                return Response(
                    {'detail': 'El origen debe estar antes que el destino.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            # Tarifa del tramo.
            precio = tarifa_para(viaje.ruta_id, o_id, d_id)
            if precio is None:
                return Response(
                    {'detail': 'No hay tarifa configurada para ese tramo.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            # Limpiar reservas expiradas antes de verificar disponibilidad.
            _marcar_expiradas(viaje)

            # Traer asientos solicitados con lock.
            numeros = data['asientos']
            asientos = list(
                Asiento.objects
                .select_for_update()
                .filter(viaje=viaje, numero__in=numeros)
                .order_by('numero')
            )
            if len(asientos) != len(numeros):
                return Response(
                    {'detail': 'Uno o más asientos no existen para este viaje.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            reservados, vendidos = _sets_estado_asientos(viaje)
            ocupados = [a.numero for a in asientos
                        if a.id in reservados or a.id in vendidos]
            if ocupados:
                return Response(
                    {'detail': f'Asientos no disponibles: {ocupados}.'},
                    status=status.HTTP_409_CONFLICT,
                )

            # Crear Reserva + items.
            total = Decimal(precio) * len(asientos)
            reserva = Reserva.objects.create(
                usuario=request.user,
                viaje=viaje,
                paradero_origen_id=o_id,
                paradero_destino_id=d_id,
                total=total,
            )
            ReservaAsiento.objects.bulk_create([
                ReservaAsiento(reserva=reserva, asiento=a, precio=precio)
                for a in asientos
            ])

        return Response(
            ReservaSerializer(reserva).data,
            status=status.HTTP_201_CREATED,
        )


# ---------------------------------------------------------------------------

class ConfirmarReservaView(APIView):
    """POST /api/reservas/<id>/confirmar/
    Simula pago exitoso, genera boletos con QR y descuenta asientos.
    """
    permission_classes = (IsAuthenticated,)

    def post(self, request, pk):
        with transaction.atomic():
            reserva = get_object_or_404(
                Reserva.objects.select_for_update().select_related('viaje'),
                pk=pk,
            )
            if reserva.usuario_id != request.user.id:
                return Response(
                    {'detail': 'No autorizado.'},
                    status=status.HTTP_403_FORBIDDEN,
                )
            if reserva.estado != Reserva.Estado.PENDIENTE:
                return Response(
                    {'detail': f'La reserva no está pendiente (estado: {reserva.estado}).'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if reserva.esta_expirada:
                reserva.estado = Reserva.Estado.EXPIRADA
                reserva.save(update_fields=['estado'])
                return Response(
                    {'detail': 'La reserva expiró. Inicia otra.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            # Generar boletos.
            boletos = []
            items = list(reserva.items.select_related('asiento').all())
            for item in items:
                boleto = Boleto.objects.create(
                    reserva=reserva,
                    usuario=reserva.usuario,
                    viaje=reserva.viaje,
                    asiento=item.asiento,
                    paradero_origen=reserva.paradero_origen,
                    paradero_destino=reserva.paradero_destino,
                    precio=item.precio,
                )
                boletos.append(boleto)

            reserva.estado = Reserva.Estado.CONFIRMADA
            reserva.fecha_confirmacion = timezone.now()
            reserva.save(update_fields=['estado', 'fecha_confirmacion'])

            # Descontar asientos disponibles del viaje.
            viaje = reserva.viaje
            nuevos = max(0, (viaje.asientos_disponibles or 0) - len(boletos))
            viaje.asientos_disponibles = nuevos
            viaje.save(update_fields=['asientos_disponibles'])

        return Response(
            {
                'reserva': ReservaSerializer(reserva).data,
                'boletos': BoletoSerializer(boletos, many=True).data,
            },
            status=status.HTTP_200_OK,
        )


class CancelarReservaView(APIView):
    """POST /api/reservas/<id>/cancelar/"""
    permission_classes = (IsAuthenticated,)

    def post(self, request, pk):
        reserva = get_object_or_404(Reserva, pk=pk)
        if reserva.usuario_id != request.user.id:
            return Response(
                {'detail': 'No autorizado.'}, status=status.HTTP_403_FORBIDDEN
            )
        if reserva.estado != Reserva.Estado.PENDIENTE:
            return Response(
                {'detail': 'Solo se pueden cancelar reservas pendientes.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        reserva.estado = Reserva.Estado.CANCELADA
        reserva.save(update_fields=['estado'])
        return Response(ReservaSerializer(reserva).data)


# ---------------------------------------------------------------------------

class MisReservasView(generics.ListAPIView):
    """GET /api/reservas/mis/"""
    permission_classes = (IsAuthenticated,)
    serializer_class = ReservaSerializer

    def get_queryset(self):
        return (
            Reserva.objects
            .filter(usuario=self.request.user)
            .select_related('viaje', 'paradero_origen', 'paradero_destino')
            .prefetch_related('items__asiento')
            .order_by('-fecha_creacion')
        )


class MisBoletosView(generics.ListAPIView):
    """GET /api/boletos/mis/"""
    permission_classes = (IsAuthenticated,)
    serializer_class = BoletoSerializer

    def get_queryset(self):
        return (
            Boleto.objects
            .filter(usuario=self.request.user)
            .select_related('viaje__ruta', 'asiento',
                            'paradero_origen', 'paradero_destino')
            .order_by('-fecha_emision')
        )


class BoletoDetalleView(generics.RetrieveAPIView):
    """GET /api/boletos/<id>/"""
    permission_classes = (IsAuthenticated,)
    serializer_class = BoletoSerializer

    def get_queryset(self):
        return Boleto.objects.filter(usuario=self.request.user).select_related(
            'viaje__ruta', 'asiento', 'paradero_origen', 'paradero_destino'
        )
