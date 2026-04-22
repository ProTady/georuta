from django.contrib import admin

from .models import Paradero, Ruta, RutaParadero, TarifaTramo


class RutaParaderoInline(admin.TabularInline):
    model = RutaParadero
    extra = 0
    fields = ('orden', 'paradero', 'tipo', 'tiempo_estimado_min')
    ordering = ('orden',)


class TarifaTramoInline(admin.TabularInline):
    model = TarifaTramo
    extra = 0
    fields = ('paradero_origen', 'paradero_destino', 'precio', 'estado')


@admin.register(Ruta)
class RutaAdmin(admin.ModelAdmin):
    list_display = ('nombre', 'origen_nombre', 'destino_nombre', 'distancia_km', 'estado')
    list_filter = ('estado',)
    search_fields = ('nombre', 'origen_nombre', 'destino_nombre')
    inlines = [RutaParaderoInline, TarifaTramoInline]


@admin.register(Paradero)
class ParaderoAdmin(admin.ModelAdmin):
    list_display = ('nombre', 'direccion', 'estado')
    list_filter = ('estado',)
    search_fields = ('nombre', 'direccion')


@admin.register(RutaParadero)
class RutaParaderoAdmin(admin.ModelAdmin):
    list_display = ('ruta', 'orden', 'paradero', 'tipo', 'tiempo_estimado_min')
    list_filter = ('ruta', 'tipo')
    ordering = ('ruta', 'orden')


@admin.register(TarifaTramo)
class TarifaTramoAdmin(admin.ModelAdmin):
    list_display = ('ruta', 'paradero_origen', 'paradero_destino', 'precio', 'estado')
    list_filter = ('ruta', 'estado')
    search_fields = ('ruta__nombre',)
