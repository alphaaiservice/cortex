---
description: "Initialize a new or upgrade existing project with Alpha AI's standard architecture. Supports Python/FastAPI, Node.js/NestJS, Java/Spring Boot. Usage: /init-project <project-name> [--lang=python|nestjs|springboot] [--with-frontend] [--with-mobile] [--with-ai] [--existing]"
---

# Project Initialization — Alpha AI Standards

Initialize project: **$ARGUMENTS**

## Mode Detection

Automatically detect whether this is a **new project** or **existing project**:

```bash
# Check if target directory has existing code
ls $ARGUMENTS/app/ 2>/dev/null || ls $ARGUMENTS/src/ 2>/dev/null || ls $ARGUMENTS/package.json 2>/dev/null
```

## Step 0: Detect Backend Language

Before scaffolding, detect the backend language:

1. **`--lang` flag**: If provided, use it directly (python, nestjs, springboot)
2. **Existing project**: Detect from files:
   - requirements.txt / pyproject.toml / app/main.py → **python-fastapi**
   - package.json with @nestjs/ / nest-cli.json / src/main.ts → **nodejs-nestjs**
   - build.gradle.kts / pom.xml with spring-boot / src/main/java/ → **java-springboot**
3. **New project without --lang**: Default to **python-fastapi**
4. **Load reference files**:
   - `skills/alpha-architecture/references/LANG_PROFILE_{LANG}.md` → directory structure, deps, configs, Docker, verify commands
   - `skills/alpha-architecture/references/CODE_PATTERNS_{LANG}.md` → code patterns

## Step 0.1: Database Selection

Before scaffolding, ask the user which database(s) this project will use:

```
╔══════════════════════════════════════════════════════════════╗
║  DATABASE SELECTION                                          ║
╠══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Which database(s) will this project use?                    ║
║                                                               ║
║  1. MySQL only     — Relational data, strict schemas,        ║
║                      transactions, JOINs. Best for: e-comm,  ║
║                      SaaS, financial apps, CRUD apps         ║
║                                                               ║
║  2. MongoDB only   — Flexible documents, nested objects,     ║
║                      schema-less. Best for: CMS, logs,       ║
║                      profiles, analytics, real-time apps     ║
║                                                               ║
║  3. Both (MySQL + MongoDB) — MySQL for transactional data,   ║
║                      MongoDB for logs/profiles/flexible docs ║
║                                                               ║
║  Enter 1, 2, or 3:                                           ║
╚══════════════════════════════════════════════════════════════╝
```

Set `DB_CHOICE` variable based on user response:
- `DB_CHOICE=mysql` → MySQL only (SQLAlchemy/Prisma/JPA)
- `DB_CHOICE=mongodb` → MongoDB only (PyMongo/Mongoose/Spring Data MongoDB)
- `DB_CHOICE=both` → MySQL + MongoDB

**If `--existing` mode**: Auto-detect from existing deps/docker-compose instead of asking:
- Found mysql/sqlalchemy/prisma/jpa → MySQL
- Found mongodb/pymongo/mongoose → MongoDB
- Found both → Both

**If PRD exists**: Infer from PRD content (e.g., "user profiles stored in MongoDB" → MongoDB; "order transactions" → MySQL). Still confirm with user.

Use this `DB_CHOICE` for ALL subsequent steps — directory scaffolding, dependencies, docker-compose, base code, and validation.

### If `--existing` flag OR existing code detected → **EXISTING MODE**

In existing mode, this command:
1. **Detects what the project actually uses** (from code, dependencies, PRD)
2. **Adds ONLY missing pieces FOR FEATURES THE PROJECT ALREADY USES**
3. **NEVER adds infrastructure for features the project doesn't use**
4. **NEVER overwrites** existing files (skip if file exists)
5. **NEVER deletes** anything
6. **Reports** what was added, what was skipped, and what's N/A

#### Existing Mode Process:

**Step E0: Detect Project Requirements (CRITICAL — DO THIS FIRST)**
```
Before adding ANYTHING, analyze what the project actually uses:

1. Read PRD.md, README.md, SPRINT_PLAN.md (if they exist)
2. Read requirements.txt / package.json to see installed dependencies
3. Read docker-compose.yml to see running services
4. Scan app/ directory for existing patterns
5. Build a YES/NO requirements profile:

   CORE (always YES — technology per detected language):
   - Backend framework: YES → [FastAPI | NestJS | Spring Boot]
   - Database: Detect DB_CHOICE from existing deps/docker-compose:
     - If sqlalchemy|prisma|jpa + pymongo|mongoose|spring-data-mongodb → DB_CHOICE=both
     - If sqlalchemy|prisma|jpa only → DB_CHOICE=mysql
     - If pymongo|mongoose|spring-data-mongodb only → DB_CHOICE=mongodb
   - JWT auth: YES → [python-jose | @nestjs/jwt | jjwt-api]
   - Layer segregation: YES (controllers → services → repositories → models)
   - Linting + types + tests: YES → [ruff+mypy+pytest | ESLint+TS+Jest | Checkstyle+Java+JUnit]

   CONDITIONAL (detect from project):
   - Redis: YES only if redis|ioredis|spring-data-redis in deps OR redis in docker-compose
   - Razorpay: YES only if razorpay in deps OR payment code exists
   - Async queue: YES only if celery|bullmq|@nestjs/bullmq in deps OR tasks/ directory exists
   - GenAI: YES only if litellm|@ai-sdk|spring-ai|langchain in deps OR ai/ directory exists
   - Meilisearch: YES only if meilisearch in deps OR search service exists
   - WebSocket: YES only if socketio in deps OR websocket code exists
   - S3/File Upload: YES only if boto3 in deps OR storage service exists
   - Mobile: YES only if mobile/ directory exists OR React Native deps
   - Sentry: YES only if sentry in deps
   - PostHog: YES only if posthog in deps

6. Show the profile to the user:
   "I detected this project uses: FastAPI, DB_CHOICE=[mysql|mongodb|both], Redis, Celery, JWT auth.
    It does NOT use: Razorpay, Meilisearch, Mobile, GenAI.
    I will only add missing infrastructure for the technologies you use.
    Shall I proceed?"

7. Wait for user confirmation before creating anything.
```

**Step E1: Scan existing structure**
```
Use Glob to map all existing directories and files.
Build a set of "existing paths" to check against.
```

**Step E2: Compare against APPLICABLE Alpha AI structure only**
For each directory/file in the standard structure:
- If the feature is **N/A** (not in requirements profile) → SKIP ENTIRELY (do NOT create)
- If **exists** → SKIP (print "✅ Already exists: [path]")
- If **missing AND applicable** → CREATE (print "📁 Created: [path]")

**Step E3: Check dependencies (ONLY for applicable features)**
Read existing requirements.txt / package.json.
For each APPLICABLE dependency (based on requirements profile):
- If **present** → SKIP
- If **missing** → APPEND (don't replace file, just add missing lines)
- If **feature is N/A** → do NOT add those dependencies

**Step E4: Generate missing configs**
For each config file (pyproject.toml, .env.example, Makefile, docker-compose.yml):
- If **exists** → SKIP (print "✅ Config exists, review manually: [path]")
- If **missing** → CREATE (include only applicable services in docker-compose)

**Step E5: Summary**
```
╔══════════════════════════════════════════════════════════════╗
║  INIT-PROJECT (EXISTING MODE) COMPLETE                        ║
╠══════════════════════════════════════════════════════════════╣
║  Technologies detected: [list of YES technologies]            ║
║  Technologies N/A (skipped): [list of NO technologies]        ║
║                                                               ║
║  Existing files preserved: [count]                            ║
║  New directories created: [count]                             ║
║  New files created: [count]                                   ║
║  Dependencies added: [count]                                  ║
║  Configs generated: [count]                                   ║
║  Features skipped (not used): [count]                         ║
║                                                               ║
║  ⚠️  Review these manually:                                   ║
║  - [list of existing configs that may need updating]          ║
║                                                               ║
║  Next steps:                                                  ║
║  → /gap-analysis — Check compliance with applicable standards ║
║  → /retrofit [feature] — Add a NEW feature to the project     ║
╚══════════════════════════════════════════════════════════════╝
```

### If NEW project (no existing code) → **NEW MODE** (default behavior below)

## Stack Configuration

> **📖 CANONICAL REFERENCE**: The complete tech-stack inventory (Core + Conditional + per-language matrices, with libraries, versions, env vars, and code patterns) lives in `commands/references/AUTO_BUILD_STACK.md`. Consult it for any "which technology should I use" question. The sections below cover only the init-time decisions specific to scaffolding a new project.

### Decisions made at init time (drives what gets scaffolded)

- **Backend language** (from Step 0): `python-fastapi` | `nodejs-nestjs` | `java-springboot`
- **Database choice** (from Step 0.1): `mysql` | `mongodb` | `both`
- **Frontend** (from `--with-frontend` flag): include Next.js scaffold YES/NO
- **Mobile** (from `--with-mobile` flag): include React Native + Expo scaffold YES/NO
- **GenAI** (from `--with-ai` flag): include `app/ai/` directory + LiteLLM scaffold YES/NO
- **Feature profile**: built in Step 0.5 from PRD.md OR command flags OR interactive prompts

### Hard rules at init time (every scaffold)

- **JWT + HTTP-Only Cookies** — NEVER localStorage/sessionStorage. Token lib per language (python-jose | @nestjs/jwt | jjwt-api).
- **Layer segregation directories** MUST exist from the start (controllers/services/repositories/models), even if empty — easier to enforce than retrofit.
- **Multi-theme support** MUST be wired in the frontend scaffold (Light + Dark + System) — never ship without dark mode.
- **Linter + type checker + test framework** MUST be configured in `pyproject.toml` / `package.json` / `build.gradle.kts` from day one.

### Conditional scaffolds (skip both the dependency AND the directory if feature profile says NO)

For each row below: if the feature is NOT in scope, skip the corresponding section of `AUTO_BUILD_STACK.md` AND the listed scaffolding action. Load the canonical reference for the actual library names, versions, and env vars.

- **Redis** → skip `app/repositories/cache/`, skip redis driver dep, skip docker-compose redis service
- **Email** → skip `app/templates/emails/`, skip mail driver dep, skip Celery email queue
- **Payments** → skip Razorpay dep, skip `app/services/billing_service.py`, skip credit-points models
- **File Upload** → skip S3 driver, skip MinIO docker-compose service, skip `app/services/storage_service.py`
- **Search** → skip Meilisearch dep, skip docker-compose meilisearch service, skip `app/services/search_service.py`
- **Real-Time** → skip WebSocket dep, skip `app/core/websocket_manager.py`
- **Mobile** → skip the entire `mobile/` directory and Expo configs
- **GenAI** → skip the entire `app/ai/` directory and LiteLLM/Qdrant/Langfuse deps
- **2FA / RBAC / PWA / i18n / Analytics / Sentry / Feature Flags / Admin Panel** → skip their respective deps + scaffolding

## Step 0.5: Determine Feature Profile (NEW MODE)

For new projects, determine what to scaffold:

```
1. If PRD.md exists in target directory → read it and build requirements profile
2. If no PRD → use command flags to determine:
   - No flags → scaffold CORE only (FastAPI + [DB per DB_CHOICE] + JWT + layers)
   - --with-frontend → add Next.js frontend
   - --with-mobile → add React Native mobile + FCM
   - --with-ai → add GenAI stack (LiteLLM, Qdrant, etc.)
3. For features not covered by flags, ask the user:
   "Does this project need: Redis? Payments? Search? Real-Time?"
4. Only scaffold directories, files, and dependencies for YES features
```

## Step 1: Create Project Structure

Create ONLY the directories needed by this project's feature profile:

> The directory structure below shows Python/FastAPI conventions. For NestJS or Spring Boot directory structures, load the appropriate LANG_PROFILE reference file. The layer concept is the same: controllers → services → repositories → models.

### Core directories (always create):
```
app/
├── api/v1/          # 🌐 Thin route controllers ONLY
├── api/v1/admin/    # 🔐 Admin API (requires admin role)
├── services/        # ⚙️ ALL business logic lives here
├── models/sql/      # (if DB_CHOICE=mysql or both) SQL ORM models
├── models/nosql/    # (if DB_CHOICE=mongodb or both) MongoDB documents
├── schemas/         # Request/response models
├── repositories/sql/    # (if DB_CHOICE=mysql or both) MySQL data access
├── repositories/nosql/  # (if DB_CHOICE=mongodb or both) MongoDB data access
├── core/            # Security, exceptions, logging
├── db/              # Database connection managers
├── config.py        # Pydantic BaseSettings
└── main.py          # App factory + lifespan
```

### Conditional directories (create ONLY if feature profile says YES):
```
├── models/cache/    # (if Redis) Redis key schemas
├── repositories/cache/  # (if Redis) Redis data access
├── templates/emails/ # (if Email) Jinja2 HTML email templates
├── tasks/           # (if Celery/Email) Celery async tasks
├── ai/              # (if --with-ai) GenAI / Agentic AI — full structure below
```

### GenAI directory structure (create ONLY if --with-ai):
```
app/ai/
├── config.py        # LiteLLM config, model registry, fallback chains
├── gateway.py       # Unified LLM gateway (generate, embed, stream)
├── prompts/         # Prompt templates (Jinja2/YAML)
├── agents/          # AI agents (ADK/LangGraph/CrewAI)
├── rag/             # RAG pipeline (embed, chunk, retrieve)
├── memory/          # Agent memory (conversation, long-term)
├── guardrails/      # Input/output filtering, cost caps
├── mcp/             # MCP server (tools + prompts + resources)
├── a2a/             # A2A protocol (Agent Card + task handler)
├── eval/            # AI Evaluation (DeepEval + RAGAS)
├── structured/      # Structured Output (instructor + Pydantic)
├── cache/           # Semantic Caching
├── reranker/        # Re-ranking (Cohere / FlashRank)
├── multimodal/      # Multi-Modal AI (vision, image gen, audio)
├── hitl/            # Human-in-the-Loop review queue
├── context/         # Context Window Management
├── voice/           # Voice AI (STT + TTS + streaming)
└── batch/           # Batch AI Processing
```

Plus: tests/ (unit/integration/e2e), migrations/, scripts/, docker/

Mobile app structure (if --with-mobile):
```
mobile/
├── app.config.ts            # Expo config (bundleIdentifier, package, scheme, plugins)
├── eas.json                 # EAS Build profiles (development, preview, production)
├── babel.config.js          # nativewind/babel + reanimated/plugin (LAST)
├── metro.config.js          # withNativeWind() wrapper
├── tailwind.config.js       # NativeWind preset + content paths
├── app/                     # App screens and navigation
│   ├── _layout.tsx          # Root layout (providers, theme, navigation)
│   ├── (auth)/              # Auth screens (login, register, forgot-password)
│   ├── (tabs)/              # Bottom tab screens (home, features, notifications, profile)
│   └── (drawer)/            # Drawer screens (settings, help, about)
├── components/              # Reusable UI components
│   ├── ui/                  # Base components (Button, Input, Card, etc.)
│   └── shared/              # Shared components (Header, BottomSheet, Toast, etc.)
├── lib/                     # Utilities
│   ├── api.ts               # Axios instance with auth interceptor
│   ├── auth.ts              # expo-secure-store token helpers
│   ├── queryClient.ts       # TanStack Query + offline persist
│   └── i18n.ts              # i18next + expo-localization setup
├── hooks/                   # Custom hooks (useAuth, useNetwork, useTheme)
├── stores/                  # Zustand stores
├── types/                   # TypeScript types (navigation, API responses)
├── assets/                  # Icons (1024x1024), splash, images
├── locales/                 # i18n translation files (en.json, hi.json)
└── __tests__/               # Jest + RNTL tests
```

## Step 2: Dependencies

> Dependencies below are for Python/FastAPI. For NestJS (package.json) or Spring Boot (build.gradle.kts), see the LANG_PROFILE reference file for the detected language.

**requirements.txt:**
```
# Core (always install)
fastapi>=0.115.0
uvicorn[standard]>=0.30.0
gunicorn>=22.0.0
pydantic>=2.0.0
pydantic-settings>=2.0.0
python-multipart>=0.0.9
python-jose[cryptography]>=3.3.0
passlib[bcrypt]>=1.7.4
httpx>=0.27.0
python-dotenv>=1.0.0
structlog>=24.0.0

# SQL Database (if DB_CHOICE=mysql or both)
sqlalchemy[asyncio]>=2.0.0
asyncmy>=0.2.9
alembic>=1.13.0

# MongoDB (if DB_CHOICE=mongodb or both)
pymongo>=4.7.0
motor>=3.4.0

# Redis (if project uses Redis)
# redis>=5.0.0

# Payments (if project has billing -- uncomment for Razorpay)
# razorpay>=1.4.0

# OAuth (if project has social login)
# authlib>=1.3.0

# Email (if project sends transactional emails)
# fastapi-mail>=1.4.0
# jinja2>=3.1.0
# itsdangerous>=2.1.0
# celery[redis]>=5.4.0
# flower>=2.0.0

# File Upload (if project has uploads)
# boto3>=1.34.0
# Pillow>=10.3.0

# Search (if project has full-text search)
# meilisearch>=0.31.0

# Real-Time (if project has WebSocket)
# python-socketio>=5.11.0

# Push Notifications (if project has mobile)
# firebase-admin>=6.5.0

# Error Tracking (recommended)
# sentry-sdk[fastapi]>=2.0.0

# Analytics (if project has analytics)
# posthog>=3.5.0

# 2FA (if project has two-factor auth)
# pyotp>=2.9.0
# qrcode[pil]>=7.4.0

# GenAI (if --with-ai -- uncomment needed packages)
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

> **Uncomment only** the dependency groups that match the project's PRD requirements or command flags. Core dependencies are always installed. Conditional dependencies are commented out by default -- uncomment them based on the feature profile.

**requirements-dev.txt:**
```
-r requirements.txt
pytest>=8.0.0
pytest-asyncio>=0.23.0
pytest-cov>=5.0.0
fakeredis>=2.21.0
ruff>=0.5.0
mypy>=1.10.0
moto[s3]>=5.0.0
playwright>=1.44.0
```

**Mobile dependencies (if --with-mobile) — package.json:**
```
# Core
expo, react-native, typescript

# Navigation
@react-navigation/native, @react-navigation/drawer, @react-navigation/bottom-tabs, @react-navigation/stack
react-native-screens, react-native-safe-area-context, react-native-gesture-handler

# UI
nativewind, react-native-reanimated, @gorhom/bottom-sheet
@shopify/flash-list, expo-image, react-native-toast-message
react-native-skeleton-placeholder, expo-haptics

# Auth
expo-secure-store, expo-auth-session, expo-web-browser
expo-apple-authentication, expo-local-authentication

# State & Network
@tanstack/react-query, zustand, axios
@react-native-community/netinfo, @tanstack/query-async-storage-persister

# Push & Real-Time
expo-notifications, expo-device, expo-constants
socket.io-client

# Media
expo-camera, expo-image-picker, expo-file-system, expo-sharing, expo-av

# Device
expo-location, expo-clipboard, expo-linking, expo-haptics, expo-network

# i18n
i18next, react-i18next, expo-localization

# Forms
react-hook-form, @hookform/resolvers, zod

# Error Tracking
sentry-expo, @sentry/react-native

# OTA Updates
expo-updates

# Testing (devDependencies)
jest, @testing-library/react-native, detox
@types/react, @types/react-native
```

## Step 3: Config Files

- `pyproject.toml` — ruff, mypy, pytest settings
- `.env.example` — all env vars with descriptions (include RAZORPAY_*, GOOGLE_*, EMAIL_SMTP_*, SENTRY_DSN, AWS_S3_BUCKET, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, MEILISEARCH_HOST, MEILISEARCH_API_KEY, FIREBASE_PROJECT_ID, POSTHOG_API_KEY, TOTP_ENCRYPTION_KEY, CDN_BASE_URL, RATE_LIMIT_DEFAULT, BACKUP_S3_BUCKET, EXPO_PUBLIC_API_URL, EXPO_PUBLIC_WS_URL, EXPO_PUBLIC_SENTRY_DSN, LITELLM_MASTER_KEY, OPENAI_API_KEY, ANTHROPIC_API_KEY, GOOGLE_API_KEY, QDRANT_HOST, QDRANT_API_KEY, LANGFUSE_HOST, LANGFUSE_PUBLIC_KEY, LANGFUSE_SECRET_KEY)
- `.editorconfig` — consistent editor settings
- `.gitignore` — Python + Node + Docker + IDE
- `Makefile` — dev, test, lint, format, migrate, docker commands
- `CLAUDE.md` — project context for Claude Code

## Step 4: Docker Setup

**docker/docker-compose.yml** -- include ONLY services the project needs:

Always include:
- app ([FastAPI port 8000 | NestJS port 3000 | Spring Boot port 8080])

Include per DB_CHOICE:
- mysql (MySQL 8.0, port 3306) -- if DB_CHOICE=mysql or both
- mongodb (MongoDB 7.0, port 27017) -- if DB_CHOICE=mongodb or both

Include if project uses these (per PRD/flags):
- redis (Redis 7, port 6379) -- if project uses Redis
- meilisearch (Meilisearch, port 7700) -- if project has full-text search
- minio (MinIO S3-compatible, port 9000/9001) -- if project has file uploads
- celery-worker + celery-beat + flower -- if project uses async tasks (email, search sync, etc.)
- qdrant (Qdrant, port 6333) -- if --with-ai and project uses RAG
- langfuse (LLM observability, port 3001) -- if --with-ai

**docker/Dockerfile** — Multi-stage Python build.

## Step 5: Base Code

Create minimal working code. Only create files for features the project actually needs:

**Always create (core):**
- `app/main.py` — FastAPI app with lifespan (connect/disconnect DBs based on DB_CHOICE)
- `app/config.py` — Pydantic BaseSettings with all env vars (DATABASE_URL if mysql, MONGODB_URL if mongodb, both if both)
- `app/core/security.py` — JWT + cookie helpers (skeleton)
- `app/core/exceptions.py` — Custom exceptions + handlers
- `app/core/logging_config.py` — structlog JSON logging + request ID middleware
- `app/api/v1/router.py` — Central router
- `app/api/v1/health.py` — GET /health endpoint
- `app/schemas/common.py` — SuccessResponse, ErrorResponse, PaginationParams

**Create based on DB_CHOICE:**
- `app/db/mysql.py` — (if DB_CHOICE=mysql or both) Async SQLAlchemy engine + session factory
- `app/db/mongodb.py` — (if DB_CHOICE=mongodb or both) PyMongo/Motor client + collection setup

**Create only if project uses Redis:**
- `app/db/redis.py` — Redis connection pool
- `app/core/rate_limiter.py` — Redis sliding window rate limiter (per-plan)

**Create only if project has social login:**
- `app/core/oauth.py` — Google OAuth2 client config (authlib with OIDC discovery)

**Create only if project has payments:**
- `app/core/razorpay_client.py` — Razorpay SDK init + signature verification helpers
- `app/core/point_costs.py` — Action -> credit point cost mapping (agent auto-generates)

**Create only if project has email:**
- `app/services/email_service.py` — Email dispatch service (sends all emails via Celery tasks)
- `app/tasks/email_tasks.py` — Celery task for async email sending (SMTP + Jinja2 templates)
- `app/templates/emails/base.html` — Base email template (header, footer, branding, unsubscribe link)
- `app/templates/emails/welcome.html` — Welcome email template
- `app/templates/emails/verify_otp.html` — Email/OTP verification template

**Create only if project has RBAC:**
- `app/core/permissions.py` — RBAC: require_role(), require_permission() FastAPI dependencies

**Create only if project has real-time features:**
- `app/core/websocket_manager.py` — WebSocket connection manager with Redis pub/sub

**Create only if project has error tracking:**
- `app/core/sentry_config.py` — Sentry SDK initialization

**Create only if project has file uploads:**
- `app/services/storage_service.py` — S3/GCS file upload abstraction (presigned URLs)

**Create only if project has full-text search:**
- `app/services/search_service.py` — Meilisearch integration (index, search)

**Create only if project has in-app notifications:**
- `app/services/notification_service.py` — In-app notification center

**Create only if project has mobile app:**
- `app/services/push_service.py` — Push notifications via FCM

**Create only if project has analytics:**
- `app/services/analytics_service.py` — Event tracking (PostHog)

**Create only if project has feature flags:**
- `app/services/feature_flag_service.py` — Feature flags (MySQL + Redis cache)

**Create only if project has feedback system:**
- `app/services/feedback_service.py` — Feedback submission + admin review

**Create only if project has onboarding flow:**
- `app/services/onboarding_service.py` — Onboarding progress tracking

**Create only if project has GDPR data export:**
- `app/services/export_service.py` — GDPR data export (ZIP generation)

**Create only if project has backup automation:**
- `app/services/backup_service.py` — MySQL + MongoDB backup to S3
- `app/tasks/backup_tasks.py` — Celery beat daily backup task

**Create only if project has session management:**
- `app/models/sql/session.py` — UserSession model (device, IP, location tracking)

**Mobile base code (if --with-mobile):**
- `mobile/app.config.ts` — Expo config with all required fields
- `mobile/eas.json` — EAS Build profiles (dev/preview/prod)
- `mobile/babel.config.js` — Preset + NativeWind + Reanimated plugins
- `mobile/metro.config.js` — withNativeWind wrapper
- `mobile/tailwind.config.js` — NativeWind preset
- `mobile/lib/api.ts` — Axios instance with expo-secure-store auth interceptor + auto-refresh
- `mobile/lib/auth.ts` — Token storage helpers (setTokens, getTokens, clearTokens)
- `mobile/lib/queryClient.ts` — TanStack Query client with offline persistence
- `mobile/lib/i18n.ts` — i18next setup with expo-localization
- `mobile/app/_layout.tsx` — Root layout with ThemeProvider, QueryClientProvider, SafeAreaProvider
- `mobile/hooks/useAuth.ts` — Auth hook (login, logout, isAuthenticated, user)
- `mobile/hooks/useNetwork.ts` — Network connectivity hook with offline banner
- `mobile/stores/authStore.ts` — Zustand auth store
- `mobile/components/ui/Button.tsx` — Themed button with haptic feedback
- `mobile/components/ui/Input.tsx` — Themed text input with label + error
- `mobile/components/shared/OfflineBanner.tsx` — Top banner shown when offline

**GenAI base code (if --with-ai):**
- `app/ai/__init__.py` — AI module init
- `app/ai/config.py` — LiteLLM config: MODEL_REGISTRY, FALLBACK_CHAIN, cost-per-model mapping
- `app/ai/gateway.py` — LiteLLM gateway wrapper: generate(), embed(), stream(), with fallbacks + cost tracking
- `app/ai/prompts/system/default.yaml` — Default system prompt template
- `app/ai/agents/base_agent.py` — Base agent class with tool use, memory, state management
- `app/ai/agents/chat_agent.py` — Conversational AI agent (Google ADK or LangGraph)
- `app/ai/agents/tools/search_tool.py` — Web search tool for agents
- `app/ai/rag/embeddings.py` — Embedding generation via LiteLLM (with Redis caching)
- `app/ai/rag/vector_store.py` — Qdrant client wrapper (upsert, search, delete)
- `app/ai/rag/chunker.py` — Semantic document chunker with overlap
- `app/ai/rag/retriever.py` — Hybrid retrieval (vector + BM25)
- `app/ai/memory/conversation.py` — Chat history storage (MongoDB)
- `app/ai/guardrails/input_filter.py` — Input validation + content filtering
- `app/ai/guardrails/output_filter.py` — Output PII detection + filtering
- `app/ai/guardrails/cost_limiter.py` — Per-user daily AI cost caps
- `app/ai/mcp/__init__.py` — MCP module init
- `app/ai/mcp/server.py` — MCP server setup
- `app/ai/mcp/prompt_server.py` — Reusable MCP prompts
- `app/ai/a2a/__init__.py` — A2A module init
- `app/ai/a2a/agent_card.py` — A2A Agent Card
- `app/ai/a2a/task_handler.py` — A2A task handler
- `app/ai/eval/llm_tests.py` — DeepEval LLM unit test runner (pytest-compatible)
- `app/ai/eval/rag_quality.py` — RAGAS RAG quality metrics (faithfulness, relevancy, recall)
- `app/ai/structured/extractor.py` — instructor + Pydantic structured output extraction
- `app/ai/cache/semantic_cache.py` — Redis semantic cache with embedding similarity
- `app/ai/reranker/reranker.py` — Cohere Rerank / FlashRank post-retrieval re-ranking
- `app/ai/multimodal/vision.py` — Vision analysis via LiteLLM (GPT-4o / Gemini / Claude)
- `app/ai/multimodal/image_gen.py` — Image generation via LiteLLM (DALL-E 3 / Flux)
- `app/ai/multimodal/audio.py` — STT (Whisper) + TTS (OpenAI / Gemini / ElevenLabs)
- `app/ai/hitl/review_queue.py` — HITL review queue with confidence threshold
- `app/ai/context/context_manager.py` — Context window management with tiktoken
- `app/ai/voice/stt.py` — Whisper speech-to-text via LiteLLM
- `app/ai/voice/tts.py` — Text-to-speech (OpenAI TTS / Gemini TTS / ElevenLabs)
- `app/ai/voice/streaming.py` — WebSocket audio streaming handler
- `app/ai/batch/batch_processor.py` — Celery batch AI processing with Redis progress

**Web frontend base code (if --with-frontend OR PRD has web frontend — default YES for most projects):**

> Load `skills/alpha-architecture/references/CODE_PATTERNS_FRONTEND_PRODUCTION.md` FIRST — the production bar (fonts & color via next/font + OKLCH tokens, real data, polish, perf/a11y, friendly errors with NO HTTP codes/exceptions).
> Load `skills/alpha-architecture/references/CODE_PATTERNS_FRONTEND_CORE.md` for architecture (routes, providers, middleware, page state).
> Load `skills/alpha-architecture/references/CODE_PATTERNS_FRONTEND_PAGES.md` for dashboard layout + page templates.
> Load `skills/alpha-architecture/references/CODE_PATTERNS_FRONTEND_UX.md` for reusable components, skeletons, animations.

Create the following files to give the frontend a working foundation:

- `frontend/package.json` — Dependencies:
  ```json
  {
    "dependencies": {
      "next": "^15.0.0",
      "react": "^19.0.0",
      "react-dom": "^19.0.0",
      "@tanstack/react-query": "^5.0.0",
      "@tanstack/react-query-devtools": "^5.0.0",
      "@tanstack/react-table": "^8.0.0",
      "react-hook-form": "^7.0.0",
      "@hookform/resolvers": "^3.0.0",
      "zod": "^3.0.0",
      "axios": "^1.7.0",
      "sonner": "^1.7.0",
      "framer-motion": "^11.0.0",
      "recharts": "^2.12.0",
      "lucide-react": "^0.400.0",
      "next-themes": "^0.4.0",
      "cmdk": "^1.0.0",
      "date-fns": "^3.0.0",
      "clsx": "^2.0.0",
      "tailwind-merge": "^2.0.0",
      "class-variance-authority": "^0.7.0"
    },
    "devDependencies": {
      "typescript": "^5.0.0",
      "@types/react": "^19.0.0",
      "@types/node": "^22.0.0",
      "tailwindcss": "^3.4.0",
      "postcss": "^8.0.0",
      "autoprefixer": "^10.0.0",
      "eslint": "^9.0.0",
      "eslint-config-next": "^15.0.0"
    }
  }
  ```

- `frontend/next.config.ts` — API proxy rewrite + image domains:
  ```typescript
  import type { NextConfig } from "next";
  const nextConfig: NextConfig = {
    async rewrites() {
      return [
        { source: "/api/:path*", destination: `${process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000"}/api/:path*` },
      ];
    },
    images: { remotePatterns: [{ protocol: "https", hostname: "**" }] },
  };
  export default nextConfig;
  ```

- `frontend/app/fonts.ts` — **Production font pairing via `next/font` (HARD — see CODE_PATTERNS_FRONTEND_PRODUCTION.md §0).** NEVER ship on system-ui default. Define a DISPLAY font (headings/brand) + a BODY/UI font from BRAND_GUIDE, each `display: "swap"` with a CSS `variable`:
  ```typescript
  import { Playfair_Display, Inter } from "next/font/google"; // ← pick per BRAND_GUIDE
  export const fontDisplay = Playfair_Display({ subsets: ["latin"], display: "swap", variable: "--font-display", weight: ["400","600","700","800"] });
  export const fontSans = Inter({ subsets: ["latin"], display: "swap", variable: "--font-sans", weight: ["300","400","500","600","700"] });
  ```
  Apply `${fontDisplay.variable} ${fontSans.variable}` to `<html>` in `app/layout.tsx`; `<body>` uses `font-sans antialiased bg-background text-foreground`.

- `frontend/app/globals.css` — **Full OKLCH semantic token system, light + dark (HARD).** `:root` + `.dark` blocks for background/foreground/card/primary/secondary/muted/accent/destructive/success/warning/info/border/input/ring. Both themes required. (Skeleton in CODE_PATTERNS_FRONTEND_PRODUCTION.md §0.2.)

- `frontend/tailwind.config.ts` — Map the token system to Tailwind (populated from BRAND_GUIDE.md). **Components use semantic tokens ONLY — never raw Tailwind palette (`bg-blue-500`) or hard-coded hex.**
  ```typescript
  import type { Config } from "tailwindcss";
  const config: Config = {
    darkMode: "class",
    content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}", "./lib/**/*.{ts,tsx}"],
    theme: {
      extend: {
        colors: {
          background: "var(--background)", foreground: "var(--foreground)",
          card: "var(--card)", primary: "var(--primary)", secondary: "var(--secondary)",
          muted: "var(--muted)", accent: "var(--accent)", destructive: "var(--destructive)",
          border: "var(--border)", input: "var(--input)", ring: "var(--ring)",
        },
        fontFamily: {
          sans: ["var(--font-sans)", "system-ui", "sans-serif"],
          display: ["var(--font-display)", "serif"],
        },
      },
    },
    plugins: [require("tailwindcss-animate")],
  };
  export default config;
  ```

- `frontend/tsconfig.json` — Strict mode + path aliases:
  ```json
  {
    "compilerOptions": {
      "strict": true,
      "target": "ES2017",
      "lib": ["dom", "dom.iterable", "esnext"],
      "jsx": "preserve",
      "module": "esnext",
      "moduleResolution": "bundler",
      "paths": { "@/*": ["./*"] },
      "incremental": true,
      "plugins": [{ "name": "next" }]
    },
    "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
    "exclude": ["node_modules"]
  }
  ```

- `frontend/middleware.ts` — Auth redirect logic:
  ```typescript
  import { NextResponse } from "next/server";
  import type { NextRequest } from "next/server";

  const publicRoutes = ["/", "/login", "/register", "/forgot-password", "/pricing", "/terms", "/privacy"];
  const authRoutes = ["/login", "/register", "/forgot-password"];

  export function middleware(request: NextRequest) {
    const { pathname } = request.nextUrl;
    const accessToken = request.cookies.get("access_token")?.value;

    if (pathname.startsWith("/api") || pathname.startsWith("/_next") || pathname.includes(".")) {
      return NextResponse.next();
    }
    if (authRoutes.includes(pathname) && accessToken) {
      return NextResponse.redirect(new URL("/dashboard", request.url));
    }
    if (!accessToken && !publicRoutes.includes(pathname)) {
      const loginUrl = new URL("/login", request.url);
      loginUrl.searchParams.set("callbackUrl", pathname);
      return NextResponse.redirect(loginUrl);
    }
    return NextResponse.next();
  }

  export const config = { matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"] };
  ```

- `frontend/app/layout.tsx` — Root layout with provider hierarchy:
  ```tsx
  import type { Metadata } from "next";
  import { Inter } from "next/font/google";
  import { Providers } from "@/providers";
  import "./globals.css";

  const inter = Inter({ subsets: ["latin"], variable: "--font-sans" });

  export const metadata: Metadata = {
    title: { default: "APP_NAME", template: "%s | APP_NAME" },
    description: "APP_DESCRIPTION",
  };

  export default function RootLayout({ children }: { children: React.ReactNode }) {
    return (
      <html lang="en" suppressHydrationWarning>
        <body className={`${inter.variable} font-sans antialiased`}>
          <Providers>{children}</Providers>
        </body>
      </html>
    );
  }
  ```

- `frontend/app/(auth)/layout.tsx` — Centered card layout:
  ```tsx
  export default function AuthLayout({ children }: { children: React.ReactNode }) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-muted/50 p-4">
        <div className="w-full max-w-md">{children}</div>
      </div>
    );
  }
  ```

- `frontend/app/(auth)/login/page.tsx` — Minimal login page skeleton (React Hook Form + Zod):
  ```tsx
  "use client";
  import { useForm } from "react-hook-form";
  import { zodResolver } from "@hookform/resolvers/zod";
  import { z } from "zod";
  // ... minimal login form with email + password + Google OAuth button
  // Full implementation follows CODE_PATTERNS_FRONTEND_PAGES.md Auth Pages pattern
  ```

- `frontend/app/(dashboard)/layout.tsx` — Sidebar + header layout:
  ```tsx
  // Full dashboard layout with collapsible sidebar, header with breadcrumbs,
  // user menu, notifications, search trigger, theme toggle
  // Follows CODE_PATTERNS_FRONTEND_PAGES.md Dashboard Layout pattern
  ```

- `frontend/app/(dashboard)/page.tsx` — Dashboard home skeleton:
  ```tsx
  // Dashboard home with stats cards, chart placeholder, recent activity
  // Follows CODE_PATTERNS_FRONTEND_PAGES.md Dashboard Page pattern
  ```

- `frontend/lib/api.ts` — Axios instance + interceptors:
  ```typescript
  import axios from "axios";

  export const api = axios.create({
    baseURL: process.env.NEXT_PUBLIC_API_URL || "",
    withCredentials: true,
    headers: { "Content-Type": "application/json" },
  });

  // Response interceptor: 401 -> refresh token -> retry
  api.interceptors.response.use(
    (response) => response,
    async (error) => {
      const originalRequest = error.config;
      if (error.response?.status === 401 && !originalRequest._retry) {
        originalRequest._retry = true;
        try {
          await axios.post("/api/v1/auth/refresh", {}, { withCredentials: true });
          return api(originalRequest);
        } catch {
          window.location.href = "/login";
          return Promise.reject(error);
        }
      }
      return Promise.reject(error);
    }
  );
  ```

- `frontend/lib/query-client.ts` — TanStack Query client:
  ```typescript
  import { QueryClient } from "@tanstack/react-query";
  export const queryClient = new QueryClient({
    defaultOptions: {
      queries: { staleTime: 60 * 1000, retry: 1, refetchOnWindowFocus: false },
    },
  });
  ```

- `frontend/hooks/useAuth.ts` — Auth hook:
  ```typescript
  "use client";
  import { useQuery, useQueryClient } from "@tanstack/react-query";
  import { api } from "@/lib/api";
  import { useRouter } from "next/navigation";

  export function useAuth() {
    const router = useRouter();
    const queryClient = useQueryClient();

    const { data: user, isLoading } = useQuery({
      queryKey: ["auth", "me"],
      queryFn: () => api.get("/api/v1/auth/me").then((r) => r.data),
      retry: false,
    });

    const logout = async () => {
      await api.post("/api/v1/auth/logout");
      queryClient.clear();
      router.push("/login");
    };

    return { user, isLoading, isAuthenticated: !!user, logout };
  }
  ```

- `frontend/providers/index.tsx` — Provider composition:
  ```tsx
  "use client";
  import { ThemeProvider } from "next-themes";
  import { QueryClientProvider } from "@tanstack/react-query";
  import { ReactQueryDevtools } from "@tanstack/react-query-devtools";
  import { Toaster } from "sonner";
  import { queryClient } from "@/lib/query-client";

  export function Providers({ children }: { children: React.ReactNode }) {
    return (
      <ThemeProvider attribute="class" defaultTheme="system" enableSystem disableTransitionOnChange>
        <QueryClientProvider client={queryClient}>
          {children}
          <Toaster richColors position="top-right" />
          <ReactQueryDevtools initialIsOpen={false} />
        </QueryClientProvider>
      </ThemeProvider>
    );
  }
  ```

- `frontend/components/ui/` — Run `npx shadcn@latest init` and add: button, card, input, label, dialog, dropdown-menu, sheet, tabs, badge, skeleton, avatar, separator, tooltip, command

- `frontend/components/shared/page-header.tsx` — Reusable page header:
  ```tsx
  interface PageHeaderProps {
    title: string;
    description?: string;
    action?: { label: string; href?: string; onClick?: () => void };
  }
  // Full implementation follows CODE_PATTERNS_FRONTEND_UX.md
  ```

- `frontend/components/shared/empty-state.tsx` — Reusable empty state:
  ```tsx
  interface EmptyStateProps {
    icon: string;
    title: string;
    description: string;
    actionLabel?: string;
    actionHref?: string;
  }
  // Full implementation follows CODE_PATTERNS_FRONTEND_UX.md
  ```

- `frontend/components/shared/data-table.tsx` — Reusable data table:
  ```tsx
  // Generic TanStack Table wrapper with sorting, filtering, pagination
  // Full implementation follows CODE_PATTERNS_FRONTEND_UX.md
  ```

## Step 6: Git Init

```bash
git init
git add -A
git commit -m "feat: initialize project with Alpha AI architecture"
```

## Step 7: Verify Build

**Quick verify (per language):**
- **Python**: `python3 -m venv venv && source venv/bin/activate && pip install -r requirements-dev.txt && ruff check app/ && python -c "from app.main import app; print('App loads')"` (ALWAYS create venv FIRST — never install globally)
- **NestJS**: `pnpm install && pnpm lint && pnpm build && echo 'App builds'`
- **Spring Boot**: `./gradlew build && echo 'App builds'`

---

## Step 8: Setup Validation (CRITICAL — Must Pass Before Declaring Init Complete)

**⚡ DELEGATE TO SUBAGENT** — spawn Task to run full setup validation.

After the project scaffolding and git init, run a comprehensive validation to confirm the setup is actually working — not just that files exist. This catches misconfiguration, missing env vars, broken imports, and service connectivity issues **before** the developer starts building features.

### 8a. Environment & Dependencies Check

```bash
# Python
python --version                                    # Confirm Python 3.11+
pip list --format=freeze | head -5                  # Confirm deps installed in venv
python -c "import fastapi; print(fastapi.__version__)"  # Confirm FastAPI importable

# NestJS
node --version                                      # Confirm Node 22+
pnpm list --depth=0 | head -5                       # Confirm deps installed
npx tsc --noEmit                                    # TypeScript compiles with zero errors

# Spring Boot
java --version                                      # Confirm Java 21+
./gradlew dependencies | head -10                   # Confirm deps resolve
./gradlew compileJava                               # Java compiles with zero errors
```

**Check**: All commands exit with code 0. If any fail, fix immediately before proceeding.

### 8b. Linter & Type Checker — Zero Errors

```bash
# Python
ruff check app/ --output-format=concise             # Zero lint errors
mypy app/ --ignore-missing-imports                   # Zero type errors (if mypy configured)

# NestJS
pnpm lint                                           # Zero ESLint errors
pnpm build                                          # TypeScript builds clean

# Spring Boot
./gradlew checkstyleMain                            # Zero style violations
./gradlew spotbugsMain                              # Zero bug patterns (if configured)
```

**Check**: Zero errors, zero warnings treated as errors. If linter reports issues, fix them — don't ship a broken scaffold.

### 8c. Docker Services Boot

```bash
# Start all services
docker compose -f docker/docker-compose.yml up -d

# Wait for services to be healthy (max 60s)
sleep 10

# Check all containers are running (not restarting/exited)
docker compose -f docker/docker-compose.yml ps --format "table {{.Name}}\t{{.Status}}"
```

**Check each service individually:**

```bash
# MySQL (if DB_CHOICE=mysql or both) — must accept connections
docker compose -f docker/docker-compose.yml exec mysql mysqladmin ping -h localhost -u root -p"${MYSQL_ROOT_PASSWORD}" 2>/dev/null && echo "✅ MySQL: OK" || echo "❌ MySQL: FAILED"

# MongoDB (if DB_CHOICE=mongodb or both) — must accept connections
docker compose -f docker/docker-compose.yml exec mongodb mongosh --eval "db.runCommand({ping:1})" --quiet 2>/dev/null && echo "✅ MongoDB: OK" || echo "❌ MongoDB: FAILED"

# Redis (if used) — must accept connections
docker compose -f docker/docker-compose.yml exec redis redis-cli ping 2>/dev/null && echo "✅ Redis: OK" || echo "❌ Redis: FAILED"

# Meilisearch (if used) — must respond to health check
curl -sf http://localhost:7700/health && echo "✅ Meilisearch: OK" || echo "❌ Meilisearch: FAILED"

# MinIO (if used) — must respond
curl -sf http://localhost:9000/minio/health/live && echo "✅ MinIO: OK" || echo "❌ MinIO: FAILED"
```

**Check**: ALL containers show "Up" status (not "Restarting" or "Exited"). All service pings return OK.

### 8d. Application Server Starts & Health Endpoint Responds

```bash
# Python — start the app server in background
source venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000 &
APP_PID=$!
sleep 5

# NestJS — start the app server in background
# pnpm start:dev &
# APP_PID=$!
# sleep 8

# Spring Boot — start the app server in background
# ./gradlew bootRun &
# APP_PID=$!
# sleep 15

# Hit the health endpoint
HEALTH_RESPONSE=$(curl -sf http://localhost:8000/health 2>/dev/null)
echo "Health response: $HEALTH_RESPONSE"

# Verify health returns 200 with valid JSON
curl -sf -o /dev/null -w "%{http_code}" http://localhost:8000/health | grep -q "200" && echo "✅ Health endpoint: OK (200)" || echo "❌ Health endpoint: FAILED"

# Check OpenAPI docs load (FastAPI / NestJS Swagger)
curl -sf -o /dev/null -w "%{http_code}" http://localhost:8000/docs | grep -q "200" && echo "✅ API docs: OK" || echo "❌ API docs: FAILED"

# Stop the app server
kill $APP_PID 2>/dev/null
```

**Check**: Health endpoint returns HTTP 200 with valid JSON. API docs page loads.

### 8e. Database Connectivity from App

```bash
# Python — verify app can connect to all databases based on DB_CHOICE
source venv/bin/activate
python -c "
from app.config import settings

# Test MySQL connection (if DB_CHOICE=mysql or both)
try:
    from app.db.mysql import engine  # only exists if DB_CHOICE=mysql or both
    from sqlalchemy import create_engine, text
    sync_engine = create_engine(settings.DATABASE_URL.replace('+aiomysql', '+pymysql'))
    with sync_engine.connect() as conn:
        result = conn.execute(text('SELECT 1'))
        print('✅ MySQL connection: OK')
except ImportError:
    print('⏭️  MySQL: not in DB_CHOICE (skipped)')
except Exception as e:
    print(f'❌ MySQL connection: FAILED ({e})')

# Test MongoDB connection (if DB_CHOICE=mongodb or both)
try:
    from app.db.mongodb import get_mongo_client  # only exists if DB_CHOICE=mongodb or both
    client = get_mongo_client()
    client.admin.command('ping')
    print('✅ MongoDB connection: OK')
except ImportError:
    print('⏭️  MongoDB: not in DB_CHOICE (skipped)')
except Exception as e:
    print(f'❌ MongoDB connection: FAILED ({e})')

# Test Redis (if configured)
try:
    import redis
    r = redis.from_url(settings.REDIS_URL)
    r.ping()
    print('✅ Redis connection: OK')
except (ImportError, AttributeError):
    print('⏭️  Redis: not configured (skipped)')
except Exception as e:
    print(f'❌ Redis connection: FAILED ({e})')
"
```

**Check**: App successfully connects to every database service that was configured. Skip services not in the project's feature profile.

### 8f. Celery Worker Starts (if project uses async tasks)

```bash
# Only run if Celery is in the project
if grep -q "celery" requirements.txt 2>/dev/null; then
    source venv/bin/activate
    celery -A app.tasks inspect ping --timeout 10 2>/dev/null && echo "✅ Celery worker: OK" || echo "⚠️  Celery worker: not running (start with docker-compose)"
fi
```

### 8g. Test Suite Runs (Smoke Test)

```bash
# Python
source venv/bin/activate && pytest tests/ -x -q --tb=short 2>/dev/null && echo "✅ Tests: PASS" || echo "⚠️  Tests: no tests yet (expected for fresh scaffold)"

# NestJS
# pnpm test -- --passWithNoTests && echo "✅ Tests: PASS" || echo "⚠️  Tests: no tests yet"

# Spring Boot
# ./gradlew test && echo "✅ Tests: PASS" || echo "⚠️  Tests: no tests yet"
```

### 8h. Security Quick Check

```bash
# Check .env is gitignored
grep -q "\.env" .gitignore && echo "✅ .env in .gitignore" || echo "❌ .env NOT in .gitignore — FIX THIS"

# Check no secrets hardcoded in committed files
git grep -i "password\|secret_key\|api_key" -- '*.py' '*.ts' '*.java' ':!*.example' ':!*.sample' | grep -v "os.getenv\|environ\|settings\.\|process.env\|@Value" | head -5
# If any matches: warn about potential hardcoded secrets

# Check Docker runs as non-root (if Dockerfile exists)
if [ -f docker/Dockerfile ]; then
    grep -q "USER" docker/Dockerfile && echo "✅ Dockerfile: non-root user" || echo "⚠️  Dockerfile: no USER directive (add non-root user)"
fi
```

### 8i. Cleanup After Validation

```bash
# Stop Docker services started for testing
docker compose -f docker/docker-compose.yml down

# Kill any remaining background processes
kill $APP_PID 2>/dev/null
```

### 8j. Validation Report

Print a validation report with pass/fail for each check:

```
╔══════════════════════════════════════════════════════════════╗
║  SETUP VALIDATION: [project-name]                            ║
╠══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Environment & Deps    [✅ PASS | ❌ FAIL]                   ║
║  Linter & Types        [✅ PASS | ❌ FAIL]                   ║
║  Docker Services       [✅ PASS | ❌ FAIL | ⏭️ SKIPPED]      ║
║  Health Endpoint       [✅ PASS | ❌ FAIL]                   ║
║  Database Connectivity [✅ PASS | ❌ FAIL | ⏭️ SKIPPED]      ║
║  Celery Worker         [✅ PASS | ⏭️ SKIPPED]                ║
║  Test Suite            [✅ PASS | ⚠️ NO TESTS YET]           ║
║  Security Checks       [✅ PASS | ⚠️ WARNINGS]               ║
║                                                               ║
║  Overall: [X/Y checks passed]                                ║
║                                                               ║
║  ❌ FAILURES (fix before proceeding):                        ║
║  - [list any failed checks with fix instructions]            ║
║                                                               ║
║  ⚠️  WARNINGS (recommended fixes):                           ║
║  - [list any warnings with suggestions]                      ║
║                                                               ║
╚══════════════════════════════════════════════════════════════╝
```

**If any ❌ FAIL**: Fix the issue immediately. Do NOT declare init complete until all critical checks pass. Common fixes:
- Missing env var → add to `.env` from `.env.example`
- Docker service won't start → check port conflicts, check `docker logs <service>`
- Import error → missing dependency in requirements.txt
- Database connection refused → Docker service not ready, wrong port/credentials in `.env`
- Linter error → fix the generated code (scaffold must be clean)

**If all ✅ PASS**: The setup is confirmed working. Proceed to Output Summary.

---

## Output Summary

Print a table of everything created with status indicators.

### Next Steps Guidance

After scaffolding, suggest the optimal next steps based on what exists:

```
╔══════════════════════════════════════════════════════════════╗
║  PROJECT INITIALIZED: [project-name]                         ║
╠══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Recommended Next Steps:                                     ║
║                                                               ║
║  Option A: Fully Autonomous Build                            ║
║  1. /gen-prd "your product idea"                             ║
║     → Generates PRD.md + SPRINT_PLAN.md + MARKET_RESEARCH.md ║
║  2. /auto-build ./PRD.md                                     ║
║     → Builds entire product with sprint tracking             ║
║                                                               ║
║  Option B: Manual Sprint-Based Development                   ║
║  1. /gen-prd "your product idea"                             ║
║     → Generates PRD.md + SPRINT_PLAN.md                      ║
║  2. /sprint-plan ./PRD.md --sprints=4 --team-size=3          ║
║     → Customize sprint plan with your team size              ║
║  3. /feature "task from sprint plan"                         ║
║     → Build features one by one following the sprint plan    ║
║                                                               ║
║  Option C: Existing Project Upgrade                          ║
║  1. /analyze-project                                         ║
║  2. /gap-analysis                                            ║
║  3. /retrofit <feature> or /migrate-stack <migration>        ║
║                                                               ║
║  All paths include automatic sprint/task planning.           ║
╚══════════════════════════════════════════════════════════════╝
```
