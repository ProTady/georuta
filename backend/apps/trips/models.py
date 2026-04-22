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
        PROGRAMADO = 'PROGRAMADO', 'Programado'
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

    fecha_viaje = models.DateField()
    hora_salida_programada = models.DateTimeField()
    hora_salida_real = models.DateTimeField(null=True, blank=True)
    hora_llegada_real = models.DateTimeField(null=True, blank=True)

    capacidad_total = models.PositiveIntegerField()
    asientos_disponibles = models.PositiveIntegerField()

    estado = models.CharField(max_length=20, choices=Estado.choices, default=Estado.PROGRAMADO)
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
        super().save(*args, **kwargs)
