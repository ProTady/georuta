"""Resetea datos de demo: borra tickets/reservas/viajes/flota y recrea vehículos,
conductores y la ruta inversa Huacho → Sayán. Deja paraderos/rutas/usuarios
pasajeros intactos."""
from datetime import date
from decimal import Decimal

from django.core.management.base import BaseCommand
from django.db import transaction

from apps.fleet.models import Conductor, Vehiculo
from apps.routes.models import Paradero, Ruta, RutaParadero, TarifaTramo
from apps.tickets.models import Asiento, Boleto, Reserva, ReservaAsiento
from apps.trips.models import Horario, Viaje
from apps.users.models import User


class Command(BaseCommand):
    help = (
        'Limpia tickets/reservas/viajes/flota. Recrea 2 vehículos (10 y 6), '
        '2 conductores y la ruta inversa Huacho-Sayán con tarifas S/8.'
    )

    @transaction.atomic
    def handle(self, *args, **options):
        self._purgar_tickets()
        self._purgar_viajes_y_flota()
        self._crear_vehiculos()
        self._crear_conductores()
        self._crear_ruta_inversa()
        self.stdout.write(self.style.SUCCESS('\n✓ Reset demo completado.'))

    # ------------------------------------------------------------------
    def _purgar_tickets(self):
        b = Boleto.objects.count()
        ra = ReservaAsiento.objects.count()
        r = Reserva.objects.count()
        a = Asiento.objects.count()
        Boleto.objects.all().delete()
        ReservaAsiento.objects.all().delete()
        Reserva.objects.all().delete()
        Asiento.objects.all().delete()
        self.stdout.write(
            f'  · Eliminados: {b} boletos, {r} reservas ({ra} items), {a} asientos'
        )

    def _purgar_viajes_y_flota(self):
        h = Horario.objects.count()
        v = Viaje.objects.count()
        veh = Vehiculo.objects.count()
        c = Conductor.objects.count()
        Viaje.objects.all().delete()
        Horario.objects.all().delete()
        Vehiculo.objects.all().delete()
        # Conductores: primero borramos solo los objetos Conductor (no los usuarios).
        Conductor.objects.all().delete()
        self.stdout.write(
            f'  · Eliminados: {v} viajes, {h} horarios, {veh} vehículos, {c} conductores'
        )

    # ------------------------------------------------------------------
    def _crear_vehiculos(self):
        especificados = [
            {
                'placa': 'ABC-100',
                'marca': 'Toyota',
                'modelo': 'Hiace',
                'color': 'Blanco',
                'capacidad_asientos': 10,
                'anio': 2022,
            },
            {
                'placa': 'XYZ-200',
                'marca': 'Hyundai',
                'modelo': 'H1',
                'color': 'Gris',
                'capacidad_asientos': 6,
                'anio': 2020,
            },
        ]
        for data in especificados:
            v = Vehiculo.objects.create(estado='ACTIVO', **data)
            self.stdout.write(
                self.style.SUCCESS(
                    f'  + Vehículo {v.placa} ({v.capacidad_asientos} asientos)'
                )
            )

    def _crear_conductores(self):
        conductores_data = [
            {
                'telefono': '999000001',
                'nombres': 'Carlos',
                'apellidos': 'Mendoza',
                'licencia_numero': 'LIC-000001',
                'licencia_categoria': 'A-IIIB',
            },
            {
                'telefono': '999000002',
                'nombres': 'Luis',
                'apellidos': 'Ramírez',
                'licencia_numero': 'LIC-000002',
                'licencia_categoria': 'A-IIIB',
            },
        ]
        for d in conductores_data:
            user, created = User.objects.get_or_create(
                telefono=d['telefono'],
                defaults={
                    'nombres': d['nombres'],
                    'apellidos': d['apellidos'],
                    'role': 'CONDUCTOR',
                },
            )
            if created:
                user.set_password('Conductor123')
                user.save()
            else:
                # Asegurar rol CONDUCTOR aunque el user existiera.
                if user.role != 'CONDUCTOR':
                    user.role = 'CONDUCTOR'
                    user.save(update_fields=['role'])

            Conductor.objects.create(
                usuario=user,
                licencia_numero=d['licencia_numero'],
                licencia_categoria=d['licencia_categoria'],
                licencia_vencimiento=date(2028, 12, 31),
                estado='ACTIVO',
            )
            self.stdout.write(
                self.style.SUCCESS(
                    f'  + Conductor {user.nombres} {user.apellidos} '
                    f'(tel {user.telefono}, pass: Conductor123)'
                )
            )

    # ------------------------------------------------------------------
    def _crear_ruta_inversa(self):
        try:
            sayan = Paradero.objects.get(nombre='Sayán')
            intermedio1 = Paradero.objects.get(nombre='Intermedio 1')
            intermedio2 = Paradero.objects.get(nombre='Intermedio 2')
            huacho = Paradero.objects.get(nombre='Huacho')
        except Paradero.DoesNotExist:
            self.stdout.write(
                self.style.WARNING('  ! Faltan paraderos base. Corre seed_georuta primero.')
            )
            return

        ruta, created = Ruta.objects.get_or_create(
            nombre='Huacho - Sayán',
            defaults={
                'origen_nombre': 'Huacho',
                'destino_nombre': 'Sayán',
                'distancia_km': Decimal('55.00'),
                'duracion_estimada_min': 75,
            },
        )
        self.stdout.write(
            self.style.SUCCESS(f'  {"+" if created else "="} Ruta: {ruta.nombre}')
        )

        orden = [
            (huacho, 1, RutaParadero.TipoParadero.ORIGEN, 0),
            (intermedio2, 2, RutaParadero.TipoParadero.INTERMEDIO, 25),
            (intermedio1, 3, RutaParadero.TipoParadero.INTERMEDIO, 50),
            (sayan, 4, RutaParadero.TipoParadero.DESTINO, 75),
        ]
        for paradero, ord_, tipo, tiempo in orden:
            RutaParadero.objects.get_or_create(
                ruta=ruta,
                paradero=paradero,
                defaults={'orden': ord_, 'tipo': tipo, 'tiempo_estimado_min': tiempo},
            )

        # Tarifas S/8 entre pares válidos (en orden).
        precio = Decimal('8.00')
        pares = [
            (huacho, intermedio2),
            (huacho, intermedio1),
            (huacho, sayan),
            (intermedio2, intermedio1),
            (intermedio2, sayan),
            (intermedio1, sayan),
        ]
        n = 0
        for o, d in pares:
            _, c = TarifaTramo.objects.get_or_create(
                ruta=ruta,
                paradero_origen=o,
                paradero_destino=d,
                defaults={'precio': precio},
            )
            if c:
                n += 1
        self.stdout.write(self.style.SUCCESS(f'  + {n} tarifas nuevas en ruta inversa'))
