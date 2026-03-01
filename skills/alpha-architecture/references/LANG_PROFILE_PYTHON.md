# Language Profile: Python / FastAPI

> Used by auto-build, init-project, and SKILL.md when backend_language = python-fastapi

---

## Runtime

| Property          | Value                                              |
|-------------------|----------------------------------------------------|
| Language          | Python 3.11+                                       |
| Framework         | FastAPI (fully async, Pydantic v2)                 |
| ASGI Server (dev) | Uvicorn (`uvicorn[standard]`)                      |
| ASGI Server (prod)| Gunicorn + UvicornWorker                           |
| Package Manager   | pip                                                |
| Dependency File   | `requirements.txt` + `requirements-dev.txt`        |
| Virtual Env       | `python -m venv venv`                              |
| Python Style      | Fully async (`async def`), type-annotated, PEP 8   |
| Config Management | Pydantic `BaseSettings` with `.env` files          |

---

## Directory Structure

### Core (always scaffolded)

```
project-root/
├── app/
│   ├── __init__.py
│   ├── main.py                      # FastAPI app factory with lifespan
│   ├── config.py                    # Pydantic BaseSettings (all env vars)
│   │
│   ├── api/
│   │   ├── __init__.py
│   │   └── v1/
│   │       ├── __init__.py
│   │       ├── router.py            # Central APIRouter (includes all sub-routers)
│   │       ├── health.py            # GET /health liveness probe
│   │       ├── auth.py              # Auth endpoints (register, login, refresh, logout)
│   │       ├── users.py             # User CRUD endpoints
│   │       └── admin/
│   │           ├── __init__.py
│   │           └── users.py         # Admin-only user management
│   │
│   ├── services/
│   │   ├── __init__.py
│   │   ├── auth_service.py          # Authentication business logic
│   │   └── user_service.py          # User business logic
│   │
│   ├── repositories/
│   │   ├── __init__.py
│   │   └── sql/
│   │       ├── __init__.py
│   │       └── user_repo.py         # MySQL user CRUD
│   │
│   ├── models/
│   │   ├── __init__.py
│   │   └── sql/
│   │       ├── __init__.py
│   │       ├── base.py              # Declarative base + common mixins (id, timestamps)
│   │       └── user.py              # User SQLAlchemy model
│   │
│   ├── schemas/
│   │   ├── __init__.py
│   │   ├── common.py               # SuccessResponse, ErrorResponse, PaginationParams
│   │   └── user.py                  # UserCreate, UserUpdate, UserResponse
│   │
│   ├── core/
│   │   ├── __init__.py
│   │   ├── security.py             # JWT creation, extraction, password hashing
│   │   ├── exceptions.py           # Custom exceptions + global handler
│   │   ├── logging_config.py       # structlog JSON logging + request ID
│   │   └── deps.py                 # FastAPI dependency functions
│   │
│   └── db/
│       ├── __init__.py
│       └── mysql.py                # AsyncSession engine + sessionmaker
│
├── migrations/                     # Alembic migration versions
│   ├── env.py
│   ├── script.py.mako
│   └── versions/
│
├── tests/
│   ├── __init__.py
│   ├── conftest.py                 # Fixtures (test DB, async client, auth headers)
│   ├── unit/
│   │   └── test_user_service.py
│   ├── integration/
│   │   └── test_auth_endpoints.py
│   └── e2e/
│
├── scripts/
│   └── seed.py                     # Database seeding script
│
├── docker/
│   ├── Dockerfile
│   └── docker-compose.yml
│
├── requirements.txt
├── requirements-dev.txt
├── pyproject.toml
├── alembic.ini
├── Makefile
├── .env.example
├── .gitignore
└── CLAUDE.md
```

### Conditional directories (create only when feature is detected)

```
app/
├── models/nosql/                   # (if MongoDB) PyMongo document schemas
├── models/cache/                   # (if Redis) Redis key schemas
├── repositories/nosql/             # (if MongoDB) MongoDB data access
├── repositories/cache/             # (if Redis) Redis data access
├── templates/emails/               # (if Email) Jinja2 HTML email templates
├── tasks/                          # (if Celery) Async tasks
│   ├── email_tasks.py
│   ├── search_tasks.py
│   └── backup_tasks.py
├── db/mongodb.py                   # (if MongoDB) PyMongo client
├── db/redis.py                     # (if Redis) redis.asyncio pool
├── core/oauth.py                   # (if Social Login) authlib Google OAuth2
├── core/razorpay_client.py         # (if Payments) Razorpay SDK init
├── core/permissions.py             # (if RBAC) require_role, require_permission
├── core/rate_limiter.py            # (if Redis) Sliding window rate limiter
├── core/websocket_manager.py       # (if WebSocket) Connection manager + Redis pub/sub
└── ai/                             # (if --with-ai) Full GenAI stack
    ├── config.py                   # LiteLLM model registry + fallback chains
    ├── gateway.py                  # Unified LLM gateway
    ├── prompts/                    # Jinja2/YAML prompt templates
    ├── agents/                     # ADK / LangGraph / CrewAI agents
    ├── rag/                        # Embed, chunk, retrieve, rerank
    ├── memory/                     # Conversation + long-term memory
    ├── guardrails/                 # Input/output filters + cost caps
    ├── mcp/                        # MCP server (tools + prompts)
    ├── a2a/                        # A2A Agent Card + task handler
    ├── eval/                       # DeepEval + RAGAS test harness
    ├── structured/                 # instructor + Pydantic extraction
    ├── cache/                      # Semantic caching (Redis + embeddings)
    ├── reranker/                   # Cohere Rerank / FlashRank
    ├── multimodal/                 # Vision, image gen, audio
    ├── hitl/                       # Human-in-the-Loop review queue
    ├── context/                    # Context window management (tiktoken)
    ├── voice/                      # STT + TTS + WebSocket streaming
    └── batch/                      # Celery batch AI ops + progress
```

---

## Core Dependencies (requirements.txt)

```txt
# ── Core (always install) ──────────────────────────────────
fastapi>=0.115.0
uvicorn[standard]>=0.30.0
gunicorn>=22.0.0
pydantic>=2.0.0
pydantic-settings>=2.0.0
python-multipart>=0.0.9
python-jose[cryptography]>=3.3.0
passlib[bcrypt]>=1.7.4
sqlalchemy[asyncio]>=2.0.0
asyncmy>=0.2.9
alembic>=1.13.0
httpx>=0.27.0
python-dotenv>=1.0.0
structlog>=24.0.0
```

---

## Conditional Dependencies

Uncomment only the groups matching the project's feature profile.

```txt
# ── MongoDB (flexible docs, logs, audit trails) ───────────
# pymongo>=4.7.0

# ── Redis (caching, rate limiting, JWT blacklist) ──────────
# redis>=5.0.0

# ── Payments / Razorpay (India SaaS billing) ──────────────
# razorpay>=1.4.0

# ── Social Login / OAuth2 ─────────────────────────────────
# authlib>=1.3.0

# ── Transactional Email ───────────────────────────────────
# fastapi-mail>=1.4.0
# jinja2>=3.1.0
# itsdangerous>=2.1.0
# celery[redis]>=5.4.0
# flower>=2.0.0

# ── File Upload (S3 / GCS) ────────────────────────────────
# boto3>=1.34.0
# Pillow>=10.3.0

# ── Full-Text Search ──────────────────────────────────────
# meilisearch>=0.31.0

# ── Real-Time WebSocket ───────────────────────────────────
# python-socketio>=5.11.0

# ── Push Notifications (Mobile) ───────────────────────────
# firebase-admin>=6.5.0

# ── Error Tracking ────────────────────────────────────────
# sentry-sdk[fastapi]>=2.0.0

# ── Analytics ──────────────────────────────────────────────
# posthog>=3.5.0

# ── Two-Factor Auth (TOTP) ────────────────────────────────
# pyotp>=2.9.0
# qrcode[pil]>=7.4.0

# ── GenAI / Agentic AI ────────────────────────────────────
# litellm>=1.81.0
# google-adk>=0.5.0
# langgraph>=0.4.0
# crewai>=0.152.0
# qdrant-client>=1.12.0
# langfuse>=2.50.0
# tiktoken>=0.8.0
# mcp>=1.0.0
# a2a-sdk>=0.3.0
# instructor>=1.7.0
# deepeval>=1.5.0
# ragas>=0.2.0
# cohere>=5.13.0
# flashrank>=0.2.0
# elevenlabs>=1.17.0
# promptfoo>=0.1.0
```

---

## Dev Dependencies (requirements-dev.txt)

```txt
-r requirements.txt
pytest>=8.0.0
pytest-asyncio>=0.23.0
pytest-cov>=5.0.0
httpx>=0.27.0
ruff>=0.5.0
mypy>=1.10.0
factory-boy>=3.3.0
faker>=25.0.0
bandit>=1.7.0
pip-audit>=2.7.0
fakeredis>=2.21.0
moto[s3]>=5.0.0
playwright>=1.44.0
```

---

## Config Files

### pyproject.toml

```toml
[project]
name = "app"
version = "0.1.0"
requires-python = ">=3.11"

[tool.ruff]
target-version = "py311"
line-length = 120
src = ["app"]

[tool.ruff.lint]
select = [
    "E",    # pycodestyle errors
    "W",    # pycodestyle warnings
    "F",    # pyflakes
    "I",    # isort
    "B",    # flake8-bugbear
    "C4",   # flake8-comprehensions
    "UP",   # pyupgrade
    "SIM",  # flake8-simplify
    "TCH",  # flake8-type-checking
    "RUF",  # ruff-specific rules
]
ignore = ["E501"]

[tool.ruff.lint.isort]
known-first-party = ["app"]

[tool.mypy]
python_version = "3.11"
strict = true
plugins = ["pydantic.mypy"]
disallow_untyped_defs = true
warn_return_any = true
warn_unused_configs = true

[[tool.mypy.overrides]]
module = ["uvicorn.*", "celery.*", "redis.*", "pymongo.*"]
ignore_missing_imports = true

[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]
addopts = "-v --tb=short --cov=app --cov-report=term-missing --cov-fail-under=80"
filterwarnings = ["ignore::DeprecationWarning"]
```

### .env.example

```env
# ── Application ────────────────────────────────────────────
APP_NAME=MyApp
APP_ENV=development
DEBUG=true
BACKEND_URL=http://localhost:8000
FRONTEND_URL=http://localhost:3000
SECRET_KEY=change-me-in-production

# ── MySQL ──────────────────────────────────────────────────
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWORD=root
MYSQL_DATABASE=app_db

# ── Auth / JWT ─────────────────────────────────────────────
JWT_SECRET_KEY=change-me-in-production
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7

# ── MongoDB (if applicable) ───────────────────────────────
# MONGO_URI=mongodb://localhost:27017
# MONGO_DATABASE=app_db

# ── Redis (if applicable) ─────────────────────────────────
# REDIS_URL=redis://localhost:6379/0

# ── Google OAuth2 (if applicable) ─────────────────────────
# GOOGLE_CLIENT_ID=
# GOOGLE_CLIENT_SECRET=
# GOOGLE_REDIRECT_URI=http://localhost:8000/api/v1/auth/google/callback

# ── Email SMTP (if applicable) ────────────────────────────
# EMAIL_SMTP_HOST=smtp.gmail.com
# EMAIL_SMTP_PORT=587
# EMAIL_SMTP_USERNAME=
# EMAIL_SMTP_PASSWORD=
# EMAIL_SMTP_TLS=true
# EMAIL_FROM=noreply@yourdomain.com
# EMAIL_FROM_NAME=MyApp

# ── Razorpay (if applicable) ──────────────────────────────
# RAZORPAY_KEY_ID=
# RAZORPAY_KEY_SECRET=
# RAZORPAY_WEBHOOK_SECRET=

# ── AWS S3 (if applicable) ────────────────────────────────
# AWS_ACCESS_KEY_ID=
# AWS_SECRET_ACCESS_KEY=
# AWS_S3_BUCKET=
# AWS_REGION=ap-south-1

# ── Sentry (if applicable) ────────────────────────────────
# SENTRY_DSN=

# ── GenAI (if applicable) ─────────────────────────────────
# LITELLM_MASTER_KEY=
# OPENAI_API_KEY=
# ANTHROPIC_API_KEY=
# GOOGLE_API_KEY=
# QDRANT_HOST=localhost
# QDRANT_PORT=6333
# QDRANT_API_KEY=
# LANGFUSE_HOST=http://localhost:3001
# LANGFUSE_PUBLIC_KEY=
# LANGFUSE_SECRET_KEY=
```

### Makefile

```makefile
.PHONY: dev test lint format migrate seed docker-up docker-down

dev:
	uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

test:
	pytest tests/ -v --cov=app --cov-fail-under=80

lint:
	ruff check app/ tests/
	mypy app/

format:
	ruff check app/ tests/ --fix
	ruff format app/ tests/

migrate:
	alembic upgrade head

migrate-new:
	alembic revision --autogenerate -m "$(msg)"

seed:
	python scripts/seed.py

docker-up:
	docker compose -f docker/docker-compose.yml up -d --build

docker-down:
	docker compose -f docker/docker-compose.yml down -v

security:
	bandit -r app/ -c pyproject.toml
	pip-audit
```

### alembic.ini

Key settings (the full file is generated by `alembic init`):

```ini
[alembic]
script_location = migrations
sqlalchemy.url = driver://user:pass@localhost/dbname
# Overridden at runtime by env.py using config.MYSQL_URL
```

---

## Entry Point (app/main.py)

```python
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.sessions import SessionMiddleware

from app.api.v1.router import api_router
from app.config import settings
from app.core.exceptions import register_exception_handlers
from app.core.logging_config import setup_logging
from app.db.mysql import engine


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Startup and shutdown events."""
    setup_logging()

    # ── Startup ────────────────────────────────────────────
    # Verify MySQL connectivity
    async with engine.begin() as conn:
        await conn.execute("SELECT 1")

    # (if MongoDB) from app.db.mongodb import mongo_client
    # mongo_client.admin.command("ping")

    # (if Redis) from app.db.redis import redis_pool
    # await redis_pool.ping()

    yield

    # ── Shutdown ───────────────────────────────────────────
    await engine.dispose()
    # (if Redis) await redis_pool.close()


def create_app() -> FastAPI:
    """Application factory."""
    app = FastAPI(
        title=settings.APP_NAME,
        version="0.1.0",
        docs_url="/docs" if settings.DEBUG else None,
        redoc_url="/redoc" if settings.DEBUG else None,
        lifespan=lifespan,
    )

    # ── CORS ───────────────────────────────────────────────
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[settings.FRONTEND_URL],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # ── Session middleware (required for OAuth2 state) ─────
    app.add_middleware(
        SessionMiddleware,
        secret_key=settings.SECRET_KEY,
    )

    # ── Exception handlers ─────────────────────────────────
    register_exception_handlers(app)

    # ── Routes ─────────────────────────────────────────────
    app.include_router(api_router, prefix="/api/v1")

    return app


app = create_app()
```

---

## Database Config (app/db/mysql.py)

```python
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.config import settings

# ── Async engine (asyncmy driver for MySQL) ────────────────
DATABASE_URL = (
    f"mysql+asyncmy://{settings.MYSQL_USER}:{settings.MYSQL_PASSWORD}"
    f"@{settings.MYSQL_HOST}:{settings.MYSQL_PORT}/{settings.MYSQL_DATABASE}"
)

engine = create_async_engine(
    DATABASE_URL,
    echo=settings.DEBUG,
    pool_size=20,
    max_overflow=10,
    pool_pre_ping=True,
    pool_recycle=3600,
)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


async def get_mysql_session():
    """FastAPI dependency that yields a transactional async session."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
```

---

## Auth Config (app/core/security.py)

```python
from datetime import datetime, timedelta, timezone
from uuid import UUID

from fastapi import Request, Response
from jose import JWTError, jwt
from passlib.context import CryptContext

from app.config import settings

# ── Password hashing ──────────────────────────────────────
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    """Hash a plaintext password with bcrypt."""
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    """Verify a password against its bcrypt hash."""
    return pwd_context.verify(plain, hashed)


# ── JWT token creation ────────────────────────────────────
def create_access_token(user_id: UUID) -> str:
    """Create a short-lived access token (30 min default)."""
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
    )
    payload = {"sub": str(user_id), "exp": expire, "type": "access"}
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def create_refresh_token(user_id: UUID) -> str:
    """Create a long-lived refresh token (7 days default)."""
    expire = datetime.now(timezone.utc) + timedelta(
        days=settings.REFRESH_TOKEN_EXPIRE_DAYS
    )
    payload = {"sub": str(user_id), "exp": expire, "type": "refresh"}
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


# ── Cookie helpers ────────────────────────────────────────
def set_auth_cookies(response: Response, access_token: str, refresh_token: str) -> None:
    """Set JWT tokens as HTTP-Only Secure cookies."""
    response.set_cookie(
        key="access_token",
        value=access_token,
        httponly=True,
        secure=True,
        samesite="lax",
        max_age=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        path="/",
    )
    response.set_cookie(
        key="refresh_token",
        value=refresh_token,
        httponly=True,
        secure=True,
        samesite="lax",
        max_age=settings.REFRESH_TOKEN_EXPIRE_DAYS * 86400,
        path="/api/v1/auth/refresh",
    )


def clear_auth_cookies(response: Response) -> None:
    """Remove auth cookies on logout."""
    response.delete_cookie("access_token", path="/")
    response.delete_cookie("refresh_token", path="/api/v1/auth/refresh")


# ── Token extraction from cookie ─────────────────────────
def extract_access_token(request: Request) -> str | None:
    """Read access token from HTTP-only cookie (NEVER from header)."""
    return request.cookies.get("access_token")


def decode_token(token: str) -> dict:
    """Decode and validate a JWT token. Raises JWTError on failure."""
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
        )
        return payload
    except JWTError:
        raise
```

---

## Docker

### Dockerfile

```dockerfile
# ── Stage 1: Builder ──────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: Runtime ──────────────────────────────────────
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /install /usr/local

# Copy application code
COPY app/ ./app/
COPY migrations/ ./migrations/
COPY alembic.ini .

# Non-root user for security
RUN adduser --disabled-password --no-create-home appuser
USER appuser

EXPOSE 8000

CMD ["gunicorn", "app.main:app", \
     "-k", "uvicorn.workers.UvicornWorker", \
     "--bind", "0.0.0.0:8000", \
     "--workers", "4", \
     "--timeout", "120", \
     "--access-logfile", "-"]
```

### docker-compose.yml (dev)

```yaml
version: "3.9"

services:
  app:
    build:
      context: ..
      dockerfile: docker/Dockerfile
    ports:
      - "8000:8000"
    env_file: ../.env
    volumes:
      - ../app:/app/app        # hot-reload in dev
    command: uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
    depends_on:
      mysql:
        condition: service_healthy

  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: app_db
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ── Uncomment per feature profile ───────────────────────

  # mongodb:
  #   image: mongo:7.0
  #   ports:
  #     - "27017:27017"
  #   volumes:
  #     - mongo_data:/data/db

  # redis:
  #   image: redis:7-alpine
  #   ports:
  #     - "6379:6379"
  #   command: redis-server --maxmemory 256mb --maxmemory-policy allkeys-lru

  # meilisearch:
  #   image: getmeili/meilisearch:v1.8
  #   ports:
  #     - "7700:7700"
  #   environment:
  #     MEILI_MASTER_KEY: change-me
  #   volumes:
  #     - meili_data:/meili_data

  # minio:
  #   image: minio/minio:latest
  #   ports:
  #     - "9000:9000"
  #     - "9001:9001"
  #   environment:
  #     MINIO_ROOT_USER: minioadmin
  #     MINIO_ROOT_PASSWORD: minioadmin
  #   command: server /data --console-address ":9001"
  #   volumes:
  #     - minio_data:/data

  # qdrant:
  #   image: qdrant/qdrant:v1.12.0
  #   ports:
  #     - "6333:6333"
  #   volumes:
  #     - qdrant_data:/qdrant/storage

volumes:
  mysql_data:
  # mongo_data:
  # meili_data:
  # minio_data:
  # qdrant_data:
```

---

## Commands

| Task                  | Command                                                              |
|-----------------------|----------------------------------------------------------------------|
| Start dev server      | `uvicorn app.main:app --reload --host 0.0.0.0 --port 8000`          |
| Lint                  | `ruff check app/ tests/`                                             |
| Format                | `ruff format app/ tests/`                                            |
| Type check            | `mypy app/`                                                          |
| Run tests             | `pytest tests/ -v --cov=app --cov-fail-under=80`                     |
| Run single test       | `pytest tests/unit/test_user_service.py -v`                          |
| Migrate (apply)       | `alembic upgrade head`                                               |
| Migrate (new)         | `alembic revision --autogenerate -m "add users table"`               |
| Migrate (rollback)    | `alembic downgrade -1`                                               |
| Security scan         | `bandit -r app/ && pip-audit`                                        |
| Seed database         | `python scripts/seed.py`                                             |
| Docker up             | `docker compose -f docker/docker-compose.yml up -d --build`          |
| Docker down           | `docker compose -f docker/docker-compose.yml down -v`                |
| Celery worker (dev)   | `celery -A app.tasks.celery_app worker --loglevel=info`              |
| Celery beat (dev)     | `celery -A app.tasks.celery_app beat --loglevel=info`                |
| Celery monitor        | `celery -A app.tasks.celery_app flower --port=5555`                  |

---

## Verify (after scaffold)

Run these commands to confirm a scaffolded project is valid:

```bash
# MANDATORY: Create and activate virtual environment FIRST
# ❌ NEVER install packages globally — ALWAYS use venv
python3 -m venv venv && source venv/bin/activate

# Install all dependencies (inside venv)
pip install -r requirements.txt -r requirements-dev.txt

# Lint and type check
ruff check app/
mypy app/

# Verify app loads without errors
python -c "from app.main import app; print('OK')"

# Run test suite (should pass with skeleton tests)
pytest tests/ -v
```

---

## Exception Handling (app/core/exceptions.py)

```python
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse


class AppException(Exception):
    """Base exception for all application errors."""
    status_code: int = 500
    detail: str = "Internal server error"

    def __init__(self, detail: str | None = None):
        self.detail = detail or self.__class__.detail


class NotFoundException(AppException):
    status_code = 404
    detail = "Resource not found"


class UnauthorizedException(AppException):
    status_code = 401
    detail = "Not authenticated"


class ForbiddenException(AppException):
    status_code = 403
    detail = "Permission denied"


class ValidationException(AppException):
    status_code = 422
    detail = "Validation error"


class ConflictException(AppException):
    status_code = 409
    detail = "Resource already exists"


def register_exception_handlers(app: FastAPI) -> None:
    """Register global exception handlers on the FastAPI app."""

    @app.exception_handler(AppException)
    async def app_exception_handler(request: Request, exc: AppException) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content={"success": False, "error": exc.detail},
        )

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
        # Log the full traceback via structlog
        import structlog
        logger = structlog.get_logger()
        logger.exception("unhandled_error", path=str(request.url))
        return JSONResponse(
            status_code=500,
            content={"success": False, "error": "Internal server error"},
        )
```

---

## Config (app/config.py)

```python
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # ── Application ────────────────────────────────────────
    APP_NAME: str = "MyApp"
    APP_ENV: str = "development"
    DEBUG: bool = True
    BACKEND_URL: str = "http://localhost:8000"
    FRONTEND_URL: str = "http://localhost:3000"
    SECRET_KEY: str = "change-me-in-production"

    # ── MySQL ──────────────────────────────────────────────
    MYSQL_HOST: str = "localhost"
    MYSQL_PORT: int = 3306
    MYSQL_USER: str = "root"
    MYSQL_PASSWORD: str = "root"
    MYSQL_DATABASE: str = "app_db"

    # ── JWT ────────────────────────────────────────────────
    JWT_SECRET_KEY: str = "change-me-in-production"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    model_config = {"env_file": ".env", "case_sensitive": True}


settings = Settings()
```

---

## Logging (app/core/logging_config.py)

```python
import logging
import sys
import uuid

import structlog
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response


def setup_logging() -> None:
    """Configure structlog for JSON structured logging."""
    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.stdlib.add_log_level,
            structlog.stdlib.add_logger_name,
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.JSONRenderer(),
        ],
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )
    logging.basicConfig(format="%(message)s", stream=sys.stdout, level=logging.INFO)


class RequestIDMiddleware(BaseHTTPMiddleware):
    """Inject a unique request ID into every log entry."""

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
        structlog.contextvars.clear_contextvars()
        structlog.contextvars.bind_contextvars(request_id=request_id)

        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        return response
```

---

## Dependencies (app/core/deps.py)

```python
from collections.abc import AsyncGenerator
from uuid import UUID

from fastapi import Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import UnauthorizedException
from app.core.security import decode_token, extract_access_token
from app.db.mysql import get_mysql_session
from app.models.sql.user import User


async def get_db(session: AsyncSession = Depends(get_mysql_session)) -> AsyncGenerator[AsyncSession, None]:
    """Alias dependency for MySQL async session."""
    yield session


async def get_current_user(request: Request, db: AsyncSession = Depends(get_mysql_session)) -> User:
    """Extract and validate JWT from HTTP-only cookie. Returns the current user."""
    token = extract_access_token(request)
    if not token:
        raise UnauthorizedException("Missing access token")

    try:
        payload = decode_token(token)
    except Exception:
        raise UnauthorizedException("Invalid or expired token")

    if payload.get("type") != "access":
        raise UnauthorizedException("Invalid token type")

    user_id = UUID(payload["sub"])

    # (if Redis) Check blacklist: if await redis.exists(f"blacklist:{token}"): raise

    from app.repositories.sql.user_repo import UserRepo
    user_repo = UserRepo(db)
    user = await user_repo.get(user_id)
    if not user or not user.is_active:
        raise UnauthorizedException("User not found or inactive")

    return user
```

---

## GenAI Stack

> Scaffolded only when `--with-ai` flag is set or PRD requires AI features.

| Component          | Technology                                          | Package                |
|--------------------|-----------------------------------------------------|------------------------|
| LLM Gateway        | LiteLLM (unified 100+ LLM providers)               | `litellm>=1.81.0`     |
| Agentic Framework  | Google ADK / LangGraph / CrewAI                     | `google-adk>=0.5.0`   |
| Vector DB          | Qdrant (self-hosted or cloud)                       | `qdrant-client>=1.12.0`|
| Embeddings         | `litellm.aembedding` (text-embedding-3-large)       | via `litellm`         |
| Observability      | Langfuse (LLM tracing, cost tracking)               | `langfuse>=2.50.0`    |
| Evaluation         | DeepEval (LLM unit tests) + RAGAS (RAG quality)     | `deepeval`, `ragas`   |
| Structured Output  | instructor + Pydantic (validated LLM extraction)    | `instructor>=1.7.0`   |
| MCP Protocol       | MCP server (tools + prompts + resources)            | `mcp>=1.0.0`          |
| A2A Protocol       | Agent Card + task handler                           | `a2a-sdk>=0.3.0`      |
| Semantic Caching   | Redis + embedding cosine similarity (>0.95)         | via `redis`           |
| Re-ranking         | Cohere Rerank v3.5 / FlashRank                      | `cohere`, `flashrank` |
| Context Management | tiktoken + auto-summarization                       | `tiktoken>=0.8.0`     |
| Voice AI           | Whisper STT + OpenAI/Gemini/ElevenLabs TTS          | via `litellm`         |
| Batch Processing   | Celery + Redis progress tracking                    | via `celery`          |
| Prompt Management  | Jinja2/YAML templates in `app/ai/prompts/`          | via `jinja2`          |

### GenAI Gateway (app/ai/gateway.py)

```python
import litellm
from app.ai.config import MODEL_REGISTRY, FALLBACK_CHAIN

async def generate(
    prompt: str,
    model_tier: str = "smart",
    stream: bool = False,
    **kwargs,
):
    """Unified LLM generation via LiteLLM with automatic fallbacks."""
    model = MODEL_REGISTRY.get(model_tier, MODEL_REGISTRY["smart"])
    return await litellm.acompletion(
        model=model,
        messages=[{"role": "user", "content": prompt}],
        stream=stream,
        fallbacks=FALLBACK_CHAIN,
        **kwargs,
    )

async def embed(text: str | list[str], model: str = "text-embedding-3-large"):
    """Generate embeddings via LiteLLM."""
    return await litellm.aembedding(model=model, input=text)
```

### GenAI Config (app/ai/config.py)

```python
MODEL_REGISTRY: dict[str, str] = {
    "fast": "gpt-4o-mini",
    "smart": "claude-sonnet-4-6",
    "premium": "claude-opus-4-6",
    "gemini": "gemini/gemini-2.5-pro",
    "local": "ollama/llama3.2",
}

FALLBACK_CHAIN: list[str] = [
    "claude-sonnet-4-6",
    "gpt-4o",
    "gemini/gemini-2.5-pro",
]

# Cost per 1K tokens (input/output) for point deduction calculation
MODEL_COSTS: dict[str, dict[str, float]] = {
    "gpt-4o-mini":        {"input": 0.00015, "output": 0.0006},
    "claude-sonnet-4-6":  {"input": 0.003,   "output": 0.015},
    "claude-opus-4-6":    {"input": 0.015,   "output": 0.075},
    "gemini/gemini-2.5-pro": {"input": 0.00125, "output": 0.005},
}
```

---

## Import Rules (Layer Enforcement)

```
app/api/        -> CAN import: services/, schemas/, core/, deps.py
app/services/   -> CAN import: repositories/, schemas/, core/, models/, OTHER services/
app/repositories/ -> CAN import: models/, db/, schemas/
app/models/     -> CAN import: NOTHING (or other models)
app/schemas/    -> CAN import: NOTHING (standalone Pydantic models)
app/core/       -> CAN import: config.py, schemas/
```

Violations of these import rules indicate a layer segregation bug. The `api/` layer must remain thin controllers that delegate to `services/`. Services must never import from `api/`. Repositories must never contain business logic.

---

## File Naming Conventions

| Layer        | Convention         | Example                           |
|--------------|--------------------|-----------------------------------|
| Models       | Singular noun      | `user.py`, `order.py`             |
| Repositories | `*_repo.py`        | `user_repo.py`, `order_repo.py`   |
| Services     | `*_service.py`     | `user_service.py`, `auth_service.py` |
| Schemas      | Singular noun      | `user.py` (UserCreate, UserUpdate, UserResponse) |
| API routes   | Plural noun        | `users.py`, `orders.py`           |
| Tests        | `test_*.py`        | `test_user_service.py`, `test_auth_endpoints.py` |
| Tasks        | `*_tasks.py`       | `email_tasks.py`, `backup_tasks.py` |
| Migrations   | Auto-generated     | `001_add_users_table.py`          |

---

## Testing Conventions

```python
# tests/conftest.py — shared fixtures
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker

from app.main import app
from app.db.mysql import get_mysql_session

TEST_DATABASE_URL = "mysql+asyncmy://root:root@localhost:3306/app_test_db"

test_engine = create_async_engine(TEST_DATABASE_URL, echo=False)
TestSessionLocal = async_sessionmaker(bind=test_engine, class_=AsyncSession, expire_on_commit=False)


@pytest_asyncio.fixture
async def db_session():
    async with TestSessionLocal() as session:
        yield session
        await session.rollback()


@pytest_asyncio.fixture
async def client(db_session):
    async def override_session():
        yield db_session

    app.dependency_overrides[get_mysql_session] = override_session
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
    app.dependency_overrides.clear()
```

---

## Security Checklist (auto-build verification)

- [ ] JWT tokens stored in HTTP-Only Secure cookies only
- [ ] CORS restricted to `FRONTEND_URL` (no wildcard in production)
- [ ] Password hashing via bcrypt (`passlib`)
- [ ] CSRF double-submit cookie pattern enabled
- [ ] Rate limiting on auth endpoints (via Redis)
- [ ] SQL injection prevention (SQLAlchemy parameterized queries)
- [ ] Input validation on all endpoints (Pydantic schemas)
- [ ] Secrets in `.env` only, never committed to git
- [ ] Non-root user in Docker container
- [ ] Swagger docs disabled in production (`docs_url=None`)
- [ ] Structured logging with request ID propagation
- [ ] `bandit` SAST scan passing
- [ ] `pip-audit` dependency vulnerability scan clean
