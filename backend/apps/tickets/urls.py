from django.urls import path

from .views import (
    BoletoDetalleView,
    CancelarReservaView,
    ConfirmarReservaView,
    MisBoletosView,
    MisReservasView,
    ReservarView,
    ViajeDetalleView,
)

urlpatterns = [
    # Detalle de viaje con asientos
    path('trips/viajes/<uuid:pk>/', ViajeDetalleView.as_view(), name='viaje-detalle'),
    path('trips/viajes/<uuid:pk>/reservar/', ReservarView.as_view(), name='viaje-reservar'),

    # Reservas
    path('reservas/mis/', MisReservasView.as_view(), name='mis-reservas'),
    path('reservas/<uuid:pk>/confirmar/', ConfirmarReservaView.as_view(), name='reserva-confirmar'),
    path('reservas/<uuid:pk>/cancelar/', CancelarReservaView.as_view(), name='reserva-cancelar'),

    # Boletos
    path('boletos/mis/', MisBoletosView.as_view(), name='mis-boletos'),
    path('boletos/<uuid:pk>/', BoletoDetalleView.as_view(), name='boleto-detalle'),
]
