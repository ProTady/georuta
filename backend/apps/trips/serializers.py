from rest_framework import serializers

from apps.routes.models import Paradero, Ruta, RutaParadero, TarifaTramo

from .models import Viaje


class ParaderoSerializer(serializers.ModelSerializer):
    class Meta:
        model = Paradero
        fields = ('id', 'nombre', 'direccion', 'latitud', 'longitud')


class RutaParaderoSerializer(serializers.ModelSerializer):
    paradero = ParaderoSerializer(read_only=True)

    class Meta:
        model = RutaParadero
        fields = ('orden', 'tipo', 'tiempo_estimado_min', 'paradero')


class RutaSerializer(serializers.ModelSerializer):
    paraderos = serializers.SerializerMethodField()

    class Meta:
        model = Ruta
        fields = (
            'id',
            'nombre',
            'origen_nombre',
            'destino_nombre',
            'distancia_km',
            'duracion_estimada_min',
            'estado',
            'paraderos',
        )

    def get_paraderos(self, obj):
        qs = obj.paraderos_rel.select_related('paradero').order_by('orden')
        return RutaParaderoSerializer(qs, many=True).data


class ViajeListSerializer(serializers.ModelSerializer):
    ruta_nombre = serializers.CharField(source='ruta.nombre', read_only=True)
    vehiculo_placa = serializers.CharField(source='vehiculo.placa', read_only=True)
    conductor_nombre = serializers.SerializerMethodField()
    tarifa = serializers.SerializerMethodField()

    class Meta:
        model = Viaje
        fields = (
            'id',
            'ruta',
            'ruta_nombre',
            'fecha_viaje',
            'hora_salida_programada',
            'capacidad_total',
            'asientos_disponibles',
            'estado',
            'vehiculo_placa',
            'conductor_nombre',
            'tarifa',
        )

    def get_conductor_nombre(self, obj):
        if obj.conductor and obj.conductor.usuario:
            return obj.conductor.usuario.full_name
        return None

    def get_tarifa(self, obj):
        origen_id = self.context.get('origen_id')
        destino_id = self.context.get('destino_id')
        if not origen_id or not destino_id:
            return None
        tarifa = TarifaTramo.objects.filter(
            ruta=obj.ruta,
            paradero_origen_id=origen_id,
            paradero_destino_id=destino_id,
            estado='ACTIVA',
        ).first()
        return tarifa.precio if tarifa else None
