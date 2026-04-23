from django.db.models.signals import post_save
from django.dispatch import receiver

from apps.trips.models import Viaje

from .models import Asiento


@receiver(post_save, sender=Viaje)
def crear_asientos_para_viaje(sender, instance: Viaje, created, **kwargs):
    """Al crear un Viaje, materializa sus asientos.

    Usa el layout del vehículo si existe (numeración explícita por celdas
    tipo ASIENTO); en caso contrario, cae al legacy 1..capacidad_total.
    """
    if not created:
        return
    if not instance.capacidad_total:
        return
    if instance.asientos.exists():
        return
    vehiculo = instance.vehiculo
    numeros = (vehiculo.asientos_desde_layout()
               if vehiculo else list(range(1, instance.capacidad_total + 1)))
    if not numeros:
        numeros = list(range(1, instance.capacidad_total + 1))
    Asiento.objects.bulk_create(
        [Asiento(viaje=instance, numero=n) for n in numeros]
    )
