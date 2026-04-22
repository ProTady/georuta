from django.contrib import admin

from .models import Conductor, Vehiculo


@admin.register(Vehiculo)
class VehiculoAdmin(admin.ModelAdmin):
    list_display = ('placa', 'marca', 'modelo', 'color', 'capacidad_asientos', 'estado')
    list_filter = ('estado', 'marca')
    search_fields = ('placa', 'marca', 'modelo')


@admin.register(Conductor)
class ConductorAdmin(admin.ModelAdmin):
    list_display = ('usuario', 'licencia_numero', 'licencia_categoria', 'licencia_vencimiento', 'estado')
    list_filter = ('estado', 'licencia_categoria')
    search_fields = ('usuario__nombres', 'usuario__apellidos', 'licencia_numero')
    autocomplete_fields = ('usuario',)
