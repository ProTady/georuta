from django.contrib import admin

from .models import Horario, Viaje


@admin.register(Horario)
class HorarioAdmin(admin.ModelAdmin):
    list_display = ('ruta', 'hora_salida', 'dias_semana', 'tarifa_base', 'estado')
    list_filter = ('ruta', 'estado')
    search_fields = ('ruta__nombre',)


@admin.register(Viaje)
class ViajeAdmin(admin.ModelAdmin):
    list_display = (
        'ruta',
        'fecha_viaje',
        'hora_salida_programada',
        'vehiculo',
        'conductor',
        'capacidad_total',
        'asientos_disponibles',
        'estado',
    )
    list_filter = ('estado', 'fecha_viaje', 'ruta')
    search_fields = ('ruta__nombre', 'vehiculo__placa')
    date_hierarchy = 'fecha_viaje'
    autocomplete_fields = ('vehiculo', 'conductor')
    readonly_fields = ('hora_salida_real', 'hora_llegada_real')
    fieldsets = (
        (None, {'fields': ('ruta', 'horario', 'vehiculo', 'conductor')}),
        ('Fechas', {'fields': ('fecha_viaje', 'hora_salida_programada', 'hora_salida_real', 'hora_llegada_real')}),
        ('Capacidad', {'fields': ('capacidad_total', 'asientos_disponibles')}),
        ('Estado', {'fields': ('estado', 'observaciones')}),
    )
