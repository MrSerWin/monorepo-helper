#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-fastapi-app" "$@"
header "Python + FastAPI + SQLAlchemy 2 + Alembic + PostgreSQL"

create_project_dir

# ── pyproject.toml ────────────────────────────────────────────
section "Project configuration"
write_file_heredoc pyproject.toml << EOF
[project]
name = "${PROJECT_NAME}"
version = "0.1.0"
description = "FastAPI + SQLAlchemy + PostgreSQL API"
requires-python = ">=3.13"
dependencies = [
    "fastapi[standard]>=0.115.0",
    "uvicorn[standard]>=0.34.0",
    "sqlalchemy[asyncio]>=2.0.40",
    "asyncpg>=0.30.0",
    "alembic>=1.15.0",
    "pydantic>=2.11.0",
    "pydantic-settings>=2.8.0",
    "python-dotenv>=1.0.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.3.0",
    "pytest-asyncio>=1.0.0",
    "httpx>=0.28.0",
    "ruff>=0.11.0",
    "mypy>=1.15.0",
]

[tool.ruff]
target-version = "py313"
line-length = 100

[tool.ruff.lint]
select = ["E", "F", "I", "UP"]

[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]

[tool.mypy]
python_version = "3.13"
strict = true
EOF
success "Created pyproject.toml"

# ── .env ──────────────────────────────────────────────────────
write_file_heredoc .env.example << 'EOF'
DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:5432/app
SYNC_DATABASE_URL=postgresql://postgres:postgres@localhost:5432/app
SECRET_KEY=change-me-to-a-secure-random-string
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

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
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
      DATABASE_URL: postgresql+asyncpg://postgres:postgres@postgres:5432/app
      SYNC_DATABASE_URL: postgresql://postgres:postgres@postgres:5432/app
    depends_on:
      - postgres
    command: uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
    volumes:
      - .:/app

volumes:
  pgdata:
EOF
success "Created docker-compose.yml"

# ── App source files ─────────────────────────────────────────
section "Application source files"

mkdir -p app/routers tests

# app/__init__.py
touch app/__init__.py

# app/config.py
write_file_heredoc app/config.py << 'EOF'
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/app"
    sync_database_url: str = "postgresql://postgres:postgres@localhost:5432/app"
    secret_key: str = "change-me"

    model_config = {"env_file": ".env"}


settings = Settings()
EOF
success "Created app/config.py"

# app/database.py
write_file_heredoc app/database.py << 'EOF'
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.config import settings

engine = create_async_engine(settings.database_url, echo=True)
async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


async def get_db() -> AsyncSession:  # type: ignore[misc]
    async with async_session() as session:
        try:
            yield session
        finally:
            await session.close()
EOF
success "Created app/database.py"

# app/models.py
write_file_heredoc app/models.py << 'EOF'
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, Text, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String, primary_key=True, server_default=func.gen_random_uuid().cast(String))
    email: Mapped[str] = mapped_column(String, unique=True, nullable=False, index=True)
    name: Mapped[str | None] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    posts: Mapped[list["Post"]] = relationship(back_populates="author", cascade="all, delete-orphan")


class Post(Base):
    __tablename__ = "posts"

    id: Mapped[str] = mapped_column(String, primary_key=True, server_default=func.gen_random_uuid().cast(String))
    title: Mapped[str] = mapped_column(String, nullable=False)
    content: Mapped[str | None] = mapped_column(Text, nullable=True)
    published: Mapped[bool] = mapped_column(Boolean, default=False)
    author_id: Mapped[str] = mapped_column(String, ForeignKey("users.id"), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    author: Mapped["User"] = relationship(back_populates="posts")
EOF
success "Created app/models.py"

# app/schemas.py
write_file_heredoc app/schemas.py << 'EOF'
from datetime import datetime

from pydantic import BaseModel, EmailStr


class UserCreate(BaseModel):
    email: EmailStr
    name: str | None = None


class UserResponse(BaseModel):
    id: str
    email: str
    name: str | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class PostCreate(BaseModel):
    title: str
    content: str | None = None
    author_id: str


class PostResponse(BaseModel):
    id: str
    title: str
    content: str | None
    published: bool
    author_id: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
EOF
success "Created app/schemas.py"

# app/routers/__init__.py
touch app/routers/__init__.py

# app/routers/users.py
write_file_heredoc app/routers/users.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import User
from app.schemas import UserCreate, UserResponse

router = APIRouter(prefix="/api/users", tags=["users"])


@router.get("/", response_model=list[UserResponse])
async def list_users(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).order_by(User.created_at.desc()))
    return result.scalars().all()


@router.get("/{user_id}", response_model=UserResponse)
async def get_user(user_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.post("/", response_model=UserResponse, status_code=201)
async def create_user(data: UserCreate, db: AsyncSession = Depends(get_db)):
    user = User(email=data.email, name=data.name)
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


@router.delete("/{user_id}", status_code=204)
async def delete_user(user_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    await db.delete(user)
    await db.commit()
EOF
success "Created app/routers/users.py"

# app/main.py
write_file_heredoc app/main.py << 'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import users

app = FastAPI(
    title="API",
    description="FastAPI + SQLAlchemy + PostgreSQL",
    version="0.1.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(users.router)


@app.get("/health")
async def health():
    return {"status": "ok"}
EOF
success "Created app/main.py"

# ── Alembic ──────────────────────────────────────────────────
section "Alembic migrations"

mkdir -p alembic/versions

write_file_heredoc alembic.ini << 'EOF'
[alembic]
script_location = alembic
prepend_sys_path = .
sqlalchemy.url = %(SYNC_DATABASE_URL)s

[loggers]
keys = root,sqlalchemy,alembic

[handlers]
keys = console

[formatters]
keys = generic

[logger_root]
level = WARN
handlers = console

[logger_sqlalchemy]
level = WARN
handlers =
qualname = sqlalchemy.engine

[logger_alembic]
level = INFO
handlers =
qualname = alembic

[handler_console]
class = StreamHandler
args = (sys.stderr,)
level = NOTSET
formatter = generic

[formatter_generic]
format = %(levelname)-5.5s [%(name)s] %(message)s
datefmt = %H:%M:%S
EOF
success "Created alembic.ini"

write_file_heredoc alembic/env.py << 'EOF'
import os
from logging.config import fileConfig

from alembic import context
from dotenv import load_dotenv
from sqlalchemy import engine_from_config, pool

from app.models import Base

load_dotenv()

config = context.config
config.set_main_option("sqlalchemy.url", os.getenv("SYNC_DATABASE_URL", ""))

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(url=url, target_metadata=target_metadata, literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
EOF
success "Created alembic/env.py"

write_file_heredoc alembic/script.py.mako << 'EOF'
"""${message}

Revision ID: ${up_revision}
Revises: ${down_revision | comma,n}
Create Date: ${create_date}
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
${imports if imports else ""}

revision: str = ${repr(up_revision)}
down_revision: Union[str, None] = ${repr(down_revision)}
branch_labels: Union[str, Sequence[str], None] = ${repr(branch_labels)}
depends_on: Union[str, Sequence[str], None] = ${repr(depends_on)}


def upgrade() -> None:
    ${upgrades if upgrades else "pass"}


def downgrade() -> None:
    ${downgrades if downgrades else "pass"}
EOF
success "Created alembic/script.py.mako"

# ── Tests ────────────────────────────────────────────────────
touch tests/__init__.py

write_file_heredoc tests/test_health.py << 'EOF'
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"
EOF
success "Created tests/test_health.py"

# ── Finalize ──────────────────────────────────────────────────
section "Finalizing"
write_gitignore ".env" "*.pyc" "__pycache__/" ".venv/" "*.egg-info/"
write_editorconfig
init_git

write_readme "$PROJECT_NAME" \
  "Python + FastAPI + SQLAlchemy 2 + Alembic + PostgreSQL API" \
  "pip install -e '.[dev]'" \
  "uvicorn app.main:app --reload"

finish "pip install -e '.[dev]'" "docker compose up -d postgres && alembic upgrade head && uvicorn app.main:app --reload"
