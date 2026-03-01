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

### Core Stack (Always Include)

#### Backend (per selected language)
- **Python/FastAPI** (default): Python 3.11+ with FastAPI (async) + Pydantic v2 + Uvicorn + Gunicorn
- **Node.js/NestJS**: NestJS 11+ with TypeScript + class-validator + class-transformer
- **Java/Spring Boot**: Spring Boot 3.4+ with Java 21 + Jakarta Validation + Gradle (Kotlin DSL)

> Include ONLY the selected language's backend in the PRD. Load stack details from LANG_PROFILE_{LANG}.md.

#### Authentication (same rules, all languages)
- JWT tokens (access: 30min, refresh: 7 days)
- Stored in HTTP-Only Secure Cookies
- CSRF: Double-submit cookie pattern
- Auth libraries: [python-jose+passlib | @nestjs/jwt+bcryptjs | jjwt-api+Spring Security]
- ❌ NEVER localStorage or sessionStorage

#### Database (Core)
- **MySQL** via [SQLAlchemy 2.0 async | Prisma | Spring Data JPA]: [list ACID-critical entities]

#### Code Architecture
Strictly segregated layers:
- **Python/FastAPI**: api/ → services/ → repositories/ → models/ → schemas/ → core/ → db/
- **Node.js/NestJS**: modules/ → controllers/ → services/ → repositories/ → entities/ → dto/
- **Java/Spring Boot**: controller/ → service/ → repository/ → entity/ → dto/ → config/

#### Testing & Quality (per language)
- [pytest+pytest-asyncio+httpx | Jest+supertest | JUnit5+Mockito+MockMvc]
- [ruff+mypy | ESLint+Prettier+TypeScript | Checkstyle+SpotBugs+Java compiler]
- >80% code coverage target

### Conditional Stack (Include ONLY if FEATURE_PROFILE says YES)

Include the following sections ONLY if the product requires them:
- **MongoDB section**: Only if product needs flexible documents, logs, profiles
- **Redis section**: Only if product needs caching, rate limiting, JWT blacklist, OTP codes
- **Razorpay/Payments section**: Only if product has paid features (and India-focused → Razorpay, otherwise research best gateway)
- **Google OAuth section**: Only if product has social login
- **Email section**: Only if product sends transactional emails
- **Mobile section**: Only if product has a mobile app
- **GenAI section**: Only if product has AI features
- **Search section**: Only if product needs full-text search
- **Real-Time section**: Only if product needs live updates/chat
- **Push Notifications**: Only if product has mobile app
- **i18n section**: Only if product needs multi-language
- **PWA section**: Only if product needs offline web

#### Google OAuth2 (Social Login) — IF FEATURE_PROFILE includes social login
- **Library**: [authlib | passport-google-oauth20 | Spring Security OAuth2 Client] (server-side Authorization Code Grant)
- Login/register via Gmail — auto-create user on first Google login
- Account linking: match by email across login methods
- Google-verified emails skip email verification
- Same JWT cookie auth after Google login (not Google tokens)
- ❌ NEVER store Google access tokens — fetch user info and discard
- ❌ NEVER use client-side Google JS SDK popup — use server redirect

#### Transactional Email System — IF FEATURE_PROFILE includes email
- **Library**: [fastapi-mail+Jinja2 | @nestjs-modules/mailer+Handlebars | spring-mail+Thymeleaf]
- **SMTP**: Gmail SMTP (dev) / AWS SES or SendGrid (production)
- **Sending**: Always async via [Celery tasks | Bull queue | @Async+ThreadPool] (never block API response)
- **Email types**: welcome, email OTP, password reset OTP, password changed, login alert, subscription activated/renewed/cancelled, payment receipt, invoice, low point balance, points exhausted, top-up confirmation, trial expiring/expired, account deactivated, weekly usage summary
- **Templates**: HTML with [Jinja2 | Handlebars | Thymeleaf] in templates directory extending base layout
- **Unsubscribe**: Token-based unsubscribe link in email footer for optional emails

#### Payments — Subscription + Credit Points — IF FEATURE_PROFILE includes payments
- **Billing model**: Subscription (monthly/yearly) gives credit points, NOT unlimited access
- If India-focused → Razorpay Subscriptions for recurring plan billing
- If global → research best payment gateway (Stripe, Razorpay, etc.)
- Credit points deducted per action (especially GenAI calls with compute cost)
- Top-up point packs via one-time purchase when points exhaust mid-cycle
- 7-day free trial with moderate free points (agent auto-calculates based on cost)
- Webhooks for subscription lifecycle + payment confirmation
- Signature verification (HMAC SHA256) — MANDATORY
- If India-focused: Currency INR (₹), amounts stored in paisa, GST 18%
- ❌ Subscription NEVER means unlimited access

#### Databases (Conditional)
- **MongoDB** via [PyMongo | Mongoose | Spring Data MongoDB] — IF FEATURE_PROFILE includes MongoDB: [list entities — flexible: profiles, audit logs, analytics]
- **Redis** via [redis.asyncio | ioredis | Spring Data Redis] — IF FEATURE_PROFILE includes Redis: JWT blacklist, rate limiting, OTP codes, caching

### Frontend — Web (if applicable)
- Next.js 15+ (App Router) + TypeScript strict + Tailwind CSS 4+
- **UI Library**: Agent chooses best based on market research:
  - shadcn/ui + Radix (SaaS dashboards, B2B) — RECOMMENDED default
  - Ant Design (data-heavy enterprise apps)
  - MUI (Material Design consumer apps)
  - Chakra UI (clean minimal startups)
  - Mantine (feature-rich complex apps)
- Framer Motion (animations, page transitions, micro-interactions)
- React Hook Form + Zod (type-safe forms)
- TanStack Query (server state) + Zustand (global state)
- Sonner (toast notifications), Lucide React (icons)
- Dark mode (next-themes) — mandatory
- Axios with withCredentials: true
- Auth state from /auth/me endpoint
- ❌ NO localStorage/sessionStorage for tokens

### Frontend — Mobile (if React Native needed)
- React Native 0.83+ with Expo SDK 55+ (New Architecture only)
- NativeWind (Tailwind for RN) or React Native Paper
- React Navigation 7 — **ALWAYS: Side Drawer + Bottom Tab Bar**
  - Bottom tabs: 4-5 core screens (always visible)
  - Side drawer: Secondary nav (settings, help, profile, logout)
  - Stack navigators inside each tab (list → detail flow)
- Reanimated 3 + Gesture Handler (60fps animations)
- expo-secure-store for auth tokens (NEVER AsyncStorage)

#### Mobile Project Config
- app.config.ts — dynamic Expo config (bundleIdentifier, package name, splash, icons, plugins)
- eas.json — EAS Build profiles (development, preview, production)
- babel.config.js — Babel presets + NativeWind plugin
- metro.config.js — Metro bundler customization (asset extensions, resolvers)
- tailwind.config.js — NativeWind Tailwind config (mobile-specific breakpoints)

#### Mobile Auth
- expo-secure-store for JWT tokens (access + refresh) — NEVER AsyncStorage or cookies
- expo-auth-session for Google OAuth (opens system browser, handles redirect)
- expo-apple-authentication — REQUIRED for iOS (Apple rejects apps without Apple Sign-In if other social logins exist)
- expo-local-authentication for biometrics (Face ID / Touch ID / fingerprint unlock)
- Token auto-refresh interceptor in Axios (intercept 401 → refresh → retry)

#### Mobile UI Libraries
- @gorhom/bottom-sheet — native-quality bottom sheets with snap points
- react-native-toast-message — toast notifications (success/error/info)
- expo-haptics — haptic feedback on button presses, swipes, confirmations
- react-native-skeleton-placeholder — skeleton loading screens (not spinners)
- expo-image — performant cached image component (replaces React Native Image)
- @shopify/flash-list — high-performance list rendering (ALWAYS use instead of FlatList)
- react-native-safe-area-context — SafeAreaView on ALL screens (no notch/island clipping)
- KeyboardAvoidingView — wrap all forms (behavior="padding" iOS, behavior="height" Android)

#### Mobile Media
- expo-camera — camera access for photo/video capture
- expo-image-picker — gallery + camera image selection with cropping
- expo-file-system — file read/write, download management, cache directory
- expo-sharing — native share sheet for files and content
- expo-av — audio/video playback and recording

#### Device Features
- expo-location — GPS coordinates, geofencing, background location
- expo-contacts — access device contacts (with permission)
- expo-clipboard — copy/paste programmatic access
- expo-linking — deep link handling + opening external URLs
- expo-device — device info (model, OS version, brand)
- expo-network — network state (wifi/cellular/offline), connection type
- expo-haptics — tactile feedback for interactions (light/medium/heavy impact)

#### Offline Support
- @react-native-community/netinfo — real-time connectivity monitoring
- TanStack Query persistQueryClient — persist query cache to AsyncStorage for offline reads
- Offline mutation queue — queue POST/PUT/DELETE requests when offline, replay when online
- Show offline banner when no connectivity (non-dismissable, top of screen)

#### Mobile Security
- Certificate pinning — pin backend TLS certificate to prevent MITM attacks
- Root/jailbreak detection — detect compromised devices, warn or restrict
- Code obfuscation — ProGuard (Android) + Hermes bytecode (iOS) for reverse-engineering protection
- Secure store — all sensitive data (tokens, keys) in expo-secure-store (Keychain iOS / Keystore Android)
- ❌ NEVER store tokens in AsyncStorage (unencrypted, accessible by other apps on rooted devices)

#### Mobile Performance
- Hermes engine — ENABLED by default (faster startup, lower memory, bytecode precompilation)
- FlashList — use @shopify/flash-list for ALL scrollable lists (2x faster than FlatList)
- expo-image caching — automatic disk + memory cache with blurhash placeholders
- Bundle analysis — react-native-bundle-visualizer for identifying large dependencies
- Avoid inline styles — use NativeWind classes or StyleSheet.create
- useMemo/useCallback for expensive computations and callback props

#### Mobile Accessibility
- accessibilityLabel on ALL touchable elements (buttons, links, icons)
- accessibilityRole — set correct role (button, link, header, image, text)
- 44x44pt minimum touch targets — Apple HIG requirement (no tiny buttons)
- Dynamic font scaling — support system font size preferences (accessibilityFontScale)
- accessibilityHint for non-obvious actions
- Reduce motion support — check useReducedMotion() before animations

#### Mobile Testing
- Jest + React Native Testing Library (RNTL) — unit + component tests
- Detox E2E — end-to-end testing on iOS simulator + Android emulator
- Device matrix — test on iPhone SE (small), iPhone 15 Pro (large), Pixel 5, Samsung Galaxy
- Test on both iOS and Android before every release

#### Mobile CI/CD
- EAS Build — cloud builds for iOS + Android (no local Xcode/Android Studio required)
- EAS Submit — automated submission to App Store Connect + Google Play Console
- EAS Update — OTA (over-the-air) JavaScript updates without app store review
- Code signing — Apple provisioning profiles + Android keystore managed by EAS
- TestFlight — iOS beta distribution to testers
- Play Store internal track — Android beta distribution to testers

#### App Store Readiness
- **iOS Checklist:**
  - Apple Sign-In MANDATORY (if any other social login exists — Apple will reject without it)
  - App Privacy Nutrition Labels (declare data collection in App Store Connect)
  - 6.7" + 5.5" screenshots required (iPhone 15 Pro Max + iPhone 8 Plus)
  - App Review guidelines compliance (no web-view-only apps, no misleading metadata)
- **Android Checklist:**
  - Target SDK 34+ (Google Play requirement)
  - Data Safety Form (declare data collection in Play Console)
  - 16:9 screenshots + 7" tablet screenshots
  - Content rating questionnaire completed
- **OTA Updates:** EAS Update for instant JS bundle fixes (no store review delay)
- **Versioning:** Semantic versioning (major.minor.patch) + buildNumber auto-increment via EAS

### GenAI / Agentic AI (if product has AI features)
- LiteLLM v1.81+ — unified LLM gateway (OpenAI, Claude, Gemini, Mistral, Bedrock, Ollama)
- Agentic framework: Google ADK v0.5+ / LangGraph / CrewAI v0.152+ (pick based on use case)
- Claude Agent SDK / OpenAI Agents SDK (if provider-specific agents needed)
- MCP (Model Context Protocol) — agent-to-tool communication standard
- MCP Prompts & Tools Server — expose reusable prompts via prompts/list + prompts/get, tools via tools/list + tools/call (Linux Foundation open standard)
- A2A (Agent-to-Agent Protocol) — agent discovery via Agent Cards (/.well-known/agent.json), task lifecycle management, supported by 150+ organizations (Google-led open standard)
- Agent Skills Standard — reusable SKILL.md packaging for AI agent capabilities, skill registry and discovery
- RAG: Qdrant (vector DB) + text-embedding-3-large + semantic chunking
- Prompt management: [Jinja2 | Handlebars | Thymeleaf]/YAML templates (version-controlled, not hardcoded)
- Streaming: SSE for token-by-token AI responses
- AI observability: Langfuse or LangSmith for LLM tracing
- Guardrails: input/output filtering, PII detection, cost caps per user
- Cost tracking: every LLM call deducts credit points (integrated with billing)
- AI Evaluation: DeepEval (LLM unit tests, pytest-compatible) + RAGAS (RAG quality metrics) + promptfoo (prompt A/B testing)
- Structured Output: [instructor+Pydantic | zod+langchain | Jackson+Spring AI] for validated LLM output extraction (auto-retry on validation failure)
- Semantic Caching: Redis + embedding cosine similarity (threshold > 0.95) — skip redundant LLM calls
- Agentic RAG: retrieval agent dynamically decides which knowledge bases to query, whether to do web search, whether to decompose complex queries into sub-queries
- Re-ranking: Cohere Rerank v3.5 / FlashRank after vector retrieval — retrieve(top_k=20) → rerank(top_n=5) → generate
- Multi-Modal AI: Vision (GPT-4o/Gemini/Claude), Image gen (DALL-E 3/Flux), TTS (OpenAI TTS / Gemini TTS / ElevenLabs), STT (Whisper) — all via LiteLLM
- Human-in-the-Loop (HITL): confidence threshold, review queue, approve/reject/edit workflow, feedback → fine-tuning
- Context Window Management: tiktoken token counting, auto-summarization when exceeding threshold, sliding window
- Voice AI: Whisper STT + OpenAI TTS / Gemini TTS / ElevenLabs, WebSocket audio streaming
- Batch AI Processing: [Celery tasks | Bull queues | Spring Batch] for bulk operations, Redis progress tracking, rate-limited batch processing

### Theme / Appearance Support (MANDATORY — All Products)
- **Minimum 3 themes**: Light Mode + Dark Mode + System Auto
- Web: next-themes + Tailwind `dark:` variant + CSS variables
- Mobile: useColorScheme() + ThemeProvider + NativeWind dark variant
- Theme toggle in navbar/settings (sun/moon/system icons)
- User theme preference persisted in DB (syncs across devices)
- All components use theme tokens — NEVER hardcoded colors
- Charts, images, code blocks — all theme-aware
- ❌ NEVER ship without dark mode support
- ❌ NEVER have white flash on dark mode page load

### Additional Infrastructure (Include per FEATURE_PROFILE)
Include each bullet ONLY if the product needs it. Do NOT include Meilisearch for a project without search, do NOT include FCM for a project without mobile, etc.
- **File Upload**: S3/GCS via [boto3 | @aws-sdk/client-s3 | AWS SDK for Java], presigned URL pattern, [Pillow | sharp | thumbnailator] for image processing, MinIO for local dev — IF product needs file uploads
- **Search**: Meilisearch (full-text search, typo tolerance, faceted), Cmd+K command palette in frontend — IF product needs full-text search
- **Real-Time**: [FastAPI WebSocket+python-socketio | @nestjs/websockets+socket.io | Spring WebSocket+STOMP], Redis pub/sub for scaling, live notifications/chat — IF product needs live updates
- **Push Notifications**: Firebase Cloud Messaging ([firebase-admin | firebase-admin SDK | firebase-admin Java SDK]), expo-notifications for mobile — IF product has mobile app
- **Error Tracking**: Sentry ([sentry-sdk[fastapi] | @sentry/node | sentry-spring-boot-starter], @sentry/nextjs, sentry-expo) — recommended for all production apps
- **Analytics**: PostHog (self-hosted, privacy-first) — event tracking, funnels, retention — IF product needs analytics
- **i18n**: next-intl (web) + i18next + expo-localization (mobile) — IF product needs multi-language
- **PWA**: next-pwa — service worker, install prompt, offline fallback — IF product needs offline web
- **CDN**: CloudFront/Cloud CDN for static assets + uploaded files — IF product serves static/uploaded content

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
