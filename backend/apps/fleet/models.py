import uuid

from django.conf import settings
from django.db import models


class Vehiculo(models.Model):
    class Estado(models.TextChoices):
        ACTIVO = 'ACTIVO', 'Activo'
        MANTENIMIENTO = 'MANTENIMIENTO', 'En mantenimiento'
        INACTIVO = 'INACTIVO', 'Inactivo'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    placa = models.CharField(max_length=20, unique=True)
    marca = models.CharField(max_length=50, blank=True, default='')
    modelo = models.CharField(max_length=50, blank=True, default='')
    color = models.CharField(max_length=30, blank=True, default='')
    capacidad_asientos = models.PositiveIntegerField(default=10)
    anio = models.PositiveIntegerField(null=True, blank=True)
    estado = models.CharField(max_length=20, choices=Estado.choices, default=Estado.ACTIVO)

    class Meta:
        db_table = 'vehiculos'
        verbose_name = 'Vehículo'
        verbose_name_plural = 'Vehículos'
        ordering = ['placa']

    def __str__(self):
        return f'{self.placa} ({self.marca} {self.modelo})'.strip()


class Conductor(models.Model):
    class Estado(models.TextChoices):
        ACTIVO = 'ACTIVO', 'Activo'
        INACTIVO = 'INACTIVO', 'Inactivo'
        SUSPENDIDO = 'SUSPENDIDO', 'Suspendido'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    usuario = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name='conductor',
    )
    licencia_numero = models.CharField(max_length=50, unique=True)
    licencia_categoria = models.CharField(max_length=20, blank=True, default='')
    licencia_vencimiento = models.DateField(null=True, blank=True)
    estado = models.CharField(max_length=20, choices=Estado.choices, default=Estado.ACTIVO)

    class Meta:
        db_table = 'conductores'
        verbose_name = 'Conductor'
        verbose_name_plural = 'Conductores'
        ordering = ['usuario__nombres']

    def __str__(self):
        return f'{self.usuario.full_name} ({self.licencia_numero})'
