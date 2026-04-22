import uuid

from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin
from django.db import models

from .managers import UserManager


class User(AbstractBaseUser, PermissionsMixin):
    class Role(models.TextChoices):
        PASAJERO = 'PASAJERO', 'Pasajero'
        CONDUCTOR = 'CONDUCTOR', 'Conductor'
        ADMIN = 'ADMIN', 'Administrador'

    class Estado(models.TextChoices):
        ACTIVO = 'ACTIVO', 'Activo'
        INACTIVO = 'INACTIVO', 'Inactivo'
        BLOQUEADO = 'BLOQUEADO', 'Bloqueado'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    telefono = models.CharField(max_length=20, unique=True)
    email = models.EmailField(max_length=120, blank=True, null=True, unique=True)

    nombres = models.CharField(max_length=120)
    apellidos = models.CharField(max_length=120, blank=True, default='')

    role = models.CharField(
        max_length=20,
        choices=Role.choices,
        default=Role.PASAJERO,
    )
    estado = models.CharField(
        max_length=20,
        choices=Estado.choices,
        default=Estado.ACTIVO,
    )

    is_staff = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)

    fecha_registro = models.DateTimeField(auto_now_add=True)
    ultimo_acceso = models.DateTimeField(blank=True, null=True)

    objects = UserManager()

    USERNAME_FIELD = 'telefono'
    REQUIRED_FIELDS = ['nombres']

    class Meta:
        db_table = 'usuarios'
        verbose_name = 'Usuario'
        verbose_name_plural = 'Usuarios'
        ordering = ['-fecha_registro']

    def __str__(self):
        return f'{self.nombres} ({self.telefono})'

    @property
    def full_name(self):
        return f'{self.nombres} {self.apellidos}'.strip()
