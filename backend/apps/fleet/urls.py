from django.urls import path

from .views import ConductoresListView, VehiculoLayoutView, VehiculosListView

urlpatterns = [
    path('fleet/vehiculos/', VehiculosListView.as_view(), name='vehiculos-list'),
    path('fleet/vehiculos/<uuid:pk>/layout/',
         VehiculoLayoutView.as_view(), name='vehiculo-layout'),
    path('fleet/conductores/', ConductoresListView.as_view(), name='conductores-list'),
]
