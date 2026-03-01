---
name: alpha-architecture
description: "ALWAYS auto-invoked on ANY code writing task. Enforces Alpha AI's CORE standards (layered architecture, JWT+HTTP-Only Cookies, MySQL+ORM, linting, type checking, testing) across all backend languages: Python/FastAPI, Node.js/NestJS, Java/Spring Boot. CONDITIONAL standards (MongoDB, Redis, Razorpay, Meilisearch, Mobile, GenAI, etc.) are enforced ONLY when the project uses those technologies. Detects backend language + project context from code, dependencies, and PRD before applying rules."
license: "Proprietary — Alpha AI Service Pvt Ltd"
compatibility: "Designed for Claude Code with cortex plugin"
metadata:
  author: "Alpha AI Service Pvt Ltd"
  version: "2.0"
---

# Alpha AI Architecture Standards

This skill is ALWAYS active. It detects project context and enforces APPLICABLE rules only.

## Step 0: Detect Project Context (ALWAYS DO THIS FIRST)

Before enforcing any rules, detect the backend language and build a requirements profile:

```
STEP 0a — DETECT BACKEND LANGUAGE (do this FIRST):

1. Look for language indicators in the project:
   - requirements.txt / pyproject.toml / app/main.py          → python-fastapi
   - package.json with @nestjs/ / nest-cli.json / src/main.ts → nodejs-nestjs
   - build.gradle.kts / pom.xml with spring-boot / src/main/java/ → java-springboot
2. If no existing code → check PRD.md or --lang flag
3. If still unknown → default to python-fastapi
4. Load the appropriate reference files:
   - references/LANG_PROFILE_{LANG}.md for stack conventions
   - references/CODE_PATTERNS_{LANG}.md for code examples
5. If Python detected → ALWAYS create virtual environment FIRST:
   python3 -m venv venv && source venv/bin/activate
   ❌ NEVER install packages globally — ALWAYS use venv

STEP 0b — BUILD REQUIREMENTS PROFILE:

1. Read PRD.md, SPRINT_PLAN.md, README.md, dependency files, docker-compose.yml
2. Scan source directory for existing code patterns
3. Build YES/NO profile:

   CORE (always YES — implementations vary by language):
   - Backend framework: YES → [FastAPI | NestJS | Spring Boot] (from Step 0a)
   - JWT + HTTP-Only Cookies: YES (if project has auth — almost all)
   - MySQL + ORM: YES → [SQLAlchemy | Prisma | Spring Data JPA]
   - Layer segregation: YES (controllers → services → repositories → models)
   - Linting: YES → [ruff | ESLint+Prettier | Checkstyle+SpotBugs]
   - Type checking: YES → [mypy | TypeScript | Java compiler]
   - Testing: YES → [pytest | Jest | JUnit 5]

   CONDITIONAL (detect from project):
   - MongoDB: YES only if project has flexible/nested documents, logs, audit trails, or profiles
   - Redis: YES only if project needs caching, rate limiting, JWT blacklist, or real-time
   - Razorpay payments: YES only if PRD mentions payments, subscriptions, billing, or India SaaS
   - Meilisearch: YES only if PRD mentions full-text search or search engine
   - Real-Time WebSocket: YES only if PRD mentions live updates, chat, notifications, or dashboards
   - Push Notifications (FCM): YES only if project has mobile app
   - File Upload (S3): YES only if PRD mentions uploads, images, or file management
   - Mobile (React Native): YES only if PRD mentions mobile app or --with-mobile flag
   - GenAI / Agentic AI: YES only if PRD mentions AI features or --with-ai flag
   - MCP Protocol: YES only if project exposes tools/prompts for AI agents
   - A2A Protocol: YES only if project needs agent-to-agent communication
   - i18n: YES only if PRD mentions multi-language
   - PWA: YES only if PRD mentions offline or installable web app
   - 2FA: YES only if PRD mentions two-factor or enhanced security
   - RBAC: YES only if PRD mentions roles beyond simple user/admin
   - Analytics (PostHog): YES only if PRD mentions analytics or event tracking
   - Error Tracking (Sentry): YES (recommended for all production apps, but not forced)

4. ONLY enforce rules for technologies marked YES
5. If unsure whether a technology applies → do NOT enforce it
```

---

## Tech Stack — CORE (Always Enforced)

> Backend technology varies by detected language (Step 0a). Frontend stack is always the same.

### Backend Stack (per language from Step 0a)

| Component | Python/FastAPI | Node.js/NestJS | Java/Spring Boot |
|-----------|---------------|----------------|------------------|
| Framework | FastAPI + Python 3.11+ | NestJS 11+ + TypeScript | Spring Boot 3.4+ + Java 21 |
| ORM | SQLAlchemy 2.0 async | Prisma | Spring Data JPA + Hibernate 6 |
| Auth lib | python-jose + passlib | @nestjs/jwt + bcryptjs | jjwt-api + Spring Security |
| Email | fastapi-mail + Celery | @nestjs-modules/mailer + BullMQ | spring-boot-starter-mail + @Async |
| Queue | Celery + Redis | BullMQ | Spring @Async + @Scheduled |
| Linter | ruff | ESLint + Prettier | Checkstyle + SpotBugs |
| Types | mypy (strict) | TypeScript (built-in) | Java compiler (built-in) |
| Tests | pytest + pytest-asyncio | Jest + supertest | JUnit 5 + Mockito + MockMvc |
| Migrations | Alembic | Prisma migrate | Flyway |
| Package | pip + requirements.txt | pnpm + package.json | Gradle (Kotlin DSL) |
| Docker base | python:3.11-slim | node:22-alpine | eclipse-temurin:21-jre-alpine |
| GenAI | LiteLLM + Google ADK | Vercel AI SDK + LangChain.js | Spring AI + LangChain4j |

**NEVER Use (any language):** Flask, Django, Express (raw), Ruby on Rails, PHP Laravel

### Core (All Languages)

| Component | Technology | NEVER Use |
|-----------|-----------|-----------|
| Auth | JWT + HTTP-Only Cookies | localStorage, sessionStorage, Bearer header from frontend |
| SQL DB | MySQL + [SQLAlchemy \| Prisma \| Spring Data JPA] | PostgreSQL, SQLite (prod), raw SQL |
| Frontend Web | Next.js 15+ + TypeScript + Tailwind + shadcn/ui (or best for product) | Vanilla JS, Vue, Angular, jQuery |
| UI Components | Agent researches & picks best (shadcn/Ant/MUI/Chakra/Mantine) | Random/mixed UI libraries, Bootstrap |
| Forms | React Hook Form + Zod | Formik, uncontrolled forms without validation |
| Themes | Multi-theme: Light + Dark + System (next-themes / ThemeProvider) | Single theme, no dark mode, hardcoded colors |

## Tech Stack — CONDITIONAL (Only If Project Uses These)

> **RULE**: Only enforce rows below IF the project context (from Step 0) indicates the technology is needed. If the project does not use MongoDB, do NOT enforce MongoDB rules. If the project has no payments, do NOT enforce Razorpay rules. Etc.

| Component | Technology | NEVER Use | Enforce When |
|-----------|-----------|-----------|--------------|
| NoSQL DB | MongoDB + [PyMongo \| Mongoose \| Spring Data MongoDB] | DynamoDB, CouchDB, Firestore | Project has flexible docs, logs, or audit trails |
| Cache | Redis + [redis.asyncio \| ioredis \| Spring Data Redis] | Memcached, in-memory dicts | Project needs caching, rate limiting, or real-time |
| Payments | Razorpay (India SaaS) | Stripe, PayPal, CCAvenue | PRD mentions payments, billing, subscriptions |
| Social Login | Google OAuth2 via [authlib \| passport-google \| Spring OAuth2 Client] | Firebase Auth, Auth0, Clerk, Google JS SDK popup | PRD mentions social login or Google sign-in |
| Email | [fastapi-mail+Celery \| @nestjs-modules/mailer+BullMQ \| spring-mail+@Async] | SendGrid SDK directly, synchronous SMTP | PRD mentions transactional emails |
| File Storage | S3/GCS via [boto3 \| @aws-sdk/s3 \| AWS SDK v2 Java] + MinIO (local dev) | Local filesystem in prod, Firebase Storage | PRD mentions file uploads or media |
| Search | Meilisearch (full-text, typo-tolerant) | Raw SQL LIKE queries, no search engine | PRD mentions full-text search |
| Real-Time | WebSocket + [python-socketio \| socket.io \| Spring WebSocket] + Redis pub/sub | Polling, Firebase Realtime DB | PRD mentions live updates, chat, or real-time |
| Push Notifications | FCM via firebase-admin + expo-notifications | OneSignal, custom push servers | Project has mobile app |
| Error Tracking | Sentry (backend + frontend + mobile) | console.log only, no error tracking | Recommended for production apps |
| Analytics | PostHog (self-hosted, privacy-first) | Google Analytics alone, no event tracking | PRD mentions analytics |
| i18n | next-intl (web) + i18next (mobile) | Hardcoded strings, no translation system | PRD mentions multi-language |
| PWA | next-pwa (service worker, offline) | No PWA support, no offline capability | PRD mentions PWA or offline web |
| RBAC | Custom roles + permissions (MySQL + Redis cache) | Simple user/admin only, no granular permissions | PRD mentions roles or permissions |
| 2FA | TOTP via [pyotp \| otplib \| dev.samstevens.totp] + QR generation | SMS-only 2FA, no authenticator app support | PRD mentions two-factor auth |
| Feature Flags | Custom (MySQL + Redis cache + admin toggle) | No feature flags, deploy for every toggle | PRD mentions gradual rollout |
| Admin Panel | Dedicated /admin API + frontend section | No admin panel, direct DB access | PRD mentions admin dashboard |
| Animation | Framer Motion (web), Reanimated 3 (mobile) | CSS-only animations for complex interactions | Project has complex UI animations |

### Mobile Stack (Only If Project Has Mobile App)

| Component | Technology | NEVER Use |
|-----------|-----------|-----------|
| Frontend Mobile | React Native + Expo + NativeWind (or best for app) | Flutter, Ionic, Cordova, native Swift/Kotlin |
| Mobile Nav | Drawer + Bottom Tabs + Stack (ALWAYS) | Tabs only, Drawer only, no consistent nav |
| Mobile Auth | expo-secure-store + expo-auth-session + expo-apple-authentication | AsyncStorage for tokens, WebView OAuth, skip Apple Sign-In |
| Mobile UI | SafeAreaView + FlashList + @gorhom/bottom-sheet + expo-image | FlatList for long lists, no SafeArea, RN Image for remote |
| Mobile Offline | NetInfo + TanStack Query persist + expo-task-manager | Assume always-online, no offline handling |
| Mobile CI/CD | EAS Build + Submit + Update (Expo) | Manual builds, no OTA updates, local signing |
| Mobile Testing | Jest + RNTL + Detox (E2E) | No mobile E2E testing, Expo Go only |

### GenAI Stack (Only If Project Has AI Features)

| Component | Technology | NEVER Use |
|-----------|-----------|-----------|
| GenAI Gateway | [LiteLLM \| Vercel AI SDK \| Spring AI] (unified multi-LLM) | hardcode single provider SDK, expose API keys to frontend |
| Agentic Framework | [Google ADK / LangGraph / CrewAI \| LangChain.js \| LangChain4j] | build agents without tool use, skip memory/state |
| RAG Pipeline | Qdrant + text-embedding-3-large + semantic chunking | stuff full docs in context, skip vector search |
| AI Observability | Langfuse or LangSmith (LLM tracing) | ship AI features without tracing, skip cost tracking |
| AI Safety | Guardrails: input filter + output filter + cost caps | allow unbounded AI calls, expose raw model errors |
| Prompt Management | Jinja2/YAML templates (version-controlled) | hardcode prompts as string literals in service code |
| MCP Protocol | MCP server (tools + prompts + resources) via JSON-RPC 2.0 | skip MCP for tool integration, hardcode tool calls |
| A2A Protocol | Agent Card discovery + task lifecycle (/.well-known/agent.json) | build agent APIs without A2A discoverability |
| AI Evaluation | [DeepEval+RAGAS \| Jest AI tests \| JUnit AI tests] + promptfoo | ship AI without evaluation, skip RAG quality checks |
| Structured Output | [instructor+Pydantic \| Zod schemas \| Spring AI structured] | parse raw LLM text with regex, skip validation |
| Semantic Caching | Redis + embedding cosine similarity (>0.95 threshold) | call LLM for identical/similar queries, skip caching |
| Agentic RAG | Retrieval agent + query decomposition + web search fallback | single fixed retrieval strategy, skip query routing |
| Re-ranking | Cohere Rerank v3.5 / FlashRank (post-retrieval) | use raw vector similarity alone, skip re-ranking |
| Multi-Modal AI | Vision + Image Gen + STT + TTS via LiteLLM | hardcode single modality, skip LiteLLM routing |
| HITL | Confidence threshold + review queue + approve/reject | auto-publish low-confidence AI output, skip review |
| Context Management | tiktoken + auto-summarization + sliding window | exceed context window, skip token counting |
| Voice AI | Whisper STT + OpenAI/Gemini/ElevenLabs TTS | block on audio processing, skip streaming |
| Batch Processing | [Celery \| BullMQ \| Spring @Async] + Redis progress tracking | process bulk AI synchronously, skip progress |

## Auth Rules — ABSOLUTE

```
╔═══════════════════════════════════════════════════════════════╗
║  JWT + Cookie Auth (ALL login methods end with JWT cookies)   ║
╠═══════════════════════════════════════════════════════════════╣
║  ✅ JWT in HTTP-Only Secure Cookies                          ║
║  ✅ Access token: 30 min                                     ║
║  ✅ Refresh token: 7 days                                    ║
║  ✅ CSRF: Double-submit cookie pattern                       ║
║  ✅ Logout: Blacklist in Redis                               ║
║  ✅ Password: bcrypt (passlib | bcryptjs | Spring Security)   ║
║                                                               ║
║  ❌ NEVER localStorage                                       ║
║  ❌ NEVER sessionStorage                                     ║
║  ❌ NEVER Authorization header from FE                       ║
║  ❌ NEVER token in URL params                                ║
║  ❌ NEVER token in JS-accessible state                       ║
╠═══════════════════════════════════════════════════════════════╣
║  Frontend Auth — Pure Cookie-Based (No localStorage)         ║
╠═══════════════════════════════════════════════════════════════╣
║  The frontend NEVER stores tokens. Browser handles cookies.  ║
║                                                               ║
║  ┌─────────────────┬─────────────────────────────────────┐   ║
║  │ Access token     │ HTTP-only cookie (set by backend)   │   ║
║  │ Refresh token    │ HTTP-only cookie (set by backend)   │   ║
║  │ User data        │ React state (in-memory only)        │   ║
║  │ Token expiry     │ React ref (in-memory only)          │   ║
║  └─────────────────┴─────────────────────────────────────┘   ║
║                                                               ║
║  ✅ Axios withCredentials: true on EVERY request             ║
║  ✅ User data re-fetched via GET /auth/me on mount           ║
║  ✅ Token expiry in React ref → schedule silent refresh      ║
║  ✅ 401 interceptor → auto-refresh → retry original request ║
║  ✅ CSRF token from non-httponly cookie → X-CSRF-Token header║
║  ✅ Login response returns user data only (tokens in cookies)║
║                                                               ║
║  ❌ NEVER read tokens in JS (HTTP-only = inaccessible)       ║
║  ❌ NEVER store tokens in localStorage or sessionStorage     ║
║  ❌ NEVER pass tokens in Authorization header from frontend  ║
║  ❌ NEVER use js-cookie or document.cookie for auth tokens   ║
║  ❌ NEVER decode JWT on frontend (backend = source of truth) ║
║  ❌ NEVER store user data in localStorage (use /auth/me)     ║
╠═══════════════════════════════════════════════════════════════╣
║  Google OAuth2 (Social Login for public-facing apps)         ║
╠═══════════════════════════════════════════════════════════════╣
║  ✅ OAuth2 lib (authlib | passport-google | Spring OAuth2)   ║
║  ✅ Server-side flow (backend handles code exchange)         ║
║  ✅ Google login → issue OUR JWT cookies (same as email)     ║
║  ✅ Account linking: match by email across methods           ║
║  ✅ Google-verified emails: skip email verification          ║
║  ✅ User model: auth_provider + google_sub fields            ║
║  ✅ Free trial points on first Google login                  ║
║                                                               ║
║  ❌ NEVER store Google access/refresh tokens                 ║
║  ❌ NEVER use Google JS SDK popup (use server redirect)      ║
║  ❌ NEVER use Firebase Auth, Auth0, Clerk                    ║
║  ❌ NEVER bypass JWT cookies for Google users                ║
║  ❌ NEVER trust client-side Google token validation          ║
╠═══════════════════════════════════════════════════════════════╣
║  Transactional Emails (ALL public-facing apps)               ║
╠═══════════════════════════════════════════════════════════════╣
║  ✅ Email library + templates (Jinja2|Handlebars|Thymeleaf)  ║
║  ✅ ALL emails async (Celery | BullMQ | @Async) non-blocking║
║  ✅ Email types: welcome, OTP, reset, alerts, invoices       ║
║  ✅ Templates extend base.html (consistent branding)         ║
║  ✅ Unsubscribe link for optional emails                     ║
║  ✅ Email logs in MongoDB (audit trail)                      ║
║                                                               ║
║  ❌ NEVER send emails synchronously (blocks API response)    ║
║  ❌ NEVER skip email on registration (welcome is mandatory)  ║
║  ❌ NEVER hardcode email content (use templates)             ║
║  ❌ NEVER expose SMTP credentials to frontend                ║
╚═══════════════════════════════════════════════════════════════╝
```

## Frontend Page Quality Rules — ENFORCED ON ALL PAGES

```
╔═══════════════════════════════════════════════════════════════╗
║  Frontend Page Quality (ENFORCED on ALL pages)                ║
╠═══════════════════════════════════════════════════════════════╣
║  ✅ Every page handles 4 states: Loading, Error, Empty, Data ║
║  ✅ Loading = skeleton matching page layout (never spinner)  ║
║  ✅ Error = retry button + user-friendly message             ║
║  ✅ Empty = illustration + CTA (never blank)                 ║
║  ✅ Responsive: mobile-first, works 320px to 2560px          ║
║  ✅ Dark mode: all elements themed (no white flash)          ║
║  ✅ SEO: generateMetadata() on every page                    ║
║  ✅ Forms: React Hook Form + Zod + inline validation         ║
║  ✅ Feedback: toast on every mutation (success/error)        ║
║  ✅ Accessibility: keyboard nav, focus rings, ARIA labels    ║
║  ✅ Dashboard layout: sidebar + header + breadcrumbs          ║
║  ✅ error.tsx + loading.tsx in EVERY route group              ║
║                                                               ║
║  ❌ NEVER show a blank page while loading (use skeleton)     ║
║  ❌ NEVER show raw API errors to users                       ║
║  ❌ NEVER skip empty state (always have illustration + CTA)  ║
║  ❌ NEVER use spinner-only loading (use content-shaped skel) ║
║  ❌ NEVER ship without mobile responsive testing             ║
║  ❌ NEVER forget error.tsx and loading.tsx in route groups    ║
║  ❌ NEVER use localStorage/sessionStorage for auth tokens    ║
║  ❌ NEVER skip dark mode support on any component            ║
║  ❌ NEVER check auth/roles in pages — middleware.ts ONLY     ║
╚═══════════════════════════════════════════════════════════════╝

Auth Verification Rule — Frontend (HARD):
- ALL auth checks (isAuthenticated, role guards, token validation)
  MUST happen in middleware.ts — NEVER in page/route components.
- Pages may use useAuth() for user DATA (name, email, avatar) and
  actions (logout), but NEVER for route protection or redirects.
- middleware.ts handles: unauthenticated → /login, auth pages
  redirect for logged-in users, admin role checks.
- If a page needs role-specific UI (e.g., show admin button),
  read user.role from useAuth() — but the ROUTE itself is
  protected by middleware, not the page component.

Auth Verification Rule — Backend (HARD — ALL 3 languages):
- ALL authentication + authorization MUST happen in the MIDDLEWARE
  layer — NEVER in individual route handlers or controllers.
- Python/FastAPI: AuthMiddleware validates JWT from cookie, attaches
  user to request.state. Public routes listed in middleware config.
  Routes access request.state.user — NEVER use Depends(get_current_user)
  for auth verification. Depends() is ONLY for service injection.
- NestJS: JwtAuthGuard registered as APP_GUARD globally in AppModule.
  Public routes use @Public() decorator. Controllers use @CurrentUser()
  to access user data — NEVER use @UseGuards(JwtAuthGuard) per controller.
- Spring Boot: SecurityFilterChain + JwtAuthFilter handles all auth.
  Route matchers define public vs protected vs admin paths.
  @PreAuthorize is ONLY for granular RBAC permissions (hasPermission),
  NEVER for authentication checks (isAuthenticated is redundant).
- ❌ NEVER check isAuthenticated in controllers/routes — middleware does it
- ❌ NEVER use per-route auth guards/dependencies for authentication
- ✅ ALWAYS configure public routes in middleware (not skip auth per route)
- ✅ ALWAYS access user from request context set by middleware
```

> Load `references/CODE_PATTERNS_FRONTEND_CORE.md` for architecture (routes, providers, middleware, page state).
> Load `references/CODE_PATTERNS_FRONTEND_PAGES.md` for dashboard layout + 6 page templates.
> Load `references/CODE_PATTERNS_FRONTEND_UX.md` for reusable components, skeletons, animations, dark mode.

## Layer Rules — ENFORCED ON EVERY FILE

> Layer names vary by language but the concept is identical across all 3 backends.

| Layer | Python (FastAPI) | NestJS | Spring Boot | Contains | NEVER Contains |
|-------|-----------------|--------|-------------|----------|----------------|
| Middleware | `app/core/auth_middleware.py` | `APP_GUARD` global guards | `SecurityFilterChain` + `JwtAuthFilter` | Auth verification, JWT validation, public route bypass | Business logic, DB queries beyond user lookup |
| Controllers | `app/api/` | `src/*/controllers/` | `src/main/java/**/controller/` | Thin route handlers → delegate to services | Business logic, DB queries, AUTH checks |
| Services | `app/services/` | `src/*/services/` | `src/main/java/**/service/` | Business logic (uses repos) | API concerns, direct DB access |
| Repositories | `app/repositories/` | `src/*/repositories/` (Prisma) | `src/main/java/**/repository/` | Pure CRUD data access | Business logic, service imports |
| Models | `app/models/` | `src/*/entities/` (Prisma schema) | `src/main/java/**/entity/` | ORM models/entities | Imports from other layers |
| DTOs | `app/schemas/` | `src/*/dto/` | `src/main/java/**/dto/` | Request/Response DTOs | Imports from other layers |

> Layer code examples (correct vs wrong) are in the per-language CODE_PATTERNS file:
> - Python: [references/CODE_PATTERNS_PYTHON.md](references/CODE_PATTERNS_PYTHON.md)
> - NestJS: [references/CODE_PATTERNS_NESTJS.md](references/CODE_PATTERNS_NESTJS.md)
> - Spring Boot: [references/CODE_PATTERNS_SPRINGBOOT.md](references/CODE_PATTERNS_SPRINGBOOT.md)

### Import Rules (same concept, all languages):
```
Controllers → CAN import from: services, DTOs, core/config
Services    → CAN import from: repositories, DTOs, core, models, OTHER services
Repositories → CAN import from: models, database config, DTOs
Models      → CAN import from: NOTHING (or other models)
DTOs        → CAN import from: NOTHING (standalone)
Core/Config → CAN import from: config, DTOs
```

## Payment Rules — Subscription + Credit Points (ONLY IF Project Has Payments)

> **Skip this entire section** if the project does not have payments, subscriptions, or billing.

```
╔════════════════════════════════════════════════════════════════╗
║  BILLING MODEL: Subscription + Credit Points (for GenAI apps) ║
╠════════════════════════════════════════════════════════════════╣
║  ✅ Razorpay Subscriptions for recurring billing              ║
║  ✅ Subscription gives FIXED credit points per cycle          ║
║  ✅ Points deducted per action (GenAI calls cost more)        ║
║  ✅ Top-up packs via Razorpay Orders when points exhaust      ║
║  ✅ 7-day free trial with moderate free points on signup      ║
║  ✅ Plan points reset on renewal (don't roll over)            ║
║  ✅ Top-up points persist across renewals                     ║
║  ✅ Point balance: Redis (fast) + MySQL (audit truth)         ║
║  ✅ Amounts in paisa (₹500 = 50000 paisa), currency INR      ║
║  ✅ HMAC SHA256 signature verification on all payments        ║
║  ✅ Webhook idempotency + Celery async processing             ║
║  ✅ GST 18% on all invoices (subscriptions + top-ups)         ║
║  ✅ Agent auto-decides point allocations based on cost         ║
║                                                                ║
║  ❌ Subscription NEVER means unlimited access                 ║
║  ❌ NEVER expose key_secret to frontend                       ║
║  ❌ NEVER trust client-side amounts or point counts           ║
║  ❌ NEVER skip signature verification                         ║
║  ❌ NEVER use Stripe for India-focused SaaS                   ║
║  ❌ NEVER deduct points without audit trail in MySQL          ║
║  ❌ NEVER process webhook without deduplication               ║
╚════════════════════════════════════════════════════════════════╝
```

> Payment code patterns (Point Deduction, Top-Up, Webhook) are in the per-language CODE_PATTERNS file.

## Modern App Infrastructure Rules — CONDITIONAL

> **Each sub-section below applies ONLY if the project uses that feature.** Do NOT force File Upload on a project without uploads, Search on a project without search, etc.

```
╔════════════════════════════════════════════════════════════════╗
║  INFRASTRUCTURE RULES — Apply ONLY for features the project   ║
║  actually uses (detected from PRD/codebase in Step 0)         ║
╠════════════════════════════════════════════════════════════════╣
║  File Upload:                                                  ║
║  ✅ Presigned URL pattern (backend signs → frontend uploads)  ║
║  ✅ Validate file type + size server-side                     ║
║  ✅ Image thumbnails via Pillow (never serve raw uploads)     ║
║  ✅ MinIO in docker-compose for local S3-compatible dev       ║
║  ❌ NEVER accept file uploads directly through API body       ║
║  ❌ NEVER store uploads on local filesystem in production     ║
║  ❌ NEVER serve user uploads from same domain (XSS risk)     ║
║                                                                ║
║  Search:                                                       ║
║  ✅ Meilisearch for full-text search (typo-tolerant, fast)   ║
║  ✅ Index sync via Celery tasks (async, non-blocking)        ║
║  ✅ Cmd+K command palette on frontend                         ║
║  ❌ NEVER use SQL LIKE '%query%' for user-facing search      ║
║  ❌ NEVER sync search index synchronously in API handler     ║
║                                                                ║
║  Real-Time:                                                    ║
║  ✅ WebSocket for live notifications, chat, dashboards        ║
║  ✅ Redis pub/sub for multi-instance WebSocket scaling        ║
║  ✅ JWT auth in WebSocket handshake                           ║
║  ❌ NEVER use HTTP polling for real-time features             ║
║                                                                ║
║  Error Tracking:                                               ║
║  ✅ Sentry on backend + frontend + mobile (3 DSNs)           ║
║  ✅ Source map upload on deploy                               ║
║  ❌ NEVER ship to production without error tracking           ║
║                                                                ║
║  Security:                                                     ║
║  ✅ RBAC with granular permissions (not just user/admin)      ║
║  ✅ 2FA via TOTP authenticator apps                           ║
║  ✅ Session management (view/revoke active sessions)          ║
║  ✅ Rate limiting per subscription plan tier                  ║
║  ✅ Audit trail for all critical actions (MongoDB)            ║
║  ❌ NEVER skip 2FA option for production apps                 ║
║  ❌ NEVER use same rate limit for all users                   ║
║                                                                ║
║  Compliance (India DPDPA + GDPR):                             ║
║  ✅ Data export endpoint (user downloads their data)          ║
║  ✅ Account deletion with 30-day grace period                 ║
║  ✅ Consent tracking in MongoDB                               ║
║  ✅ Legal pages: Terms, Privacy, Cookie, Refund policies      ║
║  ✅ Cookie consent banner                                     ║
║  ❌ NEVER launch without legal pages                          ║
║  ❌ NEVER collect data without consent tracking               ║
║                                                                ║
║  Notifications:                                                ║
║  ✅ In-app notification center (bell icon + badge count)      ║
║  ✅ Notifications stored in MongoDB (flexible schema)         ║
║  ✅ Mark as read, dismiss, paginated list                     ║
║  ✅ Real-time push via WebSocket on new notification          ║
║  ❌ NEVER skip notification center for SaaS apps              ║
║                                                                ║
║  Logging & Observability:                                      ║
║  ✅ Structured JSON logging (structlog|winston|Logback)       ║
║  ✅ Request ID propagation across all log entries             ║
║  ✅ Audit trail for critical actions (MongoDB AuditLog)       ║
║  ❌ NEVER use print/console.log/System.out in production     ║
║                                                                ║
║  Backup & Recovery:                                            ║
║  ✅ Daily MySQL + MongoDB dumps to S3 via scheduled tasks     ║
║  ✅ Automated backup rotation (30-day retention)              ║
║  ❌ NEVER ship production without automated backups           ║
║                                                                ║
║  CDN & Performance:                                            ║
║  ✅ CDN (CloudFront/Cloud CDN) for static + uploaded files   ║
║  ✅ Next.js Image optimization with CDN                       ║
║  ✅ Lazy loading, code splitting, bundle optimization         ║
║  ❌ NEVER serve user uploads from app server                  ║
║                                                                ║
║  Growth:                                                       ║
║  ✅ Analytics event tracking (PostHog or custom)              ║
║  ✅ Feature flags for gradual rollout                         ║
║  ✅ i18n multi-language (English + Hindi minimum)             ║
║  ✅ PWA support (offline, installable)                        ║
║  ✅ Social sharing (OG tags, Web Share API, deep links)       ║
║  ✅ Onboarding flow for first-time users                      ║
║  ✅ In-app feedback widget                                    ║
║  ❌ NEVER ship without analytics                              ║
║  ❌ NEVER hardcode UI strings (use i18n keys)                ║
╚════════════════════════════════════════════════════════════════╝
```

## Mobile App Rules (ONLY IF Project Has Mobile App)

> **Skip this entire section** if the project does not have a mobile app (no --with-mobile flag, no React Native in codebase).

```
╔════════════════════════════════════════════════════════════════╗
║  MOBILE APP RULES — Apply ONLY to React Native mobile apps    ║
╠════════════════════════════════════════════════════════════════╣
║  Project Setup:                                                ║
║  ✅ app.config.ts with bundleIdentifier + package name        ║
║  ✅ eas.json with dev/preview/production build profiles       ║
║  ✅ babel.config.js: nativewind/babel + reanimated/plugin     ║
║  ✅ metro.config.js: withNativeWind() wrapper                 ║
║  ✅ EXPO_PUBLIC_* env vars (never hardcoded URLs)             ║
║  ❌ NEVER use Expo Go for production testing (use dev client) ║
║                                                                ║
║  Auth (DIFFERENT from web):                                    ║
║  ✅ expo-secure-store for JWT tokens (Keychain/Keystore)      ║
║  ✅ Axios interceptor: read token → add Authorization header  ║
║  ✅ Auto-refresh on 401 (transparent to user)                 ║
║  ✅ Google OAuth via expo-auth-session (system browser)       ║
║  ✅ Apple Sign-In via expo-apple-authentication (iOS)         ║
║  ✅ Biometric: expo-local-authentication (Face ID/fingerprint)║
║  ❌ NEVER use HTTP-only cookies on mobile (can't access them) ║
║  ❌ NEVER use AsyncStorage for tokens (not encrypted)         ║
║  ❌ NEVER skip Apple Sign-In (App Store rejection)            ║
║  ❌ NEVER use WebView for OAuth (security risk)               ║
║                                                                ║
║  UI Patterns:                                                  ║
║  ✅ SafeAreaView on ALL screens (notch + status bar safe)     ║
║  ✅ KeyboardAvoidingView on ALL form screens                  ║
║  ✅ FlashList (Shopify) for all lists (10x faster than FlatList)║
║  ✅ @gorhom/bottom-sheet for filters, actions, pickers        ║
║  ✅ expo-image with blurhash (cached, fast, placeholder)      ║
║  ✅ react-native-toast-message for notifications              ║
║  ✅ expo-haptics on button press, success, error              ║
║  ✅ Skeleton loaders on all data-loading screens              ║
║  ✅ Pull-to-refresh on all list screens                       ║
║  ✅ Platform.OS for iOS/Android-specific styling              ║
║  ❌ NEVER use ScrollView for long lists                       ║
║  ❌ NEVER use RN Image for remote images (no caching)         ║
║                                                                ║
║  Offline & Network:                                            ║
║  ✅ @react-native-community/netinfo for connectivity          ║
║  ✅ Offline banner when no internet                           ║
║  ✅ TanStack Query with persistQueryClient                    ║
║  ✅ Offline mutation queue → replay when online               ║
║  ❌ NEVER assume always-online                                ║
║                                                                ║
║  Security:                                                     ║
║  ✅ Certificate pinning for API calls                         ║
║  ✅ Root/jailbreak detection                                  ║
║  ✅ No console.log in production (__DEV__ guard)              ║
║  ✅ Clear secure store on logout                              ║
║  ✅ Disable dev menu in production                            ║
║  ❌ NEVER log tokens, passwords, or PII                       ║
║                                                                ║
║  Performance:                                                  ║
║  ✅ Hermes engine (always enabled in SDK 55+)                 ║
║  ✅ React.memo() on expensive components                      ║
║  ✅ Lazy load screens with React.lazy                         ║
║  ✅ Target: <30MB bundle, <5s cold start                      ║
║  ❌ NEVER create closures in render functions                 ║
║                                                                ║
║  App Store:                                                    ║
║  ✅ EAS Build for cloud builds (never build locally for prod) ║
║  ✅ EAS Submit for store submission                           ║
║  ✅ EAS Update for OTA JS updates                             ║
║  ✅ Semver versioning with auto-increment                     ║
║  ✅ TestFlight (iOS) + Play internal testing (Android)        ║
║  ❌ NEVER commit signing keys to git                          ║
║                                                                ║
║  Accessibility:                                                ║
║  ✅ accessibilityLabel on ALL interactive elements            ║
║  ✅ accessibilityRole: button, link, header, image            ║
║  ✅ Min touch target: 44x44pt (iOS) / 48x48dp (Android)      ║
║  ✅ Dynamic font scaling supported                            ║
║  ❌ NEVER rely on color alone for information                 ║
╚════════════════════════════════════════════════════════════════╝
```

## GenAI / Agentic AI Rules (ONLY IF Project Has AI Features)

> **Skip this entire section** if the project does not have AI/GenAI features (no --with-ai flag, no LiteLLM/LangGraph/ADK in dependencies).

```
╔══════════════════════════════════════════════════════════════════╗
║  GENAI RULES — Apply ONLY to projects with AI features            ║
╠══════════════════════════════════════════════════════════════════╣
║  LLM Gateway:                                                     ║
║  ✅ Unified gateway (LiteLLM|Vercel AI|Spring AI) no direct SDK  ║
║  ✅ Model registry with tiers: fast/smart/premium/local          ║
║  ✅ Fallback chains: primary → fallback → budget model           ║
║  ✅ Cost tracking per user per request                            ║
║  ✅ Every LLM call deducts from credit point balance             ║
║  ❌ NEVER import provider SDK directly (openai/anthropic/etc)    ║
║  ❌ NEVER expose LLM API keys to frontend                        ║
║  ❌ NEVER allow AI calls without point deduction                 ║
║                                                                   ║
║  Agentic Architecture:                                            ║
║  ✅ Agentic framework per lang (ADK/LangGraph|LangChain.js|LC4j) ║
║  ✅ Stateful workflows (LangGraph|LangChain.js|LangChain4j)     ║
║  ✅ Role-based agent collaboration (CrewAI or equivalent)        ║
║  ✅ MCP protocol for agent-to-tool communication                 ║
║  ✅ Agent memory: conversation (MongoDB) + long-term (vector DB) ║
║  ❌ NEVER build agents without tool use capability               ║
║  ❌ NEVER skip agent state management                            ║
║                                                                   ║
║  RAG Pipeline:                                                    ║
║  ✅ Qdrant (self-hosted) or Pinecone (managed) for vectors       ║
║  ✅ Semantic chunking with overlap (not fixed-size)              ║
║  ✅ Hybrid retrieval: vector similarity + BM25 keyword           ║
║  ✅ Cache embeddings in Redis (7-day TTL)                        ║
║  ❌ NEVER stuff entire documents into LLM context                ║
║  ❌ NEVER use naive fixed-size chunking                          ║
║                                                                   ║
║  Streaming & UX:                                                  ║
║  ✅ SSE (Server-Sent Events) for AI response streaming           ║
║  ✅ Token-by-token rendering on frontend                         ║
║  ✅ Stop generation button                                       ║
║  ✅ Markdown rendering for AI responses                          ║
║  ❌ NEVER wait for full response before showing to user          ║
║                                                                   ║
║  Prompts:                                                         ║
║  ✅ Templates in ai/prompts/ (Jinja2|Handlebars|Thymeleaf/YAML) ║
║  ✅ Version-controlled prompt registry                            ║
║  ✅ System prompt + user prompt separation                       ║
║  ❌ NEVER hardcode prompts as string literals in code             ║
║                                                                   ║
║  Open Standards (MCP + A2A):                                       ║
║  ✅ MCP server for tool/prompt/resource exposure (JSON-RPC 2.0)   ║
║  ✅ Expose reusable prompts via MCP prompts/list + prompts/get    ║
║  ✅ A2A Agent Card at /.well-known/agent.json                     ║
║  ✅ A2A task handler for agent-to-agent communication             ║
║  ✅ A2A skills declaration in Agent Card                          ║
║  ❌ NEVER skip Agent Card for AI-powered services                 ║
║  ❌ NEVER build tool integrations without MCP protocol             ║
║                                                                   ║
║  Agentic RAG:                                                     ║
║  ✅ Retrieval agent decides: which KB, web search, decompose      ║
║  ✅ Re-ranking after retrieval (Cohere / FlashRank)               ║
║  ✅ Query decomposition for complex questions                     ║
║  ❌ NEVER use single fixed retrieval strategy for all queries     ║
║                                                                   ║
║  Structured Output:                                               ║
║  ✅ Validated LLM extraction (instructor+Pydantic|Zod|records)   ║
║  ✅ Auto-retry on validation failure (max 2 retries)              ║
║  ❌ NEVER parse raw LLM text with regex                           ║
║                                                                   ║
║  Semantic Caching:                                                ║
║  ✅ Redis + embedding similarity (threshold > 0.95)              ║
║  ✅ TTL-based expiry, bypass for time-sensitive queries           ║
║  ❌ NEVER call LLM for identical/near-identical queries           ║
║                                                                   ║
║  AI Evaluation & Testing:                                         ║
║  ✅ LLM unit tests (DeepEval/pytest | Jest | JUnit 5)           ║
║  ✅ RAGAS for RAG quality (faithfulness, relevancy, recall)       ║
║  ✅ promptfoo for prompt A/B testing                              ║
║  ❌ NEVER ship AI features without evaluation metrics             ║
║                                                                   ║
║  Multi-Modal & Voice:                                             ║
║  ✅ All modalities via gateway (vision, image, audio, TTS)       ║
║  ✅ Voice: Whisper STT + OpenAI/Gemini/ElevenLabs TTS            ║
║  ✅ WebSocket audio streaming for real-time voice                 ║
║  ❌ NEVER hardcode single provider for any modality               ║
║                                                                   ║
║  HITL & Batch:                                                    ║
║  ✅ Confidence threshold for auto-publish vs review queue         ║
║  ✅ Async batch AI (Celery|BullMQ|@Async) + Redis progress       ║
║  ✅ Context window management with token counting + auto-summarize║
║  ❌ NEVER auto-publish low-confidence AI output                   ║
║  ❌ NEVER process bulk AI operations synchronously                ║
║                                                                   ║
║  Safety & Guardrails:                                             ║
║  ✅ Input validation (max tokens, content filtering)             ║
║  ✅ Output PII detection + harmful content blocking              ║
║  ✅ Per-user daily cost caps (prevent runaway spend)             ║
║  ✅ Audit log every AI interaction in MongoDB                    ║
║  ❌ NEVER expose raw LLM errors to users                         ║
║  ❌ NEVER allow unbounded AI calls without cost limits           ║
╚══════════════════════════════════════════════════════════════════╝
```

## Database Selection Guide

Before creating ANY model, decide which DB:

| Use MySQL (ORM) When | Use MongoDB When | Use Redis When |
|---------------------|-----------------|---------------|
| ACID transactions needed | Schema is flexible/dynamic | TTL-based storage |
| Complex JOINs required | Deeply nested documents | Counters/rate limits |
| Unique constraints critical | Read-heavy, denormalized | JWT blacklist |
| Foreign keys needed | Logs, audit trails | OTP/verification codes |
| Financial data | User preferences/settings | Caching |
| Inventory/orders | Content/media metadata | Pub/sub messaging |

## File Naming Conventions (per language)

### Python/FastAPI
- Models: `user.py`, `order.py` (singular) | Repos: `user_repo.py` | Services: `user_service.py`
- Schemas: `user.py` (UserCreate, UserUpdate, UserResponse) | Routes: `users.py` (plural)
- Tests: `test_user_service.py`

### Node.js/NestJS
- Entities: `user.entity.ts` | Repos: `user.repository.ts` | Services: `user.service.ts`
- DTOs: `create-user.dto.ts`, `user-response.dto.ts` | Controllers: `user.controller.ts`
- Tests: `user.service.spec.ts`, `user.controller.spec.ts`

### Java/Spring Boot
- Entities: `User.java` (PascalCase) | Repos: `UserRepository.java` | Services: `UserService.java`
- DTOs: `CreateUserRequest.java`, `UserResponse.java` (records) | Controllers: `UserController.java`
- Tests: `UserServiceTest.java`, `UserControllerTest.java`

## Error Handling (per language)

Raise in services, catch in global middleware — never in repos.

**Python:** Custom exceptions in `core/exceptions.py`, global exception handler middleware
**NestJS:** Custom exceptions extending `HttpException`, global `@Catch()` exception filter
**Spring Boot:** Custom exceptions, `@ControllerAdvice` global error handler

> See per-language CODE_PATTERNS files for complete error handling examples.

---

## Code Patterns Reference (Progressive Disclosure)

Code patterns are split by backend language. Load the one matching the detected language (Step 0a):

- **Python/FastAPI**: [references/CODE_PATTERNS_PYTHON.md](references/CODE_PATTERNS_PYTHON.md)
- **Node.js/NestJS**: [references/CODE_PATTERNS_NESTJS.md](references/CODE_PATTERNS_NESTJS.md)
- **Java/Spring Boot**: [references/CODE_PATTERNS_SPRINGBOOT.md](references/CODE_PATTERNS_SPRINGBOOT.md)
- **Frontend Core (Next.js)**: [references/CODE_PATTERNS_FRONTEND_CORE.md](references/CODE_PATTERNS_FRONTEND_CORE.md)
- **Frontend Pages (Next.js)**: [references/CODE_PATTERNS_FRONTEND_PAGES.md](references/CODE_PATTERNS_FRONTEND_PAGES.md)
- **Frontend UX (Next.js)**: [references/CODE_PATTERNS_FRONTEND_UX.md](references/CODE_PATTERNS_FRONTEND_UX.md)
- **Chrome Extension (MV3)**: [references/CODE_PATTERNS_CHROME_EXTENSION.md](references/CODE_PATTERNS_CHROME_EXTENSION.md)

Language profiles (directory structure, dependencies, configs, Docker, verify commands):
- **Python**: [references/LANG_PROFILE_PYTHON.md](references/LANG_PROFILE_PYTHON.md)
- **NestJS**: [references/LANG_PROFILE_NESTJS.md](references/LANG_PROFILE_NESTJS.md)
- **Spring Boot**: [references/LANG_PROFILE_SPRINGBOOT.md](references/LANG_PROFILE_SPRINGBOOT.md)

All patterns include:

- File Upload (Presigned URL)
- RBAC (Granular Permissions)
- Dependency Injection (FastAPI Depends)
- Async Everything
- Google OAuth2 (authlib)
- Email Sending (Celery + fastapi-mail)
- Mobile Auth (expo-secure-store)
- Point Deduction (GenAI billing)
- Webhook (Razorpay)
- GenAI Gateway (LiteLLM)
- RAG Retrieval (Qdrant)
- AI Streaming (SSE)
- MCP Prompt Server
- A2A Agent Card
- Structured Output (instructor + Pydantic)
- Semantic Caching (Redis + embedding similarity)
- Agentic RAG (dynamic retrieval agent)
- Re-ranking (Cohere Rerank / FlashRank)
- AI Evaluation (DeepEval + RAGAS)
- Context Window Management (tiktoken)
- Human-in-the-Loop (HITL review queue)
- Voice AI (Whisper STT + OpenAI/Gemini/ElevenLabs TTS)
- Batch AI Processing (Celery + Redis progress)
- Dashboard Layout (sidebar + header + breadcrumbs)
- Page State Pattern (loading/error/empty/data)
- Data Table (TanStack Table + sort + filter + paginate)
- Form Page (React Hook Form + Zod + validation + toast)
- Auth Pages (login + register + forgot password)
- Reusable Components (PageHeader, EmptyState, StatCard, etc.)
