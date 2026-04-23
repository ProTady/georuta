from django.apps import AppConfig


class TicketsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'apps.tickets'
    verbose_name = 'Tickets (reservas y boletos)'

    def ready(self):
        # Importar signals para que se registren.
        from . import signals  # noqa: F401
