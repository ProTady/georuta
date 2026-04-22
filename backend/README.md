# GeoRuta – Backend (Django + DRF)

API REST para el aplicativo GeoRuta.

## Requisitos

- Python 3.10+
- PostgreSQL local corriendo
- Una base de datos llamada `georuta` (o el nombre que pongas en `.env`)

## Setup (primera vez)

```bash
cd backend

# 1. Crear virtualenv
python -m venv .venv
.venv\Scripts\activate       # Windows
# source .venv/bin/activate  # Linux/Mac

# 2. Instalar dependencias
pip install -r requirements.txt

# 3. Configurar variables de entorno
copy .env.example .env       # Windows
# cp .env.example .env       # Linux/Mac
# -> edita .env con tu password de PostgreSQL

# 4. Crear la base de datos en PostgreSQL
# Desde psql o pgAdmin:
#   CREATE DATABASE georuta;

# 5. Aplicar migraciones base de Django
python manage.py migrate

# 6. Crear superusuario para el admin
python manage.py createsuperuser

# 7. Levantar servidor de desarrollo
python manage.py runserver
```

## Verificación rápida

- Health check: http://127.0.0.1:8000/api/health/ → `{"status": "ok"}`
- Admin: http://127.0.0.1:8000/admin/

## Estructura

```
backend/
├── config/              # Settings y URLs raíz
├── apps/                # Apps de negocio (se añadirán por fase)
├── manage.py
├── requirements.txt
└── .env                 # No versionar
```

## Siguiente fase

Fase 1: crear la app `apps.users` con modelo custom de usuario + endpoints de registro y login (JWT).
