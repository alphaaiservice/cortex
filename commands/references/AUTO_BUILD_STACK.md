# Auto-Build Reference: Tech Stack, Project Structure & Auth Rules

> **This file is referenced by `/auto-build` command.** Do NOT invoke this file directly.
> It is loaded by Agent subagents when they need tech stack details for a build phase.

---

## ⚙️ TECH STACK (Core + Conditional)

### Step 0: Read PRD Requirements Profile

Before building, read the SPEC_FILE (from $ARGUMENTS — could be PRD.md, design.md, spec.md, or any filename) and determine which technologies this product needs:

> **Language Detection**: If PRD specifies a backend language, use it. Otherwise detect from existing code or default to Python/FastAPI.
- **CORE (always build)**: Backend framework (FastAPI|NestJS|Spring Boot), JWT+Cookies, MySQL+ORM, layer segregation, linting, type checking, testing
- **CONDITIONAL (build only if PRD requires)**: MongoDB, Redis, Razorpay, Meilisearch, WebSocket, FCM, S3, Mobile, GenAI, i18n, PWA, 2FA, RBAC

If the PRD does not mention payments → skip the entire Razorpay/payments section.
If the PRD does not mention mobile → skip the entire mobile section.
If the PRD does not mention AI features → skip the entire GenAI section.
If the PRD does not mention full-text search → skip Meilisearch.
Build ONLY what the product needs.

### Step 0.1: Detect Backend Language

Before building, detect which backend language to use:

1. **Existing project** → detect from files:
   - requirements.txt / pyproject.toml / app/main.py → **python-fastapi**
   - package.json with @nestjs/ / nest-cli.json / src/main.ts → **nodejs-nestjs**
   - build.gradle.kts / pom.xml with spring-boot / src/main/java/ → **java-springboot**
2. **New project** → check SPEC_FILE for language preference OR `--lang` flag
3. **Default**: python-fastapi (if no language specified)
4. **Load reference files**:
   - `skills/alpha-architecture/references/LANG_PROFILE_{LANG}.md` for stack conventions
   - `skills/alpha-architecture/references/CODE_PATTERNS_{LANG}.md` for code examples

### Backend Stack (per detected language)

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

> For full directory structure, dependencies, configs, and commands → load the LANG_PROFILE for the detected language.
> For code patterns (layer examples, auth, email, payments, GenAI) → load the CODE_PATTERNS for the detected language.

### Core Stack (Always Used)

### Backend (per detected language — see Step 0.1)
- **Python**: FastAPI + Python 3.11+ + Pydantic v2
- **NestJS**: NestJS 11+ + TypeScript + class-validator
- **Spring Boot**: Spring Boot 3.4+ + Java 21 + Jakarta Validation
- **Directory structure, deps, configs**: Load from LANG_PROFILE_{LANG}.md
- **Code patterns**: Load from CODE_PATTERNS_{LANG}.md

### Authentication
- **Strategy**: JWT (access + refresh tokens) stored in **HTTP-Only Secure Cookies**
- **NEVER use localStorage or sessionStorage** for tokens — this is a hard rule
- **Access token**: Short-lived (30 min), set as HTTP-only cookie
- **Refresh token**: Long-lived (7 days), set as HTTP-only cookie with `/auth/refresh` path
- **Cookie settings**: `httponly=True, secure=True, samesite="lax"`
- **Token library**: `python-jose[cryptography]` | `@nestjs/jwt` | `jjwt-api` (per detected language)
- **Password hashing**: `passlib[bcrypt]` | `bcryptjs` | `Spring Security BCrypt` (per detected language)
- **CSRF protection**: Double-submit cookie pattern for non-GET requests

### Google OAuth2 (Social Login — Public-Facing Apps)
- **Library**: `authlib` | `passport-google-oauth20` | `Spring Security OAuth2 Client` (per detected language)
- **Provider**: Google (Gmail login)
- **Flow**: Authorization Code Grant (server-side, NOT implicit/client-side)
- **On first Google login**: Auto-create User in MySQL + UserProfile in MongoDB (link by email)
- **On returning Google login**: Lookup by email, issue JWT cookies (same as email/password login)
- **Google credentials**: `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` from Google Cloud Console
- **Redirect URI**: `{BACKEND_URL}/api/v1/auth/google/callback`
- **Scopes**: `openid email profile`
- **Account linking**: If user registered with email/password first, Google login links to same account (match by email)
- **NEVER store Google access tokens** — only use them to fetch user info, then discard
- **NEVER allow Google login to bypass email verification** — Google-verified emails are trusted
- **Frontend**: "Sign in with Google" button using redirect (NOT Google JS SDK popup)
- **Configuration** (`app/core/oauth.py`):
  ```python
  from authlib.integrations.starlette_client import OAuth

  oauth = OAuth()
  oauth.register(
      name="google",
      client_id=settings.GOOGLE_CLIENT_ID,
      client_secret=settings.GOOGLE_CLIENT_SECRET,
      server_metadata_url="https://accounts.google.com/.well-known/openid-configuration",
      client_kwargs={"scope": "openid email profile"},
  )
  ```

### Transactional Email System
- **Library**: `fastapi-mail` | `@nestjs-modules/mailer` | `spring-boot-starter-mail` (per detected language)
- **SMTP Provider**: Gmail SMTP (`smtp.gmail.com:587`) for dev/small-scale OR AWS SES / SendGrid for production
- **Templates**: Jinja2 | Handlebars | Thymeleaf HTML email templates (per detected language)
- **Sending**: Always async via Celery | BullMQ | @Async (NEVER block API response for email)
- **Configuration**: Via Pydantic BaseSettings (SMTP host, port, username, password, TLS)
- **From Address**: Configurable `EMAIL_FROM` (e.g., `noreply@yourdomain.com`)
- **Email Types (ALL required for public-facing apps)**:
  ```
  ┌──────────────────────────────────────────────────────────────────────────┐
  │  EMAIL TYPE              │  TRIGGER                 │  TEMPLATE          │
  ├──────────────────────────┼──────────────────────────┼────────────────────┤
  │  Welcome Email           │  User registration       │  welcome.html      │
  │  Email Verification OTP  │  Registration / change   │  verify_otp.html   │
  │  Password Reset OTP      │  POST /auth/forgot-pwd   │  reset_otp.html    │
  │  Password Changed        │  After password reset    │  pwd_changed.html  │
  │  Login Alert             │  Login from new device   │  login_alert.html  │
  │  Subscription Activated  │  Plan purchase success   │  sub_activated.html│
  │  Subscription Renewed    │  Monthly/yearly renewal  │  sub_renewed.html  │
  │  Subscription Cancelled  │  User cancels plan       │  sub_cancelled.html│
  │  Payment Receipt         │  Any successful payment  │  payment_receipt.html│
  │  Invoice Email           │  Invoice generated       │  invoice.html      │
  │  Low Point Balance       │  Balance < 20% of plan   │  low_balance.html  │
  │  Points Exhausted        │  Balance reaches 0       │  points_exhausted.html│
  │  Top-Up Confirmation     │  Top-up purchase success │  topup_confirm.html│
  │  Trial Expiring Soon     │  2 days before trial end │  trial_expiring.html│
  │  Trial Expired           │  Trial period ended      │  trial_expired.html│
  │  Account Deactivated     │  Admin deactivates       │  deactivated.html  │
  │  Weekly Usage Summary    │  Celery beat (weekly)    │  weekly_summary.html│
  └──────────────────────────┴──────────────────────────┴────────────────────┘
  ```
- **Email Template Pattern**:
  ```python
  # app/services/email_service.py
  class EmailService:
      async def send_email(self, to: str, subject: str, template: str, context: dict):
          """Dispatch email via Celery task (non-blocking)."""
          send_email_task.delay(to=to, subject=subject, template=template, context=context)

      async def send_welcome(self, user: User):
          await self.send_email(
              to=user.email,
              subject="Welcome to {app_name}!",
              template="welcome.html",
              context={"name": user.display_name, "trial_points": user.trial_points},
          )

      async def send_otp(self, email: str, otp: str, purpose: str = "verification"):
          await self.send_email(
              to=email,
              subject=f"Your OTP: {otp}",
              template="verify_otp.html",
              context={"otp": otp, "purpose": purpose, "expiry_minutes": 5},
          )

      async def send_low_balance_alert(self, user: User, balance: int, plan_total: int):
          await self.send_email(
              to=user.email,
              subject="Low Point Balance Alert",
              template="low_balance.html",
              context={"balance": balance, "plan_total": plan_total},
          )
  ```
- **Celery Email Task** (`app/tasks/email_tasks.py`):
  ```python
  @celery_app.task(name="email.send", autoretry_for=(Exception,), retry_backoff=True, max_retries=3)
  def send_email_task(to: str, subject: str, template: str, context: dict):
      """Send email via SMTP (runs in Celery worker)."""
      # Load Jinja2 template, render HTML, send via fastapi-mail/smtplib
  ```
- **Env Vars**:
  ```
  EMAIL_SMTP_HOST=smtp.gmail.com
  EMAIL_SMTP_PORT=587
  EMAIL_SMTP_USERNAME=noreply@yourdomain.com
  EMAIL_SMTP_PASSWORD=app-specific-password
  EMAIL_SMTP_TLS=true
  EMAIL_FROM=noreply@yourdomain.com
  EMAIL_FROM_NAME=YourApp
  ```

### Databases
- **Relational (SQL)** [CORE — always]: MySQL via `SQLAlchemy 2.0` (async with `asyncmy` driver)
- **NoSQL (Document Store)** [CONDITIONAL — if PRD needs flexible docs/logs/profiles]: MongoDB via `pymongo` (sync driver)
- **In-Memory Cache/Queue** [CONDITIONAL — if PRD needs caching/rate-limiting/real-time]: Redis via `redis.asyncio`
- **Use the RIGHT database for the RIGHT job**:
  - MongoDB: User profiles, content, logs, flexible/nested documents, audit trails
  - MySQL: Financial transactions, orders, inventory, anything needing ACID/joins/constraints
  - Redis: Session cache, rate limiting, real-time counters, pub/sub, task queues, OTP storage

### Task Queue
- **Worker**: Celery 5.x with `celery[redis]`
- **Broker**: Redis (same Redis instance, database 1)
- **Result Backend**: Redis (database 2)
- **Serializer**: JSON (never pickle — security risk)
- **Beat Scheduler**: `celery-beat` for periodic tasks
- **Monitoring**: Flower (`flower`) for real-time task monitoring
- **Configuration**: Via `app/core/celery_app.py` with Pydantic settings
- **Task Location**: `app/tasks/` directory — one file per domain (e.g., `email_tasks.py`, `report_tasks.py`)
- **Naming Convention**: `@celery_app.task(name="domain.action")` e.g., `"email.send_welcome"`
- **Error Handling**: Auto-retry with exponential backoff (`autoretry_for`, `retry_backoff=True`, `max_retries=3`)
- **Priority Queues**: `default`, `high_priority`, `low_priority`

### Payments — Subscription + Credit Points (ONLY IF PRD Has Payments)

> **Skip this entire section** if the PRD does not mention payments, billing, subscriptions, or monetization.
- **Gateway**: Razorpay (`razorpay` Python SDK)
- **NEVER use Stripe for India-focused SaaS** — Razorpay has better UPI/INR/Indian bank support
- **Billing Model**: **SUBSCRIPTION + CREDIT POINTS** (hybrid)
  - Users subscribe to a plan (monthly/yearly) via **Razorpay Subscriptions**
  - Subscription does **NOT** give unlimited access
  - Each plan allocates a **fixed pool of credit points per billing cycle**
  - Points are **deducted per action/usage** (especially GenAI calls with compute cost)
  - Points exhaust mid-cycle → user buys **top-up point packs** via Razorpay Orders
  - Unused points **DO NOT roll over** to next cycle (reset on renewal)
  - This model is essential for **GenAI-based apps** where each API call has real compute cost

- **Subscription Plans with Credit Points (Agent Auto-Decides)**:
  ```
  The auto-build agent MUST analyze the product's feature costs and auto-create
  subscription plans with appropriate point allocations. Use this formula:

  1. List ALL actions with their point costs (GenAI actions cost more)
  2. Calculate average_daily_usage for a typical user
  3. Free Trial   = 7 days + (average_daily_usage × 7 × 0.6) points (moderate, not full)
  4. Basic Plan   = average_daily_usage × 30 days × 0.8  (light user, monthly)
  5. Pro Plan     = average_daily_usage × 30 days × 2.0  (power user, monthly)
  6. Enterprise   = average_daily_usage × 30 days × 5.0  (team/heavy, monthly)
  7. Yearly plans = monthly × 12 with 20% discount
  8. Price in INR, round to ₹199/₹499/₹999/₹1,999/₹4,999 etc.

  Example (GenAI SaaS where avg user does 30 actions/day, avg cost 8 pts):
  ┌──────────────────────────────────────────────────────────────────────┐
  │  Free Trial   │  7 days  │  ₹0      │  ~1,000 pts  │ Explore only  │
  │  Basic/mo     │  Monthly │  ₹499    │  5,000 pts   │ Light user    │
  │  Pro/mo       │  Monthly │  ₹1,499  │  15,000 pts  │ Power user    │
  │  Enterprise/mo│  Monthly │  ₹4,999  │  40,000 pts  │ Team/heavy    │
  │  Basic/yr     │  Yearly  │  ₹4,799  │  5,000/mo    │ 20% savings   │
  │  Pro/yr       │  Yearly  │  ₹14,399 │  15,000/mo   │ 20% savings   │
  │  Enterprise/yr│  Yearly  │  ₹47,999 │  40,000/mo   │ 20% savings   │
  └──────────────────────────────────────────────────────────────────────┘

  Top-Up Packs (when points exhaust mid-cycle):
  ┌──────────────────────────────────────────────────────────────────────┐
  │  Small Top-Up  │  1,000 pts  │  ₹149   │  ~125 actions             │
  │  Medium Top-Up │  3,000 pts  │  ₹399   │  ~375 actions (+7% bonus) │
  │  Large Top-Up  │  8,000 pts  │  ₹999   │  ~1000 actions (+15% bonus)│
  └──────────────────────────────────────────────────────────────────────┘
  ```

- **7-Day Free Trial (MANDATORY on signup)**:
  ```
  On user registration:
  1. Set user.trial_started_at = now()
  2. Set user.trial_ends_at = now() + 7 days
  3. Set user.current_plan = "free_trial"
  4. Credit FREE POINTS — auto-calculated by agent:
     free_points = average_action_cost × average_daily_actions × 7 × 0.6
     → Moderate amount: enough to explore all features, NOT enough for full production use
     → Agent decides based on actual product cost structure
  5. Set user.is_trial = True
  6. After 7 days (Celery beat checks daily):
     - Trial expired + points exhausted → show paywall, must subscribe
     - Trial expired + points remaining → let them finish remaining points, then paywall
     - On subscribe → trial ends, plan activates, cycle points credited
  ```

- **Point Deduction Flow (ENFORCED — especially for GenAI actions)**:
  ```
  1. User triggers action (GenAI generation, API call, query, export, etc.)
  2. Middleware/dependency checks:
     a. Is user subscribed OR in trial? (if neither → 403 must subscribe)
     b. user.point_balance >= action_cost? (if not → 402 insufficient points)
  3. If insufficient points → HTTP 402 Payment Required:
     {
       "error": "insufficient_points",
       "required": 10,
       "balance": 3,
       "topup_packs": [...],
       "upgrade_plan": { "name": "Pro", "points": 15000, "price_inr": 1499 }
     }
  4. If sufficient → Deduct points atomically:
     a. Redis: DECRBY user:{id}:points {cost} (fast, real-time)
     b. MySQL: INSERT point_transaction (ACID audit trail — action, cost, balance_after)
     c. If balance < 20% of plan allocation → notify user (low balance alert via Celery)
  5. Process the action (GenAI call, etc.)
  6. Return result + headers:
     X-Points-Remaining: {balance}
     X-Points-Plan-Total: {plan_allocation}
  ```

- **Subscription Flow (Razorpay Subscriptions)**:
  ```
  1. POST /api/v1/subscriptions/create (plan_id, billing_cycle=monthly|yearly)
  2. Backend → razorpay.subscription.create() → returns subscription_id
  3. Frontend → Opens Razorpay Checkout with subscription_id
  4. User pays via UPI/Card/NetBanking/Wallet
  5. Webhook: subscription.activated →
     a. Set user.current_plan, user.subscription_id, user.cycle_start, user.cycle_end
     b. Credit plan's point allocation to user balance
     c. End trial if active
     d. Generate invoice with GST
  6. Webhook: subscription.charged (monthly renewal) →
     a. Reset point balance to plan allocation (unused points DO NOT roll over)
     b. Update cycle_start, cycle_end
     c. Generate new invoice
  7. Webhook: subscription.cancelled →
     a. Let user use remaining points until cycle_end
     b. After cycle_end: downgrade to free (no points, read-only access)
  8. Webhook: payment.failed →
     a. Notify user, Razorpay auto-retries
     b. After max retries → subscription paused → freeze point deductions
  ```

- **Top-Up Purchase Flow (Razorpay Orders — one-time)**:
  ```
  1. Frontend → POST /api/v1/points/topup (pack_id)
  2. Backend → Lookup pack price → razorpay.order.create(amount_paisa, currency=INR)
  3. Frontend → Opens Razorpay Checkout with order_id
  4. User pays via UPI/Card/NetBanking/Wallet
  5. Frontend → POST /api/v1/points/verify (payment_id, order_id, signature)
  6. Backend → Verify HMAC SHA256 signature → ACID transaction:
     a. Credit top-up points to user balance (MySQL + Redis)
     b. INSERT point_transaction (type=CREDIT, source=TOPUP, pack_id)
     c. Generate invoice with GST
  7. Top-up points are ADDED to existing balance (not reset)
  8. Top-up points DO carry through subscription renewals (unlike plan points)
  ```

- **Signature Verification — MANDATORY**:
  ```python
  import hmac, hashlib
  generated_signature = hmac.new(
      key_secret.encode(),
      f"{order_id}|{payment_id}".encode(),
      hashlib.sha256
  ).hexdigest()
  assert generated_signature == razorpay_signature  # MUST match
  ```

- **Webhook Security — MANDATORY**:
  - Verify webhook signature using `razorpay_client.utility.verify_webhook_signature(body, signature, webhook_secret)`
  - Use idempotency — deduplicate by `event_id` in Redis/MySQL
  - Store raw webhook payload in MongoDB for audit trail
  - Process webhooks via Celery task (don't block the request)

- **Credit Point Balance Architecture**:
  ```
  ┌─────────────────────────────────────────────────────────────────────┐
  │              SUBSCRIPTION + CREDIT POINT SYSTEM                    │
  │                                                                     │
  │  Redis (FAST — real-time reads/deductions):                        │
  │    user:{id}:points          = current total balance (integer)     │
  │    user:{id}:points:plan     = points from current plan cycle      │
  │    user:{id}:points:topup    = points from top-up purchases        │
  │    user:{id}:daily_usage     = today's point usage counter         │
  │    → Middleware reads this for sub-ms point checks                  │
  │                                                                     │
  │  MySQL (TRUTH — ACID, billing, disputes):                          │
  │    credit_balance: user_id, plan_points, topup_points, total       │
  │    point_transaction: every credit/debit with full metadata        │
  │      → type: PLAN_CREDIT | TOPUP_CREDIT | DEBIT | TRIAL_CREDIT    │
  │      → action: "ai_generation" | "search" | "export" etc.         │
  │      → cost: points consumed                                       │
  │      → balance_after: running balance for audit                    │
  │    subscription: plan_id, cycle_start, cycle_end, status           │
  │                                                                     │
  │  Point Reset on Renewal:                                           │
  │    - plan_points → reset to plan allocation                        │
  │    - topup_points → carry forward (they paid extra for these)      │
  │    - total = new plan_points + remaining topup_points              │
  │                                                                     │
  │  Deduction Priority:                                               │
  │    1. Deduct from plan_points FIRST (these expire on renewal)      │
  │    2. Then deduct from topup_points (these persist)                │
  │                                                                     │
  │  Sync Strategy:                                                    │
  │    - Subscription renewal: MySQL first → Redis reset               │
  │    - Top-up purchase: MySQL first (ACID) → Redis increment         │
  │    - Action deduction: Redis first (speed) → async MySQL log       │
  │    - Daily reconciliation: Celery beat — MySQL wins on mismatch    │
  └─────────────────────────────────────────────────────────────────────┘
  ```

- **Point Cost Configuration** (`app/core/point_costs.py`):
  ```python
  # Agent auto-generates these based on product features + compute cost
  # GenAI actions cost MORE because they consume real GPU/API compute
  POINT_COSTS = {
      # Basic operations (low cost)
      "api_read": 1,                # Simple CRUD read
      "api_write": 2,               # Create/Update operation
      "search_basic": 2,            # Simple search/filter

      # Medium operations
      "search_fulltext": 5,         # Full-text search
      "file_upload": 5,             # File processing
      "export_csv": 5,              # CSV export
      "export_pdf": 8,              # PDF generation

      # GenAI operations (HIGH cost — real compute)
      "ai_chat_message": 5,         # Single AI chat turn
      "ai_generation_short": 10,    # Short AI generation (<500 tokens)
      "ai_generation_long": 25,     # Long AI generation (>500 tokens)
      "ai_image_generation": 30,    # Image generation
      "ai_document_analysis": 20,   # Document/PDF AI analysis
      "ai_code_generation": 15,     # Code generation
      "ai_summarization": 10,       # Text summarization
      "ai_translation": 8,          # AI translation

      # Heavy operations
      "bulk_operation": 20,         # Batch processing
      "report_generation": 15,      # Complex analytics report
      "api_integration_call": 3,    # External API relay

      # Agent adds product-specific costs here based on actual compute
  }

  # Agent auto-calculates based on above costs:
  # FREE_TRIAL_POINTS = avg_action_cost × avg_daily_actions × 7 days × 0.6
  ```

- **Currency**: Always INR (₹) for India SaaS. Store amounts in **paisa** (smallest unit) in DB.
- **GST**: Include GST calculation (18% for software services). Store GST breakdown in invoice.
- **Razorpay Env Vars**:
  ```
  RAZORPAY_KEY_ID=rzp_test_xxxxx            # Test mode key
  RAZORPAY_KEY_SECRET=xxxxx                  # Secret key (NEVER expose to frontend)
  RAZORPAY_WEBHOOK_SECRET=xxxxx              # Webhook signature verification
  RAZORPAY_PLAN_ID_BASIC_MO=plan_xxxxx      # Monthly plan IDs
  RAZORPAY_PLAN_ID_PRO_MO=plan_xxxxx
  RAZORPAY_PLAN_ID_ENTERPRISE_MO=plan_xxxxx
  RAZORPAY_PLAN_ID_BASIC_YR=plan_xxxxx      # Yearly plan IDs
  RAZORPAY_PLAN_ID_PRO_YR=plan_xxxxx
  RAZORPAY_PLAN_ID_ENTERPRISE_YR=plan_xxxxx
  ```
- **Test Mode**: Always develop with `rzp_test_` keys. Switch to `rzp_live_` only in production env.

- **Google OAuth2 Env Vars**:
  ```
  GOOGLE_CLIENT_ID=xxxxx.apps.googleusercontent.com
  GOOGLE_CLIENT_SECRET=GOCSPX-xxxxx
  GOOGLE_REDIRECT_URI=http://localhost:8000/api/v1/auth/google/callback
  ```

- **Email / SMTP Env Vars**:
  ```
  EMAIL_SMTP_HOST=smtp.gmail.com
  EMAIL_SMTP_PORT=587
  EMAIL_SMTP_USERNAME=noreply@yourdomain.com
  EMAIL_SMTP_PASSWORD=app-specific-password       # Gmail App Password (not account password)
  EMAIL_SMTP_TLS=true
  EMAIL_FROM=noreply@yourdomain.com
  EMAIL_FROM_NAME=YourApp
  ```

### File Upload & Cloud Storage (ONLY IF PRD Has File Uploads)

> **Skip this section** if the PRD does not mention file uploads, images, or media.
- **Library**: `boto3` (AWS S3) or `google-cloud-storage` (GCS) — agent picks based on deployment target
- **Local Dev**: MinIO (S3-compatible) in docker-compose for local development
- **CDN**: CloudFront (AWS) or Cloud CDN (GCP) for serving uploaded files
- **Image Processing**: `Pillow` for thumbnails, resizing, format conversion
- **Upload Pattern**: Presigned URL (backend generates → frontend uploads directly to S3 → backend confirms)
- **File Types**: Profile avatars, documents, media, exports
- **Storage Location**: `app/services/storage_service.py` — abstract interface for S3/GCS/local
- **Security**: Validate file type + size server-side, scan for malware, never serve user uploads from same domain
- **Max File Size**: Configurable per file type (default: 10MB images, 50MB documents)
- **Env Vars**: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_S3_BUCKET`, `AWS_REGION`, `CDN_BASE_URL`

### Real-Time — WebSocket + SSE (ONLY IF PRD Has Real-Time Features)

> **Skip this section** if the PRD does not mention live updates, chat, real-time dashboards, or notifications.
- **Library**: FastAPI native WebSocket support + `python-socketio` (for rooms/namespaces)
- **Use Cases**: Live notifications, chat, real-time dashboards, collaborative editing, live status updates
- **Transport**: WebSocket primary, SSE fallback for simple one-way streams
- **Auth**: JWT token sent in WebSocket handshake query param (server validates on connect)
- **Rooms/Channels**: User-specific (user:{id}), resource-specific (order:{id}), broadcast (all)
- **Scaling**: Redis Pub/Sub as message broker for multi-instance WebSocket
- **Frontend (Web)**: Native WebSocket API or socket.io-client
- **Frontend (Mobile)**: socket.io-client for React Native
- **Location**: `app/core/websocket_manager.py` — connection manager with Redis pub/sub
- **Events**: `notification.new`, `chat.message`, `data.updated`, `status.changed`

### Push Notifications (Mobile)
- **Service**: Firebase Cloud Messaging (FCM) via `firebase-admin` Python SDK
- **Mobile**: `expo-notifications` for Expo-based React Native apps
- **Device Token Storage**: MySQL `device_tokens` table (user_id, token, platform, created_at)
- **Notification Types**: New message, payment confirmation, low balance alert, subscription renewal, system announcement
- **Sending**: Always via Celery task (never block API)
- **Topics**: Subscribe users to topics (e.g., `plan_pro`, `feature_updates`)
- **Silent Push**: Background data sync without visible notification
- **Env Vars**: `FIREBASE_PROJECT_ID`, `FIREBASE_CREDENTIALS_JSON`
- **Location**: `app/services/push_service.py`, `app/tasks/push_tasks.py`

### In-App Notification Center
- **Storage**: MongoDB `notifications` collection (flexible schema, high write volume)
- **Schema**: `{user_id, type, title, body, data, is_read, created_at, action_url}`
- **API Endpoints**:
  - `GET /api/v1/notifications` — paginated list (unread first)
  - `PATCH /api/v1/notifications/:id/read` — mark single as read
  - `PATCH /api/v1/notifications/read-all` — mark all as read
  - `GET /api/v1/notifications/unread-count` — badge count
  - `DELETE /api/v1/notifications/:id` — dismiss notification
- **Real-Time**: Push new notifications via WebSocket to connected clients
- **Redis**: `user:{id}:unread_count` — cached unread count for fast badge display
- **Types**: `system`, `payment`, `subscription`, `alert`, `social`, `marketing`
- **Preferences**: User can mute specific notification types
- **Frontend**: Bell icon in navbar with badge count, dropdown list, click to navigate

### Search (Full-Text Search Engine)
- **Engine**: Meilisearch (recommended — fast, easy, great for SaaS) or Elasticsearch
- **Library**: `meilisearch` Python SDK
- **Docker**: Meilisearch container in docker-compose
- **Indexing Strategy**: Sync on create/update/delete via Celery tasks (async indexing)
- **Searchable Entities**: Users, products, content, orders — whatever the product needs
- **Features**: Typo tolerance, faceted search, filters, sorting, highlighting, pagination
- **API**: `GET /api/v1/search?q=query&type=users&filters=...`
- **Frontend**: Command palette (Cmd+K) powered by search API, instant results
- **Location**: `app/services/search_service.py`, `app/tasks/search_tasks.py`
- **Env Vars**: `MEILISEARCH_HOST`, `MEILISEARCH_API_KEY`

### Admin Panel
- **Approach**: Dedicated admin API routes (`/api/v1/admin/`) + separate admin frontend page/section
- **Auth**: Only users with `role=admin` or `role=super_admin` can access
- **Features**:
  ```
  ┌──────────────────────────────────────────────────────────────────┐
  │  ADMIN PANEL — MANDATORY for every SaaS product                 │
  │                                                                  │
  │  User Management:                                                │
  │    ├── List/search/filter all users                             │
  │    ├── View user details (profile, subscription, points, logs)  │
  │    ├── Activate/deactivate/ban users                            │
  │    ├── Impersonate user (view app as them — audit logged)       │
  │    ├── Manual point credit/debit with reason                    │
  │    └── Reset password, force logout                             │
  │                                                                  │
  │  Subscription Management:                                        │
  │    ├── View all subscriptions (active, cancelled, expired)      │
  │    ├── Manual plan change / extend trial                        │
  │    └── Revenue dashboard (MRR, churn, LTV)                     │
  │                                                                  │
  │  Content Management:                                              │
  │    ├── CRUD for all domain entities                              │
  │    ├── Feature flags toggle                                     │
  │    └── System announcements                                     │
  │                                                                  │
  │  Analytics Dashboard:                                            │
  │    ├── Daily/weekly/monthly active users                        │
  │    ├── Revenue metrics (MRR, ARPU, churn rate)                  │
  │    ├── Top users by usage                                       │
  │    ├── Error rates, API latency                                 │
  │    └── Real-time active connections count                       │
  │                                                                  │
  │  System:                                                          │
  │    ├── Celery task monitor (via Flower or custom)               │
  │    ├── Email logs viewer                                        │
  │    ├── Webhook delivery logs                                    │
  │    ├── Audit trail viewer                                       │
  │    └── System health overview                                   │
  └──────────────────────────────────────────────────────────────────┘
  ```
- **Location**: `app/api/v1/admin/` (admin routes), `app/services/admin_service.py`

### RBAC (Role-Based Access Control)
- **Model**: Role + Permission based (not just user/admin)
- **Default Roles**: `super_admin`, `admin`, `moderator`, `user`, `viewer`, `guest`
- **Permissions**: Granular action-level (`users:read`, `users:write`, `users:delete`, `admin:access`, `billing:manage`)
- **Storage**: MySQL tables: `roles`, `permissions`, `role_permissions`, `user_roles`
- **Implementation**: FastAPI dependency `require_permission("users:write")`
- **Middleware Pattern**:
  ```python
  def require_role(roles: list[str]):
      async def checker(user = Depends(get_current_user)):
          if user.role not in roles:
              raise ForbiddenException("Insufficient permissions")
      return Depends(checker)

  def require_permission(permission: str):
      async def checker(user = Depends(get_current_user)):
          user_perms = await permission_service.get_user_permissions(user.id)
          if permission not in user_perms:
              raise ForbiddenException(f"Missing permission: {permission}")
      return Depends(checker)
  ```
- **Cache**: User permissions cached in Redis (invalidate on role change)
- **Location**: `app/core/permissions.py`, `app/models/sql/role.py`, `app/models/sql/permission.py`

### Two-Factor Authentication (2FA)
- **Method**: TOTP (Time-based One-Time Password) via authenticator apps (Google Authenticator, Authy)
- **Library**: `pyotp` for TOTP generation/verification
- **QR Code**: `qrcode` library to generate setup QR code
- **Flow**:
  1. User enables 2FA → backend generates TOTP secret → returns QR code URL
  2. User scans QR with authenticator app → enters 6-digit code to verify
  3. Backend stores encrypted TOTP secret + backup codes in MySQL
  4. On login: after password → prompt for 2FA code → verify with `pyotp.TOTP(secret).verify(code)`
  5. Backup codes (10 one-time codes) for recovery if phone lost
- **Storage**: `user.totp_secret` (encrypted), `user.is_2fa_enabled`, `user_backup_codes` table
- **Env Var**: `TOTP_ENCRYPTION_KEY` for encrypting TOTP secrets at rest
- **API Endpoints**:
  - `POST /api/v1/auth/2fa/enable` → returns QR code + backup codes
  - `POST /api/v1/auth/2fa/verify-setup` → verify first code to activate
  - `POST /api/v1/auth/2fa/disable` → disable 2FA (requires current code)
  - `POST /api/v1/auth/2fa/verify` → verify code during login
  - `POST /api/v1/auth/2fa/backup` → use backup code

### Session Management
- **Track All Active Sessions**: MySQL `user_sessions` table (id, user_id, device_info, ip_address, location, created_at, last_active_at, is_current)
- **Device Fingerprinting**: User-Agent parsing + IP geolocation (free MaxMind GeoLite2)
- **API Endpoints**:
  - `GET /api/v1/auth/sessions` — list all active sessions with device info
  - `DELETE /api/v1/auth/sessions/:id` — revoke specific session (logout that device)
  - `DELETE /api/v1/auth/sessions` — revoke all sessions except current (logout everywhere)
- **Security Alerts**: Email notification on login from new device/location
- **Frontend**: Settings page showing "Active Sessions" with device icons + "Logout" button per session

### Error Tracking & Crash Reporting
- **Backend**: Sentry (`sentry-sdk[fastapi]`) — auto-captures unhandled exceptions, slow transactions
- **Frontend Web**: `@sentry/nextjs` — JS errors, component errors, performance
- **Frontend Mobile**: `sentry-expo` — React Native crashes, native errors
- **Configuration**: Via `SENTRY_DSN` env var (per environment)
- **Features**: Error grouping, stack traces, user context, breadcrumbs, release tracking
- **Source Maps**: Upload source maps on deploy for readable stack traces
- **Alerts**: Sentry → Slack/email alert on new/regression errors
- **Performance**: Transaction tracing for slow API endpoints (>500ms)
- **Location**: `app/core/sentry_config.py` — init with FastAPI integration

### Internationalization (i18n / Multi-Language)
- **Backend**: `babel` for Python translations, accept `Accept-Language` header
- **Frontend Web**: `next-intl` or `next-i18next` for Next.js
- **Frontend Mobile**: `expo-localization` + `i18next` + `react-i18next` for React Native
- **Default Languages**: English (en) + Hindi (hi) — add more as needed
- **Translation Files**: JSON per language in `public/locales/{lang}/common.json`
- **Strategy**:
  - UI strings: Translation keys (`t('dashboard.welcome')`)
  - User content: Stored in original language (NOT translated)
  - Dates/numbers: Locale-aware formatting (`Intl.DateTimeFormat`, `Intl.NumberFormat`)
  - Currency: Already INR but display with locale formatting (₹1,499 not ₹1499)
  - RTL: Not needed for Hindi/English but architecture-ready
- **Detection**: Browser language → user preference → default (en)
- **User Setting**: Language preference saved in user profile (syncs across devices)
- **Admin**: Translation management in admin panel (or external tool like Crowdin)

### PWA (Progressive Web App) Support
- **next-pwa**: PWA plugin for Next.js — auto-generates service worker
- **Features**:
  - Install prompt ("Add to Home Screen")
  - Offline fallback page
  - Background sync for offline actions
  - Push notifications (Web Push API)
  - App-like experience on mobile browsers
- **manifest.json**: Product name, icons, theme_color (from BRAND_GUIDE.md), display: standalone
- **Service Worker**: Cache static assets, API response caching strategy
- **Icons**: Generate all PWA icon sizes from brand logo (192x192, 512x512)
- **Caching**: Stale-while-revalidate for API, cache-first for static assets

### Product Analytics & Event Tracking
- **Self-Hosted**: PostHog (`posthog-python` backend, `posthog-js` frontend) — RECOMMENDED for privacy
- **Alternative**: Mixpanel, Amplitude, or custom events in MongoDB
- **Backend Events**: Track via Celery task (non-blocking)
  ```python
  analytics_service.track(user_id, "feature_used", {"feature": "ai_generation", "points_cost": 10})
  ```
- **Frontend Events**: Auto-track page views, clicks, form submissions
- **Key Metrics to Track**:
  ```
  ┌──────────────────────────────────────────────────────────────────┐
  │  ANALYTICS EVENTS — Track these for product intelligence        │
  │                                                                  │
  │  Acquisition:                                                    │
  │    ├── user_signed_up (method: email/google, source: utm_*)     │
  │    ├── user_activated (completed onboarding)                    │
  │    └── trial_started / trial_expired / trial_converted          │
  │                                                                  │
  │  Engagement:                                                     │
  │    ├── feature_used (feature_name, duration)                    │
  │    ├── page_viewed (path, referrer, duration)                   │
  │    ├── search_performed (query, results_count, clicked_result)  │
  │    └── session_duration, daily_active_time                      │
  │                                                                  │
  │  Revenue:                                                        │
  │    ├── subscription_created (plan, billing_cycle, amount)       │
  │    ├── subscription_upgraded / downgraded / cancelled           │
  │    ├── topup_purchased (pack, amount)                           │
  │    └── points_exhausted (action that triggered)                 │
  │                                                                  │
  │  Retention:                                                      │
  │    ├── user_returned (days_since_last_visit)                    │
  │    ├── feature_adoption_rate                                    │
  │    └── churn_risk_score (calculated by Celery beat)             │
  └──────────────────────────────────────────────────────────────────┘
  ```
- **Location**: `app/services/analytics_service.py`, `app/tasks/analytics_tasks.py`
- **Env Vars**: `POSTHOG_API_KEY`, `POSTHOG_HOST`

### Social Sharing & Deep Links
- **OG Meta Tags**: Dynamic per page — `og:title`, `og:description`, `og:image`, `og:url`
- **Twitter Cards**: `twitter:card=summary_large_image`, `twitter:title`, `twitter:image`
- **JSON-LD**: Structured data for SEO (Organization, Product, FAQ schemas)
- **Share Buttons**: Native Web Share API (`navigator.share()`) with fallback buttons
- **Deep Links (Mobile)**:
  - Universal Links (iOS) + App Links (Android) via Expo linking
  - Config: `app.json` → `expo.scheme`, `expo.ios.associatedDomains`, `expo.android.intentFilters`
  - Server: `/.well-known/apple-app-site-association` + `/.well-known/assetlinks.json`
  - Pattern: `https://app.domain.com/resource/:id` → opens in app if installed, web if not
- **Referral System**: Shareable referral links with tracking (`?ref=USER_CODE`)
- **Location**: Next.js Metadata API in layouts, `app/api/v1/share.py` for dynamic OG images

### Feature Flags
- **Library**: Custom lightweight implementation (no external dependency for simple cases)
- **Storage**: MySQL `feature_flags` table + Redis cache
- **Schema**: `{name, is_enabled, rollout_percentage, allowed_roles, allowed_user_ids, created_at}`
- **Types**:
  - **Global**: On/off for everyone
  - **Percentage**: Gradual rollout (10% → 50% → 100%)
  - **Role-based**: Only admins or beta testers see it
  - **User-specific**: Enable for specific user IDs
  - **Plan-based**: Feature only for Pro/Enterprise plans
- **Implementation**:
  ```python
  # Backend
  if await feature_flag_service.is_enabled("new_dashboard", user_id=user.id):
      return new_dashboard_response()
  else:
      return old_dashboard_response()

  # Frontend — via API
  const { flags } = useFeatureFlags()  // fetched from GET /api/v1/flags
  if (flags.new_dashboard) return <NewDashboard />
  ```
- **Admin**: Toggle flags from admin panel (instant, no deploy needed)
- **API**: `GET /api/v1/flags` — returns user's active flags (cached)
- **Location**: `app/services/feature_flag_service.py`, `app/models/sql/feature_flag.py`

### Legal Pages (MANDATORY for public apps)
- **Pages to Generate**:
  ```
  ┌──────────────────────────────────────────────────────────────────┐
  │  LEGAL PAGES — Required for ANY public-facing application       │
  │                                                                  │
  │  1. Terms of Service (/terms)                                   │
  │     - User obligations, acceptable use, liability limits        │
  │     - Subscription terms, refund policy                         │
  │     - India-specific: IT Act compliance, DPDPA reference        │
  │                                                                  │
  │  2. Privacy Policy (/privacy)                                   │
  │     - What data collected, how used, who shared with            │
  │     - Cookie usage, analytics tracking disclosure               │
  │     - Data retention periods                                    │
  │     - User rights: access, correction, deletion                 │
  │     - India DPDPA compliance, GDPR compliance (if EU users)    │
  │     - Contact: Data Protection Officer email                    │
  │                                                                  │
  │  3. Cookie Policy (/cookies)                                    │
  │     - Essential cookies (auth, CSRF)                            │
  │     - Analytics cookies (PostHog, etc.)                         │
  │     - Cookie consent banner (mandatory in EU, good practice)    │
  │                                                                  │
  │  4. Refund Policy (/refund)                                     │
  │     - Subscription cancellation terms                           │
  │     - Credit point refund policy (non-refundable once used)    │
  │     - India Consumer Protection Act compliance                  │
  │                                                                  │
  │  5. Acceptable Use Policy (/acceptable-use)                     │
  │     - Prohibited content/behavior                               │
  │     - API usage limits                                          │
  │     - Account termination conditions                            │
  └──────────────────────────────────────────────────────────────────┘
  ```
- **Implementation**: Static MDX pages in Next.js `/app/(legal)/` route group
- **Footer**: Links to all legal pages in website footer (ALWAYS visible)
- **Signup**: Checkbox "I agree to Terms of Service and Privacy Policy" (MANDATORY)
- **Agent**: Auto-generate placeholder legal pages — user/lawyer reviews before launch

### Data Export & GDPR / DPDPA Compliance
- **User Rights**:
  - `GET /api/v1/account/export` → Download all personal data as JSON/ZIP (queued via Celery)
  - `DELETE /api/v1/account` → Request account deletion (soft delete → hard delete after 30 days)
  - `PATCH /api/v1/account/consent` → Update data processing consent
- **Data Export**: All user data from MySQL + MongoDB + Redis → packaged as JSON → emailed as download link
- **Account Deletion Flow**:
  1. User requests deletion → confirmation email
  2. Soft delete immediately (data retained 30 days for recovery)
  3. Celery scheduled task → hard delete after 30 days (MySQL + MongoDB + Redis + S3 files)
  4. Razorpay subscription cancelled on deletion
- **Data Retention Policy**: Define per data type (user data: 30 days after deletion, logs: 90 days, invoices: 7 years)
- **Consent Tracking**: MongoDB document per user tracking what they consented to and when
- **India DPDPA**: Data Protection Board notification capability, data localization awareness

### Feedback & Support System
- **In-App Feedback Widget**: Floating button (bottom-right) → slide-out form
- **Feedback Types**: Bug report, feature request, general feedback, support request
- **Storage**: MongoDB `feedback` collection (user_id, type, message, screenshot_url, page_url, metadata, status, created_at)
- **API**: `POST /api/v1/feedback` — submit feedback with optional screenshot
- **Admin**: Feedback viewer in admin panel with status tracking (open/in-progress/resolved)
- **Help Center**: Static FAQ/docs pages or integrated knowledge base
- **Contact**: Support email form at `/contact`
- **Optional Integration**: Intercom, Crisp, or Tawk.to chat widget (agent decides based on product)

### Onboarding Flow (First-Time User Experience)
- **Library (Web)**: `driver.js` or `react-joyride` for product tours
- **Library (Mobile)**: Custom modal sequence or `react-native-copilot`
- **Flow**:
  1. Welcome modal with product overview (after first login)
  2. Guided tour highlighting key features (3-5 steps)
  3. Setup checklist (complete profile, try core feature, invite team)
  4. Progress indicator ("3 of 5 steps completed")
  5. Skip option (never force completion)
- **Storage**: MongoDB `user_onboarding` (user_id, steps_completed, completed_at, skipped)
- **API**: `GET /api/v1/onboarding/status`, `PATCH /api/v1/onboarding/step/:step`
- **Trigger**: Only show once (track completion status)
- **Empty States**: Every page with no data shows helpful illustration + CTA ("Create your first X")

### Backup & Disaster Recovery
- **MySQL**: Automated daily backups via `mysqldump` or managed DB snapshots (Celery beat)
- **MongoDB**: `mongodump` daily backups to S3/GCS
- **Redis**: RDB snapshots + AOF persistence (configured in redis.conf)
- **S3/Storage**: Cross-region replication for uploaded files
- **Backup Storage**: Separate S3 bucket with lifecycle policy (keep 30 daily + 12 monthly + 1 yearly)
- **Recovery Testing**: Monthly restore test (documented in RUNBOOK.md)
- **RTO/RPO**: Recovery Time Objective < 1 hour, Recovery Point Objective < 1 hour
- **Scripts**: `scripts/backup.sh`, `scripts/restore.sh` — tested and documented
- **Location**: `app/tasks/backup_tasks.py` — Celery beat schedule

### CDN & Asset Optimization
- **CDN**: CloudFront (AWS) or Cloud CDN (GCP) for static assets + user uploads
- **Image Optimization**: Next.js `<Image>` component (auto WebP/AVIF, lazy loading, responsive sizes)
- **Static Assets**: CSS/JS bundled and served from CDN with cache headers (immutable, max-age=31536000)
- **Fonts**: Self-hosted fonts (not Google Fonts CDN) for GDPR + performance
- **Lazy Loading**: Images, heavy components, below-fold content
- **Code Splitting**: Next.js automatic code splitting + `dynamic()` imports for heavy components
- **Compression**: gzip/Brotli for API responses (FastAPI GZip middleware)
- **Bundle Analysis**: `@next/bundle-analyzer` to monitor bundle size
- **Lighthouse Target**: Performance score > 90, Accessibility > 90

### API Rate Limiting (Per Plan)
- **Implementation**: Redis sliding window counter per user + per IP
- **Tiers**:
  ```
  ┌──────────────────────────────────────────────────────────┐
  │  Rate Limits per Subscription Plan                       │
  │                                                          │
  │  Free Trial:    30 req/min,    500 req/hour             │
  │  Basic Plan:    60 req/min,  2,000 req/hour             │
  │  Pro Plan:     120 req/min,  5,000 req/hour             │
  │  Enterprise:   300 req/min, 15,000 req/hour             │
  │  Admin:        Unlimited                                 │
  │                                                          │
  │  Unauthenticated: 20 req/min per IP (public endpoints)  │
  └──────────────────────────────────────────────────────────┘
  ```
- **Headers**: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset` on every response
- **Exceeded**: HTTP 429 Too Many Requests with `Retry-After` header
- **Location**: `app/api/middleware.py` — rate limit middleware reading plan from user context

### Centralized Logging
- **Structured**: `structlog` → JSON format (already present, extend with below)
- **Aggregation**: Loki + Grafana (lightweight) or ELK Stack (Elasticsearch + Logstash + Kibana)
- **Docker**: Loki container in docker-compose.monitoring.yml
- **Log Levels**: DEBUG (dev), INFO (staging), WARNING (prod)
- **Context**: Every log includes `request_id`, `user_id`, `endpoint`, `duration_ms`
- **Request ID**: UUID per request (set in middleware, propagated to all services/tasks)
- **Audit Trail**: Critical actions logged to MongoDB (who did what, when, from where)
- **Retention**: 7 days hot (searchable), 90 days cold (S3 archive)
- **Alerting**: Grafana alerts on error rate spike, 5xx count > threshold

### Code Quality
- **Linter**: `ruff` (replaces flake8 + isort + black)
- **Type Checking**: `mypy` with strict mode
- **Testing**: `pytest` + `pytest-asyncio` + `httpx` (for async test client)
- **Coverage**: `pytest-cov` (target >80%)
- **OAuth**: `authlib` (Google OAuth2 integration)
- **Email**: `fastapi-mail` (async email with Jinja2 templates), `jinja2` (template engine)

### API Layer
- **REST**: FastAPI native routes under `/api/v1/` (default, always included)
- **GraphQL**: Strawberry GraphQL (`strawberry-graphql[fastapi]`) mounted at `/graphql`
- **GraphQL Schema**: Auto-generated from Pydantic schemas using `strawberry.experimental.pydantic`
- **GraphQL Auth**: Same JWT cookie auth — extract token from cookies in GraphQL context
- **GraphQL Subscriptions**: Via WebSocket at `/graphql` (for real-time features)
- **DataLoader**: Use `strawberry.dataloader.DataLoader` to prevent N+1 queries
- **GraphQL Location**: `app/graphql/` directory with `schema.py`, `types/`, `resolvers/`, `mutations/`
- **When to use REST vs GraphQL**:
  - REST: Simple CRUD, webhooks, file uploads, third-party integrations
  - GraphQL: Complex nested queries, mobile clients, dashboard aggregations

### Frontend — Web App (if applicable)
- **Framework**: React 19+ with Next.js 15+ (App Router, TypeScript strict)
- **Styling**: Tailwind CSS 4+ (utility-first, JIT)
- **⭐ PRODUCTION BAR (HARD — see `skills/alpha-architecture/references/CODE_PATTERNS_FRONTEND_PRODUCTION.md`)**: Every frontend ships production-ready, ALWAYS:
  - **Fonts**: a real typeface pairing (DISPLAY + BODY) via `next/font` (self-hosted, zero layout shift) — NEVER system-ui default.
  - **Color**: a full OKLCH semantic design-token system in `globals.css` with light **and** dark themes; components use semantic tokens ONLY (`bg-primary`, `text-foreground`) — NEVER raw Tailwind palette (`bg-blue-500`) or hard-coded hex (hex lives only in BRAND_GUIDE/SVG/email). Run `/gen-brand` first if no `BRAND_GUIDE.md` exists.
  - **Errors**: every user-facing error is a friendly, branded, brand-voice message via ONE `getErrorMessage` mapper — NEVER an HTTP status code, exception name, stack trace, or raw API payload shown to the user.
  - Plus: real-data wiring (no mocks/dead buttons), `frontend-design` skill for visual pages, next/image + WCAG 2.1 AA, error.tsx/loading.tsx per route group.
- **UI Component Library** (Agent MUST choose best for the product — research during Phase -1):
  ```
  ┌──────────────────────────────────────────────────────────────────────────┐
  │  AGENT: Pick the BEST UI library based on product type & market research │
  │  WebSearch: "best React UI component library 2025 2026"                  │
  │  WebSearch: "[product category] dashboard UI best practices"             │
  │                                                                          │
  │  OPTION A: shadcn/ui + Radix UI (RECOMMENDED for most SaaS)             │
  │    → Beautifully designed, accessible, copy-paste components             │
  │    → Radix primitives (unstyled, accessible) + Tailwind styling          │
  │    → Full ownership of code (no dependency lock-in)                      │
  │    → Best for: SaaS dashboards, admin panels, B2B tools                  │
  │    → Install: npx shadcn-ui@latest init                                  │
  │                                                                          │
  │  OPTION B: Ant Design (antd) — for data-heavy enterprise apps           │
  │    → 60+ components, excellent tables/forms/charts                       │
  │    → Best for: CRM, ERP, analytics dashboards, enterprise tools          │
  │    → Strong i18n, RTL support                                            │
  │                                                                          │
  │  OPTION C: Material UI (MUI) — for Google Material Design aesthetic     │
  │    → Most popular React UI library, massive ecosystem                    │
  │    → Best for: Consumer apps, familiar Material Design look              │
  │    → MUI X for premium data grids, date pickers                          │
  │                                                                          │
  │  OPTION D: Chakra UI — for clean, minimal SaaS products                 │
  │    → Simple API, great DX, built-in dark mode                            │
  │    → Best for: Startups, MVPs, clean aesthetic                           │
  │                                                                          │
  │  OPTION E: Mantine — for feature-rich apps needing everything            │
  │    → 120+ components + hooks, excellent DX                               │
  │    → Best for: Complex apps needing forms, rich text, notifications      │
  │                                                                          │
  │  Decision criteria (use market research):                                │
  │    1. What UI patterns do top competitors use?                           │
  │    2. What's the product type? (dashboard, consumer, marketplace, etc.)  │
  │    3. What level of customization is needed?                             │
  │    4. Target audience aesthetic expectations?                            │
  └──────────────────────────────────────────────────────────────────────────┘
  ```
- **Animation & Motion**: Framer Motion (`framer-motion`) — smooth page transitions, micro-interactions, layout animations
- **Icons**: Lucide React (`lucide-react`) — consistent, clean icon set (pairs with shadcn/ui)
- **Charts/Data Viz**: Recharts or Tremor (Tailwind-native charts for dashboards)
- **Forms**: React Hook Form + Zod validation (type-safe, performant)
- **Toast/Notifications**: Sonner (`sonner`) — beautiful toast notifications
- **State Management**: Zustand (global state) + TanStack Query (server state/caching)
- **Date Handling**: date-fns (lightweight, tree-shakeable)
- **Tables**: TanStack Table (headless, powerful sorting/filtering/pagination)
- **Rich Text Editor**: Tiptap (if content editing needed — extensible, ProseMirror-based)
- **File Upload**: react-dropzone (drag & drop file uploads)
- **HTTP Client**: Axios with `withCredentials: true` (for cookie-based auth REST)
- **GraphQL Client**: Apollo Client or urql (with `credentials: 'include'` for cookies)
- **Dark Mode**: next-themes (system-aware dark/light/auto toggle)
- **SEO**: Next.js built-in Metadata API + JSON-LD structured data
- **Loading States**: Skeleton loaders (never blank loading screens)
- **Error Boundaries**: react-error-boundary (graceful error handling)
- **NEVER use localStorage/sessionStorage for auth tokens**

### Frontend — Mobile App (if React Native)
- **Framework**: React Native 0.83+ with Expo SDK 55+ (managed workflow, New Architecture only)
- **Navigation**: React Navigation 7 — **MANDATORY pattern: Side Drawer + Bottom Tabs**
  ```
  ┌──────────────────────────────────────────────────────────────────┐
  │  MOBILE NAVIGATION PATTERN (ALWAYS — Non-Negotiable)            │
  │                                                                  │
  │  Root: DrawerNavigator (side drawer — swipe from left)          │
  │    ├── Drawer Items: Profile, Settings, Help, Logout, etc.     │
  │    └── Main: BottomTabNavigator (bottom tab bar — always visible)│
  │          ├── Tab 1: Home (StackNavigator inside)                │
  │          ├── Tab 2: [Core Feature] (StackNavigator inside)      │
  │          ├── Tab 3: [Core Feature] (StackNavigator inside)      │
  │          ├── Tab 4: Notifications (StackNavigator inside)       │
  │          └── Tab 5: Profile/More (StackNavigator inside)        │
  │                                                                  │
  │  Bottom tabs: 4-5 tabs MAX (most important screens)             │
  │  Drawer: Secondary navigation (settings, help, account, etc.)  │
  │  Stack: Within each tab for deep navigation (list → detail)     │
  │                                                                  │
  │  ✅ Bottom tabs visible on ALL main screens                     │
  │  ✅ Drawer accessible via hamburger icon (top-left)             │
  │  ✅ Drawer also opens on swipe-from-left gesture               │
  │  ✅ Active tab highlighted with brand color                     │
  │  ✅ Tab icons: Lucide or custom SVG icons                       │
  │  ❌ NEVER hide bottom tabs on main screens                      │
  │  ❌ NEVER use more than 5 bottom tabs                           │
  │  ❌ NEVER use only drawer without bottom tabs                   │
  │  ❌ NEVER use only tabs without drawer                          │
  └──────────────────────────────────────────────────────────────────┘
  ```
- **Styling** (Agent MUST choose best for the mobile app):
  ```
  ┌──────────────────────────────────────────────────────────────────────────┐
  │  AGENT: Pick the BEST mobile UI approach based on product type           │
  │  WebSearch: "best React Native UI library 2025 2026"                     │
  │  WebSearch: "[product category] mobile app design patterns"              │
  │                                                                          │
  │  OPTION A: NativeWind + shadcn/ui RN (RECOMMENDED)                      │
  │    → Tailwind CSS for React Native                                       │
  │    → Consistent styling between web and mobile                           │
  │    → Best for: Unified web+mobile codebase                               │
  │                                                                          │
  │  OPTION B: React Native Paper (Material Design)                          │
  │    → Google Material Design 3 components                                 │
  │    → Best for: Android-first apps, Material aesthetic                    │
  │                                                                          │
  │  OPTION C: Tamagui — for cross-platform with max performance            │
  │    → Optimizing compiler, shared styles web+native                       │
  │    → Best for: Performance-critical apps, complex UI                     │
  │                                                                          │
  │  OPTION D: Gluestack UI v2 — for enterprise mobile apps                 │
  │    → Accessible, themeable, production-ready                             │
  │    → Best for: Enterprise/B2B mobile apps                                │
  │                                                                          │
  │  OPTION E: React Native Elements — for rapid prototyping                │
  │    → Simple, consistent cross-platform components                        │
  │    → Best for: MVPs, quick mobile apps                                   │
  └──────────────────────────────────────────────────────────────────────────┘
  ```
- **Animation**: React Native Reanimated 3 + Gesture Handler (60fps native animations)
- **Icons**: react-native-vector-icons or Lucide React Native
- **State Management**: Zustand + TanStack Query (same as web)
- **Storage**: expo-secure-store (for tokens — NEVER AsyncStorage for auth)
- **Push Notifications**: expo-notifications + Firebase Cloud Messaging
- **Camera/Media**: expo-camera, expo-image-picker, expo-image (fast cached images)
- **Auth**: expo-secure-store for JWT tokens + expo-auth-session for OAuth flows + expo-local-authentication for biometrics

### Mobile Project Config (MANDATORY)
```
┌──────────────────────────────────────────────────────────────────────────┐
│  MOBILE PROJECT SETUP — Must be configured before first build           │
│                                                                          │
│  app.config.ts:                                                          │
│  ├── name, slug, version, orientation                                   │
│  ├── icon: "./assets/icon.png" (1024x1024)                              │
│  ├── splash: { image, resizeMode, backgroundColor }                     │
│  ├── scheme: "[app-name]" (for deep links)                              │
│  ├── ios.bundleIdentifier: "com.alphaai.[appname]"                      │
│  ├── ios.supportsTablet: true                                            │
│  ├── ios.associatedDomains: ["applinks:api.domain.com"]                 │
│  ├── ios.infoPlist: { NSCameraUsageDescription, NSPhotoLibraryUsage }   │
│  ├── android.package: "com.alphaai.[appname]"                           │
│  ├── android.adaptiveIcon: { foregroundImage, backgroundColor }         │
│  ├── android.intentFilters: [deep link config]                          │
│  ├── plugins: ["expo-router", "expo-secure-store", etc.]                │
│  └── extra.eas.projectId: "[EAS project ID]"                            │
│                                                                          │
│  eas.json (EAS Build profiles):                                         │
│  ├── development: { developmentClient: true, distribution: "internal" } │
│  ├── preview: { distribution: "internal" }                               │
│  ├── production: { autoIncrement: true }                                 │
│  └── submit: { ios: { appleId, ascAppId }, android: { track: "internal" } } │
│                                                                          │
│  babel.config.js (CRITICAL — these plugins required):                   │
│  ├── preset: "babel-preset-expo"                                         │
│  ├── plugins: ["nativewind/babel"]  (for NativeWind)                    │
│  └── plugins: ["react-native-reanimated/plugin"] (MUST be LAST)         │
│                                                                          │
│  metro.config.js:                                                        │
│  ├── withNativeWind() wrapper for NativeWind CSS support                │
│  └── resolver.sourceExts for custom file extensions                     │
│                                                                          │
│  tailwind.config.js (for NativeWind):                                   │
│  ├── content: ["./app/**/*.{js,jsx,ts,tsx}"]                            │
│  └── presets: [require("nativewind/preset")]                            │
│                                                                          │
│  Environment Variables:                                                  │
│  ├── EXPO_PUBLIC_API_URL — backend API base URL                         │
│  ├── EXPO_PUBLIC_WS_URL — WebSocket URL                                 │
│  ├── EXPO_PUBLIC_SENTRY_DSN — Sentry DSN for mobile                    │
│  └── Access via process.env.EXPO_PUBLIC_* in app code                   │
└──────────────────────────────────────────────────────────────────────────┘
```

### Mobile Auth System (Different from Web)
```
┌──────────────────────────────────────────────────────────────────────────┐
│  MOBILE AUTH — Native apps can't use HTTP-Only cookies!                  │
│                                                                          │
│  Token Storage:                                                          │
│  ✅ expo-secure-store for JWT access + refresh tokens                   │
│  ✅ Tokens stored in iOS Keychain / Android Keystore (hardware-backed)  │
│  ✅ Axios interceptor: reads token from secure store, adds to header    │
│  ✅ Auto-refresh: 401 → read refresh token → POST /auth/refresh        │
│  ✅ Auth state persists across app restarts (read from secure store)    │
│  ❌ NEVER use AsyncStorage for tokens (not encrypted)                   │
│  ❌ NEVER store tokens in React state only (lost on kill)               │
│                                                                          │
│  Google OAuth on Mobile:                                                 │
│  ✅ expo-auth-session + expo-web-browser (opens system browser)         │
│  ✅ Flow: App → system browser → Google consent → redirect back to app │
│  ✅ Deep link callback: [scheme]://auth/google/callback                 │
│  ✅ Exchange auth code → backend → get JWT → store in secure store      │
│  ❌ NEVER use react-native-google-signin (deprecated patterns)          │
│  ❌ NEVER embed WebView for OAuth (security violation)                  │
│                                                                          │
│  Apple Sign-In (REQUIRED for iOS App Store):                            │
│  ✅ expo-apple-authentication (native iOS Sign In with Apple)           │
│  ✅ Required if ANY third-party login exists (Google, Facebook, etc.)   │
│  ✅ Send Apple identity token to backend → verify → issue JWT           │
│  ✅ Handle: name only provided on FIRST login (cache it!)               │
│  ❌ NEVER skip Apple Sign-In (Apple WILL reject the app)                │
│                                                                          │
│  Biometric Auth (optional but recommended):                             │
│  ✅ expo-local-authentication (Face ID / Touch ID / Fingerprint)        │
│  ✅ Use for: app unlock, confirm payments, sensitive actions            │
│  ✅ Check device capability: hasHardwareAsync() + isEnrolledAsync()     │
│  ✅ Fallback to PIN/password if biometrics unavailable                  │
│                                                                          │
│  Auth Startup Flow (on app launch):                                     │
│  1. Read access token from expo-secure-store                            │
│  2. If exists → validate with GET /auth/me                              │
│  3. If valid → hydrate user state → navigate to Home                    │
│  4. If 401 → try refresh token → if success → retry                    │
│  5. If no token or refresh fails → navigate to Login                    │
│  6. Show splash screen during this check (no flash of login)            │
└──────────────────────────────────────────────────────────────────────────┘
```

### Mobile UI Patterns (MANDATORY)
```
┌──────────────────────────────────────────────────────────────────────────┐
│  MOBILE UI PATTERNS — Every RN app MUST implement these                  │
│                                                                          │
│  Layout Essentials:                                                      │
│  ✅ SafeAreaView wrapping ALL screens (react-native-safe-area-context)  │
│  ✅ KeyboardAvoidingView on ALL screens with inputs                     │
│  ✅ StatusBar component (adapts to theme: light-content / dark-content) │
│  ✅ Platform.OS checks for iOS/Android-specific styling                 │
│  ✅ Dimensions API or useWindowDimensions for responsive layouts        │
│                                                                          │
│  Lists & Scrolling:                                                      │
│  ✅ FlashList (by Shopify) instead of FlatList (10x faster)            │
│  ✅ Pull-to-refresh on all list screens (RefreshControl)                │
│  ✅ Infinite scroll with onEndReached + pagination                      │
│  ✅ Empty state component when list has no data                         │
│  ✅ List item separators + loading footer                               │
│  ❌ NEVER use ScrollView for long lists (kills performance)             │
│                                                                          │
│  Bottom Sheet:                                                           │
│  ✅ @gorhom/bottom-sheet (best RN bottom sheet library)                 │
│  ✅ Use for: filters, actions, confirmations, pickers                   │
│  ✅ Gesture-driven with Reanimated + Gesture Handler                    │
│  ✅ Backdrop overlay with dim background                                │
│                                                                          │
│  Feedback:                                                               │
│  ✅ react-native-toast-message (toast notifications)                    │
│  ✅ expo-haptics (haptic feedback on button press, success, error)      │
│  ✅ Skeleton loaders (react-native-skeleton-placeholder)                │
│  ✅ Activity indicators for async operations                            │
│  ✅ Confirmation dialogs for destructive actions                        │
│                                                                          │
│  Images:                                                                 │
│  ✅ expo-image (fast, cached, supports blurhash placeholders)           │
│  ✅ Blurhash placeholder while loading (smooth UX)                      │
│  ❌ NEVER use RN Image for remote images (no caching)                   │
│                                                                          │
│  Forms:                                                                  │
│  ✅ React Hook Form + Zod (same as web — shared validation)            │
│  ✅ Custom TextInput with label, error state, focus animation           │
│  ✅ Secure text entry toggle (show/hide password)                       │
│  ✅ Date picker: @react-native-community/datetimepicker                 │
│  ✅ Dropdown/Select: react-native-dropdown-picker or custom bottom sheet │
│                                                                          │
│  Modals & Overlays:                                                      │
│  ✅ React Native Modal for full-screen overlays                         │
│  ✅ ActionSheet for iOS-style action menus                              │
│  ✅ Alert.alert() for simple confirmations                              │
└──────────────────────────────────────────────────────────────────────────┘
```

### Mobile Media & Device Features
```
┌──────────────────────────────────────────────────────────────────────────┐
│  MEDIA & DEVICE FEATURES — Add based on app requirements                 │
│                                                                          │
│  Camera & Media (most apps need these):                                  │
│  ├── expo-camera: Camera capture (photo/video, QR scanning)             │
│  ├── expo-image-picker: Select from gallery or take photo               │
│  ├── expo-file-system: Download, cache, manage local files              │
│  ├── expo-sharing: Share files/content to other apps                    │
│  ├── expo-av: Audio/video playback and recording                        │
│  └── expo-media-library: Save photos/videos to device gallery           │
│                                                                          │
│  Device APIs (add if app needs):                                         │
│  ├── expo-location: GPS location, geofencing, background location       │
│  ├── expo-contacts: Read device contacts (social/messaging apps)        │
│  ├── expo-calendar: Read/write calendar events                          │
│  ├── expo-sensors: Accelerometer, gyroscope (fitness/AR apps)           │
│  ├── expo-haptics: Vibration patterns (success, warning, selection)     │
│  ├── expo-clipboard: Copy/paste programmatically                        │
│  ├── expo-linking: Open URLs, maps, phone dialer, email                 │
│  ├── expo-device: Device name, model, OS version                        │
│  ├── expo-network: Check connectivity (WiFi/cellular/offline)           │
│  ├── expo-battery: Battery level and charging state                     │
│  └── expo-brightness: Screen brightness control                        │
│                                                                          │
│  Permission Handling (IMPORTANT):                                        │
│  ✅ Always check permission status BEFORE requesting                    │
│  ✅ Show custom explanation screen BEFORE system permission dialog      │
│  ✅ Handle "never_ask_again" → direct user to Settings                  │
│  ✅ Graceful degradation when permission denied                         │
│  ❌ NEVER request all permissions on app launch (request in context)    │
└──────────────────────────────────────────────────────────────────────────┘
```

### Mobile Offline & Network
```
┌──────────────────────────────────────────────────────────────────────────┐
│  OFFLINE & NETWORK — Production apps MUST handle connectivity            │
│                                                                          │
│  Network Detection:                                                      │
│  ✅ @react-native-community/netinfo for connectivity monitoring         │
│  ✅ Show offline banner when no internet (top-of-screen, non-blocking)  │
│  ✅ Auto-retry queued requests when back online                         │
│  ✅ TanStack Query: networkMode: 'offlineFirst' for cached data         │
│                                                                          │
│  Offline Data Strategy:                                                  │
│  ✅ TanStack Query persistQueryClient with AsyncStorage                 │
│  ✅ Critical data cached locally (user profile, settings, recent items) │
│  ✅ Queue mutations when offline → replay when online                   │
│  ✅ Conflict resolution: server wins (last-write-wins) or prompt user   │
│  ✅ Optimistic UI updates (show change immediately, sync in background) │
│                                                                          │
│  Background Tasks:                                                       │
│  ✅ expo-task-manager for background execution                          │
│  ✅ expo-background-fetch for periodic sync                             │
│  ✅ Background notification handling                                     │
│  ❌ NEVER assume always-online (handle airplane mode, tunnels, etc.)    │
└──────────────────────────────────────────────────────────────────────────┘
```

### Mobile Security (Production MUST-HAVE)
```
┌──────────────────────────────────────────────────────────────────────────┐
│  MOBILE SECURITY — Beyond token storage                                  │
│                                                                          │
│  Token & Data Security:                                                  │
│  ✅ expo-secure-store for all sensitive data (Keychain/Keystore)        │
│  ✅ Clear secure store on logout (remove all tokens)                    │
│  ✅ No sensitive data in AsyncStorage (use only for preferences)        │
│                                                                          │
│  Network Security:                                                       │
│  ✅ Certificate pinning (react-native-ssl-pinning or custom)            │
│  ✅ iOS: App Transport Security enforced (HTTPS only)                   │
│  ✅ Android: Network security config (restrict cleartext traffic)       │
│  ✅ API base URL from env variable (not hardcoded)                      │
│                                                                          │
│  App Integrity:                                                          │
│  ✅ Root/jailbreak detection (jail-monkey or expo-device checks)        │
│  ✅ Code obfuscation enabled in production builds                       │
│  ✅ Disable React Native dev menu in production                         │
│  ✅ Hide sensitive screens from app switcher (iOS: blur overlay)        │
│  ✅ Prevent screenshots on sensitive screens (optional, fintech apps)   │
│                                                                          │
│  Clipboard & Input:                                                      │
│  ✅ Auto-clear clipboard after pasting OTP/password (10s timeout)       │
│  ✅ secureTextEntry for all password fields                             │
│  ❌ NEVER log sensitive data (tokens, passwords, PII) in console        │
│  ❌ NEVER use console.log in production (use __DEV__ flag)              │
└──────────────────────────────────────────────────────────────────────────┘
```

### Mobile Performance
```
┌──────────────────────────────────────────────────────────────────────────┐
│  PERFORMANCE — Ship a fast, smooth mobile app                            │
│                                                                          │
│  Runtime:                                                                │
│  ✅ Hermes engine (default in Expo SDK 55+ — always enabled)            │
│  ✅ FlashList over FlatList for all long lists                          │
│  ✅ React.memo() on expensive components                                │
│  ✅ useCallback/useMemo for derived values and handlers                 │
│  ✅ Avoid re-renders: separate state into small atoms (Zustand slices)  │
│                                                                          │
│  Images:                                                                 │
│  ✅ expo-image with caching + blurhash placeholders                     │
│  ✅ Serve resized images from CDN (never full-res on mobile)            │
│  ✅ Lazy load off-screen images                                         │
│                                                                          │
│  Bundle:                                                                 │
│  ✅ Bundle analysis: npx react-native-bundle-visualizer                 │
│  ✅ Tree-shake unused imports                                            │
│  ✅ Lazy load screens with React.lazy + Suspense                        │
│  ✅ Target: <30MB initial bundle, <5s cold start                        │
│                                                                          │
│  Memory:                                                                 │
│  ✅ Clean up subscriptions/timers in useEffect cleanup                  │
│  ✅ Use Flipper or React DevTools for memory profiling                  │
│  ❌ NEVER create closures in render (causes re-renders)                 │
│  ❌ NEVER store large data in React state (use external stores)         │
└──────────────────────────────────────────────────────────────────────────┘
```

### Mobile Accessibility (WCAG + Platform Guidelines)
```
┌──────────────────────────────────────────────────────────────────────────┐
│  ACCESSIBILITY — Support VoiceOver (iOS) + TalkBack (Android)            │
│                                                                          │
│  ✅ accessibilityLabel on ALL interactive elements                      │
│  ✅ accessibilityRole: "button", "link", "header", "image", etc.       │
│  ✅ accessibilityHint for non-obvious actions                           │
│  ✅ accessible={true} on custom touchable components                    │
│  ✅ accessibilityState: { selected, disabled, checked, expanded }       │
│  ✅ Dynamic font scaling: allowFontScaling={true} (default)             │
│  ✅ Minimum touch target: 44x44pt (iOS) / 48x48dp (Android)            │
│  ✅ Color contrast ratio: 4.5:1 for text, 3:1 for large text           │
│  ✅ accessibilityLiveRegion for dynamic content updates                 │
│  ✅ Focus management: announce screen changes to screen readers         │
│  ❌ NEVER rely on color alone to convey information                     │
│  ❌ NEVER disable font scaling on text components                       │
└──────────────────────────────────────────────────────────────────────────┘
```

### Mobile Testing
```
┌──────────────────────────────────────────────────────────────────────────┐
│  TESTING — Mobile-specific test strategy                                 │
│                                                                          │
│  Unit Tests:                                                             │
│  ✅ Jest + React Native Testing Library (RNTL)                          │
│  ✅ Test: components, hooks, utils, Zustand stores                      │
│  ✅ Mock: expo modules, navigation, secure store, API calls             │
│  ✅ Coverage target: >80% (same as backend)                             │
│                                                                          │
│  Integration Tests:                                                      │
│  ✅ RNTL renderScreen() with mocked navigation context                  │
│  ✅ Test: navigation flows, form submissions, API integration           │
│  ✅ Mock: TanStack Query responses, WebSocket events                    │
│                                                                          │
│  E2E Tests:                                                              │
│  ✅ Detox (by Wix) for native E2E testing                               │
│  ✅ Test on: iOS Simulator + Android Emulator                           │
│  ✅ Test flows: login, registration, core features, push notifications  │
│  ✅ Run in CI via EAS Build (development client)                        │
│                                                                          │
│  Device Matrix:                                                          │
│  ├── iOS: iPhone 15 (latest), iPhone SE (smallest), iPad (tablet)       │
│  ├── Android: Pixel 8 (stock), Samsung Galaxy (custom), budget device   │
│  ├── OS versions: latest + latest-1 (minimum support)                   │
│  └── Test: portrait + landscape, light + dark mode, with/without notch  │
└──────────────────────────────────────────────────────────────────────────┘
```

### App Store Readiness (MANDATORY for release)
```
┌──────────────────────────────────────────────────────────────────────────┐
│  APP STORE SUBMISSION — Everything needed to publish                      │
│                                                                          │
│  iOS App Store (Apple):                                                  │
│  ✅ Apple Developer Account ($99/year)                                   │
│  ✅ App Store Connect: create app, set bundle ID, categories            │
│  ✅ Apple Sign-In implemented (REQUIRED if Google login exists)          │
│  ✅ Privacy policy URL (hosted on web, linked in app.json)              │
│  ✅ App icons: 1024x1024 (no transparency, no rounded corners)          │
│  ✅ Screenshots: 6.7" (iPhone 15 Pro Max) + 5.5" (iPhone 8 Plus)       │
│  ✅ iPad screenshots if supportsTablet: true                            │
│  ✅ App description, keywords, subtitle, what's new                     │
│  ✅ Age rating questionnaire completed                                   │
│  ✅ Export compliance (uses encryption: YES for HTTPS)                   │
│  ✅ Content rights declaration                                           │
│  ✅ In-App Purchase config (if applicable)                               │
│  ✅ TestFlight beta distribution before release                          │
│                                                                          │
│  Google Play Store (Android):                                            │
│  ✅ Google Play Developer Account ($25 one-time)                        │
│  ✅ Play Console: create app, set package name, categories              │
│  ✅ Privacy policy URL (same as iOS)                                     │
│  ✅ App icon: 512x512 (Google Play listing)                             │
│  ✅ Feature graphic: 1024x500                                            │
│  ✅ Screenshots: phone (min 2) + tablet (if applicable)                 │
│  ✅ Store listing: short + full description                              │
│  ✅ Content rating (IARC questionnaire)                                  │
│  ✅ Data safety form (declare what data you collect)                     │
│  ✅ Target API level (latest Android SDK required)                      │
│  ✅ App signing: Google Play App Signing (upload key + signing key)     │
│  ✅ Internal testing track → Closed testing → Open testing → Production │
│                                                                          │
│  App Versioning:                                                         │
│  ✅ Semantic versioning: major.minor.patch (1.0.0)                      │
│  ✅ iOS: CFBundleShortVersionString + CFBundleVersion                   │
│  ✅ Android: versionName + versionCode (integer, must increment)        │
│  ✅ EAS Build autoIncrement for versionCode/buildNumber                 │
│                                                                          │
│  OTA Updates (Over-the-Air):                                             │
│  ✅ expo-updates for JS bundle updates without store review             │
│  ✅ EAS Update for channel-based updates (preview, production)          │
│  ✅ Critical bug fixes deployed in minutes (vs days for store review)   │
│  ✅ Fallback to embedded bundle if update fails                         │
│  ❌ NEVER use OTA for native code changes (requires new binary)         │
│                                                                          │
│  App Size Optimization:                                                  │
│  ✅ Target: <50MB download, <100MB installed                            │
│  ✅ ProGuard/R8 enabled for Android (shrink + obfuscate)                │
│  ✅ Asset optimization: compress images, remove unused assets           │
│  ✅ Hermes bytecode compilation (smaller + faster than JSC)             │
│  ✅ Lazy load non-critical screens and features                         │
└──────────────────────────────────────────────────────────────────────────┘
```

### Mobile CI/CD (EAS Pipeline)
```
┌──────────────────────────────────────────────────────────────────────────┐
│  MOBILE CI/CD — Build, Test, Deploy pipeline                             │
│                                                                          │
│  EAS Build (Cloud Builds):                                               │
│  ✅ eas build --platform ios --profile production                       │
│  ✅ eas build --platform android --profile production                   │
│  ✅ Development builds for testing (dev client, not Expo Go)            │
│  ✅ Preview builds for QA team (internal distribution)                  │
│  ✅ Production builds for store submission                               │
│                                                                          │
│  EAS Submit (Auto-Submit to Stores):                                    │
│  ✅ eas submit --platform ios (to App Store Connect / TestFlight)       │
│  ✅ eas submit --platform android (to Google Play internal track)       │
│  ✅ Configure in eas.json submit profiles                               │
│                                                                          │
│  EAS Update (OTA Updates):                                               │
│  ✅ eas update --branch production --message "fix: [description]"      │
│  ✅ Channel-based: updates only go to matching runtime version          │
│  ✅ Rollback capability if update causes issues                         │
│                                                                          │
│  Code Signing:                                                           │
│  ✅ iOS: Apple provisioning profiles + certificates (EAS manages)       │
│  ✅ Android: Upload keystore (EAS generates or use custom)              │
│  ✅ Credentials stored securely in EAS (never in git)                   │
│  ❌ NEVER commit .p12, .keystore, or provisioning profiles to git       │
│                                                                          │
│  Beta Distribution:                                                      │
│  ✅ iOS: TestFlight (via EAS Submit)                                    │
│  ✅ Android: Firebase App Distribution or Play internal testing         │
│  ✅ Share preview builds with QA via EAS internal distribution          │
│                                                                          │
│  GitHub Actions for Mobile:                                              │
│  ├── on push to main: eas update (OTA for JS changes)                  │
│  ├── on release tag: eas build + eas submit (new binary)               │
│  ├── on PR: run Jest tests + lint + type check                          │
│  └── Secrets: EXPO_TOKEN in GitHub Actions secrets                      │
└──────────────────────────────────────────────────────────────────────────┘
```

### Multiple Theme / Appearance Support (MANDATORY)
```
┌──────────────────────────────────────────────────────────────────────────┐
│  MULTI-THEME SYSTEM — Every product MUST support multiple themes        │
│                                                                          │
│  REQUIRED THEMES (minimum):                                              │
│  ├── Light Mode (default for new users)                                  │
│  ├── Dark Mode (true dark, not just gray)                               │
│  ├── System/Auto (follow OS preference — prefers-color-scheme)          │
│  └── [Optional] Custom brand themes (e.g., midnight, ocean, sunset)     │
│                                                                          │
│  WEB (Next.js):                                                          │
│  ├── Library: next-themes (handles SSR, flash prevention, localStorage) │
│  ├── Tailwind: dark: variant (class-based dark mode)                    │
│  ├── Theme toggle: in navbar/settings (sun/moon/system icons)           │
│  ├── CSS variables for theme-aware custom colors                        │
│  ├── Brand colors adapt: primary stays, backgrounds/surfaces change     │
│  └── Charts, images, code blocks — all theme-aware                     │
│                                                                          │
│  MOBILE (React Native):                                                  │
│  ├── Library: useColorScheme() + custom ThemeProvider                   │
│  ├── NativeWind dark: variant OR theme-aware StyleSheet                 │
│  ├── Theme toggle: in Settings screen + follow system default           │
│  ├── Status bar, navigation bar — adapt to current theme               │
│  └── Splash screen — neutral color that works for all themes           │
│                                                                          │
│  IMPLEMENTATION:                                                         │
│  ├── Theme context provider wrapping entire app                         │
│  ├── Design tokens defined per theme (colors, shadows, borders)         │
│  ├── User preference persisted (DB for logged-in, localStorage guest)   │
│  ├── Smooth theme transition (no flash, no layout shift)                │
│  └── All components use theme tokens, NEVER hardcoded colors           │
│                                                                          │
│  ✅ Minimum 3 themes: Light + Dark + System Auto                       │
│  ✅ Theme preference saved per user (syncs across devices)              │
│  ✅ Tailwind dark: classes on ALL styled elements                       │
│  ✅ Images/illustrations have light AND dark variants                   │
│  ✅ Charts adapt colors for readability in both themes                  │
│  ✅ Email templates: light background (emails don't support dark mode)  │
│                                                                          │
│  ❌ NEVER ship without dark mode                                        │
│  ❌ NEVER hardcode colors — always use theme tokens/CSS variables       │
│  ❌ NEVER have white flash on dark mode page load                       │
│  ❌ NEVER forget to theme: modals, dropdowns, tooltips, popovers       │
│  ❌ NEVER ignore code blocks / syntax highlighting in dark mode         │
└──────────────────────────────────────────────────────────────────────────┘
```

### UI/UX Quality Standards (ENFORCED)
```
┌──────────────────────────────────────────────────────────────────────────┐
│  UI/UX QUALITY RULES — Build an UNMATCHABLE product                     │
│                                                                          │
│  ✅ Research competitor UIs during Phase -1 (WebFetch landing pages)    │
│  ✅ Multiple theme support (Light + Dark + System — minimum)           │
│  ✅ Mobile responsive (every page must work on 320px to 2560px)        │
│  ✅ Loading skeletons (never show blank loading screens)                │
│  ✅ Smooth animations (page transitions, hover effects, micro-interactions)│
│  ✅ Consistent design tokens (colors, spacing, typography, shadows)     │
│  ✅ Accessible (WCAG 2.1 AA — keyboard nav, screen readers, contrast)  │
│  ✅ Empty states with helpful illustrations/CTAs                        │
│  ✅ Error states with clear recovery actions                            │
│  ✅ Toast notifications for all user actions                            │
│  ✅ Optimistic UI updates (instant feedback, sync in background)        │
│  ✅ Keyboard shortcuts for power users (Cmd+K command palette)         │
│  ✅ Progressive disclosure (don't overwhelm, reveal complexity)        │
│  ✅ Consistent iconography (single icon library, not mixed)            │
│  ✅ Typography hierarchy (clear h1-h6, body, caption, mono)            │
│  ✅ Proper spacing system (4px/8px grid, consistent padding/margins)   │
│                                                                          │
│  ❌ NEVER ship without multi-theme support (Light + Dark + System)      │
│  ❌ NEVER use browser default form styles (always custom styled)        │
│  ❌ NEVER show raw error messages to users (user-friendly messages)     │
│  ❌ NEVER use `alert()` or `confirm()` (use proper modals/toasts)      │
│  ❌ NEVER leave empty states unstyled                                   │
│  ❌ NEVER mix icon libraries (pick one and stick with it)               │
│  ❌ NEVER ship without mobile responsiveness                            │
│  ❌ NEVER use inline styles when Tailwind classes exist                 │
└──────────────────────────────────────────────────────────────────────────┘
```

---

### GenAI / Agentic AI Features (if PRD includes AI capabilities)

When the PRD includes ANY AI-powered features (chatbot, AI assistant, content generation, AI search, recommendations, autonomous agents, workflows), use this **modern GenAI stack**:

```
╔══════════════════════════════════════════════════════════════════════════╗
║  GENAI / AGENTIC AI STACK — 2026 Modern Standards                       ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║  LLM Gateway (REQUIRED — never hardcode a single provider):             ║
║  ✅ LiteLLM v1.81+ — unified gateway to 100+ LLMs                      ║
║  ✅ Supports: OpenAI, Anthropic Claude, Google Gemini, Mistral,         ║
║     Cohere, AWS Bedrock, Azure OpenAI, Groq, Together, Ollama (local)   ║
║  ✅ Cost tracking per user (integrates with credit point system)        ║
║  ✅ Fallback chains: primary model → fallback model → budget model      ║
║  ✅ Load balancing across multiple API keys                              ║
║  ✅ Guardrails + content filtering                                       ║
║  ❌ NEVER hardcode OpenAI/Anthropic SDK directly — use LiteLLM          ║
║  ❌ NEVER expose API keys to frontend                                    ║
║  ❌ NEVER skip cost tracking (each LLM call = point deduction)          ║
║                                                                          ║
║  Agentic Frameworks (pick based on use case):                            ║
║  ✅ Google ADK v0.5+ — multi-agent, tool use, Gemini-optimized          ║
║     → Best for: Google ecosystem, Vertex AI deployment, agent teams      ║
║  ✅ LangGraph — graph-based stateful multi-agent orchestration           ║
║     → Best for: complex workflows, cyclic graphs, conditional branching  ║
║  ✅ CrewAI v0.152+ — role-based collaborative multi-agent                ║
║     → Best for: team-like agent collaboration, role assignment           ║
║  ✅ Anthropic Claude Agent SDK — Claude agents with MCP tools            ║
║     → Best for: Claude-powered agents, computer use, MCP integrations   ║
║  ✅ OpenAI Agents SDK — OpenAI agent framework (evolved from Swarm)     ║
║     → Best for: GPT-powered agents, OpenAI tool ecosystem              ║
║                                                                          ║
║  Agent Protocols & Standards (Open Standards):                            ║
║  ✅ MCP (Model Context Protocol) — agent-to-tool communication           ║
║     → Linux Foundation standard, Anthropic + OpenAI + Google adopted    ║
║     → Expose tools, resources, and reusable prompts via MCP servers     ║
║     → JSON-RPC 2.0 transport (stdio or SSE)                             ║
║  ✅ A2A (Agent-to-Agent Protocol) — inter-agent communication            ║
║     → Linux Foundation standard, 150+ organizations adopted             ║
║     → Agent Cards for discovery (/.well-known/agent.json)               ║
║     → Skills declaration, task lifecycle, multi-turn conversations      ║
║  ✅ Agent Skills Standard — reusable SKILL.md packaging                  ║
║     → Open standard adopted by Claude, Copilot, Cursor, Codex, Kiro    ║
║  ✅ Custom @tool decorators for function calling                         ║
║                                                                          ║
║  RAG (Retrieval-Augmented Generation) — Agentic RAG:                     ║
║  ✅ Vector DB: Qdrant (self-hosted) or Pinecone (managed)               ║
║  ✅ Embeddings: text-embedding-3-large (OpenAI) or Gemini embedding     ║
║  ✅ Document loaders: PDF, DOCX, CSV, HTML, Markdown                    ║
║  ✅ Chunking: semantic chunking with overlap                             ║
║  ✅ Hybrid search: vector similarity + keyword (BM25)                    ║
║  ✅ Agentic RAG: retrieval agent dynamically decides:                    ║
║     → Which knowledge base(s) to query                                   ║
║     → Whether to do web search for fresh data                            ║
║     → Whether to decompose complex queries into sub-queries              ║
║     → Whether retrieved context is sufficient or needs more retrieval    ║
║  ✅ Re-ranking: Cohere Rerank / FlashRank after retrieval                ║
║  ✅ Query decomposition: break complex questions into sub-queries        ║
║  ✅ Routing: agent routes to best retrieval strategy per query           ║
║  ❌ NEVER use naive fixed-size chunking                                  ║
║  ❌ NEVER skip embedding caching (expensive to recompute)               ║
║  ❌ NEVER use single-shot retrieval for complex queries (use agentic)   ║
║                                                                          ║
║  Prompt Management (Open Standard):                                      ║
║  ✅ Prompt templates in separate files (Jinja2/YAML, not hardcoded)     ║
║  ✅ MCP Prompt Server — expose reusable prompts via MCP protocol        ║
║     → Clients discover prompts via prompts/list, retrieve via prompts/get║
║     → Supports arguments, templating, embedded resources                ║
║  ✅ Version-controlled prompts (prompt registry)                         ║
║  ✅ System prompt + user prompt separation                               ║
║  ✅ Few-shot examples stored in DB/files                                 ║
║  ❌ NEVER hardcode prompts as string literals in service code            ║
║                                                                          ║
║  Streaming & UX:                                                         ║
║  ✅ Server-Sent Events (SSE) for LLM streaming responses                ║
║  ✅ Token-by-token streaming to frontend                                 ║
║  ✅ Typing indicator while AI generates                                  ║
║  ✅ Stop generation button                                               ║
║  ✅ Markdown rendering for AI responses                                  ║
║  ❌ NEVER wait for full response before showing (always stream)          ║
║                                                                          ║
║  AI Safety & Guardrails:                                                 ║
║  ✅ Input validation (max tokens, content filtering)                     ║
║  ✅ Output filtering (PII detection, harmful content blocking)           ║
║  ✅ Rate limiting per user on AI endpoints                               ║
║  ✅ Cost caps per user (prevent runaway spend)                           ║
║  ✅ Audit log every AI interaction (MongoDB)                             ║
║  ❌ NEVER allow unbounded AI calls without cost limits                   ║
║  ❌ NEVER expose raw model errors to users                               ║
║                                                                          ║
║  Observability:                                                          ║
║  ✅ LangSmith or Langfuse for LLM tracing                               ║
║  ✅ Token usage tracking per request                                     ║
║  ✅ Latency monitoring per model                                         ║
║  ✅ Cost dashboard (daily/weekly/monthly spend)                          ║
║  ✅ Model performance comparison (A/B testing)                           ║
║                                                                          ║
║  AI Evaluation & Testing:                                                ║
║  ✅ DeepEval for LLM unit tests (pytest-compatible)                     ║
║  ✅ RAGAS for RAG quality metrics (faithfulness, relevancy, recall)     ║
║  ✅ promptfoo for prompt A/B testing (YAML config)                      ║
║  ✅ CI/CD integration: run AI evals on every PR                         ║
║  ✅ Regression tests for prompt changes                                  ║
║  ❌ NEVER ship AI features without evaluation metrics                    ║
║  ❌ NEVER change prompts without regression testing                      ║
║                                                                          ║
║  Structured Output:                                                      ║
║  ✅ Pydantic models for LLM response validation                         ║
║  ✅ instructor library for structured extraction                        ║
║  ✅ response_format={"type": "json_object"} when available              ║
║  ✅ Fallback: parse + retry on validation failure                        ║
║  ❌ NEVER trust raw LLM text output for structured data                  ║
║  ❌ NEVER skip validation on function calling results                    ║
║                                                                          ║
║  Semantic Caching:                                                       ║
║  ✅ Redis + embedding similarity for repeated queries                   ║
║  ✅ Cache threshold: cosine similarity > 0.95 = cache hit               ║
║  ✅ TTL-based cache expiry (configurable per use case)                  ║
║  ✅ Cache bypass for user-specific or time-sensitive queries            ║
║  ❌ NEVER cache without embedding similarity (exact match fails)         ║
║                                                                          ║
║  AI Chat Frontend Components:                                            ║
║  ✅ Chat message bubbles (user/assistant/system)                        ║
║  ✅ Markdown + syntax highlighting for code blocks                      ║
║  ✅ Typing indicator with animated dots                                  ║
║  ✅ Stop generation button (AbortController)                            ║
║  ✅ Copy/regenerate/feedback buttons per message                        ║
║  ✅ File upload drop zone for RAG                                       ║
║  ✅ Model/persona selector in chat header                               ║
║  ✅ Chat history sidebar with search                                     ║
║  ❌ NEVER render raw AI text (always parse markdown)                     ║
║                                                                          ║
║  Re-ranking (RAG Quality Boost):                                         ║
║  ✅ Cohere Rerank or FlashRank after vector retrieval                   ║
║  ✅ Cross-encoder re-ranking for top-k refinement                       ║
║  ✅ Pipeline: retrieve(top_k=20) → rerank(top_n=5) → generate          ║
║  ❌ NEVER pass raw vector results to LLM without re-ranking             ║
║                                                                          ║
║  Multi-Modal AI:                                                         ║
║  ✅ Vision: image understanding via LiteLLM (GPT-4o, Gemini, Claude)   ║
║  ✅ Image generation: DALL-E 3 / Flux via LiteLLM                      ║
║  ✅ Audio transcription: Whisper via LiteLLM                            ║
║  ✅ Text-to-Speech: OpenAI TTS / Gemini TTS / ElevenLabs               ║
║  ✅ All modalities go through LiteLLM gateway (unified billing)        ║
║  ❌ NEVER call modal APIs directly (use LiteLLM)                        ║
║                                                                          ║
║  Human-in-the-Loop (HITL):                                               ║
║  ✅ Review queue for AI-generated content before publishing             ║
║  ✅ Approve/reject/edit workflow with audit trail                       ║
║  ✅ Feedback collection (thumbs up/down + free text)                    ║
║  ✅ Feedback → fine-tuning data pipeline                                ║
║  ✅ Confidence threshold: auto-publish above, review below              ║
║  ❌ NEVER auto-publish critical AI actions without human review          ║
║                                                                          ║
║  Context Window Management:                                              ║
║  ✅ Token counting before every LLM call (tiktoken)                     ║
║  ✅ Auto-summarization when conversation exceeds threshold              ║
║  ✅ Sliding window: keep last N messages + summary of older             ║
║  ✅ Smart truncation: prioritize system prompt + recent context         ║
║  ❌ NEVER send more tokens than model limit                              ║
║                                                                          ║
║  Voice AI:                                                               ║
║  ✅ Speech-to-Text: Whisper (via LiteLLM or direct)                    ║
║  ✅ Text-to-Speech: OpenAI TTS-1 / ElevenLabs                          ║
║  ✅ Real-time voice: WebSocket audio streaming                          ║
║  ✅ Voice input button in chat UI (mobile + web)                        ║
║  ❌ NEVER process audio synchronously (stream or background job)         ║
║                                                                          ║
║  Batch AI Processing:                                                    ║
║  ✅ Celery tasks for bulk AI operations (batch embed, batch classify)   ║
║  ✅ Progress tracking via Redis (percent complete, ETA)                 ║
║  ✅ Webhook/SSE notification on batch completion                        ║
║  ✅ Rate-limited batch processing (respect provider limits)             ║
║  ❌ NEVER block API for batch operations (always background)             ║
╚══════════════════════════════════════════════════════════════════════════╝
```

#### GenAI Backend Architecture

```
app/
├── ai/                              # All GenAI code lives here
│   ├── config.py                    # LiteLLM config, model registry, fallback chains
│   ├── gateway.py                   # LiteLLM gateway wrapper (unified LLM access)
│   ├── prompts/                     # Prompt templates (Jinja2 or YAML)
│   │   ├── system/                  # System prompts per agent role
│   │   └── user/                    # User prompt templates
│   ├── agents/                      # Agentic AI agents
│   │   ├── base_agent.py           # Base agent class (tool use, memory, state)
│   │   ├── chat_agent.py           # Conversational AI assistant
│   │   ├── research_agent.py       # Web research + RAG agent
│   │   ├── workflow_agent.py       # Multi-step task automation agent
│   │   └── tools/                   # Custom tools for agents
│   │       ├── search_tool.py      # Web search via SerpAPI/Tavily
│   │       ├── db_tool.py          # Database query tool
│   │       ├── api_tool.py         # External API calling tool
│   │       └── file_tool.py        # File processing tool
│   ├── rag/                         # RAG pipeline
│   │   ├── embeddings.py           # Embedding generation (LiteLLM embeddings)
│   │   ├── vector_store.py         # Qdrant/Pinecone vector store client
│   │   ├── chunker.py              # Document chunking (semantic)
│   │   ├── retriever.py            # Hybrid retrieval (vector + keyword)
│   │   └── loaders/                # Document loaders
│   │       ├── pdf_loader.py
│   │       ├── docx_loader.py
│   │       └── web_loader.py
│   ├── memory/                      # Agent memory
│   │   ├── conversation.py         # Chat history (MongoDB)
│   │   ├── long_term.py            # Long-term memory (vector DB)
│   │   └── session.py              # Session state (Redis)
│   ├── mcp/                         # MCP Protocol (agent-to-tool)
│   │   ├── server.py               # MCP server setup (tools + prompts + resources)
│   │   ├── prompt_server.py        # Reusable prompt templates via MCP
│   │   └── tool_server.py          # Custom tools exposed via MCP
│   ├── a2a/                         # A2A Protocol (agent-to-agent)
│   │   ├── agent_card.py           # Agent Card (/.well-known/agent.json)
│   │   ├── task_handler.py         # A2A task lifecycle handler
│   │   └── client.py               # A2A client for calling remote agents
│   ├── eval/                        # AI Evaluation & Testing
│   │   ├── deepeval_tests.py       # LLM unit tests (DeepEval + pytest)
│   │   ├── ragas_eval.py           # RAG quality metrics (RAGAS)
│   │   └── promptfoo_config.yaml   # Prompt A/B testing config
│   ├── structured/                  # Structured Output
│   │   ├── extractor.py            # Pydantic-based LLM output extraction (instructor)
│   │   └── validators.py           # Response validation + retry logic
│   ├── cache/                       # Semantic Caching
│   │   └── semantic_cache.py       # Redis + embedding similarity cache
│   ├── reranker/                    # Re-ranking
│   │   └── reranker.py             # Cohere Rerank / FlashRank integration
│   ├── multimodal/                  # Multi-Modal AI
│   │   ├── vision.py               # Image understanding (GPT-4o, Gemini, Claude)
│   │   ├── image_gen.py            # Image generation (DALL-E 3 / Flux)
│   │   └── audio.py                # STT (Whisper) + TTS (OpenAI/ElevenLabs)
│   ├── hitl/                        # Human-in-the-Loop
│   │   ├── review_queue.py         # AI content review queue
│   │   └── feedback.py             # User feedback collection + export
│   ├── context/                     # Context Window Management
│   │   ├── token_counter.py        # tiktoken token counting
│   │   └── summarizer.py           # Auto-summarization for long conversations
│   ├── voice/                       # Voice AI
│   │   ├── stt.py                  # Speech-to-Text (Whisper)
│   │   └── tts.py                  # Text-to-Speech (OpenAI TTS / ElevenLabs)
│   ├── batch/                       # Batch AI Processing
│   │   └── batch_processor.py      # Celery-based bulk AI ops + progress tracking
│   └── guardrails/                  # Safety + filtering
│       ├── input_filter.py         # Input validation + content filter
│       ├── output_filter.py        # Output PII/harmful content filter
│       └── cost_limiter.py         # Per-user cost caps
```

#### GenAI API Endpoints

```
### AI (/api/v1/ai)
| Method | Path              | Auth | Points | Description |
|--------|-------------------|------|--------|-------------|
| POST   | /chat             | Yes  | 5-20   | Chat with AI (streaming SSE) |
| POST   | /chat/sessions    | Yes  | 0      | Create new chat session |
| GET    | /chat/sessions    | Yes  | 0      | List chat sessions |
| GET    | /chat/sessions/:id| Yes  | 0      | Get chat history |
| DELETE | /chat/sessions/:id| Yes  | 0      | Delete chat session |
| POST   | /generate         | Yes  | 10-50  | Generate content (text, code, etc.) |
| POST   | /summarize        | Yes  | 5-15   | Summarize text/document |
| POST   | /analyze          | Yes  | 10-30  | Analyze data/document |
| POST   | /rag/upload       | Yes  | 5      | Upload document for RAG |
| POST   | /rag/query        | Yes  | 8-20   | Query RAG knowledge base |
| GET    | /rag/documents    | Yes  | 0      | List uploaded RAG documents |
| DELETE | /rag/documents/:id| Yes  | 0      | Delete RAG document |
| POST   | /agent/run        | Yes  | 20-100 | Run agentic workflow |
| GET    | /agent/status/:id | Yes  | 0      | Check agent task status |
| POST   | /agent/stop/:id   | Yes  | 0      | Stop running agent |
| GET    | /usage/ai         | Yes  | 0      | AI usage stats (tokens, cost) |

### MCP Protocol (/api/v1/mcp)
| Method | Path              | Auth | Points | Description |
|--------|-------------------|------|--------|-------------|
| GET    | /prompts          | Yes  | 0      | List available MCP prompts |
| POST   | /prompts/:name    | Yes  | 0      | Get rendered prompt with arguments |
| GET    | /tools            | Yes  | 0      | List available MCP tools |
| POST   | /tools/:name      | Yes  | 5-50   | Execute MCP tool |
| GET    | /resources        | Yes  | 0      | List available MCP resources |

### A2A Protocol (/.well-known + /a2a)
| Method | Path                    | Auth  | Description |
|--------|-------------------------|-------|-------------|
| GET    | /.well-known/agent.json | No    | Agent Card discovery (A2A standard) |
| POST   | /a2a/tasks              | A2A   | Receive task from external agent |
| GET    | /a2a/tasks/:id          | A2A   | Get task status |
| POST   | /a2a/tasks/:id/cancel   | A2A   | Cancel running task |

### Multi-Modal (/api/v1/ai)
| Method | Path              | Auth | Points | Description |
|--------|-------------------|------|--------|-------------|
| POST   | /vision/analyze   | Yes  | 15-40  | Analyze image (describe, extract, OCR) |
| POST   | /image/generate   | Yes  | 20-50  | Generate image from text prompt |
| POST   | /audio/transcribe | Yes  | 10-30  | Speech-to-text (Whisper) |
| POST   | /audio/tts        | Yes  | 5-15   | Text-to-speech (stream audio) |

### Voice AI (/api/v1/ai/voice)
| Method | Path              | Auth | Points | Description |
|--------|-------------------|------|--------|-------------|
| WS     | /voice/stream     | Yes  | 10/min | Real-time voice chat (WebSocket) |
| POST   | /voice/transcribe | Yes  | 10-30  | Upload audio file for transcription |

### HITL Review (/api/v1/ai/review)
| Method | Path              | Auth | Points | Description |
|--------|-------------------|------|--------|-------------|
| GET    | /review/queue     | Yes  | 0      | List items pending human review |
| POST   | /review/:id/approve | Yes | 0     | Approve AI-generated content |
| POST   | /review/:id/reject  | Yes | 0     | Reject with feedback |
| POST   | /feedback         | Yes  | 0      | Submit user feedback on AI response |

### Batch Processing (/api/v1/ai/batch)
| Method | Path              | Auth | Points | Description |
|--------|-------------------|------|--------|-------------|
| POST   | /batch/embed      | Yes  | 5/doc  | Batch embed multiple documents |
| POST   | /batch/classify   | Yes  | 3/item | Batch classify/label items |
| GET    | /batch/:id/status | Yes  | 0      | Check batch job progress |
| POST   | /batch/:id/cancel | Yes  | 0      | Cancel running batch job |
```

#### GenAI Pattern — LiteLLM Gateway

```python
# ✅ CORRECT: Use LiteLLM as unified gateway
# app/ai/gateway.py
import litellm
from app.config import settings

litellm.set_verbose = False

MODEL_REGISTRY = {
    "fast": "gpt-4o-mini",              # Quick, cheap tasks
    "smart": "claude-sonnet-4-6",        # Complex reasoning
    "premium": "claude-opus-4-6",        # Highest quality
    "gemini": "gemini/gemini-2.5-pro",   # Google ecosystem
    "local": "ollama/llama3.2",          # Local/private data
}

FALLBACK_CHAIN = ["claude-sonnet-4-6", "gpt-4o", "gemini/gemini-2.5-pro"]

async def generate(
    prompt: str,
    model_tier: str = "smart",
    stream: bool = True,
    max_tokens: int = 4096,
    user_id: str = None,
) -> AsyncGenerator:
    model = MODEL_REGISTRY.get(model_tier, MODEL_REGISTRY["smart"])
    response = await litellm.acompletion(
        model=model,
        messages=[{"role": "user", "content": prompt}],
        max_tokens=max_tokens,
        stream=stream,
        fallbacks=FALLBACK_CHAIN,
        metadata={"user_id": user_id},  # Cost tracking
    )
    return response

# ❌ WRONG: Direct SDK usage (locked to one provider)
import openai
client = openai.OpenAI(api_key=settings.OPENAI_API_KEY)  # NO! Use LiteLLM
```

#### GenAI Pattern — Google ADK Multi-Agent

```python
# ✅ CORRECT: Google ADK with LiteLLM for model flexibility
# app/ai/agents/research_agent.py
from google.adk.agents import Agent
from google.adk.tools import FunctionTool
from google.adk.models import LiteLlm

research_agent = Agent(
    name="research_agent",
    model=LiteLlm(model="claude-sonnet-4-6"),  # Any model via LiteLLM
    instruction="You are a research assistant. Search the web and analyze data.",
    tools=[
        FunctionTool(search_web),
        FunctionTool(query_database),
        FunctionTool(analyze_document),
    ],
)

# Multi-agent team
from google.adk.agents import Agent

coordinator = Agent(
    name="coordinator",
    model=LiteLlm(model="claude-sonnet-4-6"),
    instruction="Coordinate research and writing tasks.",
    sub_agents=[research_agent, writer_agent, fact_checker_agent],
)
```

#### GenAI Pattern — RAG Pipeline

```python
# ✅ CORRECT: RAG with vector search + hybrid retrieval
# app/ai/rag/retriever.py
from qdrant_client import QdrantClient
import litellm

async def embed_text(text: str) -> list[float]:
    response = await litellm.aembedding(
        model="text-embedding-3-large",
        input=text,
    )
    return response.data[0]["embedding"]

async def retrieve(query: str, top_k: int = 5) -> list[dict]:
    query_embedding = await embed_text(query)
    results = qdrant_client.search(
        collection_name="documents",
        query_vector=query_embedding,
        limit=top_k,
    )
    return [{"text": r.payload["text"], "score": r.score} for r in results]

# ❌ WRONG: Stuffing entire documents into context (token waste)
async def bad_rag(query: str):
    all_docs = load_all_documents()  # NO! Use vector search
    return await litellm.acompletion(
        model="gpt-4o",
        messages=[{"role": "user", "content": f"{all_docs}\n\n{query}"}],
    )
```

#### GenAI Pattern — Streaming SSE Endpoint

```python
# ✅ CORRECT: SSE streaming for AI responses
# app/api/v1/ai.py
from fastapi.responses import StreamingResponse

@router.post("/chat")
async def chat(
    req: ChatRequest,
    user: User = Depends(get_current_user),
    _points: None = Depends(require_points(cost=10)),
):
    async def stream_response():
        response = await ai_gateway.generate(
            prompt=req.message,
            model_tier=req.model_tier or "smart",
            stream=True,
            user_id=str(user.id),
        )
        async for chunk in response:
            content = chunk.choices[0].delta.content or ""
            if content:
                yield f"data: {json.dumps({'content': content})}\n\n"
        yield "data: [DONE]\n\n"

    return StreamingResponse(
        stream_response(),
        media_type="text/event-stream",
    )

# ❌ WRONG: Waiting for full response
@router.post("/chat")
async def chat(req: ChatRequest):
    response = await litellm.acompletion(...)  # Blocks until complete
    return {"response": response.choices[0].message.content}  # NO! Stream it
```

#### GenAI Pattern — MCP Prompt Server (Open Standard)

```python
# ✅ CORRECT: Expose reusable prompts via MCP protocol
# app/ai/mcp/prompt_server.py
from mcp.server import Server
from mcp.types import Prompt, PromptArgument, PromptMessage, TextContent

server = Server("alpha-ai-prompts")

@server.list_prompts()
async def list_prompts() -> list[Prompt]:
    return [
        Prompt(
            name="code_review",
            title="Review Code",
            description="Analyze code quality and suggest improvements",
            arguments=[
                PromptArgument(name="code", description="Code to review", required=True),
                PromptArgument(name="language", description="Programming language", required=False),
            ],
        ),
        Prompt(
            name="summarize_document",
            title="Summarize Document",
            description="Generate concise summary of a document",
            arguments=[
                PromptArgument(name="content", description="Document content", required=True),
            ],
        ),
    ]

@server.get_prompt()
async def get_prompt(name: str, arguments: dict) -> list[PromptMessage]:
    template = await load_prompt_template(name)  # Load from app/ai/prompts/
    rendered = template.render(**arguments)
    return [PromptMessage(role="user", content=TextContent(type="text", text=rendered))]

# ❌ WRONG: Hardcoded prompts in service code
prompt = f"Review this code: {code}"  # NO! Use MCP prompt server
```

#### GenAI Pattern — A2A Agent Card (Open Standard)

```python
# ✅ CORRECT: Expose agent capabilities via A2A Agent Card
# app/ai/a2a/agent_card.py
AGENT_CARD = {
    "name": "alpha-ai-assistant",
    "description": "Alpha AI assistant with RAG, code generation, and analysis capabilities",
    "url": f"{settings.BACKEND_URL}/a2a",
    "version": "1.0.0",
    "capabilities": {
        "streaming": True,
        "pushNotifications": False,
    },
    "skills": [
        {
            "id": "document-analysis",
            "name": "Document Analysis",
            "description": "Analyze and extract insights from uploaded documents using RAG",
            "tags": ["rag", "analysis", "documents"],
        },
        {
            "id": "code-generation",
            "name": "Code Generation",
            "description": "Generate code based on natural language descriptions",
            "tags": ["code", "generation", "development"],
        },
    ],
    "authentication": {
        "schemes": ["bearer"],
    },
}

# Discovery endpoint — A2A standard
@router.get("/.well-known/agent.json")
async def get_agent_card():
    """A2A Agent Card discovery endpoint (open standard)."""
    return AGENT_CARD

# A2A task handler — process incoming tasks from other agents
@router.post("/a2a/tasks")
async def handle_a2a_task(task: A2ATaskRequest, auth: str = Depends(verify_a2a_auth)):
    """Handle A2A task requests from external agents."""
    result = await a2a_task_handler.process(task)
    return {"taskId": result.id, "status": result.status, "result": result.output}
```

#### GenAI MongoDB Documents

```
Document: AIConversation
| Field       | Type       | Description |
|-------------|------------|-------------|
| user_id     | UUID       | Chat owner |
| session_id  | str        | Conversation session ID |
| messages    | list[dict] | [{role, content, timestamp, tokens, model}] |
| model_used  | str        | Primary model used |
| total_tokens| int        | Total tokens consumed |
| total_cost  | float      | Estimated cost in USD |
| created_at  | datetime   | Session start |
| updated_at  | datetime   | Last message |

Document: RAGDocument
| Field       | Type       | Description |
|-------------|------------|-------------|
| user_id     | UUID       | Document owner |
| filename    | str        | Original filename |
| file_type   | str        | pdf/docx/csv/html |
| chunk_count | int        | Number of chunks |
| embedding_model | str    | Model used for embeddings |
| vector_ids  | list[str]  | IDs in vector DB |
| status      | str        | processing/ready/failed |
| created_at  | datetime   | Upload timestamp |

Document: AgentRun
| Field       | Type       | Description |
|-------------|------------|-------------|
| user_id     | UUID       | Who triggered the agent |
| agent_type  | str        | research/workflow/analysis |
| input       | dict       | Agent input parameters |
| steps       | list[dict] | [{tool, input, output, duration}] |
| result      | dict       | Final agent output |
| tokens_used | int        | Total tokens across all steps |
| cost        | float      | Total cost |
| status      | str        | running/completed/failed/stopped |
| started_at  | datetime   | Run start |
| completed_at| datetime   | Run end |
```

---

## 🏗️ ENFORCED PROJECT STRUCTURE (Properly Segregated Layers)

```
project_root/
│
├── app/                            # Main application package
│   ├── __init__.py
│   ├── main.py                     # FastAPI app factory, lifespan events
│   ├── config.py                   # Settings via Pydantic BaseSettings (.env loading)
│   │
│   ├── api/                        # 🌐 API LAYER (Routes/Endpoints only)
│   │   ├── __init__.py
│   │   ├── deps.py                 # Dependency injection (get_db, get_current_user, etc.)
│   │   ├── middleware.py           # CORS, CSRF, rate limiting, logging middleware
│   │   └── v1/                     # API versioning
│   │       ├── __init__.py
│   │       ├── router.py           # Central router aggregating all endpoints
│   │       ├── auth.py             # POST /auth/login, /register, /refresh, /logout + GET /auth/google, /auth/google/callback
│   │       ├── users.py            # CRUD /users
│   │       ├── subscriptions.py    # POST /subscriptions/create, /cancel, GET /subscriptions/current, /plans
│   │       ├── points.py           # POST /points/topup, /points/verify, GET /points/balance, /points/usage
│   │       ├── invoices.py         # GET /invoices, GET /invoices/:id/download
│   │       ├── webhooks.py         # POST /webhooks/razorpay (no auth — signature verified)
│   │       ├── notifications.py   # GET /notifications, PATCH /read, GET /unread-count
│   │       ├── search.py          # GET /search?q=query&type=&filters=
│   │       ├── feedback.py        # POST /feedback (bug report, feature request, support)
│   │       ├── account.py         # GET /account/export, DELETE /account, PATCH /account/consent
│   │       ├── flags.py           # GET /flags (user's active feature flags)
│   │       ├── onboarding.py      # GET /onboarding/status, PATCH /onboarding/step/:step
│   │       ├── upload.py          # POST /upload/presigned-url, POST /upload/confirm
│   │       ├── ai.py              # POST /ai/chat (SSE), /ai/generate, /ai/rag/query, /ai/agent/run
│   │       └── [resource].py       # One file per resource
│   │
│   │   └── admin/                     # 🔐 ADMIN API (require_role(['admin', 'super_admin']))
│   │       ├── __init__.py
│   │       ├── users.py           # Admin user management (list, ban, impersonate)
│   │       ├── subscriptions.py   # Admin subscription management
│   │       ├── analytics.py       # Admin analytics dashboard data
│   │       ├── flags.py           # Admin feature flag CRUD
│   │       ├── feedback.py        # Admin feedback viewer
│   │       └── system.py          # Admin system health, logs, tasks
│   │
│   ├── services/                   # ⚙️ SERVICE LAYER (Business logic ONLY)
│   │   ├── __init__.py
│   │   ├── auth_service.py         # Login, register, token generation, password reset, Google OAuth, 2FA
│   │   ├── user_service.py         # User CRUD operations, profile management
│   │   ├── email_service.py        # Transactional email dispatch (welcome, OTP, alerts, invoices via Celery)
│   │   ├── storage_service.py      # File upload/download — S3/GCS abstraction (presigned URLs)
│   │   ├── search_service.py       # Full-text search via Meilisearch (index, search, sync)
│   │   ├── notification_service.py # In-app notification center (create, read, mark read, push)
│   │   ├── push_service.py         # Push notifications via FCM (mobile) + Web Push
│   │   ├── analytics_service.py    # Event tracking (PostHog or custom MongoDB)
│   │   ├── feature_flag_service.py # Feature flags: is_enabled(), rollout, per-plan
│   │   ├── admin_service.py        # Admin operations: user management, metrics, system health
│   │   ├── export_service.py       # GDPR data export: collect all user data → ZIP → email link
│   │   ├── subscription_service.py # Razorpay subscription lifecycle, plan upgrades/downgrades
│   │   ├── point_service.py        # Credit point balance, deduction, top-up, trial allocation
│   │   ├── invoice_service.py      # Invoice generation with GST calculation
│   │   ├── webhook_service.py      # Razorpay webhook processing (subscription + payment events)
│   │   └── [resource]_service.py   # One service per domain entity
│   │
│   ├── ai/                          # 🤖 GENAI / AGENTIC AI LAYER (if PRD has AI features)
│   │   ├── __init__.py
│   │   ├── config.py               # LiteLLM config, model registry, fallback chains
│   │   ├── gateway.py              # LiteLLM unified gateway (generate, embed, stream)
│   │   ├── prompts/                # Prompt templates (Jinja2/YAML — NOT hardcoded strings)
│   │   │   ├── system/             # System prompts per agent role
│   │   │   └── user/               # User prompt templates
│   │   ├── agents/                 # Agentic AI agents (ADK/LangGraph/CrewAI)
│   │   │   ├── base_agent.py      # Base agent: tool use, memory, state
│   │   │   ├── chat_agent.py      # Conversational AI assistant
│   │   │   ├── research_agent.py  # Web research + RAG agent
│   │   │   ├── workflow_agent.py  # Multi-step task automation
│   │   │   └── tools/              # Custom agent tools (@tool decorated)
│   │   │       ├── search_tool.py # Web search (SerpAPI/Tavily)
│   │   │       ├── db_tool.py     # Database query tool
│   │   │       └── api_tool.py    # External API tool
│   │   ├── rag/                    # RAG pipeline
│   │   │   ├── embeddings.py      # Embedding generation via LiteLLM
│   │   │   ├── vector_store.py    # Qdrant/Pinecone client
│   │   │   ├── chunker.py         # Semantic document chunking
│   │   │   ├── retriever.py       # Hybrid retrieval (vector + BM25)
│   │   │   └── loaders/            # Document loaders (PDF, DOCX, CSV, HTML)
│   │   ├── memory/                 # Agent memory (conversation + long-term)
│   │   │   ├── conversation.py    # Chat history (MongoDB)
│   │   │   ├── long_term.py       # Long-term memory (vector DB)
│   │   │   └── session.py         # Session state (Redis)
│   │   └── guardrails/             # AI safety (input/output filtering, cost caps)
│   │       ├── input_filter.py
│   │       ├── output_filter.py
│   │       └── cost_limiter.py
│   │
│   ├── models/                     # 📦 DATA MODEL LAYER
│   │   ├── __init__.py
│   │   ├── sql/                    # SQLAlchemy models (MySQL)
│   │   │   ├── __init__.py
│   │   │   ├── base.py             # DeclarativeBase, common mixins (TimestampMixin, SoftDeleteMixin)
│   │   │   ├── user.py             # User SQLAlchemy model
│   │   │   ├── subscription.py     # Razorpay subscription (sub_id, plan_id, cycle, point_allocation)
│   │   │   ├── credit_balance.py   # User credit points (plan_points, topup_points, total)
│   │   │   ├── point_transaction.py# Every credit/debit log (type, action, cost, balance_after)
│   │   │   ├── topup_order.py      # Razorpay top-up order (order_id, pack_id, amount_paisa, status)
│   │   │   ├── invoice.py          # Invoice with GST breakdown (subtotal, gst_amount, total)
│   │   │   ├── role.py             # Role + Permission models (RBAC)
│   │   │   ├── user_session.py    # Active sessions (device, IP, last_active)
│   │   │   ├── feature_flag.py    # Feature flags (name, enabled, rollout%, roles)
│   │   │   ├── device_token.py    # Push notification device tokens (FCM)
│   │   │   └── [entity].py
│   │   ├── nosql/                  # PyMongo document models
│   │   │   ├── __init__.py
│   │   │   ├── user_profile.py     # UserProfile PyMongo Document
│   │   │   ├── webhook_log.py     # Razorpay webhook raw payload audit trail
│   │   │   ├── notification.py    # In-app notifications (user_id, type, title, body, is_read)
│   │   │   ├── feedback.py        # User feedback/bug reports (type, message, screenshot)
│   │   │   ├── audit_log.py       # Audit trail (who did what, when, from where)
│   │   │   ├── email_log.py       # Email delivery log (status, template, error)
│   │   │   ├── onboarding.py      # User onboarding progress (steps, completed_at)
│   │   │   ├── consent.py         # GDPR/DPDPA consent tracking per user
│   │   │   └── [entity].py
│   │   └── cache/                  # Redis key schemas / cache models
│   │       ├── __init__.py
│   │       └── keys.py             # Redis key constants and builders
│   │
│   ├── schemas/                    # 📋 SCHEMA LAYER (Pydantic request/response models)
│   │   ├── __init__.py
│   │   ├── auth.py                 # LoginRequest, TokenResponse, RegisterRequest, GoogleAuthCallback
│   │   ├── user.py                 # UserCreate, UserUpdate, UserResponse, UserList
│   │   ├── common.py               # PaginationParams, SuccessResponse, ErrorResponse
│   │   ├── subscription.py        # CreateSubscriptionRequest, SubscriptionResponse, PlanResponse
│   │   ├── points.py              # PointBalanceResponse, TopupRequest, TopupVerifyRequest, UsageResponse
│   │   ├── invoice.py             # InvoiceResponse, InvoiceDownloadResponse
│   │   └── [resource].py
│   │
│   ├── repositories/               # 🗄️ REPOSITORY LAYER (Data access ONLY)
│   │   ├── __init__.py
│   │   ├── base.py                 # BaseRepository with generic CRUD
│   │   ├── sql/                    # MySQL repositories
│   │   │   ├── __init__.py
│   │   │   ├── user_repo.py
│   │   │   └── [entity]_repo.py
│   │   ├── nosql/                  # MongoDB repositories
│   │   │   ├── __init__.py
│   │   │   ├── user_profile_repo.py
│   │   │   └── [entity]_repo.py
│   │   └── cache/                  # Redis repositories
│   │       ├── __init__.py
│   │       ├── session_cache.py    # Token blacklist, rate limit counters
│   │       └── [entity]_cache.py
│   │
│   ├── core/                       # 🔧 CORE UTILITIES
│   │   ├── __init__.py
│   │   ├── security.py             # JWT creation/verification, password hashing, cookie helpers
│   │   ├── oauth.py               # Google OAuth2 client configuration (authlib)
│   │   ├── permissions.py         # RBAC: require_role(), require_permission() dependencies
│   │   ├── exceptions.py           # Custom exception classes + exception handlers
│   │   ├── logging_config.py       # Structured logging setup (JSON format) + request ID middleware
│   │   ├── sentry_config.py       # Sentry SDK initialization + FastAPI integration
│   │   ├── websocket_manager.py   # WebSocket connection manager with Redis pub/sub
│   │   ├── constants.py            # App-wide constants
│   │   ├── razorpay_client.py     # Razorpay SDK client init, signature verification helpers
│   │   ├── point_costs.py         # Action → point cost mapping (agent auto-generates)
│   │   ├── celery_app.py          # Celery configuration with Redis broker
│   │   └── utils.py                # Generic utility functions
│   │
│   ├── graphql/                     # 🔮 GRAPHQL LAYER (alongside REST)
│   │   ├── __init__.py
│   │   ├── schema.py               # Root Query + Mutation + Subscription schema
│   │   ├── context.py              # GraphQL context (auth, dataloaders)
│   │   ├── types/                   # Strawberry types (auto-generated from Pydantic schemas)
│   │   │   ├── __init__.py
│   │   │   ├── user_types.py
│   │   │   └── [resource]_types.py
│   │   ├── resolvers/              # Query resolvers
│   │   │   ├── __init__.py
│   │   │   ├── user_resolvers.py
│   │   │   └── [resource]_resolvers.py
│   │   ├── mutations/              # Mutation resolvers
│   │   │   ├── __init__.py
│   │   │   ├── auth_mutations.py
│   │   │   └── [resource]_mutations.py
│   │   └── dataloaders/            # DataLoaders to prevent N+1
│   │       ├── __init__.py
│   │       └── user_loader.py
│   │
│   ├── tasks/                       # 📬 CELERY TASK LAYER
│   │   ├── __init__.py
│   │   ├── email_tasks.py          # Email sending tasks (welcome, OTP, alerts, invoices, all transactional emails)
│   │   ├── report_tasks.py         # Report generation tasks
│   │   ├── payment_tasks.py        # Webhook processing, invoice generation, payment reconciliation
│   │   ├── push_tasks.py           # Push notification sending (FCM + Web Push)
│   │   ├── search_tasks.py         # Search index sync on create/update/delete
│   │   ├── analytics_tasks.py      # Event tracking dispatch + aggregation
│   │   ├── export_tasks.py         # GDPR data export (collect → ZIP → email download link)
│   │   ├── backup_tasks.py         # Database backup (MySQL dump + MongoDB dump → S3)
│   │   ├── cleanup_tasks.py        # Data cleanup: expired sessions, old logs, orphaned files
│   │   └── [domain]_tasks.py       # One task file per domain
│   │
│   ├── templates/                     # 📧 EMAIL TEMPLATES (Jinja2)
│   │   └── emails/
│   │       ├── base.html              # Base email layout (header, footer, branding)
│   │       ├── welcome.html           # Welcome email on registration
│   │       ├── verify_otp.html        # Email/OTP verification
│   │       ├── reset_otp.html         # Password reset OTP
│   │       ├── pwd_changed.html       # Password changed confirmation
│   │       ├── login_alert.html       # New device login alert
│   │       ├── sub_activated.html     # Subscription activated
│   │       ├── sub_renewed.html       # Subscription renewed
│   │       ├── sub_cancelled.html     # Subscription cancelled
│   │       ├── payment_receipt.html   # Payment receipt
│   │       ├── invoice.html           # Invoice with GST breakdown
│   │       ├── low_balance.html       # Low point balance warning
│   │       ├── points_exhausted.html  # Points exhausted alert
│   │       ├── topup_confirm.html     # Top-up purchase confirmation
│   │       ├── trial_expiring.html    # Trial expiring soon (2 days before)
│   │       ├── trial_expired.html     # Trial expired notification
│   │       ├── deactivated.html       # Account deactivated
│   │       └── weekly_summary.html    # Weekly usage summary
│   │
│   └── db/                         # 🔌 DATABASE CONNECTION LAYER
│       ├── __init__.py
│       ├── mysql.py                # AsyncEngine, async_session_maker, get_mysql_session
│       ├── mongodb.py              # PyMongo client, collection setup, get_mongo_db
│       └── redis.py                # Redis connection pool, get_redis
│
├── migrations/                     # Alembic migrations (MySQL only)
│   ├── env.py
│   ├── versions/
│   └── alembic.ini
│
├── tests/                          # 🧪 TEST LAYER (mirrors app/ structure)
│   ├── __init__.py
│   ├── conftest.py                 # Fixtures: test DB, test client, test user, mock redis
│   ├── unit/
│   │   ├── services/
│   │   └── core/
│   ├── integration/
│   │   ├── api/
│   │   └── repositories/
│   └── e2e/
│
├── scripts/                        # Utility scripts
│   ├── seed_db.py
│   ├── create_admin.py
│   └── health_check.py
│
├── docker/
│   ├── Dockerfile                  # Multi-stage Python build
│   ├── Dockerfile.dev              # Development with hot reload
│   └── docker-compose.yml          # App + MySQL + MongoDB + Redis + Meilisearch + MinIO + Celery + Flower + Qdrant (if AI) + Langfuse (if AI)
│
├── .env.example
├── .gitignore
├── .editorconfig
├── pyproject.toml                  # Ruff, mypy, pytest config
├── requirements.txt
├── requirements-dev.txt
├── alembic.ini
├── CLAUDE.md
├── README.md
└── Makefile
```

### LAYER DEPENDENCY RULES (STRICTLY ENFORCED)

```
┌──────────────────────────────────────────────────────────────┐
│                     LAYER DEPENDENCY RULES                    │
│                                                               │
│  api/ ──► services/ ──► repositories/ ──► models/ + db/      │
│   │           │  ▲             │                              │
│   │           │  │             └── schemas/ (for validation)  │
│   │           │  └── services/ (cross-service calls OK)      │
│   │           └── core/ (security, exceptions, utils)        │
│   └── deps.py (dependency injection)                         │
│                                                               │
│  ❌ api/ must NEVER import from repositories/ directly       │
│  ❌ services/ must NEVER import from api/                    │
│  ❌ repositories/ must NEVER import from services/           │
│  ❌ models/ must NEVER import from any upper layer           │
│  ❌ NO business logic in api/ layer (only route definitions) │
│  ❌ NO database queries in services/ (use repositories)      │
│  ❌ NO HTTP/request concepts in repositories/                │
│                                                               │
│  ✅ api/ → thin: validate input, call service, return output │
│  ✅ services/ → all business logic, orchestration, rules     │
│  ✅ services/ → CAN call other services (cross-domain logic) │
│  ✅ repositories/ → pure data access (CRUD), queries only    │
│  ✅ schemas/ → request/response shapes, validation rules     │
│  ✅ models/ → database entity definitions only               │
│  ✅ core/ → cross-cutting concerns (security, logging, etc.) │
└──────────────────────────────────────────────────────────────┘
```

---

## 🔐 AUTH IMPLEMENTATION (JWT + HTTP-Only Cookies)

### TOKEN STORAGE — HARD RULES
```
  ✅ HTTP-Only Cookies ONLY (server sets, browser sends automatically)
  ❌ NEVER localStorage
  ❌ NEVER sessionStorage
  ❌ NEVER in JavaScript-accessible memory/state for persistence
  ❌ NEVER in Authorization header from frontend
```

### Cookie Configuration (core/security.py):
```python
ACCESS_TOKEN_EXPIRE = timedelta(minutes=30)
REFRESH_TOKEN_EXPIRE = timedelta(days=7)

def set_auth_cookies(response: Response, access_token: str, refresh_token: str):
    response.set_cookie(
        key="access_token", value=access_token,
        httponly=True, secure=True, samesite="lax",
        max_age=int(ACCESS_TOKEN_EXPIRE.total_seconds()), path="/",
    )
    response.set_cookie(
        key="refresh_token", value=refresh_token,
        httponly=True, secure=True, samesite="lax",
        max_age=int(REFRESH_TOKEN_EXPIRE.total_seconds()),
        path="/api/v1/auth/refresh",
    )

def clear_auth_cookies(response: Response):
    response.delete_cookie("access_token", path="/")
    response.delete_cookie("refresh_token", path="/api/v1/auth/refresh")
```

### Token Extraction (api/deps.py):
```python
async def get_current_user(request: Request):
    token = request.cookies.get("access_token")
    if not token:
        raise HTTPException(status_code=401, detail="Not authenticated")
    payload = verify_token(token)
    return await user_service.get_by_id(payload["sub"])
```

### Login Pattern (api/v1/auth.py):
```python
@router.post("/login")
async def login(credentials: LoginRequest, response: Response):
    user = await auth_service.authenticate(credentials.email, credentials.password)
    access_token = create_access_token(user.id)
    refresh_token = create_refresh_token(user.id)
    await redis_cache.set_refresh_token(user.id, refresh_token)
    set_auth_cookies(response, access_token, refresh_token)
    return {"message": "Login successful", "user": UserResponse.model_validate(user)}
```

### CSRF Protection:
- Server sets `csrf_token` cookie (NOT httponly, so JS can read it)
- Frontend reads csrf_token from cookie, sends in X-CSRF-Token header
- Server middleware compares cookie value with header value on POST/PUT/DELETE

### Token Refresh Flow:
```
Client ──(auto cookie)──► POST /auth/refresh
  ├─ Read refresh_token from cookie
  ├─ Verify JWT + check Redis blacklist
  ├─ Generate new access_token + refresh_token (token rotation)
  ├─ Blacklist old refresh_token in Redis
  ├─ Set new cookies
  └─ Return 200
```

### Logout:
```
POST /auth/logout
  ├─ Read access_token + refresh_token from cookies
  ├─ Add both token JTIs to Redis blacklist (TTL = remaining expiry)
  ├─ Clear auth cookies
  └─ Return 200
```

### Google OAuth2 Flow (Social Login):
```
┌─────────────────────────────────────────────────────────────────────┐
│  GOOGLE OAUTH2 LOGIN FLOW (Authorization Code Grant)               │
│                                                                     │
│  1. User clicks "Sign in with Google" on frontend                  │
│  2. Frontend → GET /api/v1/auth/google                             │
│  3. Backend generates Google auth URL → 302 redirect to Google     │
│  4. User authenticates on Google consent screen                     │
│  5. Google → GET /api/v1/auth/google/callback?code=xxx&state=xxx   │
│  6. Backend exchanges code for Google tokens (server-side)          │
│  7. Backend fetches user info (email, name, picture) from Google   │
│  8. Backend checks: does user with this email exist in MySQL?      │
│     a. YES → Login: generate JWT, set cookies, redirect to app    │
│     b. NO → Register: create User + UserProfile, set cookies      │
│  9. Set auth_provider='google' on User model                      │
│  10. Redirect to frontend dashboard with cookies set               │
│                                                                     │
│  IMPORTANT:                                                         │
│  ✅ Same JWT cookie auth — Google login just creates/finds user    │
│  ✅ Google-verified emails are trusted (skip email verification)   │
│  ✅ Account linking: match by email across login methods           │
│  ✅ Free trial auto-credited on first Google login (same as reg)   │
│  ❌ NEVER store Google access/refresh tokens                       │
│  ❌ NEVER use Google JS SDK popup (use server redirect flow)       │
│  ❌ NEVER let Google bypass auth — always issue OUR JWT cookies    │
└─────────────────────────────────────────────────────────────────────┘
```

### Google OAuth2 Implementation:
```python
# app/api/v1/auth.py — Google OAuth routes
@router.get("/google")
async def google_login(request: Request):
    """Redirect user to Google consent screen."""
    redirect_uri = settings.GOOGLE_REDIRECT_URI
    return await oauth.google.authorize_redirect(request, redirect_uri)

@router.get("/google/callback")
async def google_callback(request: Request, response: Response):
    """Handle Google OAuth callback, create/login user, set JWT cookies."""
    token = await oauth.google.authorize_access_token(request)
    user_info = token.get("userinfo")
    if not user_info or not user_info.get("email"):
        raise HTTPException(400, "Failed to get user info from Google")

    # Find or create user
    user = await auth_service.google_login_or_register(
        email=user_info["email"],
        name=user_info.get("name", ""),
        picture=user_info.get("picture", ""),
        google_sub=user_info["sub"],
    )

    # Issue JWT cookies (same as email/password login)
    access_token = create_access_token(user.id)
    refresh_token = create_refresh_token(user.id)
    set_auth_cookies(response, access_token, refresh_token)

    # Redirect to frontend dashboard
    return RedirectResponse(url=settings.FRONTEND_URL + "/dashboard", status_code=302)
```

```python
# app/services/auth_service.py — Google login/register logic
async def google_login_or_register(
    self, email: str, name: str, picture: str, google_sub: str
) -> User:
    """Find existing user by email or create new user from Google OAuth."""
    user = await self.user_repo.get_by_email(email)
    if user:
        # Existing user — link Google if not already linked
        if not user.google_sub:
            await self.user_repo.update(user.id, google_sub=google_sub, auth_provider="google")
        return user

    # New user — register (no password needed for Google-only users)
    user = await self.user_repo.create(
        email=email,
        display_name=name,
        auth_provider="google",
        google_sub=google_sub,
        is_email_verified=True,  # Google-verified email is trusted
    )
    # Create MongoDB profile
    await self.profile_repo.create(user_id=user.id, display_name=name, avatar_url=picture)
    # Credit free trial points (same as email registration)
    await self.point_service.credit_trial_points(user.id)
    # Send welcome email
    await self.email_service.send_welcome(user)
    return user
```

### User Model Auth Fields (MySQL):
```python
# Additional fields on User model for multi-auth support
class User(Base):
    ...
    auth_provider: Mapped[str] = mapped_column(String(20), default="email")  # "email" | "google"
    google_sub: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True)
    is_email_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    ...
```

### 🌐 Frontend Auth — Pure Cookie-Based (No localStorage)

**Key principle**: The frontend NEVER stores tokens. The browser handles cookie storage automatically. Cookies are set by the backend via `Set-Cookie` headers and sent by the browser on every request via `withCredentials: true`.

```
┌───────────────────┬───────────────────────────────────┬───────────────────────────────────────────────┐
│       What        │               Where               │                      Why                      │
├───────────────────┼───────────────────────────────────┼───────────────────────────────────────────────┤
│ Access token      │ HTTP-only cookie (set by backend) │ Browser sends automatically on every request  │
├───────────────────┼───────────────────────────────────┼───────────────────────────────────────────────┤
│ Refresh token     │ HTTP-only cookie (set by backend) │ Browser sends automatically to /api/v1/auth/* │
├───────────────────┼───────────────────────────────────┼───────────────────────────────────────────────┤
│ User data         │ React state (in-memory)           │ For UI rendering only                         │
├───────────────────┼───────────────────────────────────┼───────────────────────────────────────────────┤
│ Token expiry time │ React ref (in-memory)             │ To schedule silent refresh before expiry       │
└───────────────────┴───────────────────────────────────┴───────────────────────────────────────────────┘
```

**Frontend implementation rules:**

```typescript
// lib/api.ts — Axios instance (ONLY way to call backend)
import axios from "axios";

const api = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL,
  withCredentials: true,  // ← THIS IS CRITICAL — sends cookies on every request
});

// Silent refresh interceptor — refresh before 401 hits the UI
let isRefreshing = false;
let failedQueue: Array<{ resolve: Function; reject: Function }> = [];

api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;
    if (error.response?.status === 401 && !originalRequest._retry) {
      if (isRefreshing) {
        // Queue subsequent 401s while refresh is in-flight
        return new Promise((resolve, reject) => {
          failedQueue.push({ resolve, reject });
        }).then(() => api(originalRequest));
      }
      originalRequest._retry = true;
      isRefreshing = true;
      try {
        await api.post("/api/v1/auth/refresh"); // Cookie sent automatically
        failedQueue.forEach(({ resolve }) => resolve());
        failedQueue = [];
        return api(originalRequest); // Retry original request
      } catch (refreshError) {
        failedQueue.forEach(({ reject }) => reject(refreshError));
        failedQueue = [];
        window.location.href = "/login"; // Session expired — redirect
        return Promise.reject(refreshError);
      } finally {
        isRefreshing = false;
      }
    }
    return Promise.reject(error);
  }
);

export default api;
```

```typescript
// hooks/useAuth.ts — Auth hook (user data in React state ONLY)
import { useState, useEffect, useRef, useCallback } from "react";
import api from "@/lib/api";

export function useAuth() {
  const [user, setUser] = useState<User | null>(null);       // In-memory only
  const [loading, setLoading] = useState(true);
  const refreshTimerRef = useRef<NodeJS.Timeout | null>(null); // In-memory only

  // On mount: check if cookies are valid by calling /auth/me
  useEffect(() => {
    api.get("/api/v1/auth/me")
      .then((res) => {
        setUser(res.data.user);
        scheduleRefresh(res.data.expires_in); // Backend returns seconds until expiry
      })
      .catch(() => setUser(null))
      .finally(() => setLoading(false));
    return () => {
      if (refreshTimerRef.current) clearTimeout(refreshTimerRef.current);
    };
  }, []);

  // Schedule silent refresh 1 minute before token expires
  const scheduleRefresh = useCallback((expiresInSeconds: number) => {
    if (refreshTimerRef.current) clearTimeout(refreshTimerRef.current);
    const refreshIn = Math.max((expiresInSeconds - 60) * 1000, 0); // 1 min before expiry
    refreshTimerRef.current = setTimeout(async () => {
      try {
        const res = await api.post("/api/v1/auth/refresh");
        scheduleRefresh(res.data.expires_in);
      } catch {
        setUser(null); // Refresh failed — session expired
      }
    }, refreshIn);
  }, []);

  const login = async (email: string, password: string) => {
    const res = await api.post("/api/v1/auth/login", { email, password });
    setUser(res.data.user);           // Store user in React state
    scheduleRefresh(res.data.expires_in); // Schedule refresh via ref
    // NOTE: No token storage — cookies are set by the backend's Set-Cookie header
  };

  const logout = async () => {
    await api.post("/api/v1/auth/logout"); // Backend clears cookies
    setUser(null);
    if (refreshTimerRef.current) clearTimeout(refreshTimerRef.current);
  };

  return { user, loading, login, logout, isAuthenticated: !!user };
}
```

**HARD RULES for frontend auth:**
```
  ✅ Axios withCredentials: true on EVERY API call
  ✅ User data in React state (useState) — re-fetched on page load via /auth/me
  ✅ Token expiry tracked in React ref — schedule silent refresh before expiry
  ✅ 401 interceptor triggers automatic token refresh (cookie-based)
  ✅ CSRF token read from non-httponly cookie, sent in X-CSRF-Token header
  ✅ Login/register responses only return user data — tokens are in Set-Cookie

  ❌ NEVER read tokens in JavaScript (HTTP-only cookies are inaccessible to JS)
  ❌ NEVER store tokens in localStorage, sessionStorage, or React state
  ❌ NEVER pass tokens in Authorization header from frontend
  ❌ NEVER use js-cookie or document.cookie for auth tokens
  ❌ NEVER decode JWT on the frontend (backend is the source of truth)
  ❌ NEVER store user data in localStorage (re-fetch from /auth/me on mount)
```

---

## 🗄️ DATABASE USAGE PATTERNS

### MySQL (via SQLAlchemy 2.0 Async):
- User accounts (email, password_hash, roles) — unique constraints
- Financial transactions, orders, invoices — ACID compliance
- **Subscriptions** (razorpay_sub_id, plan_id, user_id, status, cycle_start, cycle_end, point_allocation)
- **Credit balances** (user_id, plan_points, topup_points, total_balance) — ACID point tracking
- **Point transactions** (user_id, type=PLAN_CREDIT|TOPUP_CREDIT|DEBIT|TRIAL_CREDIT, action, cost, balance_after)
- **Top-up orders** (razorpay_order_id, pack_id, amount_paisa, status, user_id) — one-time purchases
- **Invoices** (invoice_number, subtotal_paisa, gst_paisa, total_paisa, user_id, source=SUBSCRIPTION|TOPUP)
- Anything with complex relationships/joins/foreign keys
- Connection: `mysql+asyncmy://` with pool_size=10, max_overflow=20

### MongoDB (via PyMongo sync):
- User profiles (flexible: preferences, settings, history)
- Content (posts, comments, media metadata)
- Audit logs, activity feeds, search docs
- **Razorpay webhook raw payloads** (full event JSON for audit/debugging)
- **Point usage analytics** (daily/weekly/monthly usage patterns per user)
- **Plan change history** (subscription upgrades, downgrades, cancellations)
- Anything with dynamic/variable schema

### Redis (via redis.asyncio):
- JWT blacklist (token JTI → expiry TTL)
- Rate limiting counters (sliding window)
- OTP/verification codes (with TTL)
- Real-time counters (views, likes)
- Pub/sub for real-time features
- Task queue integration
- **Razorpay webhook idempotency** (event_id → processed, TTL 48h)
- **Credit point balance cache** (user:{id}:points → real-time balance for fast middleware checks)
- **Daily usage counter** (user:{id}:daily_usage → reset daily via Celery beat)
- **Low balance alert flag** (user:{id}:low_balance_notified → prevent spam notifications)

---

