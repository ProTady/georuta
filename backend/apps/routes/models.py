import uuid

from django.db import models


class EstadoActivo(models.TextChoices):
    ACTIVA = 'ACTIVA', 'Activa'
    INACTIVA = 'INACTIVA', 'Inactiva'


class Ruta(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    nombre = models.CharField(max_length=150)
    origen_nombre = models.CharField(max_length=120)
    destino_nombre = models.CharField(max_length=120)
    distancia_km = models.DecimalField(max_digits=8, decimal_places=2, null=True, blank=True)
    duracion_estimada_min = models.IntegerField(null=True, blank=True)
    estado = models.CharField(max_length=20, choices=EstadoActivo.choices, default=EstadoActivo.ACTIVA)

    class Meta:
        db_table = 'rutas'
        verbose_name = 'Ruta'
        verbose_name_plural = 'Rutas'
        ordering = ['nombre']

    def __str__(self):
        return self.nombre


class Paradero(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    nombre = models.CharField(max_length=120)
    direccion = models.TextField(blank=True, default='')
    latitud = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    longitud = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    estado = models.CharField(
        max_length=20,
        choices=[('ACTIVO', 'Activo'), ('INACTIVO', 'Inactivo')],
        default='ACTIVO',
    )

    class Meta:
        db_table = 'paraderos'
        verbose_name = 'Paradero'
        verbose_name_plural = 'Paraderos'
        ordering = ['nombre']

    def __str__(self):
        return self.nombre


class RutaParadero(models.Model):
    class TipoParadero(models.TextChoices):
        ORIGEN = 'ORIGEN', 'Origen'
        INTERMEDIO = 'INTERMEDIO', 'Intermedio'
        DESTINO = 'DESTINO', 'Destino'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    ruta = models.ForeignKey(Ruta, on_delete=models.CASCADE, related_name='paraderos_rel')
    paradero = models.ForeignKey(Paradero, on_delete=models.PROTECT, related_name='rutas_rel')
    orden = models.PositiveIntegerField()
    tipo = models.CharField(max_length=20, choices=TipoParadero.choices)
    tiempo_estimado_min = models.IntegerField(null=True, blank=True)

    class Meta:
        db_table = 'ruta_paraderos'
        verbose_name = 'Paradero en ruta'
        verbose_name_plural = 'Paraderos por ruta'
        constraints = [
            models.UniqueConstraint(fields=['ruta', 'orden'], name='uq_ruta_orden'),
            models.UniqueConstraint(fields=['ruta', 'paradero'], name='uq_ruta_paradero'),
        ]
        ordering = ['ruta', 'orden']

    def __str__(self):
        return f'{self.ruta.nombre} #{self.orden}: {self.paradero.nombre}'


class TarifaTramo(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    ruta = models.ForeignKey(Ruta, on_delete=models.CASCADE, related_name='tarifas')
    paradero_origen = models.ForeignKey(
        Paradero, on_delete=models.PROTECT, related_name='tarifas_como_origen'
    )
    paradero_destino = models.ForeignKey(
        Paradero, on_delete=models.PROTECT, related_name='tarifas_como_destino'
    )
    precio = models.DecimalField(max_digits=10, decimal_places=2)
    estado = models.CharField(max_length=20, choices=EstadoActivo.choices, default=EstadoActivo.ACTIVA)

    class Meta:
        db_table = 'tarifas_tramo'
        verbose_name = 'Tarifa por tramo'
        verbose_name_plural = 'Tarifas por tramo'
        constraints = [
            models.UniqueConstraint(
                fields=['ruta', 'paradero_origen', 'paradero_destino'],
                name='uq_tarifa_ruta_tramo',
            ),
        ]
        ordering = ['ruta', 'paradero_origen', 'paradero_destino']

    def __str__(self):
        return f'{self.ruta.nombre}: {self.paradero_origen.nombre} → {self.paradero_destino.nombre} S/{self.precio}'
