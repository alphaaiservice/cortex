---
description: "Scan an existing codebase to map architecture, identify tech stack, and generate project intelligence. Creates PROJECT_ANALYSIS.md + auto-generates CLAUDE.md. Usage: /analyze-project [path-to-project]"
---

# Project Analyzer — Existing Codebase Intelligence

Analyze the existing project at: **$ARGUMENTS** (default: current directory)

This command scans an existing codebase and produces a comprehensive analysis that powers `/gap-analysis`, `/retrofit`, and `/auto-build --existing`.

---

## Step 1: Discover Project Root & Type

```bash
# Detect project type from files present
ls -la $ARGUMENTS 2>/dev/null || ls -la .
```

Identify:
- **Backend framework**: Look for `requirements.txt`, `pyproject.toml`, `package.json`, `go.mod`, `Cargo.toml`, `pom.xml`
- **Frontend framework**: Look for `next.config.*`, `nuxt.config.*`, `angular.json`, `vite.config.*`, `app.config.ts`
- **Mobile framework**: Look for `app.json`, `app.config.ts` (Expo), `Podfile` (iOS), `build.gradle` (Android)
- **Database**: Look for `alembic/`, `migrations/`, `prisma/`, `docker-compose.yml` (DB services)
- **CI/CD**: Look for `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`, `Dockerfile`
- **AI/ML**: Look for `app/ai/`, `agents/`, `prompts/`, model configs

## Step 2: Deep Scan Architecture (Use Agent subagents (mode = "bypassPermissions") in parallel)

### Scan 2A: Backend Analysis
```
Use Glob + Grep to find:
- Framework: FastAPI/Flask/Django/Express/NestJS/Spring/Go
- Auth: JWT, OAuth, session-based, Firebase Auth, Auth0, Clerk
- Token storage: HTTP-only cookies vs localStorage vs sessionStorage
- Database: MySQL/PostgreSQL/SQLite/MongoDB/Redis connections
- ORM: SQLAlchemy/Prisma/TypeORM/Mongoose/PyMongo/Beanie/Motor
- Payment: Stripe/Razorpay/PayPal integrations
- Email: SMTP/SendGrid/SES/fastapi-mail
- Task queue: Celery/Bull/RabbitMQ
- File storage: S3/GCS/local filesystem
- Search: Elasticsearch/Meilisearch/Algolia
- Real-time: WebSocket/Socket.IO/SSE/polling
- Cache: Redis/Memcached/in-memory
```

### Scan 2B: Frontend Analysis
```
Use Glob + Grep to find:
- Framework: Next.js/React/Vue/Angular/Svelte
- UI library: shadcn/Ant Design/MUI/Chakra/Mantine/Bootstrap/Tailwind
- State management: Redux/Zustand/MobX/Recoil/Context
- Forms: React Hook Form/Formik/custom
- API client: Axios/fetch/TanStack Query/SWR
- Auth handling: Where tokens are stored, how auth state is managed
- Theme: Dark mode support? CSS variables? Tailwind dark?
- i18n: Any translation system?
- PWA: Service worker? Manifest?
```

### Scan 2C: Mobile Analysis (if mobile/ or app/ with RN)
```
Use Glob + Grep to find:
- Framework: React Native/Expo/Flutter/Native
- Expo SDK version, React Native version
- Navigation: React Navigation/Expo Router
- Auth storage: SecureStore/AsyncStorage/Keychain
- UI: NativeWind/Paper/styled-components
- State: Zustand/Redux/MobX
- Offline: NetInfo/offline queue
- Push: expo-notifications/FCM
```

### Scan 2D: Infrastructure Analysis
```
Use Glob + Grep to find:
- Docker: docker-compose.yml services list
- CI/CD: Pipeline stages and tools
- Error tracking: Sentry/Bugsnag/none
- Analytics: PostHog/GA/Mixpanel/none
- Logging: structlog/Winston/Pino/basic logging
- Monitoring: Prometheus/Grafana/Datadog/none
- Environment: .env files, secrets management
```

### Scan 2E: Code Architecture Analysis
```
Use Glob to map directory structure:
- Layer segregation: api/services/repos pattern?
- Flat vs nested structure?
- Monolith vs microservices?
- Shared libraries? Monorepo?

Use Grep to find:
- Import patterns (cross-layer violations?)
- Error handling patterns
- Dependency injection patterns
- Test organization
```

### Scan 2F: GenAI/AI Analysis (if any AI code found)
```
Use Glob + Grep to find:
- LLM provider: OpenAI/Anthropic/Google direct SDK vs LiteLLM gateway
- Agent framework: LangChain/LangGraph/CrewAI/ADK/custom
- RAG: Vector DB (Pinecone/Qdrant/Weaviate/Chroma), embedding model
- Prompts: Hardcoded strings vs template files
- AI observability: Langfuse/LangSmith/none
- Guardrails: Input/output filtering? Cost caps?
- MCP: Any MCP server/client?
- A2A: Any Agent Card?
```

## Step 3: Measure Project Size & Quality

```bash
# Lines of code by language
find . -name "*.py" -o -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" | head -500 | xargs wc -l 2>/dev/null | tail -1

# Test count
find . -name "test_*.py" -o -name "*.test.ts" -o -name "*.spec.ts" | wc -l

# Total files
find . -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/venv/*" -not -path "*/__pycache__/*" -type f | wc -l
```

Count:
- Total lines of code (per language)
- Number of API endpoints
- Number of database models/tables
- Number of test files
- Number of Celery/background tasks
- Number of UI pages/screens

## Step 4: Generate PROJECT_ANALYSIS.md

Save the complete analysis:

```markdown
# Project Analysis Report
**Generated**: [date]
**Project**: [name from package.json/pyproject.toml]
**Path**: [project path]

## Tech Stack Detected

### Backend
| Component | Current Technology | Version |
|-----------|-------------------|---------|
| Language | [Python 3.x / Node.js / Go] | [version] |
| Framework | [FastAPI / Flask / Django / Express] | [version] |
| Auth | [JWT cookies / JWT localStorage / session / Firebase] | |
| SQL DB | [MySQL / PostgreSQL / SQLite / none] | [version] |
| NoSQL DB | [MongoDB / DynamoDB / none] | [version] |
| ORM | [SQLAlchemy / Prisma / TypeORM / Mongoose] | [version] |
| Cache | [Redis / Memcached / none] | [version] |
| Payments | [Stripe / Razorpay / none] | |
| Email | [fastapi-mail / SendGrid / SES / none] | |
| Task Queue | [Celery / Bull / none] | |
| File Storage | [S3 / GCS / local / none] | |
| Search | [Meilisearch / Elasticsearch / none] | |
| Real-Time | [WebSocket / Socket.IO / polling / none] | |

### Frontend
| Component | Current Technology | Version |
|-----------|-------------------|---------|
| Framework | [Next.js / React / Vue / none] | [version] |
| UI Library | [shadcn / Ant Design / MUI / custom] | |
| CSS | [Tailwind / CSS Modules / styled-components] | |
| State | [Zustand / Redux / Context] | |
| Forms | [React Hook Form / Formik / custom] | |
| Auth | [Cookie-based / localStorage / sessionStorage] | |
| Theme | [Dark mode: yes/no] | |
| i18n | [next-intl / i18next / none] | |

### Mobile (if present)
| Component | Current Technology | Version |
|-----------|-------------------|---------|
| Framework | [React Native / Expo / Flutter / none] | [version] |
| Navigation | [React Navigation / Expo Router] | |
| Auth Storage | [SecureStore / AsyncStorage / Keychain] | |
| UI | [NativeWind / Paper / custom] | |

### GenAI (if present)
| Component | Current Technology | Version |
|-----------|-------------------|---------|
| LLM Gateway | [LiteLLM / direct OpenAI SDK / none] | |
| Agent Framework | [ADK / LangGraph / LangChain / none] | |
| Vector DB | [Qdrant / Pinecone / Chroma / none] | |
| RAG | [yes / no] | |
| Prompts | [template files / hardcoded strings] | |
| AI Observability | [Langfuse / LangSmith / none] | |

### Infrastructure
| Component | Current Technology |
|-----------|-------------------|
| Docker | [yes / no] — services: [list] |
| CI/CD | [GitHub Actions / GitLab CI / none] |
| Error Tracking | [Sentry / Bugsnag / none] |
| Analytics | [PostHog / GA / none] |
| Logging | [structlog / basic / none] |
| Monitoring | [Prometheus / none] |

## Architecture

### Directory Structure
```
[ASCII tree of actual project structure]
```

### Layer Pattern
- [x] Layer segregation (api/services/repos): [yes / no / partial]
- [x] Business logic location: [services / mixed / controllers]
- [x] Data access pattern: [repository / direct ORM / raw SQL]
- [x] Import violations found: [count]

### Code Quality
| Metric | Value |
|--------|-------|
| Total LOC | [number] |
| Python LOC | [number] |
| TypeScript/JS LOC | [number] |
| API Endpoints | [count] |
| DB Models | [count] |
| Test Files | [count] |
| Test Coverage | [%] (if measurable) |

## Existing Features Inventory
- [ ] User authentication (email/password)
- [ ] Social login (Google/Apple/GitHub)
- [ ] Email verification
- [ ] Password reset
- [ ] Subscription billing
- [ ] Credit point system
- [ ] File upload
- [ ] Full-text search
- [ ] Real-time notifications
- [ ] Push notifications (mobile)
- [ ] RBAC (role-based access)
- [ ] 2FA/TOTP
- [ ] Session management
- [ ] Admin panel
- [ ] Feature flags
- [ ] Dark mode / themes
- [ ] i18n / multi-language
- [ ] PWA support
- [ ] Analytics tracking
- [ ] Error tracking (Sentry)
- [ ] GDPR compliance
- [ ] Feedback system
- [ ] Onboarding flow
- [ ] Automated backups
- [ ] Rate limiting
- [ ] AI chat / GenAI features
- [ ] RAG pipeline
- [ ] Agent workflows
- [ ] MCP protocol
- [ ] A2A protocol

## Key Files Map
| Purpose | File Path |
|---------|-----------|
| App entry | [path] |
| Config | [path] |
| Auth | [path] |
| DB connection | [path] |
| Main router | [path] |
| Models dir | [path] |
| Tests dir | [path] |
```

## Step 5: Auto-Generate CLAUDE.md

If no CLAUDE.md exists in the project, create one based on the analysis:

```markdown
# CLAUDE.md — [Project Name]

## Project Overview
[Auto-generated from analysis]

## Tech Stack
[From PROJECT_ANALYSIS.md]

## Architecture
[Layer pattern + directory structure]

## Key Conventions
[Detected patterns — naming, imports, error handling]

## Build & Test Commands
[Detected from package.json scripts / Makefile / pyproject.toml]

## Important Files
[Key files map from analysis]
```

If CLAUDE.md already exists, print a diff of what's missing vs what was detected.

## Step 6: Output Summary

Print a dashboard:

```
╔══════════════════════════════════════════════════════════════╗
║  PROJECT ANALYSIS COMPLETE                                    ║
╠══════════════════════════════════════════════════════════════╣
║  Project: [name]                                              ║
║  Type: [Backend / Fullstack / Mobile / GenAI]                ║
║  Stack: [FastAPI + Next.js + MySQL + Redis]                  ║
║  Size: [X] files, [Y] LOC                                   ║
║  Tests: [Z] test files                                       ║
║                                                               ║
║  📄 Generated: PROJECT_ANALYSIS.md                            ║
║  📄 Generated: CLAUDE.md (if missing)                         ║
║                                                               ║
║  Next steps:                                                  ║
║  → /gap-analysis    — See what's missing vs Alpha AI standards║
║  → /retrofit        — Add missing features                   ║
║  → /migrate-stack   — Migrate tech components                ║
║  → /auto-build --existing PRD.md — Build on top of this      ║
╚══════════════════════════════════════════════════════════════╝
```
