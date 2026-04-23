from rest_framework import serializers

from .models import Conductor, Vehiculo


class VehiculoSerializer(serializers.ModelSerializer):
    class Meta:
        model = Vehiculo
        fields = (
            'id',
            'placa',
            'marca',
            'modelo',
            'color',
            'capacidad_asientos',
            'anio',
            'estado',
            'layout',
        )
        read_only_fields = ('id',)


class LayoutInputSerializer(serializers.Serializer):
    """Valida el layout: estructura y unicidad de números de asiento."""
    filas = serializers.IntegerField(min_value=1, max_value=20)
    columnas = serializers.IntegerField(min_value=1, max_value=10)
    celdas = serializers.ListField(child=serializers.ListField())

    def validate(self, attrs):
        filas, cols, celdas = attrs['filas'], attrs['columnas'], attrs['celdas']
        if len(celdas) != filas:
            raise serializers.ValidationError('celdas debe tener exactamente "filas" arrays.')
        numeros_vistos = set()
        choferes = 0
        asientos = 0
        for fila in celdas:
            if len(fila) != cols:
                raise serializers.ValidationError(
                    'Cada fila de celdas debe tener exactamente "columnas" elementos.'
                )
            for c in fila:
                if c is None:
                    continue
                if not isinstance(c, dict):
                    raise serializers.ValidationError('Celda inválida.')
                tipo = c.get('tipo')
                if tipo == 'CHOFER':
                    choferes += 1
                elif tipo == 'ASIENTO':
                    n = c.get('numero')
                    if not isinstance(n, int) or n < 1:
                        raise serializers.ValidationError(
                            'Asiento requiere "numero" entero ≥ 1.'
                        )
                    if n in numeros_vistos:
                        raise serializers.ValidationError(
                            f'Número de asiento duplicado: {n}.'
                        )
                    numeros_vistos.add(n)
                    asientos += 1
                else:
                    raise serializers.ValidationError(
                        f'Tipo de celda desconocido: {tipo!r}'
                    )
        if choferes < 1:
            raise serializers.ValidationError('Debe haber al menos una celda CHOFER.')
        if asientos < 1:
            raise serializers.ValidationError('Debe haber al menos una celda ASIENTO.')
        attrs['_asientos_total'] = asientos
        return attrs


class ConductorSerializer(serializers.ModelSerializer):
    nombres = serializers.CharField(source='usuario.nombres', read_only=True)
    apellidos = serializers.CharField(source='usuario.apellidos', read_only=True)

    class Meta:
        model = Conductor
        fields = ('id', 'nombres', 'apellidos', 'licencia_numero', 'estado')
