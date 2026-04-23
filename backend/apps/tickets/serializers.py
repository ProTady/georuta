from django.utils import timezone
from rest_framework import serializers

from apps.routes.models import TarifaTramo

from .models import Asiento, Boleto, Reserva, ReservaAsiento


# ---------- Asientos / detalle de viaje ----------

class AsientoEstadoSerializer(serializers.ModelSerializer):
    """Asiento con su estado dinámico: LIBRE | RESERVADO | VENDIDO."""
    estado = serializers.SerializerMethodField()

    class Meta:
        model = Asiento
        fields = ('id', 'numero', 'estado')

    def get_estado(self, obj):
        held = self.context.get('asientos_reservados', set())
        sold = self.context.get('asientos_vendidos', set())
        if obj.id in sold:
            return 'VENDIDO'
        if obj.id in held:
            return 'RESERVADO'
        return 'LIBRE'


# ---------- Creación de reserva ----------

class ReservarInputSerializer(serializers.Serializer):
    paradero_origen_id = serializers.UUIDField()
    paradero_destino_id = serializers.UUIDField()
    asientos = serializers.ListField(
        child=serializers.IntegerField(min_value=1),
        min_length=1, max_length=10,
    )

    def validate(self, attrs):
        if attrs['paradero_origen_id'] == attrs['paradero_destino_id']:
            raise serializers.ValidationError(
                {'paradero_destino_id': 'Debe ser distinto al origen.'}
            )
        # duplicados en la lista de asientos
        asientos = attrs['asientos']
        if len(set(asientos)) != len(asientos):
            raise serializers.ValidationError(
                {'asientos': 'No repitas el mismo asiento.'}
            )
        return attrs


# ---------- Boletos ----------

class BoletoSerializer(serializers.ModelSerializer):
    asiento_numero = serializers.IntegerField(source='asiento.numero', read_only=True)
    ruta_nombre = serializers.CharField(source='viaje.ruta.nombre', read_only=True)
    fecha_viaje = serializers.DateField(source='viaje.fecha_viaje', read_only=True)
    hora_salida = serializers.DateTimeField(
        source='viaje.hora_salida_programada', read_only=True
    )
    origen_nombre = serializers.CharField(
        source='paradero_origen.nombre', read_only=True
    )
    destino_nombre = serializers.CharField(
        source='paradero_destino.nombre', read_only=True
    )

    class Meta:
        model = Boleto
        fields = (
            'id', 'viaje', 'asiento', 'asiento_numero',
            'ruta_nombre', 'fecha_viaje', 'hora_salida',
            'paradero_origen', 'paradero_destino', 'origen_nombre', 'destino_nombre',
            'precio', 'qr_token', 'estado', 'fecha_emision',
        )


# ---------- Reservas ----------

class ReservaItemSerializer(serializers.ModelSerializer):
    asiento_numero = serializers.IntegerField(source='asiento.numero', read_only=True)

    class Meta:
        model = ReservaAsiento
        fields = ('asiento', 'asiento_numero', 'precio')


class ReservaSerializer(serializers.ModelSerializer):
    items = ReservaItemSerializer(many=True, read_only=True)
    segundos_restantes = serializers.SerializerMethodField()

    class Meta:
        model = Reserva
        fields = (
            'id', 'viaje',
            'paradero_origen', 'paradero_destino',
            'total', 'estado',
            'fecha_creacion', 'expira_en', 'segundos_restantes',
            'fecha_confirmacion',
            'items',
        )

    def get_segundos_restantes(self, obj):
        if obj.estado != Reserva.Estado.PENDIENTE:
            return 0
        delta = (obj.expira_en - timezone.now()).total_seconds()
        return max(0, int(delta))


# ---------- Helper: tarifa para (ruta, origen, destino) ----------

def tarifa_para(ruta_id, origen_id, destino_id):
    tarifa = TarifaTramo.objects.filter(
        ruta_id=ruta_id,
        paradero_origen_id=origen_id,
        paradero_destino_id=destino_id,
        estado='ACTIVA',
    ).first()
    return tarifa.precio if tarifa else None
