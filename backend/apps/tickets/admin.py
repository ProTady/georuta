from django.contrib import admin

from .models import Asiento, Boleto, Reserva, ReservaAsiento


@admin.register(Asiento)
class AsientoAdmin(admin.ModelAdmin):
    list_display = ('viaje', 'numero')
    list_filter = ('viaje__fecha_viaje', 'viaje__ruta')
    search_fields = ('viaje__id',)
    autocomplete_fields = ('viaje',)


class ReservaAsientoInline(admin.TabularInline):
    model = ReservaAsiento
    extra = 0
    autocomplete_fields = ('asiento',)
    readonly_fields = ('precio',)


@admin.register(Reserva)
class ReservaAdmin(admin.ModelAdmin):
    list_display = (
        'id', 'usuario', 'viaje', 'estado', 'total',
        'fecha_creacion', 'expira_en',
    )
    list_filter = ('estado', 'viaje__fecha_viaje')
    search_fields = ('id', 'usuario__telefono', 'usuario__email')
    autocomplete_fields = ('usuario', 'viaje', 'paradero_origen', 'paradero_destino')
    readonly_fields = ('fecha_creacion', 'fecha_confirmacion')
    inlines = [ReservaAsientoInline]


@admin.register(Boleto)
class BoletoAdmin(admin.ModelAdmin):
    list_display = (
        'id', 'usuario', 'viaje', 'asiento', 'estado', 'precio', 'fecha_emision',
    )
    list_filter = ('estado', 'viaje__fecha_viaje')
    search_fields = ('id', 'qr_token', 'usuario__telefono')
    autocomplete_fields = ('reserva', 'usuario', 'viaje', 'asiento',
                           'paradero_origen', 'paradero_destino')
    readonly_fields = ('qr_token', 'fecha_emision', 'fecha_uso')
