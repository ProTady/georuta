import secrets
import uuid
from datetime import timedelta

from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models
from django.utils import timezone

from apps.routes.models import Paradero
from apps.trips.models import Viaje


# Ventana de reserva: el usuario tiene 10 minutos para confirmar el pago.
RESERVA_TTL_MINUTOS = 10


def default_expira_en():
    return timezone.now() + timedelta(minutes=RESERVA_TTL_MINUTOS)


def generate_qr_token() -> str:
    # 43 chars url-safe, no guessable.
    return secrets.token_urlsafe(32)


class Asiento(models.Model):
    """Un asiento físico de un Viaje (se crea en lote al crear el Viaje)."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    viaje = models.ForeignKey(Viaje, on_delete=models.CASCADE, related_name='asientos')
    numero = models.PositiveIntegerField()

    class Meta:
        db_table = 'asientos'
        verbose_name = 'Asiento'
        verbose_name_plural = 'Asientos'
        ordering = ['viaje', 'numero']
        constraints = [
            models.UniqueConstraint(fields=['viaje', 'numero'], name='uq_asiento_viaje_numero'),
        ]

    def __str__(self):
        return f'Asiento {self.numero} · {self.viaje}'


class Reserva(models.Model):
    class Estado(models.TextChoices):
        PENDIENTE = 'PENDIENTE', 'Pendiente de pago'
        CONFIRMADA = 'CONFIRMADA', 'Confirmada'
        EXPIRADA = 'EXPIRADA', 'Expirada'
        CANCELADA = 'CANCELADA', 'Cancelada'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    usuario = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name='reservas',
    )
    viaje = models.ForeignKey(Viaje, on_delete=models.PROTECT, related_name='reservas')

    paradero_origen = models.ForeignKey(
        Paradero, on_delete=models.PROTECT, related_name='reservas_origen'
    )
    paradero_destino = models.ForeignKey(
        Paradero, on_delete=models.PROTECT, related_name='reservas_destino'
    )

    asientos = models.ManyToManyField(
        Asiento, through='ReservaAsiento', related_name='reservas'
    )

    total = models.DecimalField(max_digits=10, decimal_places=2)

    estado = models.CharField(
        max_length=20, choices=Estado.choices, default=Estado.PENDIENTE
    )
    fecha_creacion = models.DateTimeField(auto_now_add=True)
    expira_en = models.DateTimeField(default=default_expira_en)
    fecha_confirmacion = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'reservas'
        verbose_name = 'Reserva'
        verbose_name_plural = 'Reservas'
        ordering = ['-fecha_creacion']
        indexes = [
            models.Index(fields=['usuario', 'estado'], name='idx_reserva_usuario_estado'),
            models.Index(fields=['viaje', 'estado'], name='idx_reserva_viaje_estado'),
        ]

    def __str__(self):
        return f'Reserva {self.id} ({self.estado})'

    def clean(self):
        super().clean()
        if self.paradero_origen_id and self.paradero_destino_id:
            if self.paradero_origen_id == self.paradero_destino_id:
                raise ValidationError('Origen y destino deben ser distintos.')

    @property
    def esta_expirada(self) -> bool:
        return (
            self.estado == self.Estado.PENDIENTE
            and timezone.now() >= self.expira_en
        )


class ReservaAsiento(models.Model):
    """Tabla intermedia Reserva ↔ Asiento (un asiento = un boleto potencial)."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    reserva = models.ForeignKey(Reserva, on_delete=models.CASCADE, related_name='items')
    asiento = models.ForeignKey(Asiento, on_delete=models.PROTECT, related_name='items_reserva')
    precio = models.DecimalField(max_digits=10, decimal_places=2)

    class Meta:
        db_table = 'reserva_asientos'
        constraints = [
            models.UniqueConstraint(fields=['reserva', 'asiento'], name='uq_reserva_asiento'),
        ]

    def __str__(self):
        return f'{self.reserva_id} · asiento {self.asiento.numero}'


class Boleto(models.Model):
    class Estado(models.TextChoices):
        VIGENTE = 'VIGENTE', 'Vigente'
        USADO = 'USADO', 'Usado (abordado)'
        ANULADO = 'ANULADO', 'Anulado'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    reserva = models.ForeignKey(Reserva, on_delete=models.PROTECT, related_name='boletos')
    usuario = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name='boletos'
    )
    viaje = models.ForeignKey(Viaje, on_delete=models.PROTECT, related_name='boletos')
    asiento = models.OneToOneField(
        Asiento, on_delete=models.PROTECT, related_name='boleto'
    )

    paradero_origen = models.ForeignKey(
        Paradero, on_delete=models.PROTECT, related_name='boletos_origen'
    )
    paradero_destino = models.ForeignKey(
        Paradero, on_delete=models.PROTECT, related_name='boletos_destino'
    )

    precio = models.DecimalField(max_digits=10, decimal_places=2)
    qr_token = models.CharField(max_length=64, unique=True, default=generate_qr_token)
    estado = models.CharField(
        max_length=20, choices=Estado.choices, default=Estado.VIGENTE
    )
    fecha_emision = models.DateTimeField(auto_now_add=True)
    fecha_uso = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'boletos'
        verbose_name = 'Boleto'
        verbose_name_plural = 'Boletos'
        ordering = ['-fecha_emision']
        indexes = [
            models.Index(fields=['usuario', 'estado'], name='idx_boleto_usuario_estado'),
        ]

    def __str__(self):
        return f'Boleto {self.id} · asiento {self.asiento.numero}'
