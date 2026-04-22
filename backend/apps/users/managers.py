from django.contrib.auth.base_user import BaseUserManager


class UserManager(BaseUserManager):
    """Manager para el usuario custom que usa telefono como identificador."""

    use_in_migrations = True

    def _create_user(self, telefono, password, **extra_fields):
        if not telefono:
            raise ValueError('El teléfono es obligatorio.')
        telefono = telefono.strip()
        email = extra_fields.pop('email', None)
        if email:
            email = self.normalize_email(email)
        user = self.model(telefono=telefono, email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_user(self, telefono, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', False)
        extra_fields.setdefault('is_superuser', False)
        return self._create_user(telefono, password, **extra_fields)

    def create_superuser(self, telefono, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('role', 'ADMIN')

        if extra_fields.get('is_staff') is not True:
            raise ValueError('Superuser debe tener is_staff=True.')
        if extra_fields.get('is_superuser') is not True:
            raise ValueError('Superuser debe tener is_superuser=True.')

        return self._create_user(telefono, password, **extra_fields)
