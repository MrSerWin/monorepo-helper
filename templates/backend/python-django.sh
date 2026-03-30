#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-django-app" "$@"
header "Python + Django 5 + DRF + PostgreSQL + Docker"

create_project_dir

# ── pyproject.toml ────────────────────────────────────────────
section "Project configuration"
write_file_heredoc pyproject.toml << EOF
[project]
name = "${PROJECT_NAME}"
version = "0.1.0"
description = "Django 5 + DRF + PostgreSQL API"
requires-python = ">=3.13"
dependencies = [
    "django>=5.2",
    "djangorestframework>=3.15.0",
    "django-cors-headers>=4.7.0",
    "django-filter>=25.1",
    "psycopg[binary]>=3.2.0",
    "python-dotenv>=1.0.0",
    "gunicorn>=23.0.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.3.0",
    "pytest-django>=4.9.0",
    "ruff>=0.11.0",
    "mypy>=1.15.0",
    "django-stubs>=5.2.0",
    "djangorestframework-stubs>=3.15.0",
]

[tool.ruff]
target-version = "py313"
line-length = 100

[tool.ruff.lint]
select = ["E", "F", "I", "UP", "DJ"]

[tool.pytest.ini_options]
DJANGO_SETTINGS_MODULE = "config.settings"
python_files = ["test_*.py"]
python_classes = ["Test*"]
python_functions = ["test_*"]

[tool.mypy]
python_version = "3.13"
plugins = ["mypy_django_plugin.main", "mypy_drf_plugin.main"]
strict = true

[tool.django-stubs]
django_settings_module = "config.settings"
EOF
success "Created pyproject.toml"

# ── .env ──────────────────────────────────────────────────────
write_file_heredoc .env.example << 'EOF'
DEBUG=True
SECRET_KEY=change-me-to-a-secure-random-string
DATABASE_URL=postgres://postgres:postgres@localhost:5432/app
ALLOWED_HOSTS=localhost,127.0.0.1
EOF
success "Created .env.example"
cp .env.example .env

# ── Docker ───────────────────────────────────────────────────
section "Docker configuration"

write_file_heredoc Dockerfile << 'EOF'
FROM python:3.13-slim

WORKDIR /app

RUN pip install --no-cache-dir uv

COPY pyproject.toml ./
RUN uv pip install --system -e ".[dev]"

COPY . .

RUN python manage.py collectstatic --noinput || true

EXPOSE 8000

CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000"]
EOF
success "Created Dockerfile"

write_file_heredoc docker-compose.yml << 'EOF'
services:
  postgres:
    image: postgres:17-alpine
    restart: unless-stopped
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: app
    volumes:
      - pgdata:/var/lib/postgresql/data

  app:
    build: .
    ports:
      - "8000:8000"
    environment:
      DEBUG: "True"
      SECRET_KEY: "dev-secret-key"
      DATABASE_URL: "postgres://postgres:postgres@postgres:5432/app"
      ALLOWED_HOSTS: "*"
    depends_on:
      - postgres
    command: python manage.py runserver 0.0.0.0:8000
    volumes:
      - .:/app

volumes:
  pgdata:
EOF
success "Created docker-compose.yml"

# ── manage.py ────────────────────────────────────────────────
section "Application source files"

write_file_heredoc manage.py << 'EOF'
#!/usr/bin/env python
"""Django's command-line utility for administrative tasks."""
import os
import sys


def main():
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Couldn't import Django. Are you sure it's installed?"
        ) from exc
    execute_from_command_line(sys.argv)


if __name__ == "__main__":
    main()
EOF
chmod +x manage.py
success "Created manage.py"

# ── config/ ──────────────────────────────────────────────────
mkdir -p config

touch config/__init__.py

# config/settings.py
write_file_heredoc config/settings.py << 'PYEOF'
import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.getenv("SECRET_KEY", "insecure-dev-key")
DEBUG = os.getenv("DEBUG", "False").lower() in ("true", "1", "yes")
ALLOWED_HOSTS = os.getenv("ALLOWED_HOSTS", "localhost,127.0.0.1").split(",")

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # Third party
    "rest_framework",
    "corsheaders",
    "django_filters",
    # Local
    "apps.core",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"

# Database
_db_url = os.getenv("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/app")
_parts = _db_url.replace("postgres://", "").replace("postgresql://", "")
_user_pass, _host_db = _parts.split("@", 1)
_user, _password = _user_pass.split(":", 1)
_host_port, _dbname = _host_db.split("/", 1)
_host_port_parts = _host_port.split(":", 1)
_host = _host_port_parts[0]
_port = _host_port_parts[1] if len(_host_port_parts) > 1 else "5432"

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": _dbname,
        "USER": _user,
        "PASSWORD": _password,
        "HOST": _host,
        "PORT": _port,
    }
}

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# CORS
CORS_ALLOW_ALL_ORIGINS = DEBUG

# DRF
REST_FRAMEWORK = {
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 20,
    "DEFAULT_FILTER_BACKENDS": [
        "django_filters.rest_framework.DjangoFilterBackend",
        "rest_framework.filters.SearchFilter",
        "rest_framework.filters.OrderingFilter",
    ],
}
PYEOF
success "Created config/settings.py"

# config/urls.py
write_file_heredoc config/urls.py << 'EOF'
from django.contrib import admin
from django.urls import include, path
from rest_framework.routers import DefaultRouter

from apps.core.views import ItemViewSet

router = DefaultRouter()
router.register(r"items", ItemViewSet)

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/", include(router.urls)),
    path("api/health/", lambda request: __import__("django.http", fromlist=["JsonResponse"]).JsonResponse({"status": "ok"})),
]
EOF
success "Created config/urls.py"

# config/wsgi.py
write_file_heredoc config/wsgi.py << 'EOF'
import os

from django.core.wsgi import get_wsgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
application = get_wsgi_application()
EOF
success "Created config/wsgi.py"

# ── apps/core/ ───────────────────────────────────────────────
mkdir -p apps/core/migrations

touch apps/__init__.py
touch apps/core/__init__.py
touch apps/core/migrations/__init__.py

# apps/core/models.py
write_file_heredoc apps/core/models.py << 'EOF'
from django.db import models


class Item(models.Model):
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True, default="")
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self) -> str:
        return self.name
EOF
success "Created apps/core/models.py"

# apps/core/serializers.py
write_file_heredoc apps/core/serializers.py << 'EOF'
from rest_framework import serializers

from .models import Item


class ItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = Item
        fields = ["id", "name", "description", "is_active", "created_at", "updated_at"]
        read_only_fields = ["id", "created_at", "updated_at"]
EOF
success "Created apps/core/serializers.py"

# apps/core/views.py
write_file_heredoc apps/core/views.py << 'EOF'
from rest_framework import viewsets
from django_filters.rest_framework import DjangoFilterBackend

from .models import Item
from .serializers import ItemSerializer


class ItemViewSet(viewsets.ModelViewSet):
    queryset = Item.objects.all()
    serializer_class = ItemSerializer
    filterset_fields = ["is_active"]
    search_fields = ["name", "description"]
    ordering_fields = ["name", "created_at"]
EOF
success "Created apps/core/views.py"

# apps/core/admin.py
write_file_heredoc apps/core/admin.py << 'EOF'
from django.contrib import admin

from .models import Item


@admin.register(Item)
class ItemAdmin(admin.ModelAdmin):
    list_display = ["name", "is_active", "created_at"]
    list_filter = ["is_active"]
    search_fields = ["name"]
EOF
success "Created apps/core/admin.py"

# apps/core/apps.py
write_file_heredoc apps/core/apps.py << 'EOF'
from django.apps import AppConfig


class CoreConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.core"
    verbose_name = "Core"
EOF
success "Created apps/core/apps.py"

# ── Tests ────────────────────────────────────────────────────
mkdir -p tests
touch tests/__init__.py

write_file_heredoc tests/test_items.py << 'EOF'
import pytest
from django.test import TestCase
from rest_framework.test import APIClient

from apps.core.models import Item


class ItemAPITestCase(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.item = Item.objects.create(name="Test Item", description="A test item")

    def test_list_items(self):
        response = self.client.get("/api/items/")
        self.assertEqual(response.status_code, 200)

    def test_create_item(self):
        response = self.client.post("/api/items/", {"name": "New Item"}, format="json")
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data["name"], "New Item")

    def test_get_item(self):
        response = self.client.get(f"/api/items/{self.item.pk}/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["name"], "Test Item")

    def test_delete_item(self):
        response = self.client.delete(f"/api/items/{self.item.pk}/")
        self.assertEqual(response.status_code, 204)
EOF
success "Created tests/test_items.py"

# ── Finalize ──────────────────────────────────────────────────
section "Finalizing"
write_gitignore ".env" "*.pyc" "__pycache__/" ".venv/" "*.egg-info/" "staticfiles/" "db.sqlite3"
write_editorconfig
init_git

write_readme "$PROJECT_NAME" \
  "Python + Django 5 + DRF + PostgreSQL API" \
  "pip install -e '.[dev]'" \
  "python manage.py runserver"

finish "pip install -e '.[dev]'" "docker compose up -d postgres && python manage.py migrate && python manage.py runserver"
