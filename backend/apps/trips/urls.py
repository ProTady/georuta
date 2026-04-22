from django.urls import path

from .views import RutaListView, TripSearchView

urlpatterns = [
    path('routes/', RutaListView.as_view(), name='route-list'),
    path('trips/search/', TripSearchView.as_view(), name='trip-search'),
]
