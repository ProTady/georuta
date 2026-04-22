"""Carga datos iniciales: ruta Sayán–Huacho con 4 paraderos y tarifas por tramo."""
from decimal import Decimal

from django.core.management.base import BaseCommand
from django.db import transaction

from apps.routes.models import Paradero, Ruta, RutaParadero, TarifaTramo


class Command(BaseCommand):
    help = 'Crea la ruta Sayán-Huacho con sus paraderos y tarifas base.'

    @transaction.atomic
    def handle(self, *args, **options):
        paraderos_data = [
            ('Sayán', 'Plaza de Armas de Sayán', Decimal('-11.1370000'), Decimal('-77.1830000')),
            ('Intermedio 1', 'Cruce intermedio 1 (por definir)', None, None),
            ('Intermedio 2', 'Cruce intermedio 2 (por definir)', None, None),
            ('Huacho', 'Terminal Huacho', Decimal('-11.1070000'), Decimal('-77.6060000')),
        ]

        paraderos = {}
        for nombre, direccion, lat, lon in paraderos_data:
            obj, created = Paradero.objects.get_or_create(
                nombre=nombre,
                defaults={'direccion': direccion, 'latitud': lat, 'longitud': lon},
            )
            paraderos[nombre] = obj
            self.stdout.write(
                self.style.SUCCESS(f'  {"+" if created else "="} Paradero: {nombre}')
            )

        ruta, created = Ruta.objects.get_or_create(
            nombre='Sayán - Huacho',
            defaults={
                'origen_nombre': 'Sayán',
                'destino_nombre': 'Huacho',
                'distancia_km': Decimal('55.00'),
                'duracion_estimada_min': 75,
            },
        )
        self.stdout.write(
            self.style.SUCCESS(f'  {"+" if created else "="} Ruta: {ruta.nombre}')
        )

        orden_paraderos = [
            ('Sayán', 1, RutaParadero.TipoParadero.ORIGEN, 0),
            ('Intermedio 1', 2, RutaParadero.TipoParadero.INTERMEDIO, 25),
            ('Intermedio 2', 3, RutaParadero.TipoParadero.INTERMEDIO, 50),
            ('Huacho', 4, RutaParadero.TipoParadero.DESTINO, 75),
        ]
        for nombre, orden, tipo, tiempo in orden_paraderos:
            RutaParadero.objects.get_or_create(
                ruta=ruta,
                paradero=paraderos[nombre],
                defaults={'orden': orden, 'tipo': tipo, 'tiempo_estimado_min': tiempo},
            )
        self.stdout.write(self.style.SUCCESS(f'  = {len(orden_paraderos)} paraderos vinculados'))

        # Tarifa base uniforme S/ 8 para cualquier tramo origen→destino válido.
        precio_base = Decimal('8.00')
        tarifas_creadas = 0
        orden_nombres = ['Sayán', 'Intermedio 1', 'Intermedio 2', 'Huacho']
        for i, origen in enumerate(orden_nombres):
            for destino in orden_nombres[i + 1:]:
                _, created = TarifaTramo.objects.get_or_create(
                    ruta=ruta,
                    paradero_origen=paraderos[origen],
                    paradero_destino=paraderos[destino],
                    defaults={'precio': precio_base},
                )
                if created:
                    tarifas_creadas += 1
        self.stdout.write(
            self.style.SUCCESS(f'  + {tarifas_creadas} tarifas nuevas (S/{precio_base} por tramo)')
        )

        self.stdout.write(self.style.SUCCESS('\n✓ Seed completado.'))
