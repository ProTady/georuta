from django.contrib.auth import authenticate, get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import serializers
from rest_framework_simplejwt.tokens import RefreshToken

User = get_user_model()


class UserSerializer(serializers.ModelSerializer):
    """Representación pública del usuario (GET /me)."""

    class Meta:
        model = User
        fields = (
            'id',
            'telefono',
            'email',
            'nombres',
            'apellidos',
            'role',
            'estado',
            'fecha_registro',
        )
        read_only_fields = fields


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = User
        fields = ('telefono', 'email', 'nombres', 'apellidos', 'password')
        extra_kwargs = {
            'email': {'required': False, 'allow_blank': True, 'allow_null': True},
            'apellidos': {'required': False, 'allow_blank': True},
        }

    def validate_telefono(self, value):
        value = (value or '').strip()
        if not value:
            raise serializers.ValidationError('El teléfono es obligatorio.')
        if User.objects.filter(telefono=value).exists():
            raise serializers.ValidationError('Ya existe una cuenta con ese teléfono.')
        return value

    def validate_email(self, value):
        if not value:
            return None
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError('Ya existe una cuenta con ese email.')
        return value

    def validate_password(self, value):
        try:
            validate_password(value)
        except DjangoValidationError as exc:
            raise serializers.ValidationError(list(exc.messages))
        return value

    def create(self, validated_data):
        password = validated_data.pop('password')
        return User.objects.create_user(password=password, **validated_data)


class LoginSerializer(serializers.Serializer):
    telefono = serializers.CharField()
    password = serializers.CharField(write_only=True)

    def validate(self, attrs):
        telefono = attrs.get('telefono', '').strip()
        password = attrs.get('password')

        user = authenticate(
            request=self.context.get('request'),
            telefono=telefono,
            password=password,
        )
        if not user:
            raise serializers.ValidationError(
                {'detail': 'Credenciales inválidas.'}
            )
        if not user.is_active or user.estado != User.Estado.ACTIVO:
            raise serializers.ValidationError(
                {'detail': 'La cuenta no está activa.'}
            )

        attrs['user'] = user
        return attrs


def tokens_for_user(user):
    refresh = RefreshToken.for_user(user)
    return {
        'access': str(refresh.access_token),
        'refresh': str(refresh),
    }
