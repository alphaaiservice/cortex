---
description: "Generate comprehensive project documentation: README, Architecture Guide, API Reference, Deployment Guide, Contributing Guide, and User Manual. Usage: /gen-docs [--type=readme|architecture|api|deployment|contributing|manual|all] [--format=markdown|docusaurus]"
---

# Comprehensive Documentation Generator

Generate production-quality documentation for this project based on: **$ARGUMENTS**

Parse `$ARGUMENTS` to determine:
- **Type**: `--type=readme` (default if not specified), `--type=architecture`, `--type=api`, `--type=deployment`, `--type=local` (LOCAL_DEV.md), `--type=contributing`, `--type=manual`, or `--type=all` (generates everything)
- **Format**: `--format=markdown` (default) or `--format=docusaurus` (generates Docusaurus-compatible docs site structure)

> **`--type=local` (also part of `all`)** generates **`LOCAL_DEV.md`** per
> `commands/references/LOCAL_DEV_STANDARD.md` §4: one-command quickstart,
> prerequisites + pinned versions, ports table, seed credentials, common `make`
> commands, hybrid native-hot-reload mode, the `make verify` boot check, and the
> full Troubleshooting matrix. Whenever the README is generated it MUST carry a
> top-level "## Run Locally" section (the 3-line quickstart, linking LOCAL_DEV.md).

If no arguments are provided, default to `--type=all --format=markdown` (generate all documentation in standard Markdown).

---

## Step 1: Analyze Project for Documentation

Before generating any documentation, perform a deep project scan. Run all detection tasks in parallel using the Agent tool.

### 1A: Discover Project Identity

```bash
# Project name and metadata
cat package.json 2>/dev/null | grep -E '"name"|"version"|"description"|"license"|"author"'
cat pyproject.toml 2>/dev/null | head -30
cat setup.py 2>/dev/null | head -30
cat Cargo.toml 2>/dev/null | head -20
cat go.mod 2>/dev/null | head -5
```

Extract:
- **Project name** (from package.json name, pyproject.toml project.name, or directory name)
- **Version** (from package.json version, pyproject.toml version, or git tags)
- **Description** (from metadata or README first line)
- **License** (from LICENSE file or metadata)
- **Author/Team** (from metadata, CODEOWNERS, or git log)

### 1B: Scan Project Structure

```bash
# Map the full directory tree (excluding noise)
find . -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/venv/*" \
       -not -path "*/__pycache__/*" -not -path "*/.next/*" -not -path "*/dist/*" \
       -not -path "*/.mypy_cache/*" -not -path "*/.ruff_cache/*" -not -path "*/.pytest_cache/*" \
       -type f | head -300
```

Use Glob to map:
- `**/*.py` — Python source files
- `**/*.ts` and `**/*.tsx` — TypeScript files
- `**/*.js` and `**/*.jsx` — JavaScript files
- `**/Dockerfile*` — Docker configurations
- `**/*.yml` and `**/*.yaml` — YAML configs (CI, Docker Compose, etc.)
- `**/test_*.py` and `**/*.test.ts` and `**/*.spec.ts` — Test files

### 1C: Detect Tech Stack

Run in parallel with Agent subagents:

**Backend detection:**
```
Use Grep to scan for:
- FastAPI: "from fastapi" or "FastAPI()" in *.py
- Flask: "from flask" or "Flask(__name__)" in *.py
- Django: "DJANGO_SETTINGS_MODULE" or "django.setup()" in *.py
- Express: "require('express')" or "from 'express'" in *.js/*.ts
- NestJS: "@nestjs/core" in *.ts
- Spring Boot: "@SpringBootApplication" in *.java
- Go: "net/http" or "gin-gonic" or "fiber" in *.go
```

**Frontend detection:**
```
Use Grep to scan for:
- Next.js: "next.config" files, "@next/" imports
- React: "react-dom" in package.json
- Vue: "vue" in package.json, *.vue files
- Angular: "@angular/core" in package.json
- Svelte: "svelte" in package.json
```

**Database detection:**
```
Use Grep to scan for:
- MySQL/PostgreSQL: "sqlalchemy", "asyncmy", "psycopg", "prisma"
- MongoDB: "pymongo", "motor", "beanie", "mongoose", "mongodb"
- Redis: "redis", "ioredis", "redis.asyncio"
- Meilisearch: "meilisearch"
- Elasticsearch: "elasticsearch"
- Qdrant: "qdrant_client"
```

**Infrastructure detection:**
```
- Docker: Dockerfile, docker-compose.yml
- CI/CD: .github/workflows/, .gitlab-ci.yml
- Cloud: AWS (boto3, @aws-sdk), GCP (google-cloud), Azure
- Monitoring: prometheus, grafana configs
- Error tracking: sentry-sdk, @sentry/
```

### 1D: Read Existing Documentation

Check for and read these files if they exist:
- `CLAUDE.md` — Project context and conventions
- `PRD.md` — Product requirements document
- `PROJECT_ANALYSIS.md` — Previous project analysis
- `README.md` — Existing README (to understand current state)
- `docs/` directory — Any existing documentation
- `CHANGELOG.md` — Change history
- `CONTRIBUTING.md` — Existing contribution guidelines
- `.env.example` or `.env.sample` — Environment variables reference

### 1E: Discover API Endpoints

```
Use Grep to find all route definitions:
- FastAPI: "@app.get|post|put|delete|patch" and "@router.get|post|put|delete|patch" in *.py
- Express: "router.get|post|put|delete|patch" and "app.get|post|put|delete|patch" in *.js/*.ts
- Django: "urlpatterns" and "path(" in urls.py files
- NestJS: "@Get|@Post|@Put|@Delete|@Patch" in *.ts
```

For each endpoint, extract:
- HTTP method and path
- Authentication requirement (look for auth decorators/middleware)
- Request parameters and body schema (from Pydantic models, Zod schemas, or type annotations)
- Response schema
- Description (from docstrings or comments)

### 1F: Discover Features

Scan for feature implementations:
- Authentication: JWT, OAuth, 2FA, session management
- Payments: Stripe, Razorpay integrations
- File upload: S3, presigned URLs
- Search: full-text search integrations
- Real-time: WebSocket, SSE
- Email: transactional email system
- Notifications: push notifications, in-app
- Admin panel: admin routes or admin UI
- i18n: internationalization setup
- Themes: dark mode, theme switching
- AI/ML: LLM integrations, RAG, agents

### 1G: Build Detection Summary

Compile all findings into a detection object to drive documentation generation:

```
DOCUMENTATION CONTEXT:
  Project Name:     [name]
  Version:          [version]
  Description:      [one-line description]
  License:          [license type]
  Backend:          [framework + language + version]
  Frontend:         [framework + version]
  Mobile:           [framework + version or "none"]
  Databases:        [list]
  Cache:            [Redis / none]
  Search:           [Meilisearch / Elasticsearch / none]
  Auth:             [JWT cookies / JWT localStorage / session / OAuth]
  Payments:         [Stripe / Razorpay / none]
  AI/ML:            [LLM provider + framework or "none"]
  Docker:           [yes / no]
  CI/CD:            [platform or "none"]
  Test Framework:   [pytest / jest / vitest / none]
  Linter:           [ruff / eslint / biome / none]
  API Endpoints:    [count]
  Features:         [list of detected features]
  Existing Docs:    [list of existing doc files]
```

---

## Step 2: Generate README.md

**Output file:** `README.md` at project root

Generate a professional, production-quality README. The README should feel polished enough for an open-source project or a professional private repository.

### README Structure

```markdown
<!-- PROJECT LOGO & BADGES -->
<div align="center">
  <h1>[Project Name]</h1>
  <p><strong>[One-line description from detection or metadata]</strong></p>

  <!-- Badges row -->
  <p>
    <a href="[ci-url]"><img src="https://img.shields.io/github/actions/workflow/status/[org]/[repo]/ci.yml?branch=main&style=flat-square&logo=github&label=CI" alt="CI Status"></a>
    <a href="[coverage-url]"><img src="https://img.shields.io/codecov/c/github/[org]/[repo]?style=flat-square&logo=codecov&label=Coverage" alt="Coverage"></a>
    <a href="[license-url]"><img src="https://img.shields.io/badge/License-[type]-blue?style=flat-square" alt="License"></a>
    <a href="[version-url]"><img src="https://img.shields.io/badge/Version-[version]-green?style=flat-square" alt="Version"></a>
    <img src="https://img.shields.io/badge/Python-[version]-3776AB?style=flat-square&logo=python&logoColor=white" alt="Python">
    <!-- Add language/framework badges based on detection -->
  </p>

  <p>
    <a href="#features">Features</a> •
    <a href="#quick-start">Quick Start</a> •
    <a href="#api-overview">API</a> •
    <a href="#deployment">Deployment</a> •
    <a href="#contributing">Contributing</a>
  </p>
</div>

---

## Overview

[2-3 paragraph description of the project. What it does, who it's for, and why it exists.
Pull from PRD.md description if available, otherwise synthesize from code analysis.]

## Features

[List all detected features with brief descriptions. Group by category.]

### Core Features
- **[Feature Name]** — [One-line description of what it does]
- **[Feature Name]** — [One-line description]

### Authentication & Security
- **[Auth type]** — [Description: e.g., "JWT tokens in HTTP-only cookies with automatic refresh"]
- **2FA/TOTP** — [if detected]
- **RBAC** — [if detected]

### Payments & Billing
- **[Payment provider]** — [if detected: subscription, one-time, credit points, etc.]

### AI & Intelligence
- **[AI features]** — [if detected: RAG, agents, chat, etc.]

[Continue for all detected feature categories]

## Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Backend | [FastAPI / Express / etc.] | API server |
| Frontend | [Next.js / React / etc.] | Web application |
| Mobile | [React Native / Expo / etc.] | Mobile apps (if detected) |
| SQL Database | [MySQL / PostgreSQL] | Transactional data |
| NoSQL Database | [MongoDB] | Flexible documents (if detected) |
| Cache | [Redis] | Session cache, rate limiting |
| Search | [Meilisearch] | Full-text search (if detected) |
| Task Queue | [Celery / Bull] | Background jobs (if detected) |
| File Storage | [S3 / MinIO] | File uploads (if detected) |
| AI/LLM | [LiteLLM / OpenAI] | AI features (if detected) |
| CI/CD | [GitHub Actions / GitLab] | Automated pipelines (if detected) |
| Monitoring | [Sentry / Prometheus] | Error and performance tracking (if detected) |

## Quick Start

### Prerequisites

[List based on detection:]
- [Language runtime]: `[version]` (e.g., Python 3.11+, Node.js 20+)
- Docker & Docker Compose (recommended)
- [Database]: [version] (if not using Docker)
- [Other requirements based on detection]

### Installation

```bash
# Clone the repository
git clone [repo-url]
cd [project-name]

# Option 1: Docker (recommended)
docker compose up -d

# Option 2: Local development
[Generate appropriate commands based on detected stack:]

# Backend setup (Python/FastAPI example)
cd backend/
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt

# Frontend setup (Next.js example)
cd frontend/
[pnpm|npm|yarn] install

# Copy environment variables
cp .env.example .env
# Edit .env with your configuration
```

### Configuration

[Generate environment variables table from .env.example if it exists:]

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DATABASE_URL` | Yes | — | MySQL/PostgreSQL connection string |
| `MONGODB_URL` | Yes | — | MongoDB connection string |
| `REDIS_URL` | Yes | `redis://localhost:6379` | Redis connection URL |
| `JWT_SECRET_KEY` | Yes | — | Secret for JWT signing |
| `[OTHER_VARS]` | [Yes/No] | [default] | [description] |

### Running the Application

```bash
# Start all services with Docker
docker compose up -d

# Or run individually:

# Backend
[uvicorn app.main:app --reload --host 0.0.0.0 --port 8000]

# Frontend
[pnpm dev | npm run dev | yarn dev]

# Workers (if Celery/task queue detected)
[celery -A app.celery worker --loglevel=info]
```

### Verify Installation

```bash
# Health check
curl http://localhost:[port]/health

# API docs (if FastAPI)
open http://localhost:[port]/docs
```

## API Overview

[Brief overview of the API structure with key endpoint groups:]

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/auth/register` | Create new account |
| POST | `/api/v1/auth/login` | Authenticate user |
| POST | `/api/v1/auth/refresh` | Refresh access token |
| POST | `/api/v1/auth/logout` | Invalidate session |

[Include 2-3 more endpoint groups as preview]

> Full API reference: [docs/API_REFERENCE.md](docs/API_REFERENCE.md) | Interactive docs: `http://localhost:[port]/docs`

## Project Structure

```
[Generate ASCII tree of actual project structure, keeping it readable:]
[project-name]/
├── [backend-dir]/
│   ├── app/
│   │   ├── api/              # Route handlers (thin controllers)
│   │   ├── services/         # Business logic
│   │   ├── repositories/     # Data access layer
│   │   ├── models/           # Database models
│   │   ├── schemas/          # Pydantic request/response schemas
│   │   ├── core/             # Config, security, exceptions
│   │   └── db/               # Database connections
│   ├── tests/                # Test suite
│   ├── alembic/              # Database migrations
│   └── requirements.txt
├── [frontend-dir]/
│   ├── src/
│   │   ├── app/              # Next.js App Router pages
│   │   ├── components/       # Reusable UI components
│   │   ├── lib/              # Utilities and API client
│   │   └── styles/           # Global styles
│   └── package.json
├── docker-compose.yml
├── .env.example
└── README.md
```

## Testing

```bash
# Run all tests
[pytest -v | pnpm test | npm test]

# Run with coverage
[pytest --cov=app --cov-report=html -v | pnpm test -- --coverage]

# Run specific test file
[pytest tests/test_auth.py -v | pnpm test -- auth.test.ts]

# Lint
[ruff check . | pnpm lint]

# Type check
[mypy . | pnpm type-check | npx tsc --noEmit]
```

## Deployment

For detailed deployment instructions, see [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md).

**Quick deploy with Docker:**
```bash
docker compose -f docker-compose.prod.yml up -d
```

## Contributing

We welcome contributions. Please see [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for guidelines.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'feat: add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

[Detected license type]. See [LICENSE](LICENSE) for details.

## Acknowledgments

- [Team/Author credits from detection]
- Built with [key technologies]
- [Any other acknowledgments]
```

**Important rules for README generation:**
- Only include sections for detected features (do not document things that do not exist)
- All shell commands must match the actual detected package manager and tools
- Environment variable table must come from actual .env.example parsing
- Project structure tree must reflect the actual directory layout
- API overview must list real discovered endpoints
- Badge URLs should use placeholder [org]/[repo] that the user can replace

---

## Step 3: Generate Architecture Documentation

**Output file:** `docs/ARCHITECTURE.md`

Only generate this file if `--type=architecture` or `--type=all` is specified.

```markdown
# Architecture Guide

## Table of Contents
- [System Overview](#system-overview)
- [Service Architecture](#service-architecture)
- [Request Flow](#request-flow)
- [Authentication Flow](#authentication-flow)
- [Database Architecture](#database-architecture)
- [Layer Segregation](#layer-segregation)
- [Key Design Decisions](#key-design-decisions)
- [Technology Rationale](#technology-rationale)

---

## System Overview

[Generate an ASCII diagram showing the high-level system architecture:]

```
┌─────────────────────────────────────────────────────────────┐
│                        CLIENTS                               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                  │
│  │ Web App  │  │ Mobile   │  │ External │                   │
│  │ (Next.js)│  │ (Expo)   │  │ APIs     │                   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘                  │
└───────┼──────────────┼──────────────┼───────────────────────┘
        │              │              │
        ▼              ▼              ▼
┌─────────────────────────────────────────────────────────────┐
│                    LOAD BALANCER / CDN                        │
│  [Nginx / CloudFront / Cloud CDN]                            │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                    API GATEWAY                                │
│  ┌──────────────────────────────────────────────┐           │
│  │  [FastAPI / Express / etc.]                   │           │
│  │  - JWT Authentication                         │           │
│  │  - Rate Limiting                              │           │
│  │  - Request Validation                         │           │
│  │  - CORS / CSRF Protection                     │           │
│  └──────────────────────────────────────────────┘           │
└──────────┬──────────────┬──────────────┬────────────────────┘
           │              │              │
           ▼              ▼              ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│   MySQL      │ │   MongoDB    │ │   Redis      │
│ (ACID data)  │ │ (Documents)  │ │ (Cache)      │
└──────────────┘ └──────────────┘ └──────────────┘
```

[Adjust the diagram based on actual detected services. Only include components that exist in the project.]

## Service Architecture

### Backend Service: [Framework Name]
[Describe the backend service architecture, entry point, middleware stack, and routing structure based on actual code analysis.]

- **Entry Point**: `[detected main file, e.g., app/main.py]`
- **Middleware Stack**: [list detected middleware: CORS, auth, rate limiting, logging, etc.]
- **Router Structure**: [how routes are organized — by module, by version, etc.]
- **Background Workers**: [Celery tasks, cron jobs, if detected]

### Frontend Service: [Framework Name] (if detected)
[Describe the frontend architecture: SSR/CSR/ISR strategy, state management, routing pattern.]

- **Rendering**: [SSR / CSR / ISR / SSG based on Next.js config or framework]
- **State Management**: [Zustand / Redux / Context — from detection]
- **API Communication**: [Axios / fetch / TanStack Query — from detection]
- **Authentication**: [How auth state is managed on the client]

### Mobile Application (if detected)
[Describe mobile architecture: navigation structure, offline strategy, native modules.]

### Data Stores
[For each detected database, describe its role:]

- **[MySQL/PostgreSQL]**: Stores ACID-critical data — [list key tables detected: users, subscriptions, transactions, etc.]
- **[MongoDB]**: Stores flexible documents — [list key collections: profiles, logs, notifications, etc.]
- **[Redis]**: Caching layer — [list key patterns: JWT blacklist, rate limiting, session cache, etc.]
- **[Qdrant/Pinecone]**: Vector store for [RAG/search] — (if detected)
- **[Meilisearch]**: Full-text search index — (if detected)

### Background Processing (if detected)
- **Task Queue**: [Celery / Bull / etc.]
- **Broker**: [Redis / RabbitMQ]
- **Key Tasks**: [list detected background tasks: email sending, data processing, AI inference, etc.]

## Request Flow

[Generate a request flow diagram based on detected architecture pattern:]

```
Client Request
     │
     ▼
┌─────────────┐
│   Middleware  │  ← CORS, Rate Limit, Request ID, Logging
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Auth Guard  │  ← JWT validation, extract user from cookie/header
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  API Layer   │  ← Route handler: validate input, delegate to service
│  (api/)      │     ❌ No business logic here
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Service     │  ← Business logic: orchestrate, validate rules, transform
│  (services/) │     ❌ No direct DB queries here
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Repository  │  ← Data access: CRUD operations, query building
│  (repos/)    │     ❌ No business logic here
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Database    │  ← MySQL / MongoDB / Redis
└─────────────┘
```

[Adjust based on whether the project follows this layered pattern or a different one.]

## Authentication Flow

[Generate auth flow based on detected auth mechanism:]

### Login Flow
```
1. Client → POST /auth/login (email, password)
2. Server validates credentials
3. Server generates JWT (access: [TTL], refresh: [TTL])
4. Server sets HTTP-only cookies (or returns tokens based on detection)
5. Client auto-sends cookies on subsequent requests
```

### Token Refresh Flow
```
1. Access token expires
2. Client receives 401
3. Client auto-retries POST /auth/refresh
4. Server validates refresh token, issues new pair
5. Original request retried with new tokens
```

### OAuth Flow (if detected)
```
1. Client → GET /auth/[provider]
2. Server redirects to [provider] consent screen
3. User authenticates
4. Provider redirects back with auth code
5. Server exchanges code for user info
6. Server creates/finds user, issues JWT
```

## Database Architecture

### Schema Overview

[For each detected database, list discovered models/tables:]

#### [MySQL/PostgreSQL] — Relational Data
| Table | Purpose | Key Fields |
|-------|---------|------------|
| [table_name] | [purpose from model analysis] | [key columns] |

[Include relationships between tables if detectable from foreign keys.]

#### [MongoDB] — Document Data (if detected)
| Collection | Purpose | Key Fields |
|------------|---------|------------|
| [collection_name] | [purpose] | [key fields] |

#### [Redis] — Cache Keys (if detected)
| Key Pattern | Type | TTL | Purpose |
|-------------|------|-----|---------|
| [pattern] | [type] | [ttl] | [purpose] |

### Entity Relationship (Key Relationships)
```
User ──────┬── has many ──→ [Resource]
           ├── has one  ──→ [Profile]
           ├── has many ──→ [Subscription]
           └── has many ──→ [Transaction]
```

## Layer Segregation

[Document the architectural pattern used in this project:]

### Import Rules
```
api/          →  services/     →  repositories/  →  models/ + db/
(controllers)    (business)       (data access)     (entities)

✅ api/ imports from services/
✅ services/ imports from repositories/
✅ repositories/ imports from models/ and db/

❌ api/ NEVER imports from repositories/ directly
❌ services/ NEVER imports from api/
❌ repositories/ NEVER imports from services/
❌ No business logic in api/ layer
❌ No database queries in services/ layer
```

### Layer Responsibilities
| Layer | Location | Responsibility | Imports From |
|-------|----------|---------------|-------------|
| API | `app/api/` | Request validation, response formatting | services/ |
| Service | `app/services/` | Business logic, orchestration | repositories/ |
| Repository | `app/repositories/` | Data access, CRUD | models/, db/ |
| Model | `app/models/` | Entity definitions | — |
| Schema | `app/schemas/` | Request/response Pydantic models | — |
| Core | `app/core/` | Config, security, exceptions | — |

## Key Design Decisions

[Document architectural decisions detected from the codebase:]

### 1. [Decision: e.g., "Async-First Architecture"]
- **Decision**: [What was chosen]
- **Rationale**: [Why — based on framework choice, async patterns found]
- **Trade-off**: [What was given up]

### 2. [Decision: e.g., "Multi-Database Strategy"]
- **Decision**: [MySQL for ACID + MongoDB for flexible data]
- **Rationale**: [Different data types have different storage needs]
- **Trade-off**: [Operational complexity of managing multiple databases]

### 3. [Decision: e.g., "JWT in HTTP-Only Cookies"]
- **Decision**: [How auth tokens are stored]
- **Rationale**: [Security: prevents XSS token theft]
- **Trade-off**: [CSRF protection required, cookie limitations]

[Generate 3-5 decisions based on actual architectural choices found in the code.]

## Technology Rationale

| Technology | Why Chosen | Alternatives Considered |
|-----------|-----------|------------------------|
| [FastAPI] | [Async, auto-docs, Pydantic validation] | Flask, Django, Express |
| [MySQL] | [ACID compliance, mature ecosystem] | PostgreSQL, SQLite |
| [Redis] | [In-memory speed, pub/sub, data structures] | Memcached |
| [etc.] | [reason] | [alternatives] |

[Generate based on detected tech stack. Only include technologies actually found.]
```

---

## Step 4: Generate API Reference

**Output file:** `docs/API_REFERENCE.md`

Only generate this file if `--type=api` or `--type=all` is specified.

```markdown
# API Reference

## Base URL

```
Development: http://localhost:[detected-port]
Production:  https://api.[domain].com
```

## Authentication

[Based on detected auth mechanism:]

All authenticated endpoints require [JWT token in HTTP-only cookie / Bearer token in Authorization header].

```bash
# Login to get authentication
curl -X POST http://localhost:[port]/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "password"}'
```

## Response Format

All responses follow this structure:

```json
{
  "success": true,
  "data": { ... },
  "message": "Operation successful"
}
```

### Error Response
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input",
    "details": [ ... ]
  }
}
```

### Common HTTP Status Codes
| Code | Meaning |
|------|---------|
| 200 | Success |
| 201 | Created |
| 400 | Bad Request — Invalid input |
| 401 | Unauthorized — Missing or invalid auth |
| 403 | Forbidden — Insufficient permissions |
| 404 | Not Found |
| 409 | Conflict — Duplicate resource |
| 422 | Unprocessable Entity — Validation failed |
| 429 | Too Many Requests — Rate limited |
| 500 | Internal Server Error |

---

## Endpoints

[For each endpoint group discovered in Step 1E, generate:]

### [Group Name] — `/api/v1/[group]`

#### `[METHOD] /api/v1/[group]/[path]`

**Description**: [What this endpoint does — from docstring or code analysis]

**Authentication**: [Required / Not Required / Admin Only]

**Rate Limit**: [X requests per minute] (if detectable)

**Request Parameters**:
| Name | In | Type | Required | Description |
|------|------|------|----------|-------------|
| [param] | [path/query/header] | [type] | [Yes/No] | [description] |

**Request Body** (if applicable):
```json
{
  "[field]": "[type] — [description]",
  "[field]": "[type] — [description]"
}
```

**Example Request**:
```bash
curl -X [METHOD] http://localhost:[port]/api/v1/[group]/[path] \
  -H "Content-Type: application/json" \
  -H "Cookie: access_token=<token>" \
  -d '{
    "[field]": "[example_value]"
  }'
```

**Success Response** (`[status_code]`):
```json
{
  "success": true,
  "data": {
    "[field]": "[type]",
    "[field]": "[type]"
  }
}
```

**Error Responses**:
| Code | Error | Description |
|------|-------|-------------|
| 400 | `VALIDATION_ERROR` | [specific validation failure] |
| 401 | `UNAUTHORIZED` | [missing auth] |
| 404 | `NOT_FOUND` | [resource not found] |

---

[Repeat the above block for EVERY discovered endpoint, grouped by module.]

## OpenAPI / Swagger

[If FastAPI detected:]
Interactive API documentation is available at:
- **Swagger UI**: `http://localhost:[port]/docs`
- **ReDoc**: `http://localhost:[port]/redoc`
- **OpenAPI JSON**: `http://localhost:[port]/openapi.json`

## Rate Limiting

[If rate limiting detected, document the limits:]

| Endpoint Group | Limit | Window |
|---------------|-------|--------|
| Auth (login/register) | [X] requests | [Y] minutes |
| General API | [X] requests | [Y] minutes |
| AI endpoints | [X] requests | [Y] minutes |

Rate limit headers returned:
- `X-RateLimit-Limit`: Maximum requests allowed
- `X-RateLimit-Remaining`: Remaining requests in window
- `X-RateLimit-Reset`: Unix timestamp when limit resets

## Pagination

[If pagination pattern detected:]

All list endpoints support cursor-based or offset pagination:

```
GET /api/v1/[resource]?page=1&per_page=20&sort=created_at&order=desc
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `page` | integer | 1 | Page number |
| `per_page` | integer | 20 | Items per page (max 100) |
| `sort` | string | `created_at` | Sort field |
| `order` | string | `desc` | Sort order (asc/desc) |

Response includes pagination metadata:
```json
{
  "data": [...],
  "meta": {
    "page": 1,
    "per_page": 20,
    "total": 150,
    "total_pages": 8
  }
}
```

## WebSocket (if detected)

[Document WebSocket endpoints and events:]

### Connection
```javascript
const socket = io('ws://localhost:[port]', {
  auth: { token: '<access_token>' }
});
```

### Events
| Event | Direction | Payload | Description |
|-------|-----------|---------|-------------|
| [event_name] | Server → Client | `{...}` | [description] |
| [event_name] | Client → Server | `{...}` | [description] |
```

**Important rules for API Reference generation:**
- ONLY document endpoints that actually exist in the codebase
- Extract real Pydantic/Zod schemas for request/response bodies
- Include actual path parameters and query parameters from route definitions
- Group endpoints logically by their router/module structure
- Include authentication requirements based on detected auth decorators

---

## Step 5: Generate Deployment Guide

**Output file:** `docs/DEPLOYMENT.md`

Only generate this file if `--type=deployment` or `--type=all` is specified.

```markdown
# Deployment Guide

## Table of Contents
- [Prerequisites](#prerequisites)
- [Environment Setup](#environment-setup)
- [Docker Deployment](#docker-deployment)
- [Cloud Deployment](#cloud-deployment)
- [Database Setup](#database-setup)
- [SSL/HTTPS Setup](#sslhttps-setup)
- [Monitoring](#monitoring)
- [Backup & Recovery](#backup--recovery)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

- Docker Engine 24+ and Docker Compose v2
- [Cloud CLI: aws-cli / gcloud / az-cli] (for cloud deployment)
- Domain name with DNS access
- SSL certificate (or use Let's Encrypt)
- [List other requirements based on detection]

## Environment Setup

### Required Environment Variables

[Generate comprehensive table from .env.example analysis:]

| Variable | Required | Example | Description |
|----------|----------|---------|-------------|
| `DATABASE_URL` | Yes | `mysql+asyncmy://user:pass@host:3306/db` | Primary database connection |
| `MONGODB_URL` | Yes | `mongodb://user:pass@host:27017/db` | MongoDB connection |
| `REDIS_URL` | Yes | `redis://host:6379/0` | Redis connection |
| `JWT_SECRET_KEY` | Yes | `[generate with: openssl rand -hex 32]` | JWT signing secret |
| `JWT_REFRESH_SECRET` | Yes | `[generate with: openssl rand -hex 32]` | Refresh token secret |
| [Other detected vars] | [Yes/No] | [example] | [description] |

### Generate Secrets
```bash
# Generate secure random secrets
openssl rand -hex 32  # For JWT_SECRET_KEY
openssl rand -hex 32  # For JWT_REFRESH_SECRET
openssl rand -hex 16  # For other secrets
```

## Docker Deployment

### Step 1: Clone and Configure
```bash
git clone [repo-url]
cd [project-name]
cp .env.example .env
# Edit .env with production values
```

### Step 2: Build Images
```bash
docker compose -f docker-compose.prod.yml build
```

### Step 3: Start Services
```bash
# Start all services
docker compose -f docker-compose.prod.yml up -d

# Verify all containers are running
docker compose ps

# Check logs
docker compose logs -f [service-name]
```

### Step 4: Run Migrations
```bash
# Database migrations
docker compose exec [backend-service] [alembic upgrade head | npx prisma migrate deploy]
```

### Step 5: Verify Deployment
```bash
# Health check
curl http://localhost:[port]/health

# Check all services
docker compose ps
```

### Docker Compose Production Config

[Generate a production-ready docker-compose.prod.yml if one doesn't exist, based on detected services:]

```yaml
version: '3.8'

services:
  [backend-service]:
    build:
      context: ./[backend-dir]
      dockerfile: Dockerfile
    ports:
      - "[port]:[port]"
    env_file:
      - .env
    depends_on:
      [database-service]:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:[port]/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  [Add other detected services: frontend, database, redis, etc.]
```

## Cloud Deployment

### AWS Deployment

#### Option A: ECS (Elastic Container Service)
```bash
# 1. Push images to ECR
aws ecr get-login-password --region [region] | docker login --username AWS --password-stdin [account-id].dkr.ecr.[region].amazonaws.com
docker tag [image]:latest [account-id].dkr.ecr.[region].amazonaws.com/[repo]:latest
docker push [account-id].dkr.ecr.[region].amazonaws.com/[repo]:latest

# 2. Create ECS cluster
aws ecs create-cluster --cluster-name [project-name]-cluster

# 3. Register task definition
aws ecs register-task-definition --cli-input-json file://ecs-task-definition.json

# 4. Create service
aws ecs create-service \
  --cluster [project-name]-cluster \
  --service-name [project-name]-service \
  --task-definition [project-name]-task \
  --desired-count 2 \
  --launch-type FARGATE
```

#### Option B: EC2 with Docker Compose
```bash
# 1. SSH into EC2 instance
ssh -i key.pem ec2-user@[ip-address]

# 2. Install Docker
sudo yum update -y && sudo yum install docker docker-compose-plugin -y
sudo systemctl start docker

# 3. Clone and deploy
git clone [repo-url]
cd [project-name]
cp .env.example .env
# Edit .env
docker compose -f docker-compose.prod.yml up -d
```

### GCP Deployment

```bash
# 1. Build and push to Artifact Registry
gcloud builds submit --tag gcr.io/[project-id]/[service-name]

# 2. Deploy to Cloud Run
gcloud run deploy [service-name] \
  --image gcr.io/[project-id]/[service-name] \
  --platform managed \
  --region [region] \
  --allow-unauthenticated \
  --set-env-vars="[KEY1=value1,KEY2=value2]"
```

## Database Setup

### [MySQL/PostgreSQL] Setup

```bash
# Create production database
[mysql -u root -p -e "CREATE DATABASE [db_name]; CREATE USER '[user]'@'%' IDENTIFIED BY '[password]'; GRANT ALL ON [db_name].* TO '[user]'@'%';"]

# Run migrations
[alembic upgrade head | npx prisma migrate deploy]
```

### [MongoDB] Setup (if detected)

```bash
# Create database and user
mongosh --eval '
  use [db_name]
  db.createUser({
    user: "[user]",
    pwd: "[password]",
    roles: [{role: "readWrite", db: "[db_name]"}]
  })
'
```

### [Redis] Setup (if detected)

```bash
# Verify Redis connection
redis-cli -h [host] -p 6379 ping
# Expected: PONG
```

## SSL/HTTPS Setup

### Option A: Let's Encrypt with Certbot

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d [domain] -d www.[domain]

# Auto-renewal
sudo certbot renew --dry-run
```

### Option B: Nginx Reverse Proxy with SSL

```nginx
server {
    listen 80;
    server_name [domain];
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name [domain];

    ssl_certificate /etc/letsencrypt/live/[domain]/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/[domain]/privkey.pem;

    location / {
        proxy_pass http://localhost:[port];
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Monitoring

### Health Checks
```bash
# Backend health
curl -f http://localhost:[port]/health || echo "Backend unhealthy"

# Database health
[mysqladmin ping -h localhost | pg_isready -h localhost]

# Redis health
redis-cli ping

# Full system check script
#!/bin/bash
services=("[backend]:[port]" "[frontend]:[port]")
for service in "${services[@]}"; do
  host="${service%%:*}"
  port="${service##*:}"
  if curl -sf "http://localhost:${port}/health" > /dev/null; then
    echo "✓ ${host} is healthy"
  else
    echo "✗ ${host} is DOWN"
  fi
done
```

### Logging
[Based on detected logging setup:]
```bash
# View application logs
docker compose logs -f [service-name]

# View last 100 lines
docker compose logs --tail=100 [service-name]
```

### Error Tracking (if Sentry detected)
- Sentry dashboard: `https://sentry.io/organizations/[org]/issues/`
- Configure `SENTRY_DSN` environment variable for each service

## Backup & Recovery

### Database Backup

```bash
# MySQL backup
mysqldump -u [user] -p [db_name] | gzip > backup_$(date +%Y%m%d_%H%M%S).sql.gz

# MongoDB backup
mongodump --uri="[MONGODB_URL]" --out=backup_$(date +%Y%m%d_%H%M%S)

# Automated daily backup (add to crontab)
0 2 * * * /path/to/backup-script.sh
```

### Restore from Backup

```bash
# MySQL restore
gunzip < backup_YYYYMMDD.sql.gz | mysql -u [user] -p [db_name]

# MongoDB restore
mongorestore --uri="[MONGODB_URL]" backup_YYYYMMDD/
```

### Rollback Procedures

```bash
# Rollback to previous Docker image
docker compose pull  # Pull previous tagged image
docker compose up -d --force-recreate

# Rollback database migration
[alembic downgrade -1 | npx prisma migrate resolve --rolled-back [migration-name]]
```

## Troubleshooting

### Common Issues

| Issue | Possible Cause | Solution |
|-------|---------------|----------|
| Container won't start | Missing environment variables | Check `docker compose logs [service]`, verify .env |
| Database connection refused | Database not ready / wrong credentials | Verify DATABASE_URL, check DB container health |
| 401 on all requests | JWT secret mismatch | Ensure JWT_SECRET_KEY matches between services |
| 502 Bad Gateway | Backend not responding | Check backend logs, verify port mapping |
| Slow responses | Missing database indexes | Run `EXPLAIN` on slow queries, add indexes |
| Out of memory | Container memory limits | Increase Docker memory limits or add swap |

### Debugging Commands
```bash
# Check container status
docker compose ps

# View real-time logs
docker compose logs -f

# Enter container shell
docker compose exec [service] /bin/bash

# Check network connectivity between containers
docker compose exec [service] ping [other-service]

# Check disk usage
docker system df
```
```

---

## Step 6: Generate Contributing Guide

**Output file:** `docs/CONTRIBUTING.md`

Only generate this file if `--type=contributing` or `--type=all` is specified.

```markdown
# Contributing Guide

Thank you for your interest in contributing to [Project Name]. This guide will help you get started.

## Table of Contents
- [Development Setup](#development-setup)
- [Branch Strategy](#branch-strategy)
- [Commit Messages](#commit-messages)
- [Pull Request Process](#pull-request-process)
- [Code Review Checklist](#code-review-checklist)
- [Testing Requirements](#testing-requirements)
- [Coding Standards](#coding-standards)

---

## Development Setup

### Prerequisites
- [Language]: [version] (e.g., Python 3.11+, Node.js 20+)
- Docker & Docker Compose
- Git 2.30+
- [Detected package manager]: [pnpm / npm / yarn / pip]

### First-Time Setup

```bash
# 1. Fork and clone
git clone https://github.com/[your-username]/[repo-name].git
cd [repo-name]

# 2. Add upstream remote
git remote add upstream https://github.com/[org]/[repo-name].git

# 3. Install dependencies
[Based on detected stack:]
# Backend
cd [backend-dir]
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
pip install -r requirements-dev.txt  # Dev dependencies

# Frontend
cd [frontend-dir]
[pnpm install | npm install | yarn install]

# 4. Setup environment
cp .env.example .env
# Edit .env with local development values

# 5. Start infrastructure services
docker compose up -d [database] [redis] [other-services]

# 6. Run database migrations
[alembic upgrade head | npx prisma migrate dev]

# 7. Verify setup
[pytest -v | pnpm test]
```

### IDE Recommendations
- **VS Code** with extensions: [Python / ESLint / Prettier / Tailwind CSS IntelliSense]
- **PyCharm** (for Python-heavy projects)
- **Cursor** (AI-assisted development)

## Branch Strategy

We follow a simplified GitFlow model:

```
main ─────────────────────────────────── (production)
  │
  └── develop ────────────────────────── (staging / integration)
        │
        ├── feature/user-auth ─────────── (feature branches)
        ├── feature/payment-flow ──────── (feature branches)
        ├── fix/login-redirect ────────── (bug fixes)
        └── hotfix/security-patch ─────── (critical fixes from main)
```

### Branch Naming Convention

| Type | Pattern | Example |
|------|---------|---------|
| Feature | `feature/[description]` | `feature/user-auth` |
| Bug Fix | `fix/[description]` | `fix/login-redirect-loop` |
| Hotfix | `hotfix/[description]` | `hotfix/sql-injection-patch` |
| Refactor | `refactor/[description]` | `refactor/auth-service` |
| Docs | `docs/[description]` | `docs/api-reference-update` |
| Test | `test/[description]` | `test/payment-integration` |
| Chore | `chore/[description]` | `chore/upgrade-dependencies` |

**Rules:**
- Always branch from `develop` (not `main`)
- Use lowercase with hyphens (no underscores, no camelCase)
- Keep branch names short but descriptive

## Commit Messages

We follow **Conventional Commits** specification:

```
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

### Types

| Type | Description | Example |
|------|-------------|---------|
| `feat` | New feature | `feat(auth): add Google OAuth login` |
| `fix` | Bug fix | `fix(api): resolve 500 on empty query param` |
| `docs` | Documentation | `docs(readme): update installation steps` |
| `style` | Code style (no logic change) | `style(lint): fix ruff warnings` |
| `refactor` | Code restructuring | `refactor(services): extract email service` |
| `perf` | Performance improvement | `perf(db): add index on users.email` |
| `test` | Adding/updating tests | `test(auth): add login flow integration tests` |
| `chore` | Maintenance | `chore(deps): update fastapi to 0.115` |
| `ci` | CI/CD changes | `ci(github): add security scanning workflow` |
| `build` | Build system changes | `build(docker): optimize multi-stage build` |

### Examples

```bash
# Feature
git commit -m "feat(payments): add Razorpay subscription create endpoint"

# Bug fix with body
git commit -m "fix(auth): prevent token refresh race condition

Multiple simultaneous 401 responses were each triggering a refresh,
causing duplicate token rotation. Added a mutex lock on refresh."

# Breaking change
git commit -m "feat(api)!: change response format to envelope pattern

BREAKING CHANGE: All API responses now wrapped in {success, data, message} envelope.
Update all API consumers to unwrap the data field."
```

## Pull Request Process

### Before Creating a PR

1. **Sync with upstream:**
   ```bash
   git fetch upstream
   git rebase upstream/develop
   ```

2. **Run all checks locally:**
   ```bash
   # Lint
   [ruff check . | pnpm lint]

   # Type check
   [mypy . | npx tsc --noEmit]

   # Tests
   [pytest -v | pnpm test]

   # Format
   [ruff format . | pnpm format]
   ```

3. **Ensure no secrets are committed:**
   - Check for `.env` files, API keys, passwords in code
   - Use `.gitignore` properly

### PR Template

When creating a PR, include:

```markdown
## Summary
[Brief description of what this PR does]

## Changes
- [Specific change 1]
- [Specific change 2]

## Type
- [ ] Feature
- [ ] Bug Fix
- [ ] Refactor
- [ ] Documentation
- [ ] Other: [describe]

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing performed

## Screenshots (if UI changes)
[Before/After screenshots]

## Checklist
- [ ] Code follows project conventions
- [ ] No hardcoded secrets or credentials
- [ ] Database migrations included (if schema changes)
- [ ] Documentation updated (if public API changes)
- [ ] All tests passing
- [ ] Linter and type checker passing
```

### Review Process

1. Create PR targeting `develop` branch
2. Assign at least one reviewer
3. CI pipeline must pass (lint, type-check, test, build)
4. At least one approval required
5. Squash merge preferred (clean history)

## Code Review Checklist

Reviewers should verify:

### Functionality
- [ ] Code does what the PR description claims
- [ ] Edge cases handled (null, empty, boundary values)
- [ ] Error handling is appropriate (not swallowing errors)
- [ ] No N+1 database queries introduced

### Security
- [ ] No secrets hardcoded
- [ ] Input validation on all user inputs
- [ ] SQL injection protection (parameterized queries / ORM)
- [ ] Auth checks on protected endpoints
- [ ] No sensitive data in logs

### Code Quality
- [ ] Follows layer segregation (api/services/repos)
- [ ] No cross-layer import violations
- [ ] Functions are focused (single responsibility)
- [ ] Meaningful variable and function names
- [ ] No commented-out code blocks

### Testing
- [ ] Tests cover happy path
- [ ] Tests cover edge cases and error paths
- [ ] Mocks are appropriate (not over-mocking)
- [ ] Tests are independent (no shared state)

### Performance
- [ ] Database queries are indexed
- [ ] No unnecessary network calls in loops
- [ ] Large lists use pagination
- [ ] Caching used where appropriate

## Testing Requirements

### Minimum Coverage
- New features: **80% line coverage** minimum
- Bug fixes: Must include a regression test
- Refactors: Existing tests must continue to pass

### Test Structure

```python
# Python / pytest
class TestUserService:
    """Tests for UserService."""

    async def test_create_user_success(self):
        """Should create user with valid input."""
        ...

    async def test_create_user_duplicate_email(self):
        """Should raise ConflictError for duplicate email."""
        ...

    async def test_create_user_invalid_email(self):
        """Should raise ValidationError for malformed email."""
        ...
```

```typescript
// TypeScript / Jest or Vitest
describe('UserService', () => {
  describe('createUser', () => {
    it('should create user with valid input', async () => { ... });
    it('should throw ConflictError for duplicate email', async () => { ... });
    it('should throw ValidationError for malformed email', async () => { ... });
  });
});
```

### Running Tests

```bash
# All tests
[pytest -v | pnpm test]

# Specific module
[pytest tests/test_auth.py -v | pnpm test -- --grep "auth"]

# With coverage
[pytest --cov=app --cov-report=html -v | pnpm test -- --coverage]

# Watch mode (during development)
[ptw | pnpm test -- --watch]
```

## Coding Standards

### [Python] Standards (if Python detected)
- **Linter**: ruff (replaces flake8, isort, black)
- **Type Checker**: mypy (strict mode)
- **Formatter**: ruff format
- **Docstrings**: Google style
- **Naming**: snake_case for variables/functions, PascalCase for classes
- **Imports**: Sorted by ruff (stdlib, third-party, local)

### [TypeScript/JavaScript] Standards (if TS/JS detected)
- **Linter**: ESLint with recommended config
- **Formatter**: Prettier
- **Types**: Strict TypeScript (no `any`)
- **Naming**: camelCase for variables/functions, PascalCase for components/classes
- **Imports**: Sorted with import/order plugin

### General Rules
- Maximum line length: 120 characters
- Use meaningful names (no single-letter variables except loop counters)
- Prefer explicit over implicit
- Keep functions small and focused
- Document public APIs with docstrings/JSDoc
- No magic numbers (use named constants)
```

---

## Step 7: Generate User Manual (if frontend exists)

**Output file:** `docs/USER_MANUAL.md`

Only generate this file if frontend is detected AND (`--type=manual` or `--type=all` is specified).

If no frontend is detected, skip this step and note it in the summary.

```markdown
# User Manual

## Table of Contents
- [Getting Started](#getting-started)
- [Account Setup](#account-setup)
- [Feature Guides](#feature-guides)
- [Settings](#settings)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [FAQ](#faq)
- [Troubleshooting](#troubleshooting)

---

## Getting Started

### Creating Your Account

1. Visit [application URL]
2. Click **Sign Up** (or **Get Started**)
3. Choose your sign-up method:
   - **Email**: Enter your email and create a password
   - **Google**: Click "Continue with Google" for one-click signup
4. Verify your email (check inbox for verification code)
5. Complete your profile setup

### Logging In

1. Visit [application URL]/login
2. Enter your email and password, or click "Continue with Google"
3. If 2FA is enabled, enter the code from your authenticator app

### Dashboard Overview

After logging in, you land on the **Dashboard** which shows:
- [Describe key dashboard elements based on detected routes/pages]
- [Key metrics or widgets]
- [Navigation structure]

---

## Account Setup

### Profile Settings
- Navigate to **Settings > Profile**
- Update your display name, avatar, and bio
- Changes are saved automatically

### Security Settings
- **Change Password**: Settings > Security > Change Password
- **Two-Factor Authentication**: Settings > Security > 2FA
  - Download an authenticator app (Google Authenticator, Authy)
  - Scan the QR code
  - Enter the verification code
  - Save your backup codes securely
- **Active Sessions**: View and revoke sessions from other devices

### Notification Preferences
- **In-App**: Toggle notification types on/off
- **Email**: Choose which emails to receive
- **Push** (mobile): Configure push notification categories

[If subscription detected:]
### Subscription & Billing
- **View Plans**: Settings > Subscription > View Plans
- **Current Plan**: See your active plan and renewal date
- **Point Balance**: Check your remaining credit points
- **Purchase Top-Up**: Buy additional points when running low
- **Billing History**: Download invoices and receipts
- **Cancel Subscription**: Cancel with access until cycle end

---

## Feature Guides

[For each major feature detected, create a walkthrough:]

### [Feature Name]

**What it does**: [Brief description]

**How to use it**:
1. [Step-by-step instructions]
2. [Include which page/screen to navigate to]
3. [Describe the UI elements and actions]
4. [Expected results]

**Tips**:
- [Useful tip about this feature]
- [Common pattern or shortcut]

[Repeat for each major feature. Generate 3-8 feature guides based on detected functionality.]

---

## Settings

### Appearance
- **Theme**: Choose Light, Dark, or System (auto-detects your OS preference)
- **Language**: [If i18n detected: Select from available languages: English, Hindi, etc.]

### Privacy
- **Data Export**: Download all your data (GDPR compliant)
- **Delete Account**: Request account deletion (30-day grace period)
- **Cookie Preferences**: Manage tracking consent

---

## Keyboard Shortcuts

[Generate based on detected frontend framework. Common shortcuts:]

| Shortcut | Action |
|----------|--------|
| `Cmd/Ctrl + K` | Open command palette / search |
| `Cmd/Ctrl + /` | Toggle shortcuts help |
| `Cmd/Ctrl + N` | Create new [resource] |
| `Esc` | Close modal / cancel action |
| `?` | Show keyboard shortcuts |

---

## FAQ

### Account & Access

**Q: I forgot my password. How do I reset it?**
A: Click "Forgot Password" on the login page. Enter your email and you will receive a reset code.

**Q: Can I change my email address?**
A: Go to Settings > Profile > Email. You will need to verify the new email address.

**Q: How do I enable two-factor authentication?**
A: Go to Settings > Security > Two-Factor Authentication. Follow the setup wizard to link your authenticator app.

[If payments detected:]
### Billing & Payments

**Q: What payment methods are accepted?**
A: [UPI, Credit/Debit Cards, Net Banking, Wallets — based on Razorpay/Stripe detection]

**Q: What happens when my points run out?**
A: Actions requiring points will be blocked. You can purchase a top-up pack or wait for your next billing cycle when plan points are refreshed.

**Q: Can I get a refund?**
A: Refer to our Refund Policy. Subscription cancellations provide access until the current billing cycle ends.

### Technical

**Q: What browsers are supported?**
A: Latest versions of Chrome, Firefox, Safari, and Edge. Internet Explorer is not supported.

**Q: Is there a mobile app?**
A: [Yes — available on iOS and Android via App Store and Google Play / Not yet — coming soon / Access the web app on mobile for a responsive experience]

**Q: Is my data secure?**
A: Yes. All data is encrypted in transit (HTTPS/TLS) and at rest. Authentication uses secure HTTP-only cookies. We do not store passwords in plain text.

---

## Troubleshooting

### Common Issues

| Problem | Solution |
|---------|----------|
| Can't log in | Clear cookies, try incognito mode, reset password |
| Page not loading | Check internet connection, clear browser cache |
| Features not appearing | Check your subscription plan, contact support |
| Slow performance | Clear browser cache, check network speed |
| Mobile app crashing | Update to latest version, reinstall if needed |

### Getting Help

- **Email**: [support email]
- **In-App**: Click the help icon (?) in the bottom-right corner
- **Documentation**: You are reading it
```

---

## Step 8: Docusaurus Option (if --format=docusaurus)

Only execute this step if `--format=docusaurus` was specified in `$ARGUMENTS`.

If `--format=docusaurus`, restructure ALL generated documentation into a Docusaurus-compatible docs site.

### Directory Structure

Create the following structure inside `docs/`:

```
docs/
├── intro.md                          # Landing page (from README content)
├── getting-started/
│   ├── _category_.json               # Category metadata
│   ├── installation.md               # Quick start from README
│   ├── configuration.md              # Environment setup
│   └── first-steps.md               # Basic usage guide
├── architecture/
│   ├── _category_.json
│   ├── overview.md                   # System overview diagram
│   ├── services.md                   # Service architecture
│   ├── request-flow.md              # Request flow diagrams
│   ├── authentication.md            # Auth flow diagrams
│   ├── database.md                  # Database schema overview
│   └── design-decisions.md          # Key decisions and rationale
├── api-reference/
│   ├── _category_.json
│   ├── overview.md                   # API overview, auth, formats
│   ├── auth.md                      # Auth endpoints
│   ├── [resource].md                # One file per endpoint group
│   └── websocket.md                 # WebSocket events (if detected)
├── deployment/
│   ├── _category_.json
│   ├── docker.md                    # Docker deployment
│   ├── cloud.md                     # Cloud deployment (AWS/GCP)
│   ├── database-setup.md           # Database setup
│   ├── ssl-https.md                # SSL configuration
│   ├── monitoring.md               # Monitoring setup
│   └── troubleshooting.md          # Common issues
├── contributing/
│   ├── _category_.json
│   ├── setup.md                    # Development setup
│   ├── workflow.md                 # Branch strategy, commits, PRs
│   ├── code-review.md             # Review checklist
│   ├── testing.md                 # Testing requirements
│   └── standards.md               # Coding standards
└── user-guide/                     # Only if frontend detected
    ├── _category_.json
    ├── getting-started.md          # First steps for users
    ├── features.md                 # Feature walkthroughs
    ├── settings.md                 # Settings guide
    ├── shortcuts.md                # Keyboard shortcuts
    └── faq.md                      # FAQ + troubleshooting
```

### Category JSON Format

Each `_category_.json` should follow this format:

```json
{
  "label": "[Category Name]",
  "position": [number],
  "link": {
    "type": "generated-index",
    "description": "[Category description]"
  }
}
```

Position order:
1. Getting Started
2. Architecture
3. API Reference
4. Deployment
5. Contributing
6. User Guide

### MDX Enhancements

Use Docusaurus MDX features in generated files:

```mdx
---
sidebar_position: 1
title: "[Page Title]"
description: "[SEO description]"
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Page Title

<Tabs>
  <TabItem value="docker" label="Docker" default>
    ```bash
    docker compose up -d
    ```
  </TabItem>
  <TabItem value="local" label="Local">
    ```bash
    pip install -r requirements.txt
    uvicorn app.main:app --reload
    ```
  </TabItem>
</Tabs>
```

Use `<Tabs>` for:
- Installation options (Docker vs Local)
- Package manager commands (npm vs pnpm vs yarn)
- Platform-specific instructions (macOS vs Linux vs Windows)
- Language-specific examples (Python vs TypeScript)

### Sidebar Configuration

Generate `sidebars.js` at docs root:

```javascript
/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  docs: [
    'intro',
    {
      type: 'category',
      label: 'Getting Started',
      items: [
        'getting-started/installation',
        'getting-started/configuration',
        'getting-started/first-steps',
      ],
    },
    {
      type: 'category',
      label: 'Architecture',
      items: [
        'architecture/overview',
        'architecture/services',
        'architecture/request-flow',
        'architecture/authentication',
        'architecture/database',
        'architecture/design-decisions',
      ],
    },
    // ... continue for all categories
  ],
};

module.exports = sidebars;
```

---

## Step 9: Output Summary

After generating all documentation files, print the following summary:

```
╔══════════════════════════════════════════════════════════════════════╗
║  DOCUMENTATION GENERATED SUCCESSFULLY                                ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  Project: [name]                                                     ║
║  Format:  [Markdown | Docusaurus]                                    ║
║  Type:    [all | specific types generated]                           ║
║                                                                      ║
║  Files Generated:                                                    ║
║  ├── README.md                    — [line count] lines (project hub) ║
║  ├── docs/ARCHITECTURE.md         — [line count] lines (system design)║
║  ├── docs/API_REFERENCE.md        — [line count] lines ([N] endpoints)║
║  ├── docs/DEPLOYMENT.md           — [line count] lines (ops guide)   ║
║  ├── docs/CONTRIBUTING.md         — [line count] lines (dev guide)   ║
║  └── docs/USER_MANUAL.md          — [line count] lines (end users)   ║
║                                                                      ║
║  [If Docusaurus:]                                                    ║
║  ├── docs/sidebars.js             — Sidebar configuration            ║
║  ├── docs/*/_category_.json       — Category metadata                ║
║  └── docs/**/*.md                 — [N] individual doc pages         ║
║                                                                      ║
║  Documentation Coverage:                                             ║
║  ├── API Endpoints Documented:    [X] of [Y] detected               ║
║  ├── Database Models Documented:  [X] of [Y] detected               ║
║  ├── Features Documented:         [X] of [Y] detected               ║
║  └── Environment Variables:       [X] of [Y] from .env.example      ║
║                                                                      ║
║  Skipped:                                                            ║
║  ├── [file] — Already exists (use --overwrite to replace)            ║
║  └── [file] — Not applicable (no frontend detected)                  ║
║                                                                      ║
╠══════════════════════════════════════════════════════════════════════╣
║  NEXT STEPS:                                                         ║
║                                                                      ║
║  1. Review generated documentation for accuracy                      ║
║  2. Fill in placeholder values: [org], [repo], [domain], etc.       ║
║  3. Add project-specific details to each document                   ║
║  4. Generate API docs from OpenAPI: open http://localhost:[port]/docs║
║  5. Set up Docusaurus (if --format=docusaurus):                     ║
║     npx create-docusaurus@latest docs-site classic                  ║
║     cp -r docs/* docs-site/docs/                                    ║
║     cd docs-site && npm start                                       ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
```

Adjust the summary:
- Only list files that were actually generated (not skipped)
- Only show Docusaurus section if `--format=docusaurus` was used
- Show accurate line counts by counting after file creation
- List any files that were SKIPPED because they already existed, with a note
- List any documentation types that were skipped because prerequisites were not met (e.g., no frontend for User Manual)
- Show documentation coverage metrics (how many endpoints, models, features were documented vs detected)

---

## Important Rules

1. **Only document what exists** — Never fabricate features, endpoints, or configurations that are not in the codebase. If unsure, mark with `[TODO: verify]` placeholder.
2. **Use detected values** — All commands, paths, ports, package managers, and URLs must come from actual project detection, not assumptions.
3. **Respect existing files** — If a documentation file already exists, do NOT overwrite it unless the user explicitly confirms. Instead, note what would be added or changed.
4. **Production quality** — Generated documentation should be immediately usable without editing, except for obvious placeholders like `[org]` and `[repo]`.
5. **Consistent formatting** — Use consistent Markdown heading levels, table formatting, and code block language annotations throughout all generated files.
6. **Cross-reference** — Link between documentation files where relevant (e.g., README links to ARCHITECTURE.md, API_REFERENCE.md links to DEPLOYMENT.md).
7. **Keep it current** — Include a "Last updated" timestamp at the top of each generated file.
8. **No emojis in documentation** — Use plain text formatting. Badges and diagrams are acceptable.
9. **Accessibility** — Use descriptive alt text for any images or badges. Ensure tables have header rows.
10. **Audience awareness** — README targets all audiences, ARCHITECTURE targets developers, DEPLOYMENT targets DevOps, USER_MANUAL targets end users. Adjust language complexity accordingly.
