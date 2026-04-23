import uuid

from django.core.exceptions import ValidationError
from django.db import models

from apps.fleet.models import Conductor, Vehiculo
from apps.routes.models import Ruta


class Horario(models.Model):
    class Estado(models.TextChoices):
        ACTIVO = 'ACTIVO', 'Activo'
        INACTIVO = 'INACTIVO', 'Inactivo'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    ruta = models.ForeignKey(Ruta, on_delete=models.CASCADE, related_name='horarios')
    hora_salida = models.TimeField()
    dias_semana = models.CharField(
        max_length=20,
        blank=True,
        default='',
        help_text='Códigos separados por coma: L,M,X,J,V,S,D',
    )
    tarifa_base = models.DecimalField(max_digits=10, decimal_places=2)
    estado = models.CharField(max_length=20, choices=Estado.choices, default=Estado.ACTIVO)

    class Meta:
        db_table = 'horarios'
        verbose_name = 'Horario'
        verbose_name_plural = 'Horarios'
        ordering = ['ruta', 'hora_salida']

    def __str__(self):
        return f'{self.ruta.nombre} @ {self.hora_salida.strftime("%H:%M")}'


class Viaje(models.Model):
    class Estado(models.TextChoices):
        ABIERTO = 'ABIERTO', 'Abierto (tomando pasajeros)'
        PROGRAMADO = 'PROGRAMADO', 'Programado (legacy)'
        EN_CURSO = 'EN_CURSO', 'En curso'
        FINALIZADO = 'FINALIZADO', 'Finalizado'
        CANCELADO = 'CANCELADO', 'Cancelado'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    ruta = models.ForeignKey(Ruta, on_delete=models.PROTECT, related_name='viajes')
    horario = models.ForeignKey(
        Horario, on_delete=models.SET_NULL, null=True, blank=True, related_name='viajes'
    )
    vehiculo = models.ForeignKey(Vehiculo, on_delete=models.PROTECT, related_name='viajes')
    conductor = models.ForeignKey(
        Conductor, on_delete=models.SET_NULL, null=True, blank=True, related_name='viajes'
    )

    # Paradero donde el carro espera (nuevo flujo pooling). Nullable para
    # compatibilidad con viajes ya PROGRAMADOS en el sistema viejo.
    origen_actual = models.ForeignKey(
        'routes.Paradero',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='viajes_abiertos',
    )

    fecha_viaje = models.DateField()
    hora_salida_programada = models.DateTimeField()
    hora_salida_real = models.DateTimeField(null=True, blank=True)
    hora_llegada_real = models.DateTimeField(null=True, blank=True)
    abierto_en = models.DateTimeField(null=True, blank=True)

    capacidad_total = models.PositiveIntegerField()
    asientos_disponibles = models.PositiveIntegerField()
    min_pasajeros_para_salir = models.PositiveIntegerField(
        default=0,
        help_text='Umbral para avisar al conductor que puede salir. 0 = sin mínimo.',
    )

    estado = models.CharField(max_length=20, choices=Estado.choices, default=Estado.ABIERTO)
    observaciones = models.TextField(blank=True, default='')

    class Meta:
        db_table = 'viajes'
        verbose_name = 'Viaje'
        verbose_name_plural = 'Viajes'
        ordering = ['-fecha_viaje', 'hora_salida_programada']
        indexes = [
            models.Index(fields=['fecha_viaje', 'estado'], name='idx_viajes_fecha_estado'),
        ]

    def __str__(self):
        return f'{self.ruta.nombre} | {self.fecha_viaje} {self.hora_salida_programada:%H:%M}'

    def clean(self):
        super().clean()
        if self.capacidad_total and self.asientos_disponibles is not None:
            if self.asientos_disponibles > self.capacidad_total:
                raise ValidationError(
                    'Los asientos disponibles no pueden exceder la capacidad total.'
                )

    def save(self, *args, **kwargs):
        # Autocompletar capacidad y asientos desde el vehículo en la creación.
        if self.vehiculo_id and not self.capacidad_total:
            self.capacidad_total = self.vehiculo.capacidad_asientos
        if self.capacidad_total and self.asientos_disponibles is None:
            self.asientos_disponibles = self.capacidad_total
        # Mínimo por defecto = 60% de capacidad si no se seteó.
        if self.capacidad_total and not self.min_pasajeros_para_salir:
            self.min_pasajeros_para_salir = max(1, int(self.capacidad_total * 0.6))
        super().save(*args, **kwargs)

    # ------------------------------------------------------------------
    # Helpers para el modelo pooling
    # ------------------------------------------------------------------
    @property
    def asientos_vendidos(self) -> int:
        return max(0, (self.capacidad_total or 0) - (self.asientos_disponibles or 0))

    def eta_minutos(self, minutos_por_asiento: int = 3) -> int:
        """Heurística v1 de ETA para viajes ABIERTOS.

        eta = max(0, (min_para_salir - vendidos) * minutos_por_asiento)
        En el futuro se puede calcular minutos_por_asiento por ruta/franja
        horaria a partir del histórico (ver Fase 4.7 del plan).
        """
        if self.estado != self.Estado.ABIERTO:
            return 0
        faltan = max(0, (self.min_pasajeros_para_salir or 0) - self.asientos_vendidos)
        return faltan * minutos_por_asiento
