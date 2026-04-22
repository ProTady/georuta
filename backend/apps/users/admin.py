from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin

from .models import User


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    ordering = ('-fecha_registro',)
    list_display = ('telefono', 'nombres', 'apellidos', 'email', 'role', 'estado', 'is_staff')
    list_filter = ('role', 'estado', 'is_staff', 'is_active')
    search_fields = ('telefono', 'email', 'nombres', 'apellidos')

    fieldsets = (
        (None, {'fields': ('telefono', 'password')}),
        ('Datos personales', {'fields': ('nombres', 'apellidos', 'email')}),
        ('Rol y estado', {'fields': ('role', 'estado')}),
        ('Permisos', {'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
        ('Fechas', {'fields': ('last_login', 'fecha_registro', 'ultimo_acceso')}),
    )
    readonly_fields = ('last_login', 'fecha_registro', 'ultimo_acceso')

    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('telefono', 'nombres', 'apellidos', 'email', 'role', 'password1', 'password2'),
        }),
    )
