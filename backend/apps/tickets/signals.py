from django.db.models.signals import post_save
from django.dispatch import receiver

from apps.trips.models import Viaje

from .models import Asiento


@receiver(post_save, sender=Viaje)
def crear_asientos_para_viaje(sender, instance: Viaje, created, **kwargs):
    """Al crear un Viaje, materializa sus asientos (1..capacidad_total)."""
    if not created:
        return
    if not instance.capacidad_total:
        return
    # Solo si aún no hay asientos (idempotente).
    if instance.asientos.exists():
        return
    Asiento.objects.bulk_create(
        [Asiento(viaje=instance, numero=n) for n in range(1, instance.capacidad_total + 1)]
    )
