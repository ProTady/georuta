from django.urls import path

from .views import (
    AbrirViajeView,
    CancelarViajeDriverView,
    RutaListView,
    SalirViajeView,
    TripSearchView,
    ViajesAbiertosView,
)

urlpatterns = [
    path('routes/', RutaListView.as_view(), name='route-list'),
    path('trips/search/', TripSearchView.as_view(), name='trip-search'),
    # Pooling (Fase 4)
    path('trips/abiertos/', ViajesAbiertosView.as_view(), name='trips-abiertos'),
    path('driver/viajes/abrir/', AbrirViajeView.as_view(), name='driver-abrir'),
    path('driver/viajes/<uuid:pk>/salir/', SalirViajeView.as_view(), name='driver-salir'),
    path('driver/viajes/<uuid:pk>/cancelar/',
         CancelarViajeDriverView.as_view(), name='driver-cancelar'),
]
