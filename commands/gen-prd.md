---
description: "Generate a detailed PRD from a brief idea, pre-configured for Alpha AI's tech stack. Supports Python/FastAPI, Node.js/NestJS, Java/Spring Boot backends. Usage: /gen-prd 'brief product idea' [--lang=python|nestjs|springboot]"
---

# PRD Generator — Alpha AI Standards

Generate a comprehensive PRD for: **$ARGUMENTS**

The PRD MUST specify Alpha AI's CORE stack (backend framework + JWT cookies + MySQL). Backend language can be Python/FastAPI (default), Node.js/NestJS, or Java/Spring Boot. CONDITIONAL technologies (MongoDB, Redis, Razorpay, Meilisearch, Mobile, GenAI, etc.) should be included ONLY if the product idea requires them. Analyze the product idea first.

## Step -1: Analyze Product Requirements (BEFORE Research)

Before doing anything, analyze the product idea ($ARGUMENTS) to determine which technologies are needed:

```
Read the product idea and determine:
- Does this need payments/billing? → Include Razorpay section
- Does this need a mobile app? → Include React Native section
- Does this need AI/GenAI features? → Include LiteLLM/RAG section
- Does this need full-text search? → Include Meilisearch
- Does this need real-time updates? → Include WebSocket
- Does this need file uploads? → Include S3/presigned URL
- Is this India-focused SaaS? → Include INR pricing, GST
- Does this need social login? → Include Google OAuth
- Does this need multi-language? → Include i18n
- Does this need offline? → Include PWA
- What backend language? → If --lang flag provided, use it. Otherwise default to Python/FastAPI.
  Supported: python (FastAPI), nestjs (NestJS 11+), springboot (Spring Boot 3.4+)

Build a FEATURE_PROFILE (YES/NO for each) and use it to determine:
- Which tech stack sections to include in the PRD
- Which data models to include
- Which API endpoints to include
- Which acceptance criteria to include
- Which backend language to use in the PRD tech stack
```

## Step 0: Market Research (MANDATORY — Do This FIRST)

Before writing the PRD, conduct thorough market research using `WebSearch` and `WebFetch` to build a world-class product:

### Research Queries (execute ALL of these):
```
1. COMPETITORS
   WebSearch: "[product idea] best tools 2025 2026"
   WebSearch: "[product idea] alternatives comparison"
   WebSearch: "[product idea] top competitors review"
   → Identify top 5-10 competitors
   → WebFetch their landing pages (features, positioning)
   → WebFetch their pricing pages (pricing models, tiers)

2. MARKET & TRENDS
   WebSearch: "[product idea] market size growth 2025 2026"
   WebSearch: "[product idea] industry trends"
   → TAM/SAM, growth rate, regional focus

3. USER PAIN POINTS
   WebSearch: "[product idea] user complaints problems"
   WebSearch: "[product idea] feature requests users want"
   WebSearch: "[product idea] reddit reviews"
   → What users love/hate about existing tools
   → Unmet needs = our opportunity

4. UX & FEATURE BEST PRACTICES
   WebSearch: "[product idea] best UX practices"
   WebSearch: "[product idea] must-have features"
   → Table-stakes features (must have on Day 1)
   → Differentiator features (our competitive edge)

5. PRICING RESEARCH (IF product has paid features)
   WebSearch: "[product idea] SaaS pricing"
   WebSearch: "[product idea] pricing strategy"
   → If India-focused: research India-specific pricing, INR, UPI, GST
   → If global: research USD pricing, multiple payment gateways
   → Inform subscription/pricing model based on product type

6. TECHNICAL LANDSCAPE
   WebSearch: "[product idea] API integrations"
   WebSearch: "[product idea] [python|node.js|java] libraries"
   → Domain-specific libraries/APIs to integrate
   → Security/compliance requirements for this domain
   → Third-party integrations users expect
```

### Research Output: `MARKET_RESEARCH.md`

Save findings BEFORE writing the PRD:
```markdown
# Market Research: [Product Idea]

## Competitors Found
| Name | URL | Key Features | Pricing | Weaknesses |
|------|-----|-------------|---------|------------|

## Market Size & Trends
- TAM: [X]
- Key trends: [list]

## User Pain Points (Opportunities)
1. [pain point] → our solution: [feature]
2. [pain point] → our solution: [feature]

## Table-Stakes Features (Must Build)
- [feature 1]
- [feature 2]

## Differentiator Features (Our Edge)
- [feature 1 — competitors don't have this]
- [feature 2 — we do this better]

## Pricing Intelligence
- Competitor range: ₹[X] to ₹[Y]/month
- Recommended: Basic ₹[X], Pro ₹[Y], Enterprise ₹[Z]

## UI/UX Decisions (Research-Based)
- Chosen UI library: [shadcn/ui | Ant Design | MUI | Chakra | Mantine — pick best for THIS product]
- App type: [Web only | Web + React Native mobile]
- Backend language: [Python/FastAPI | Node.js/NestJS | Java/Spring Boot]
- Design aesthetic: [modern minimal | data-dense enterprise | consumer playful]
- Competitor UI strengths: [what looks good in competitor products]
- Competitor UI weaknesses: [what feels bad — our opportunity]

## Technical Insights
- Libraries to use: [list]
- APIs to integrate: [list]
- Compliance needs: [list]
```

**USE this research to inform EVERY section of the PRD below** — features, data models, pricing, API design, and **UI/UX library choice**.

---

## Output: `PRD.md`

```markdown
# Product Requirements Document

## 1. Product Overview
- **Name**: [product name]
- **Description**: [2-3 sentence summary]
- **Target Users**: [who uses this]
- **Core Value Proposition**: [why it matters]
- **Market Research**: See `MARKET_RESEARCH.md` for full competitive analysis
- **Key Differentiators**: [2-3 features that set us apart from competitors, informed by research]
- **Competitor Gaps We Address**: [what existing tools do poorly that we solve]
- **Brand Personality**: [3-4 adjectives describing the brand feel: e.g., modern, trustworthy, innovative]
- **Brand Voice**: [professional/friendly/playful/authoritative — influences all copy]

## 2. Tech Stack (Alpha AI Standard)

> **📖 CANONICAL REFERENCE**: The full tech stack — every library, version, pattern, env var, and conditional rule — is defined in `commands/references/AUTO_BUILD_STACK.md`. Do NOT re-template it here. Generate this PRD section by selecting from the canonical reference based on the FEATURE_PROFILE built in Step -1.

### How to generate this section in the PRD

1. **Load** `commands/references/AUTO_BUILD_STACK.md` for the canonical stack definitions.

2. **Always include in the PRD** (CORE — applies to every product):
   - **Backend framework** for the selected language (FastAPI | NestJS | Spring Boot) — copy the matching column from `Backend Stack` matrix
   - **Authentication** — JWT + HTTP-Only Cookies (same rules all languages; never localStorage/sessionStorage)
   - **MySQL + ORM** — pick driver per language (SQLAlchemy 2.0 async | Prisma | Spring Data JPA); list the ACID-critical entities
   - **Code architecture** — strict layer segregation (controllers → services → repositories → models)
   - **Testing & Quality** — linter + type checker + test framework per language, >80% coverage target
   - **Frontend Web** (if `--with-frontend` or PRD says web): Next.js 15+ + TypeScript + Tailwind 4+ + UI library (agent picks shadcn/Ant/MUI/Chakra/Mantine via market research)
   - **Multi-theme** — Light + Dark + System Auto (MANDATORY, never ship without dark mode)

3. **Include CONDITIONAL sections ONLY if FEATURE_PROFILE flags them YES** — each section name maps to a `### header` in AUTO_BUILD_STACK.md:
   - `Google OAuth2 (Social Login — Public-Facing Apps)` — if profile.has_social_login
   - `Transactional Email System` — if profile.sends_email
   - `Databases` (MongoDB) — if profile.needs_flexible_docs
   - `Databases` (Redis) — if profile.needs_caching OR profile.needs_realtime OR profile.needs_rate_limit
   - `Task Queue` — if profile.has_email OR profile.has_async_jobs
   - `Payments — Subscription + Credit Points` — if profile.has_payments (India → Razorpay)
   - `File Upload & Cloud Storage` — if profile.has_file_uploads
   - `Real-Time — WebSocket + SSE` — if profile.has_realtime
   - `Push Notifications (Mobile)` — if profile.has_mobile
   - `Search (Full-Text Search Engine)` — if profile.has_search
   - `Admin Panel`, `RBAC`, `Two-Factor Authentication (2FA)` — per flags
   - `Session Management`, `Error Tracking & Crash Reporting` — recommended for production
   - `Internationalization (i18n)` — if profile.is_multi_language
   - `PWA (Progressive Web App) Support` — if profile.has_offline
   - `Product Analytics & Event Tracking`, `Feature Flags`, `Backup & Disaster Recovery`, `API Rate Limiting`, `Centralized Logging` — per flags
   - `Frontend — Mobile App (if React Native)` + all 12 Mobile sub-sections (Mobile Project Config, Auth, UI Patterns, Media & Device Features, Offline & Network, Security, Performance, Accessibility, Testing, CI/CD, App Store Readiness) — if profile.has_mobile
   - `GenAI / Agentic AI Features` — if profile.has_ai (covers LiteLLM gateway, agentic framework, RAG, MCP, A2A, evaluation, structured output, semantic caching, multi-modal, HITL, voice AI, batch processing)

4. **Copy verbatim** from the canonical stack — don't paraphrase or summarize. The generated PRD must match what `/auto-build` will actually implement. If a downstream agent reads the PRD and a detail is missing or rephrased, the build will diverge from the standard.

5. **NEVER list a technology** the FEATURE_PROFILE does not require — including unused infrastructure in the PRD causes `/auto-build` to scaffold dead code (extra docker-compose services, unused deps, empty directories).

## 3. Data Models

### MySQL Models ([SQLAlchemy | Prisma | Spring Data JPA])
[For ACID-critical entities]

#### Model: User
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | Primary key |
| email | String(255) | UNIQUE, NOT NULL | Login email |
| password_hash | String(255) | NULLABLE | Bcrypt hash (NULL for Google-only users) |
| auth_provider | String(20) | DEFAULT 'email' | 'email' or 'google' |
| google_sub | String(255) | UNIQUE, NULLABLE | Google OAuth subject ID |
| is_email_verified | Boolean | DEFAULT False | True for Google-verified emails |
| role | Enum | DEFAULT 'user' | user/admin |
| is_active | Boolean | DEFAULT True | Account status |
| created_at | DateTime | AUTO | Creation timestamp |
| updated_at | DateTime | AUTO | Update timestamp |

#### Model: Subscription (Razorpay)
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | Primary key |
| user_id | UUID | FK → User | Subscribing user |
| razorpay_sub_id | String(50) | UNIQUE | Razorpay subscription ID |
| plan_id | String(50) | NOT NULL | Razorpay plan ID |
| plan_name | Enum | | basic/pro/enterprise |
| billing_cycle | Enum | | monthly/yearly |
| point_allocation | Integer | NOT NULL | Points credited per cycle |
| status | Enum | | created/authenticated/active/paused/cancelled |
| cycle_start | DateTime | | Current billing cycle start |
| cycle_end | DateTime | | Current billing cycle end |

#### Model: CreditBalance
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | Primary key |
| user_id | UUID | FK → User, UNIQUE | One balance per user |
| plan_points | Integer | DEFAULT 0 | Points from subscription (reset on renewal) |
| topup_points | Integer | DEFAULT 0 | Points from top-up purchases (persist) |
| total_balance | Integer | DEFAULT 0 | plan_points + topup_points |
| updated_at | DateTime | AUTO | Last balance update |

#### Model: PointTransaction
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | Primary key |
| user_id | UUID | FK → User, INDEX | Transaction owner |
| type | Enum | NOT NULL | PLAN_CREDIT / TOPUP_CREDIT / DEBIT / TRIAL_CREDIT |
| action | String(50) | NULLABLE | "ai_generation" / "search" / "export" (for DEBITs) |
| points | Integer | NOT NULL | Points credited or debited |
| balance_after | Integer | NOT NULL | Running balance after this txn |
| metadata | JSON | NULLABLE | Extra context (pack_id, plan_id, etc.) |
| created_at | DateTime | AUTO | Transaction timestamp |

#### Model: TopupOrder (Razorpay)
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | Primary key |
| user_id | UUID | FK → User | Buyer |
| razorpay_order_id | String(50) | UNIQUE, NOT NULL | Razorpay order ID |
| pack_id | String(30) | NOT NULL | small_topup / medium_topup / large_topup |
| points | Integer | NOT NULL | Points in this pack |
| amount_paisa | Integer | NOT NULL | Price in paisa |
| status | Enum | DEFAULT 'created' | created/paid/failed |
| razorpay_payment_id | String(50) | NULLABLE | Set after payment capture |
| created_at | DateTime | AUTO | Order timestamp |

#### Model: Invoice
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | Primary key |
| invoice_number | String(20) | UNIQUE, AUTO | INV-2026-00001 format |
| user_id | UUID | FK → User | Billed user |
| source | Enum | NOT NULL | SUBSCRIPTION / TOPUP |
| subtotal_paisa | Integer | NOT NULL | Amount before GST |
| gst_rate | Integer | DEFAULT 18 | GST percentage |
| gst_paisa | Integer | NOT NULL | GST amount in paisa |
| total_paisa | Integer | NOT NULL | Total including GST |

#### Model: Role (RBAC)
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | Primary key |
| name | String(50) | UNIQUE | super_admin/admin/moderator/user/viewer |
| permissions | JSON | NOT NULL | List of permission strings |

#### Model: UserSession
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | Primary key |
| user_id | UUID | FK → User | Session owner |
| device_info | String(255) | | User-Agent parsed device name |
| ip_address | String(45) | | IPv4/IPv6 address |
| location | String(100) | NULLABLE | City, Country from IP geolocation |
| last_active_at | DateTime | AUTO | Last activity timestamp |
| is_current | Boolean | DEFAULT False | Whether this is the current session |

#### Model: FeatureFlag
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | Primary key |
| name | String(100) | UNIQUE | Flag name (e.g., new_dashboard) |
| is_enabled | Boolean | DEFAULT False | Global toggle |
| rollout_percentage | Integer | DEFAULT 0 | Gradual rollout 0-100% |
| allowed_roles | JSON | NULLABLE | Roles that can see this feature |
| allowed_plans | JSON | NULLABLE | Plans that include this feature |

#### Model: DeviceToken (Push Notifications)
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | Primary key |
| user_id | UUID | FK → User | Device owner |
| token | String(255) | UNIQUE | FCM device token |
| platform | Enum | NOT NULL | ios/android/web |
| created_at | DateTime | AUTO | Registration timestamp |

[Add domain-specific MySQL models]

### MongoDB Documents ([PyMongo | Mongoose | Spring Data MongoDB])
[For flexible/nested data]

#### Document: UserProfile
| Field | Type | Description |
|-------|------|-------------|
| user_id | UUID | FK to MySQL User |
| display_name | str | Public name |
| avatar_url | str | Profile image |
| preferences | dict | User settings (flexible) |
| activity_log | list[dict] | Recent actions |

#### Document: EmailLog
| Field | Type | Description |
|-------|------|-------------|
| user_id | UUID | Recipient user |
| email_type | str | welcome / otp / reset / invoice / alert etc. |
| to_email | str | Recipient email address |
| subject | str | Email subject line |
| status | str | sent / failed / bounced |
| sent_at | datetime | When email was sent |
| error | str | Error message if failed |

#### Document: Notification (In-App)
| Field | Type | Description |
|-------|------|-------------|
| user_id | UUID | Recipient |
| type | str | system/payment/subscription/alert/social |
| title | str | Notification title |
| body | str | Notification body text |
| data | dict | Additional context (action_url, entity_id) |
| is_read | bool | Read status (default False) |
| created_at | datetime | When created |

#### Document: Feedback
| Field | Type | Description |
|-------|------|-------------|
| user_id | UUID | Submitter |
| type | str | bug_report/feature_request/support/general |
| message | str | Feedback text |
| screenshot_url | str | Optional screenshot S3 URL |
| page_url | str | Page where feedback was submitted |
| status | str | open/in_progress/resolved/closed |
| admin_notes | str | Admin response notes |

#### Document: AuditLog
| Field | Type | Description |
|-------|------|-------------|
| user_id | UUID | Actor |
| action | str | user.created/subscription.cancelled/admin.ban_user etc. |
| entity_type | str | user/subscription/invoice etc. |
| entity_id | str | ID of affected entity |
| changes | dict | Before/after values |
| ip_address | str | Actor's IP |
| created_at | datetime | When action occurred |

#### Document: AIConversation
| Field | Type | Description |
|-------|------|-------------|
| user_id | UUID | Chat owner |
| session_id | str | Conversation session ID |
| messages | list[dict] | [{role, content, timestamp, tokens_used, model}] |
| model_used | str | Primary model used |
| total_tokens | int | Total tokens consumed in session |
| total_cost | float | Estimated cost in USD |
| created_at | datetime | Session start |

#### Document: RAGDocument
| Field | Type | Description |
|-------|------|-------------|
| user_id | UUID | Document owner |
| filename | str | Original filename |
| file_type | str | pdf/docx/csv/html/md |
| chunk_count | int | Number of chunks created |
| embedding_model | str | Model used for embeddings |
| vector_ids | list[str] | IDs in Qdrant vector DB |
| status | str | processing/ready/failed |

#### Document: AgentRun
| Field | Type | Description |
|-------|------|-------------|
| user_id | UUID | Who triggered the agent |
| agent_type | str | chat/research/workflow/analysis |
| steps | list[dict] | [{tool, input, output, duration_ms}] |
| tokens_used | int | Total tokens across all steps |
| cost | float | Total cost in USD |
| status | str | running/completed/failed/stopped |

[Add domain-specific MongoDB documents]

### Redis Keys
| Key Pattern | Type | TTL | Purpose |
|-------------|------|-----|---------|
| blacklist:{jti} | string | token_expiry | JWT blacklist |
| rate:{ip} | sorted_set | 60s | Rate limiting |
| otp:{email} | string | 300s | Email verification |
| cache:{resource}:{id} | hash | 3600s | Entity cache |
| user:{id}:points | integer | none | Credit point balance (real-time) |
| user:{id}:daily_usage | integer | 86400s | Today's point usage (reset daily) |
| rzp_webhook:{event_id} | string | 172800s | Razorpay webhook idempotency (48h) |
| oauth_state:{state} | string | 600s | Google OAuth CSRF state parameter (10 min) |
| email_unsub:{token} | string | none | Email unsubscribe token → user_id mapping |
| user:{id}:sessions | set | none | Active session IDs |
| user:{id}:permissions | string | 3600s | Cached RBAC permissions |
| flag:{name} | hash | 300s | Feature flag cache |
| rate:{plan}:{user_id} | sorted_set | 60s | Per-plan rate limiting |
| search:sync:{entity} | string | none | Search index sync lock |
| notif:{user_id}:unread | integer | none | Unread notification badge count |
| ai:session:{session_id} | hash | 3600s | Active AI chat session state |
| ai:cost:{user_id}:daily | integer | 86400s | Daily AI spend tracking |
| ai:rate:{user_id} | sorted_set | 60s | AI endpoint rate limiting |
| rag:embed:{hash} | string | 604800s | Cached embedding (7 days) |

## 4. API Endpoints

### Auth (/api/v1/auth)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /register | No | Create account + set cookies |
| POST | /login | No | Authenticate + set cookies |
| POST | /refresh | Cookie | Rotate tokens |
| POST | /logout | Cookie | Blacklist + clear cookies |
| GET | /me | Cookie | Get current user |
| POST | /forgot-password | No | Send reset OTP email |
| POST | /reset-password | No | Verify OTP + new password |
| GET | /google | No | Redirect to Google OAuth consent screen |
| GET | /google/callback | No | Handle Google callback → create/login user → set cookies |
| POST | /verify-email | No | Verify email OTP (for email/password registrations) |
| POST | /resend-otp | No | Resend email verification OTP |
| POST | /2fa/enable | Cookie | Enable 2FA → returns QR code + backup codes |
| POST | /2fa/verify-setup | Cookie | Verify first TOTP code to activate 2FA |
| POST | /2fa/verify | No | Verify TOTP code during login |
| POST | /2fa/disable | Cookie | Disable 2FA (requires current code) |
| POST | /2fa/backup | No | Use backup code for recovery |
| GET | /sessions | Cookie | List all active sessions |
| DELETE | /sessions/:id | Cookie | Revoke specific session |
| DELETE | /sessions | Cookie | Revoke all sessions except current |

### [Resource] (/api/v1/[resource])
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | / | Yes | List (paginated) |
| POST | / | Yes | Create |
| GET | /:id | Yes | Get by ID |
| PUT | /:id | Yes | Update |
| DELETE | /:id | Admin | Soft delete |

### Subscriptions (/api/v1/subscriptions)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /plans | No | List plans with point allocations + pricing (INR) |
| POST | /create | Yes | Create Razorpay subscription for a plan |
| GET | /current | Yes | Get active subscription + point allocation |
| POST | /cancel | Yes | Cancel subscription (access until cycle end) |
| POST | /change-plan | Yes | Upgrade/downgrade (prorated point adjustment) |

### Credit Points (/api/v1/points)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /balance | Yes | Get point balance (plan_points, topup_points, total) |
| GET | /usage | Yes | Point usage history (paginated, filterable) |
| GET | /costs | Yes | List all action → point cost mappings |
| POST | /topup | Yes | Purchase top-up pack via Razorpay order |
| POST | /topup/verify | Yes | Verify top-up payment + credit points |
| GET | /packs | No | List available top-up packs with pricing |

### Invoices (/api/v1/invoices)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | / | Yes | List user's invoices (subscriptions + top-ups) |
| GET | /:id | Yes | Get invoice details with GST breakdown |
| GET | /:id/download | Yes | Download invoice PDF |

### Webhooks (/api/v1/webhooks)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /razorpay | No (signature verified) | Razorpay webhook (subscription + payment events) |

### Notifications (/api/v1/notifications)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | / | Yes | List notifications (paginated, unread first) |
| PATCH | /:id/read | Yes | Mark single notification as read |
| PATCH | /read-all | Yes | Mark all notifications as read |
| GET | /unread-count | Yes | Get unread badge count |
| DELETE | /:id | Yes | Dismiss notification |

### Search (/api/v1/search)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | / | Yes | Full-text search (?q=query&type=&filters=) |

### File Upload (/api/v1/upload)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /presigned-url | Yes | Get presigned S3 upload URL |
| POST | /confirm | Yes | Confirm upload completion |

### Account (/api/v1/account)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /export | Yes | Request data export (GDPR) → emailed as ZIP |
| DELETE | / | Yes | Request account deletion (soft delete + 30-day grace) |
| PATCH | /consent | Yes | Update data processing consent |

### Feedback (/api/v1/feedback)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | / | Yes | Submit feedback (bug, feature request, support) |

### Onboarding (/api/v1/onboarding)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /status | Yes | Get onboarding progress |
| PATCH | /step/:step | Yes | Mark onboarding step complete |

### Feature Flags (/api/v1/flags)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | / | Yes | Get user's active feature flags |

### Admin (/api/v1/admin) — requires admin role
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /users | Admin | List all users (search, filter, sort) |
| PATCH | /users/:id | Admin | Update user (activate, ban, change role) |
| POST | /users/:id/impersonate | SuperAdmin | Impersonate user session |
| GET | /analytics/dashboard | Admin | Analytics overview (DAU, revenue, churn) |
| GET | /flags | Admin | List all feature flags |
| POST | /flags | Admin | Create feature flag |
| PATCH | /flags/:id | Admin | Update feature flag |
| GET | /feedback | Admin | List all feedback submissions |
| PATCH | /feedback/:id | Admin | Update feedback status + admin notes |

### Devices (/api/v1/devices)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /register | Yes | Register device token for push notifications |
| DELETE | /:token | Yes | Unregister device token |

### AI (/api/v1/ai) — if product has AI features
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /chat | Yes | Chat with AI assistant (SSE streaming) |
| POST | /chat/sessions | Yes | Create new chat session |
| GET | /chat/sessions | Yes | List user's chat sessions |
| GET | /chat/sessions/:id | Yes | Get chat session history |
| DELETE | /chat/sessions/:id | Yes | Delete chat session |
| POST | /generate | Yes | Generate content (text, code, summary) |
| POST | /rag/upload | Yes | Upload document for RAG knowledge base |
| POST | /rag/query | Yes | Query RAG knowledge base |
| GET | /rag/documents | Yes | List uploaded RAG documents |
| DELETE | /rag/documents/:id | Yes | Delete RAG document + vectors |
| POST | /agent/run | Yes | Run agentic workflow |
| GET | /agent/status/:id | Yes | Check agent task status |
| GET | /usage/ai | Yes | AI usage stats (tokens, cost, history) |

### Multi-Modal (/api/v1/ai)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /vision/analyze | Yes | Analyze image with AI (GPT-4o/Gemini/Claude vision) |
| POST | /image/generate | Yes | Generate image (DALL-E 3 / Flux) |
| POST | /audio/transcribe | Yes | Speech-to-text (Whisper STT) |
| POST | /audio/synthesize | Yes | Text-to-speech (OpenAI TTS / Gemini TTS / ElevenLabs) |

### Voice AI (/api/v1/ai/voice)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| WS | /stream | Yes | WebSocket audio streaming (real-time STT + TTS) |
| POST | /conversations | Yes | Create voice conversation session |

### HITL Review (/api/v1/ai/review)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /queue | Admin | List items pending human review |
| POST | /:id/approve | Admin | Approve AI-generated content |
| POST | /:id/reject | Admin | Reject with feedback |
| PATCH | /:id/edit | Admin | Edit AI content before publishing |

### Batch Processing (/api/v1/ai/batch)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /embed | Yes | Batch embed documents (async [Celery | Bull | Spring Batch]) |
| POST | /generate | Yes | Batch content generation (async [Celery | Bull | Spring Batch]) |
| GET | /jobs | Yes | List batch job statuses |
| GET | /jobs/:id | Yes | Get batch job progress + results |

### MCP Protocol (/api/v1/mcp) — Model Context Protocol endpoints
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /prompts | Yes | List available MCP prompts (prompts/list) |
| POST | /prompts/:name | Yes | Get rendered prompt by name with arguments (prompts/get) |
| GET | /tools | Yes | List available MCP tools (tools/list) |
| POST | /tools/:name | Yes | Execute MCP tool by name with input (tools/call) |

### A2A Protocol — Agent-to-Agent communication endpoints
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /.well-known/agent.json | No | Agent Card discovery (public metadata, skills, capabilities) |
| POST | /a2a/tasks | Yes | Receive task from external agent (create new task) |
| GET | /a2a/tasks/:id | Yes | Get task status and result by ID |

[Repeat for each domain resource]

## 5. Pages / Screens (if frontend)

Must include:
- `/login` — Email/password form + "Sign in with Google" button (redirect to GET /auth/google)
- `/register` — Email/password form + "Sign up with Google" button + email verification step
- `/verify-email` — OTP input for email verification
- `/forgot-password` — Email input → sends reset OTP
- `/reset-password` — OTP + new password input
- `/dashboard` — Main app dashboard (shows point balance widget)
- `/settings/notifications` — Email notification preferences (toggle: weekly summary, login alerts, low balance alerts)
- `/unsubscribe/:token` — Email unsubscribe landing page

[Define additional domain-specific pages with route, auth requirement, components, API calls]

## 6. User Flows

### Registration Flow (Email/Password)
1. User → POST /auth/register (email, password, name)
2. Server creates User in MySQL (auth_provider='email') + UserProfile in MongoDB
3. Server generates email verification OTP → sends OTP email via [Celery | Bull | @Async] task
4. Server generates JWT tokens, sets HTTP-only cookies
5. Server returns user data, browser stores cookies automatically
6. Credit free trial points to user balance
7. Send welcome email via async task [Celery | Bull | @Async]
8. Redirect to dashboard (with banner: "Verify your email")

### Registration/Login Flow (Google OAuth2)
1. User clicks "Sign in with Google" → GET /auth/google
2. Server generates state token, stores in Redis (10 min TTL)
3. Server redirects to Google consent screen
4. User authenticates on Google
5. Google redirects → GET /auth/google/callback?code=xxx&state=xxx
6. Server verifies state, exchanges code for Google tokens (server-side)
7. Server fetches user info (email, name, picture) from Google
8. Server checks: user with this email exists?
   - YES → Login: issue JWT cookies, link Google sub if not linked
   - NO → Register: create User (auth_provider='google', is_email_verified=True), create profile, credit trial points, send welcome email
9. Set JWT HTTP-only cookies → redirect to frontend /dashboard

### Login Flow (Email/Password)
1. User → POST /auth/login (email, password)
2. Server verifies password hash (bcrypt)
3. Server generates tokens, stores refresh hash in Redis
4. Server sets HTTP-only cookies
5. Browser auto-sends cookies on subsequent requests
6. If login from new device/IP → send login alert email via async task [Celery | Bull | @Async]

### Token Refresh Flow
1. Access token expires (30 min)
2. Frontend gets 401 → auto-retries POST /auth/refresh
3. Server reads refresh_token cookie, validates, rotates
4. New cookies set, original request retried

### Subscription + Credit Points Flow
1. User selects plan → POST /subscriptions/create (plan_id, billing_cycle)
2. Backend → razorpay.subscription.create() → returns subscription_id
3. Frontend opens Razorpay Checkout with subscription_id
4. User pays via UPI / Card / NetBanking / Wallet
5. Webhook: subscription.activated →
   - Activate plan, set cycle dates
   - Credit plan's point allocation to user balance
   - Generate invoice with GST
6. User performs actions → points deducted per action
7. Monthly renewal webhook: subscription.charged →
   - Reset plan_points to plan allocation (unused points don't roll over)
   - topup_points carry forward
   - Generate new invoice

### Point Deduction Flow (on every metered action)
1. User triggers action (GenAI call, export, etc.)
2. Middleware/guard/interceptor `require_points(cost)` checks balance
3. If insufficient → 402 with upgrade/topup options
4. If sufficient → deduct from Redis (fast) + log to MySQL (audit)
5. Return result + X-Points-Remaining header

### Top-Up Purchase Flow (when points exhaust mid-cycle)
1. User clicks "Buy more points" → POST /points/topup (pack_id)
2. Backend → razorpay.order.create(pack_price_paisa) → returns order_id
3. Frontend opens Razorpay Checkout with order_id
4. After payment → POST /points/topup/verify (payment_id, order_id, signature)
5. Backend verifies → credits top-up points (these persist across renewals)
6. Invoice generated with GST

### Mobile Auth Flow
1. User opens app → splash screen shown
2. Check expo-secure-store for stored access token
3. If token exists → GET /auth/me to validate
4. If valid → navigate to Home (hydrate user state)
5. If 401 → try refresh token from secure store
6. If refresh succeeds → store new tokens → retry
7. If no token or refresh fails → navigate to Login
8. Login: email/password or Google (expo-auth-session) or Apple Sign-In
9. On success → store JWT in expo-secure-store → navigate to Home

### Mobile Google OAuth Flow
1. User taps "Sign in with Google"
2. expo-auth-session opens system browser → Google consent
3. Google redirects to [scheme]://auth/google/callback with auth code
4. App sends auth code to backend POST /auth/google/mobile
5. Backend exchanges code → creates/finds user → returns JWT
6. App stores JWT in expo-secure-store → navigates to Home

## 7. Product Branding
- **Brand Name**: [product name]
- **Tagline**: [one-line value proposition]
- **Brand Voice**: [professional/friendly/playful/authoritative]
- **Primary Color**: #[hex] — used for CTAs, links, brand accent
- **Color Palette**: [define full palette with light/dark mode variants]
- **Typography**: [heading font + body font — e.g., Plus Jakarta Sans + Inter]
- **Logo Style**: [wordmark / icon+wordmark / lettermark]
- **Favicon**: Simplified brand icon
- **OG Image**: Product name + tagline + screenshot (1200x630)
- **Email Branding**: Logo header + brand colors + consistent footer
- **See `BRAND_GUIDE.md`** for full brand system with Tailwind design tokens

## 8. Non-Functional Requirements

- API response time: < 200ms (p95)
- JWT access token: 30 min, refresh token: 7 days
- Rate limiting: 100 req/min per IP (Redis sliding window)
- CORS: Configured allowed origins
- CSRF: Double-submit cookie on mutations
- All passwords: bcrypt with cost factor 12
- All env vars: via [Pydantic BaseSettings | @nestjs/config+Joi | Spring Boot application.yml+@ConfigurationProperties]
- Structured logging: [structlog | pino | Logback+logstash-encoder] → JSON

## 9. Acceptance Criteria

Generate acceptance criteria ONLY for features included in this PRD.
Do NOT include criteria for technologies/features not used by this product.

### Core Criteria (Always Include)
- [ ] All API endpoints working with proper auth
- [ ] JWT + Cookie auth fully functional (login/refresh/logout)
- [ ] Zero usage of localStorage/sessionStorage for tokens
- [ ] CSRF protection active on POST/PUT/DELETE
- [ ] MySQL for transactional data
- [ ] Layer segregation enforced (no cross-layer imports)
- [ ] All tests passing (>80% coverage)
- [ ] Linting + type checking clean [ruff+mypy | ESLint+TypeScript | Checkstyle+SpotBugs]
- [ ] Docker Compose runs all services

### Conditional Criteria (Include ONLY if feature is in this PRD)

Generate additional criteria for each feature the product uses:
- If payments → Razorpay/payment flow, credit points, invoices, GST (if India-focused)
- If MongoDB → flexible data stored correctly
- If Redis → caching, blacklist, rate limiting working
- If Google OAuth → OAuth2 redirect flow, account linking
- If email → transactional emails via async tasks [Celery | Bull | @Async], templates, unsubscribe
- If mobile → Expo builds, Apple Sign-In, secure store, FlashList, accessibility
- If GenAI → LiteLLM, streaming, RAG, evaluation, cost tracking
- If search → Meilisearch full-text search working
- If real-time → WebSocket notifications working
- If i18n → multi-language support working
- If PWA → service worker, install prompt, offline fallback
- If file uploads → presigned URL, S3/MinIO, CDN serving

Do NOT include mobile criteria if the product has no mobile app.
Do NOT include GenAI criteria if the product has no AI features.
Do NOT include payment criteria if the product has no billing.
Do NOT include search criteria if the product has no full-text search.
Do NOT include i18n criteria if the product has no multi-language need.
```

Save as `PRD.md` (and `MARKET_RESEARCH.md` from Step 0).

---

## Step FINAL: Auto-Generate Sprint Plan (MANDATORY)

After saving PRD.md, AUTOMATICALLY generate a sprint plan. Do NOT skip this step.

### Sprint Plan Generation

Read the PRD.md you just created and break it into sprint-sized tasks:

1. **Extract all features** from the PRD (user stories, acceptance criteria, technical requirements)
2. **Decompose into atomic tasks** — separate backend, frontend, mobile, infra, testing, and docs tasks
3. **Estimate effort** using T-shirt sizes:
   - XS (1 point) = config changes, simple UI tweaks (< 2 hours)
   - S (2 points) = single endpoint, simple component (2-4 hours)
   - M (3 points) = full CRUD, complex component (4-8 hours)
   - L (5 points) = multi-model feature, complex logic (1-2 days)
   - XL (8 points) = major system: auth, payments, GenAI pipeline (2-5 days)

4. **Build dependency graph** — infrastructure first, then models, then APIs, then frontend:
   - Phase -1: Market Research (already done above)
   - Phase 0: Project scaffold + config
   - Phase 1: Database models + migrations
   - Phase 2: Repository + service layers
   - Phase 3: Auth system (JWT, OAuth, email)
   - Phase 4: Payment system (Razorpay, credit points)
   - Phase 5: Core API endpoints
   - Phase 6: Frontend pages + integration
   - Phase 7: Mobile app (if applicable)
   - Phase 8: GenAI features (if applicable)
   - Phase 9: Testing + security + polish
   - Phase 10: Documentation + CI/CD + deployment

5. **Distribute into sprints** (default: 4 sprints, 2 weeks each):
   - Sprint 1: Foundation (scaffold + models + auth)
   - Sprint 2: Core features (APIs + frontend)
   - Sprint 3: Advanced features (payments + GenAI + mobile)
   - Sprint 4: Polish (tests + security + docs + deploy)

6. **Generate `SPRINT_PLAN.md`** with:

```markdown
# Sprint Plan: [Project Name]
**Generated**: [date]
**From**: PRD.md
**Total Sprints**: [n]
**Total Tasks**: [n]
**Total Story Points**: [n]

## Sprint Overview
| Sprint | Theme | Story Points | Key Deliverables |
|--------|-------|-------------|------------------|

## Sprint 1: Foundation
| # | Task | Type | Size | Points | Phase | Depends On | Status |
|---|------|------|------|--------|-------|------------|--------|
| 1.1 | Create project scaffold | Infra | XS | 1 | 0 | — | ⬜ |
| 1.2 | Setup MySQL + MongoDB + Redis | Infra | S | 2 | 0 | 1.1 | ⬜ |
| 1.3 | Create User model | Backend | S | 2 | 1 | 1.2 | ⬜ |
...

### Sprint 1 Acceptance Criteria
- [ ] User can register and login
- [ ] JWT tokens in HTTP-only cookies
...

## Sprint 2: Core Features
...

## Sprint 3: Advanced Features
...

## Sprint 4: Polish + Launch
...

## Critical Path
[task] → [task] → [task] → ... → [launch]

## Auto-Build Phase Mapping
| Sprint | Maps to Auto-Build Phases |
|--------|--------------------------|
| Sprint 1 | Phase 0, 1, 2, 3, 6 |
| Sprint 2 | Phase 4, 5, 7 |
| Sprint 3 | Phase 6.5, 6.8, 9, 9.5 |
| Sprint 4 | Phase 8, 10, 11, 12 |
```

Save as `SPRINT_PLAN.md` in the same directory as PRD.md.

---

## Output Summary

After generating both files, show:

```
╔══════════════════════════════════════════════════════════════╗
║  PRD + SPRINT PLAN GENERATED                                 ║
╠══════════════════════════════════════════════════════════════╣
║                                                               ║
║  📄 PRD.md — [n] pages, [n] features, [n] acceptance criteria║
║  📋 SPRINT_PLAN.md — [n] sprints, [n] tasks, [n] story pts  ║
║  📊 MARKET_RESEARCH.md — [n] competitors analyzed            ║
║                                                               ║
║  Sprint Breakdown:                                           ║
║  Sprint 1: Foundation       — [n] tasks, [n] points          ║
║  Sprint 2: Core Features    — [n] tasks, [n] points          ║
║  Sprint 3: Advanced         — [n] tasks, [n] points          ║
║  Sprint 4: Polish + Launch  — [n] tasks, [n] points          ║
║                                                               ║
║  Next Steps:                                                 ║
║  • /auto-build ./PRD.md  — Build entire product autonomously ║
║  • /init-project <name>  — Just scaffold, build manually     ║
║                                                               ║
║  Auto-build will read SPRINT_PLAN.md and track progress      ║
║  per task, updating status from ⬜ → 🔄 → ✅ as it builds.  ║
╚══════════════════════════════════════════════════════════════╝
```
