# Auto-Build Reference: Phase Definitions (1-15)

> **This file is referenced by `/auto-build` command.** Do NOT invoke this file directly.
> It contains detailed instructions for each build phase (1-15).
> Agent subagents receive relevant phase content when delegated a phase.

---

## PHASE 1: PROJECT SCAFFOLD

**⚡ DELEGATE TO SUBAGENT** — do NOT write scaffold code in main context.

Spawn an Agent subagent (mode = "bypassPermissions") with these instructions:
- **FIRST** create `.claude/settings.local.json` in the project root with autonomous permissions:
  ```json
  {
    "permissions": {
      "allow": ["Bash", "Read", "Edit", "Write", "Glob", "Grep", "WebFetch", "Agent", "MCP"]
    }
  }
  ```
- Create entire folder structure from LANG_PROFILE
- Python: ALWAYS `python3 -m venv venv && source venv/bin/activate` FIRST (MANDATORY). ❌ NEVER install globally.
- NestJS: `pnpm install` | Spring Boot: `./gradlew build`
- Create config files: pyproject.toml (ruff + mypy + pytest), .env.example, Makefile, CLAUDE.md
- **Verify:** `ruff check app/ && python -c "from app.main import app"`
- **Commit:** `feat(scaffold): initialize project with Alpha AI structure`

In main context after subagent returns: confirm scaffold created, move to Phase 2.

## PHASE 2: DATABASE CONNECTIONS

**⚡ DELEGATE TO SUBAGENT** — spawn Task for DB setup.

Subagent creates: app/db/mysql.py, app/db/mongodb.py, app/db/redis.py, app/config.py, docker-compose.yml.
**Commit:** `feat(db): configure MySQL + MongoDB + Redis async connections`

## PHASE 3: DATA MODELS

**⚡ DELEGATE TO SUBAGENT(S)** — spawn 1-2 Tasks (SQL models + NoSQL schemas can be parallel).

SQLAlchemy models in models/sql/, PyMongo document schemas in models/nosql/, Redis keys in models/cache/.
Alembic init + first migration.
**Commit:** `feat(models): define data models across all databases`

## PHASE 4: REPOSITORY LAYER

**⚡ DELEGATE TO SUBAGENT** — spawn Task for repo layer.

CRUD repos for sql/, nosql/, cache/. Generic BaseRepository. Pure data access, NO logic.
**Commit:** `feat(repos): implement repository layer`

## PHASE 5: SERVICE LAYER

**⚡ DELEGATE TO SUBAGENT** — spawn Task for services.

Business logic services. Call repos, never touch DB directly. Never import from api/.
**Commit:** `feat(services): implement business logic services`

## PHASE 6: AUTH SYSTEM (Complete)

**⚡ DELEGATE TO SUBAGENT** — spawn Task for auth (this is the largest single phase, give subagent full context).

**HARD RULE: ALL auth verification MUST happen in the MIDDLEWARE layer — NEVER in individual routes/controllers.**
- **Python/FastAPI**: Create `app/core/auth_middleware.py` (AuthMiddleware) that validates JWT from HTTP-Only cookie, checks Redis blacklist, attaches user to `request.state.user`. Public routes configured in middleware. Routes access user via `request.state.user` — NEVER via `Depends(get_current_user)` for auth.
- **NestJS**: Register `JwtAuthGuard` as `APP_GUARD` globally in AppModule. Add `@Public()` decorator + `IS_PUBLIC_KEY` metadata for exempt routes. Controllers use `@CurrentUser()` — NEVER `@UseGuards(JwtAuthGuard)` per controller.
- **Spring Boot**: `SecurityFilterChain` + `JwtAuthFilter` handles all auth. Route matchers define public/protected/admin paths. NEVER use `@PreAuthorize("isAuthenticated()")` — it's redundant. `@PreAuthorize` is ONLY for granular RBAC (`hasPermission()`).

JWT + HTTP-Only Cookies. CSRF. Token blacklist in Redis. Full flow: register/login/refresh/logout.
Google OAuth2 social login: GET /auth/google → callback → JWT cookies.
2FA/TOTP: Enable/disable 2FA, QR code generation, backup codes, verify on login.
Session Management: Track active sessions (device, IP, location), revoke sessions.
RBAC: Roles table, permissions table, role_permissions join — enforced via middleware guards (global), NOT per-route.
Transactional email setup: email_service.py, Celery email tasks, ALL 17 Jinja2 email templates.
**Commit:** `feat(auth): JWT middleware + Google OAuth2 + 2FA + RBAC + session management + email system`

## PHASE 6.5: SUBSCRIPTION + CREDIT POINT SYSTEM (India SaaS — Razorpay)

**⚡ DELEGATE TO SUBAGENT** — this is a large phase, spawn Task with all file details below.

Setup Razorpay subscription + credit point billing end-to-end:
1. `app/core/razorpay_client.py` — Razorpay SDK client init, signature verification, webhook verification
2. `app/core/point_costs.py` — Action → point cost mapping (agent auto-generates based on product features + compute cost)
3. `app/models/sql/subscription.py` — Subscription model (razorpay_sub_id, plan_id, user_id FK, status, cycle_start, cycle_end, point_allocation)
4. `app/models/sql/credit_balance.py` — CreditBalance model (user_id FK UNIQUE, plan_points, topup_points, total_balance)
5. `app/models/sql/point_transaction.py` — PointTransaction model (user_id FK, type=PLAN_CREDIT|TOPUP_CREDIT|DEBIT|TRIAL_CREDIT, action, cost, balance_after, created_at)
6. `app/models/sql/topup_order.py` — TopupOrder model (razorpay_order_id, pack_id, amount_paisa, currency=INR, status, user_id FK)
7. `app/models/sql/invoice.py` — Invoice model (invoice_number, subtotal_paisa, gst_rate=18, gst_paisa, total_paisa, user_id FK, source=SUBSCRIPTION|TOPUP)
8. `app/models/nosql/webhook_log.py` — MongoDB document for raw webhook payloads
9. `app/schemas/subscription.py` — CreateSubscriptionRequest(plan_id, billing_cycle), SubscriptionResponse, PlanResponse(with point_allocation)
10. `app/schemas/points.py` — PointBalanceResponse, TopupRequest(pack_id), TopupVerifyRequest, UsageHistoryResponse
11. `app/repositories/sql/subscription_repo.py`, `credit_balance_repo.py`, `point_transaction_repo.py`, `topup_order_repo.py`, `invoice_repo.py`
12. `app/services/subscription_service.py` — create_subscription(), cancel(), upgrade(), downgrade(), handle_renewal()
13. `app/services/point_service.py` — check_balance(), deduct_points(), credit_plan_points(), credit_topup(), credit_trial(), get_usage_history(), reconcile_balances()
14. `app/services/invoice_service.py` — generate_invoice(), calculate_gst(), download_invoice_pdf()
15. `app/services/webhook_service.py` — process_razorpay_webhook(), handle_subscription_activated(), handle_subscription_charged(), handle_subscription_cancelled(), handle_payment_failed()
16. `app/api/deps.py` — Add `require_points(cost: int)` dependency that checks balance before action
17. `app/tasks/payment_tasks.py` — Celery tasks: webhook processing, invoice PDF, daily point reconciliation, low-balance notifications, trial expiry checks
18. Free trial setup in registration flow: credit auto-calculated free points on signup
19. Alembic migrations for all payment/point tables
**Commit:** `feat(payments): Razorpay subscription + credit point system with trial and top-ups`

## PHASE 6.8: FILE UPLOAD + SEARCH + NOTIFICATIONS

**⚡ DELEGATE TO SUBAGENT** — spawn Task for file/search/notification infra.

1. File Upload: storage_service.py with S3/GCS abstraction, presigned URL pattern, image processing (Pillow thumbnails)
2. Search: Meilisearch integration, search_service.py, index sync via Celery tasks on entity CRUD
3. In-App Notifications: MongoDB notification collection, notification_service.py, WebSocket push to connected clients
4. Push Notifications: FCM integration via firebase-admin, device token storage, push_service.py + push_tasks.py
5. WebSocket Manager: websocket_manager.py with Redis pub/sub for multi-instance scaling
**Commit:** `feat(infra): file upload + search + notifications + real-time WebSocket`

## PHASE 7: API LAYER

**⚡ DELEGATE TO SUBAGENT** — spawn Task for all API routes.

Thin routes. Validate → call service → return response. Versioned under /api/v1/.
**Auth is handled by middleware — routes do NOT check auth.** Routes access user from request context (request.state.user / @CurrentUser() / @AuthenticationPrincipal). Public routes are configured in middleware, not per-route.
Include ALL endpoints: billing (subscriptions, points, invoices, webhooks), notifications (list, read, unread-count), search (full-text), feedback (submit), account (export, delete, consent), feature flags (user's flags), onboarding (status, step), upload (presigned-url, confirm).
Admin API: /api/v1/admin/ routes — user management, subscription management, analytics, feature flags CRUD, feedback viewer, system health.
Rate limiting per plan tier (Redis sliding window) + require_points() dependencies. RBAC permissions enforced via middleware guards.
**Commit:** `feat(api): REST API endpoints + admin panel + rate limiting`

## PHASE 7.5: GRAPHQL LAYER

**⚡ DELEGATE TO SUBAGENT** — spawn Task for GraphQL layer.

Strawberry GraphQL schema, types auto-generated from Pydantic schemas, resolvers calling services, mutations for write operations, DataLoaders for N+1 prevention, WebSocket subscriptions for real-time. Mount at `/graphql`. Auth via cookie context.
**Commit:** `feat(graphql): GraphQL API alongside REST`

## PHASE 8: MIDDLEWARE + ERROR TRACKING + LOGGING

**⚡ DELEGATE TO SUBAGENT** — spawn Task for middleware + logging.

CORS, CSRF double-submit, rate limiting per plan (Redis sliding window), structured logging with request ID.
Sentry integration (sentry-sdk[fastapi]) for error tracking + performance monitoring.
Centralized logging: structlog → JSON, request_id propagation, audit trail to MongoDB.
API rate limit headers (X-RateLimit-Limit/Remaining/Reset) on every response.
GZip compression middleware for API responses.
**Commit:** `feat(middleware): CORS, CSRF, rate limiting, Sentry, logging`

## PHASE 9: FRONTEND (if needed)

**⚡ DELEGATE TO SUBAGENT(S)** — spawn 1-3 Tasks (infrastructure, pages, and polish can be parallel).

**CRITICAL**: Load these 3 files before writing ANY frontend code:
- `skills/alpha-architecture/references/CODE_PATTERNS_FRONTEND_CORE.md` — architecture, routes, providers, middleware, page state
- `skills/alpha-architecture/references/CODE_PATTERNS_FRONTEND_PAGES.md` — dashboard layout, 6 page templates
- `skills/alpha-architecture/references/CODE_PATTERNS_FRONTEND_UX.md` — reusable components, skeletons, animations, dark mode
Follow Page State Pattern, Dashboard Layout, and component patterns EXACTLY.

**FIRST**: Read `BRAND_GUIDE.md` and configure Tailwind with brand design tokens (colors, fonts, spacing, shadows, border-radius).
Generate favicon, OG images, and PWA manifest with brand identity.
Apply brand colors, typography, and styling consistently across ALL pages and components.

### Phase 9a: Project Setup

```bash
npx create-next-app@latest frontend --typescript --tailwind --eslint --app --src-dir=false --import-alias="@/*"
cd frontend
```

Install dependencies:
```bash
# UI Components
npx shadcn@latest init
pnpm add @tanstack/react-query @tanstack/react-query-devtools

# Forms & Validation
pnpm add react-hook-form @hookform/resolvers zod

# Data Table
pnpm add @tanstack/react-table

# Toast & Feedback
pnpm add sonner

# Animation
pnpm add framer-motion

# Charts
pnpm add recharts

# Icons
pnpm add lucide-react

# HTTP Client
pnpm add axios

# Theme
pnpm add next-themes

# Utilities
pnpm add date-fns clsx tailwind-merge

# Command Palette
pnpm add cmdk
```

Configure `tailwind.config.ts` with BRAND_GUIDE tokens:
- Extend colors with brand primary, secondary, accent
- Extend fontFamily with brand fonts
- Extend borderRadius, spacing, shadows from brand guide
- Add CSS variables for light/dark theme tokens in globals.css

**Commit:** `feat(frontend): Next.js project setup with all dependencies`

### Phase 9b: Core Infrastructure

Create the foundational infrastructure — follow CODE_PATTERNS_FRONTEND_CORE.md exactly:

1. **`lib/api.ts`** — Axios instance with:
   - `baseURL` from env (NEXT_PUBLIC_API_URL)
   - `withCredentials: true` on EVERY request (HTTP-Only cookie auth)
   - Response interceptor: 401 → attempt token refresh → retry original request
   - Response interceptor: extract user-friendly error messages
   - CSRF token from non-httponly cookie → X-CSRF-Token header

2. **`lib/query-client.ts`** — TanStack Query client with default options (staleTime, retry, refetchOnWindowFocus)

3. **`providers/index.tsx`** — Provider composition hierarchy:
   ThemeProvider → QueryClientProvider → Toaster → ReactQueryDevtools

4. **`hooks/useAuth.ts`** — Auth hook:
   - `useQuery` to GET /auth/me on mount
   - Returns: { user, isLoading, isAuthenticated, logout }
   - logout: POST /auth/logout → invalidate queries → redirect to /login
   - NEVER stores tokens in JS — relies on HTTP-Only cookies

5. **`middleware.ts`** — Auth redirect logic (SINGLE source of truth for auth):
   - Public routes pass through
   - Unauthenticated on protected route → redirect /login?callbackUrl=
   - Authenticated on /login or /register → redirect /dashboard
   - Admin role check via JWT payload decode
   - **HARD RULE**: ALL auth verification happens in middleware.ts ONLY
   - NEVER check auth/roles in page components, useEffect redirects, or ProtectedRoute wrappers
   - Pages use useAuth() for user DATA only (name, avatar, logout action) — NOT for route protection

6. **`app/layout.tsx`** — Root layout with Providers, fonts, metadata

7. **Theme setup** — CSS variables in globals.css for light/dark, next-themes ThemeProvider

**Commit:** `feat(frontend): core infrastructure — API client, providers, auth, middleware`

### Phase 9c: Layouts

Create layouts for each route group — follow CODE_PATTERNS_FRONTEND_PAGES.md Dashboard Layout pattern:

1. **`app/(dashboard)/layout.tsx`** — Dashboard layout:
   - Collapsible sidebar (icon-only mode on desktop, overlay drawer on mobile)
   - Navigation items with Lucide icons + active state highlighting
   - Header with: breadcrumbs, Cmd+K search trigger, notification bell (badge), theme toggle, user dropdown (profile, settings, logout)
   - Content area with scroll container
   - User info at sidebar bottom

2. **`app/(auth)/layout.tsx`** — Auth layout:
   - Centered card on gradient/pattern background
   - App logo at top
   - No sidebar, no header

3. **`app/(marketing)/layout.tsx`** — Marketing layout:
   - Top navbar with logo + nav links + CTA button
   - Footer with links, social, legal

4. **`app/(admin)/layout.tsx`** — Admin layout:
   - Similar to dashboard but with admin-specific navigation
   - "Admin Panel" badge in header

5. **`app/(legal)/layout.tsx`** — Legal layout:
   - Simple centered content with max-width
   - Back link to home

Add `loading.tsx` and `error.tsx` to EVERY route group.

**Commit:** `feat(frontend): route group layouts — dashboard, auth, marketing, admin, legal`

### Phase 9d: Reusable Components

Create shared components — follow CODE_PATTERNS_FRONTEND_UX.md Reusable Components section:

1. **`components/shared/page-header.tsx`** — Title + description + action button(s)
2. **`components/shared/data-table.tsx`** — Generic TanStack Table wrapper with sorting, filtering, pagination, row selection, responsive (table on desktop, cards on mobile)
3. **`components/shared/form-field.tsx`** — Label + input + error + description, integrates with React Hook Form
4. **`components/shared/empty-state.tsx`** — Icon + title + description + action button
5. **`components/shared/confirm-dialog.tsx`** — "Are you sure?" with cancel/confirm, loading state
6. **`components/shared/search-input.tsx`** — Debounced search with Cmd+K hint, clear button
7. **`components/shared/pagination.tsx`** — Page numbers + prev/next + items per page
8. **`components/shared/stat-card.tsx`** — Metric card with title, value, trend, change%
9. **`components/shared/skeletons.tsx`** — PageSkeleton, TableSkeleton, CardSkeleton, FormSkeleton, DashboardSkeleton
10. **`components/shared/command-palette.tsx`** — Cmd+K command palette with cmdk

All components: responsive, dark mode compatible, accessible (ARIA labels, keyboard nav, focus rings).

**Commit:** `feat(frontend): reusable components — PageHeader, DataTable, FormField, EmptyState, etc.`

### Phase 9e: Auth Pages

Create auth pages — follow CODE_PATTERNS_FRONTEND_PAGES.md Auth Pages pattern:

1. **Login** (`app/(auth)/login/page.tsx`):
   - Email + password fields (React Hook Form + Zod)
   - "Sign in with Google" button → redirect to GET /api/v1/auth/google
   - "Remember me" checkbox
   - "Forgot password?" link
   - "Don't have an account? Register" link
   - Loading state on submit, error display
   - Redirect to callbackUrl on success

2. **Register** (`app/(auth)/register/page.tsx`):
   - Name + email + password + confirm password
   - "Sign up with Google" button
   - Terms of Service checkbox
   - Redirect to email verification on success

3. **Forgot Password** (`app/(auth)/forgot-password/page.tsx`):
   - Email input → send reset link
   - Success state: "Check your email"

4. **Reset Password** (`app/(auth)/reset-password/page.tsx`):
   - New password + confirm (with token from URL)

5. **Verify Email** (`app/(auth)/verify-email/page.tsx`):
   - Auto-verify from URL token, show success/error

**Commit:** `feat(frontend): auth pages — login, register, forgot/reset password, verify email`

### Phase 9f: Dashboard & CRUD Pages

Create all dashboard pages — EVERY page MUST follow Page State Pattern (Loading → Error → Empty → Data):

1. **Dashboard Home** (`app/(dashboard)/page.tsx`):
   - Stats cards row (4 cards: revenue/users/orders/growth with trend arrows)
   - Area chart (Recharts) showing trends
   - Recent activity list
   - Quick actions grid

2. **Entity List Pages** (`app/(dashboard)/[entity]/page.tsx`):
   - PageHeader with title + "Create New" button
   - Search bar (debounced) + filter dropdowns
   - DataTable with sortable columns, row actions (view/edit/delete), bulk selection
   - Pagination
   - Empty state: "No [entities] yet. Create your first one."
   - Mobile: card layout instead of table

3. **Entity Detail Pages** (`app/(dashboard)/[entity]/[id]/page.tsx`):
   - Breadcrumbs: Dashboard > Entities > Entity Name
   - PageHeader with title + actions dropdown (edit, delete, duplicate)
   - Tabbed content (Overview, Activity, Settings)
   - Delete confirmation dialog

4. **Entity Create/Edit Pages** (`app/(dashboard)/[entity]/new/page.tsx` and `[id]/edit/page.tsx`):
   - React Hook Form + Zod schema
   - All field types: text, textarea, select, checkbox, date, file upload
   - Inline validation errors
   - Submit: loading state → success toast + redirect
   - Unsaved changes warning

Include Razorpay + Credit Point UI:
- Load Razorpay checkout script
- **Credit point balance widget** in navbar/header (always visible: "⚡ 4,230 pts remaining")
- **Usage dashboard** — daily/weekly point consumption chart, action breakdown
- **Low balance alert banner** — "You have X points left. Buy top-up or upgrade plan."
- **Top-up purchase modal** — select pack, pay via Razorpay Checkout (one-time order)
- **402 Payment Required handler** — intercept 402, show upgrade/topup modal
- Invoice history page with GST breakdown and PDF download
- Plan management page (current plan, upgrade/downgrade, cancel, renewal date)

**Commit:** `feat(frontend): dashboard home, CRUD pages, billing UI with Razorpay`

### Phase 9g: Settings & Profile

Create settings pages — follow CODE_PATTERNS_FRONTEND_PAGES.md Settings Page pattern:

- **Tab navigation** (vertical sidebar on desktop, horizontal tabs on mobile):
  - **Profile**: Avatar upload + name + email + bio
  - **Security**: Change password form + 2FA toggle (QR code + TOTP) + active sessions list (with revoke)
  - **Notifications**: Toggle switches for email preferences (weekly summary, low balance, login alerts, marketing)
  - **Appearance**: Theme selector (light/dark/system) + language picker
  - **Billing**: Current plan card + upgrade/downgrade + payment method + invoice history
  - **Data**: Export my data button + delete account (with confirmation)

Each tab saves independently. Toast feedback on save.
Google OAuth callback handler (frontend catches redirect after successful Google auth).
Email notification preferences page (user can toggle: weekly summary, low balance alerts, login alerts).
Unsubscribe from emails via token link in email footer.

**Commit:** `feat(frontend): settings pages — profile, security, notifications, appearance, billing, data`

### Phase 9h: Admin Panel

Create admin section in `(admin)` route group — protected by admin role:

1. **User Management**: DataTable of users + search + filter by role/status + edit user + ban/unban
2. **Analytics Dashboard**: charts for signups, revenue, active users, retention
3. **Feature Flags**: toggle table with name, description, enabled %, rollout strategy
4. **Feedback Review**: list of user feedback with status (new/reviewed/resolved), reply functionality

**Commit:** `feat(frontend): admin panel — users, analytics, feature flags, feedback`

### Phase 9i: Marketing & Legal

1. **Landing Page** (`app/(marketing)/page.tsx`):
   - Hero section with CTA
   - Feature grid (3-4 columns)
   - Social proof / testimonials
   - Pricing preview
   - Final CTA

2. **Pricing Page** (`app/(marketing)/pricing/page.tsx`):
   - Plan cards (Basic/Pro/Enterprise) with monthly/yearly toggle
   - Point allocation per plan
   - Feature comparison table
   - Razorpay subscription checkout flow

3. **Legal Pages** (`app/(legal)/[slug]/page.tsx`):
   - Terms of Service, Privacy Policy, Cookie Policy, Refund Policy
   - MDX content or rich text
   - Table of contents sidebar

4. **Cookie Consent Banner**: GDPR/EU compliant, accept/reject/customize

**Commit:** `feat(frontend): landing, pricing, legal pages, cookie consent`

### Phase 9j: Polish & Quality

1. **Error Pages**: Branded 404 (`not-found.tsx`), 500 (`global-error.tsx`), offline page
2. **Cmd+K Search**: Command palette powered by Meilisearch — keyboard shortcut, search results, navigation, recent items
3. **Notification Center**: Bell icon in header → dropdown list with badge count, mark as read, click to navigate, paginated
4. **Onboarding Flow**: Welcome modal → guided product tour → setup checklist for first-time users
5. **PWA Support**: Service worker, install prompt, offline fallback, manifest.json with brand colors
6. **i18n**: next-intl for multi-language (English + Hindi minimum), language switcher in settings
7. **Social Sharing**: OG meta tags per page, share buttons (native Web Share API), generateMetadata() on all pages
8. **Feedback Widget**: Floating button (bottom-right) → slide-out form (bug/feature/support)
9. **Empty States**: EVERY page with no data shows illustration + helpful CTA
10. **Deep Links**: Configure for React Native (Universal Links + App Links) if mobile app exists

**Commit:** `feat(frontend): polish — error pages, Cmd+K, notifications, onboarding, PWA, i18n`

### Phase 9k: Frontend Verification

Run comprehensive quality check on EVERY page:

```
╔═══════════════════════════════════════════════════════════════╗
║  FRONTEND QUALITY VERIFICATION                                ║
╠═══════════════════════════════════════════════════════════════╣
║  For EVERY page, verify:                                      ║
║                                                               ║
║  □ Responsive: renders correctly 320px → 2560px               ║
║  □ Dark mode: all elements themed (no white flash)            ║
║  □ Loading state: content-shaped skeleton (never spinner)     ║
║  □ Error state: retry button + user-friendly message          ║
║  □ Empty state: illustration + CTA (never blank page)         ║
║  □ SEO: generateMetadata() + OG tags                          ║
║  □ Forms: React Hook Form + Zod + inline validation + toast   ║
║  □ Keyboard: Tab order, focus rings, Enter to submit          ║
║  □ Accessibility: ARIA labels, alt text, color contrast       ║
║  □ Performance: no layout shift, images optimized             ║
║  □ error.tsx exists in every route group                       ║
║  □ loading.tsx exists in every route group                     ║
║                                                               ║
║  Run: pnpm build — zero errors, zero type errors              ║
║  Run: pnpm lint — zero warnings                               ║
╚═══════════════════════════════════════════════════════════════╝
```

Fix any issues found during verification before proceeding.

**Commit:** `feat(frontend): complete Next.js with all modern features and quality verification`

## PHASE 9.5: MOBILE APP (if React Native needed)

**⚡ DELEGATE TO SUBAGENT(S)** — spawn 2-3 Tasks (setup+nav, screens+UI, push+offline can be parallel).

### Step 9.5.1: Project Setup
- Initialize Expo project: `npx create-expo-app@latest [name] --template blank-typescript`
- Create `app.config.ts` with: name, slug, version, scheme, ios.bundleIdentifier, android.package, plugins, splash, icon, adaptiveIcon
- Create `eas.json` with development/preview/production build profiles
- Create `babel.config.js` with expo preset + nativewind/babel + reanimated/plugin (LAST)
- Create `metro.config.js` with withNativeWind wrapper
- Create `tailwind.config.js` with NativeWind preset
- Create `.env` with EXPO_PUBLIC_API_URL, EXPO_PUBLIC_WS_URL, EXPO_PUBLIC_SENTRY_DSN
- Install EAS CLI: `npm install -g eas-cli && eas init`
- Generate app assets: icon (1024x1024), splash screen, adaptive icon
**Commit:** `feat(mobile): Expo project setup with EAS + NativeWind config`

### Step 9.5.2: Navigation + Core Layout
- Install React Navigation 7: @react-navigation/native, drawer, bottom-tabs, stack
- Install dependencies: react-native-screens, react-native-safe-area-context, react-native-gesture-handler, react-native-reanimated
- Create navigation structure: DrawerNavigator → BottomTabNavigator → StackNavigators
- Drawer items: Profile, Settings, Help & Support, About, Logout
- Bottom tabs: Home, [Feature 1], [Feature 2], Notifications, Profile
- Stack navigators inside each tab for drill-down flows
- SafeAreaView wrapping all screens
- StatusBar component adapting to theme
- TypeScript navigation types: RootStackParamList, TabParamList, DrawerParamList
**Commit:** `feat(mobile): navigation with drawer + bottom tabs + typed routes`

### Step 9.5.3: Authentication
- expo-secure-store: store/retrieve/delete JWT tokens
- Axios interceptor: read token from secure store → add Authorization header
- Auto-refresh interceptor: 401 → refresh token → retry original request
- Auth startup flow: splash → check stored token → validate → navigate
- Login screen: email/password + Google Sign-In + Apple Sign-In
- Google OAuth via expo-auth-session + expo-web-browser
- Apple Sign-In via expo-apple-authentication (iOS only, hide on Android)
- Biometric unlock via expo-local-authentication (optional, settings toggle)
- Registration screen: email/password form + social sign-up + OTP verification
- Forgot password flow: email input → OTP → new password
**Commit:** `feat(mobile): auth with Google + Apple + biometric + token refresh`

### Step 9.5.4: Core Screens + UI
- Install UI essentials: @gorhom/bottom-sheet, react-native-toast-message, expo-haptics, react-native-skeleton-placeholder, expo-image, @shopify/flash-list
- Dashboard screen with key metrics + quick actions
- Feature screens (domain-specific, from PRD)
- Notification center: FlashList + mark read + swipe to dismiss
- Profile screen: avatar, name, email, subscription status
- Settings screen: theme toggle, notifications, language, security (2FA, sessions), privacy, about
- Subscription/billing screen: current plan, point balance, upgrade, top-up
- All forms use React Hook Form + Zod
- KeyboardAvoidingView on all form screens
- Pull-to-refresh on all list screens
- Skeleton loaders on all data-loading screens
- Empty states with illustrations + CTAs
- expo-haptics on button presses, success/error actions
**Commit:** `feat(mobile): core screens with modern UX patterns`

### Step 9.5.5: Push Notifications + Real-Time
- expo-notifications: request permissions, register device token
- Send FCM token to backend: POST /devices/register
- Handle foreground notifications (in-app toast)
- Handle background notifications (system tray)
- Handle notification tap → deep link to relevant screen
- Notification categories with action buttons
- WebSocket connection: socket.io-client with JWT auth
- Real-time updates: new notifications, chat messages, data changes
- Auto-reconnect on network recovery
**Commit:** `feat(mobile): push notifications + WebSocket real-time`

### Step 9.5.6: Media, Device Features, Offline
- expo-camera: photo capture, QR scanning (if needed)
- expo-image-picker: profile photo, file uploads
- expo-file-system: download/cache files locally
- expo-sharing: share content to other apps
- expo-image: cached image loading with blurhash placeholders
- @react-native-community/netinfo: connectivity monitoring
- Offline banner: show when no internet
- TanStack Query with persistQueryClient: cache critical data offline
- Offline mutation queue: store actions → replay when online
- expo-linking: open URLs, phone, email, maps
- expo-clipboard: copy referral codes, OTPs
- expo-haptics: tactile feedback throughout app
**Commit:** `feat(mobile): media + device features + offline support`

### Step 9.5.7: Theme + i18n + Accessibility
- ThemeProvider with useColorScheme() + user preference from API
- NativeWind dark: variant for all components
- Theme toggle in Settings: Light / Dark / System
- Status bar + navigation bar adapt to theme
- expo-localization + i18next: multi-language support
- Minimum: English + Hindi (add more per market research)
- Language switcher in Settings
- All UI strings via i18n keys (NEVER hardcoded text)
- Accessibility: accessibilityLabel on all buttons/icons
- accessibilityRole on all interactive elements
- Minimum 44x44pt touch targets
- Dynamic font scaling support
**Commit:** `feat(mobile): multi-theme + i18n + accessibility`

### Step 9.5.8: Security Hardening
- Certificate pinning for API calls
- Root/jailbreak detection (warn user, optionally block)
- Disable dev menu in production builds
- Clear secure store on logout
- Auto-clear clipboard after OTP paste (10s)
- secureTextEntry on all password inputs
- App switcher blur overlay on iOS (hide sensitive content)
- No console.log in production (__DEV__ guard)
- Sentry integration: sentry-expo for crash reporting
**Commit:** `feat(mobile): security hardening + Sentry crash reporting`

### Step 9.5.9: Testing
- Jest + React Native Testing Library setup
- Test: all screens render correctly
- Test: auth flow (login, register, token refresh)
- Test: navigation (drawer, tabs, deep links)
- Test: forms (validation, submission, error states)
- Test: offline behavior (cached data, mutation queue)
- Mock: expo modules, navigation, secure store, API responses
- Detox E2E setup: login flow, core feature flow, push notification flow
- Coverage target: >80%
**Commit:** `test(mobile): comprehensive test suite`

### Step 9.5.10: App Store Preparation
- Generate app store assets: screenshots (6.7" + 5.5" + iPad)
- Write store listing: title, subtitle, description, keywords, what's new
- Configure privacy policy URL in app.config.ts
- iOS: export compliance, age rating, content rights
- Android: data safety form, content rating (IARC), target API level
- EAS Build production profiles: `eas build --platform all --profile production`
- EAS Submit setup: `eas submit --platform all`
- Beta distribution: TestFlight (iOS) + Play internal testing (Android)
- OTA updates setup: expo-updates + EAS Update channels
- App versioning: semver with auto-increment buildNumber/versionCode
**Commit:** `chore(mobile): app store readiness + EAS CI/CD pipeline`

## PHASE 10: ANALYTICS + FEATURE FLAGS + GROWTH

**⚡ DELEGATE TO SUBAGENT** — spawn Task for analytics + flags.

PostHog integration (or custom): backend event tracking via Celery + frontend auto-tracking.
Feature flags service: MySQL storage + Redis cache, admin toggle, per-plan gating.
Referral system: shareable referral links with tracking codes.
Analytics dashboard in admin panel: DAU/WAU/MAU, revenue, churn, feature adoption.
**Commit:** `feat(growth): analytics + feature flags + referral system`

## PHASE 11: TESTING

**⚡ DELEGATE TO SUBAGENT(S)** — spawn 2-3 Tasks (unit tests, E2E tests, perf tests can be parallel).

This is the most critical quality phase. Use the full testing toolchain:

### 11a. Unit + Integration Tests
Generate comprehensive test suites using `/gen-tests` patterns:
- Unit tests for ALL services (mock repositories)
- Integration tests for ALL API endpoints (use TestClient + httpx)
- Repository tests against test databases
- Target >80% coverage on ALL source code
- Mock ALL external services: Razorpay, FCM, S3, Meilisearch, Google OAuth, email

```bash
# Run test suite with coverage
pytest tests/ -v --cov=app --cov-report=term-missing --cov-fail-under=80
```

### 11b. End-to-End Tests
Generate E2E tests using `/e2e-test` patterns:
- **Web (Playwright)**: Auth flow, payment flow, CRUD operations, real-time features
- **Mobile (Detox)**: Login, navigation, push notifications, offline mode
- **Critical user journeys**: Register → Login → Use Features → Pay → Upgrade Plan

```bash
# Web E2E
npx playwright test --project=chromium
# Mobile E2E
npx detox test --configuration ios.sim.release
```

### 11c. Performance Tests (Baseline)
Run baseline performance tests using `/perf-test` patterns:
- API response time benchmarks (P50, P95, P99)
- Concurrent user load test (50 users baseline)
- Database query performance

**Commit:** `test: comprehensive unit, integration, and E2E test suite`

---

## PHASE 12: SECURITY + COMPLIANCE + POLISH

**⚡ DELEGATE TO SUBAGENT** — spawn Task for security scan + hardening.

Use `/security-scan` patterns for comprehensive security hardening:

### 12a. Security Scan
Run the full security scanning toolchain:
- **SAST**: Static analysis for vulnerabilities (bandit for Python, eslint-plugin-security for JS)
- **Secret Detection**: Scan ALL files for accidentally committed secrets
- **Dependency Audit**: Check ALL dependencies for known CVEs
- **OWASP Top 10**: Verify protection against all OWASP Top 10 vulnerabilities

### 12b. Security Hardening
- Rate limiting: Per-plan rate limits using Redis + slowapi
- CORS: Strict origin whitelist (no wildcards in production)
- CSRF: Double-submit cookie pattern
- XSS: Content Security Policy headers
- SQL Injection: Parameterized queries only (SQLAlchemy ORM)
- Auth: JWT HTTP-Only cookies ONLY (NEVER localStorage/sessionStorage)

### 12c. Error Tracking + Monitoring
- Sentry integration for backend + frontend + mobile
- Structured logging (JSON format)
- Health endpoints: /health, /ready, /health/dependencies

### 12d. Compliance
- GDPR/DPDPA: Data export endpoint, account deletion flow, consent tracking
- Backup: Celery beat for daily MySQL + MongoDB dumps to S3
- Graceful shutdown handlers
- Error pages (404, 500, 403)

**Commit:** `chore: security hardening, compliance, and error tracking`

---

## PHASE 13: DOCUMENTATION

**⚡ DELEGATE TO SUBAGENT** — spawn Task for all docs generation.

Generate comprehensive documentation using `/gen-docs` patterns:

### 13a. Core Documentation
- **README.md**: Project overview, setup instructions, tech stack, architecture overview
- **ARCHITECTURE.md**: System architecture, component diagram, data flow, layer segregation
- **API_DOCS.md**: Auto-generated from OpenAPI spec + custom endpoint documentation
- **CONTRIBUTING.md**: Development setup, coding standards, PR process, review checklist
- **CHANGELOG.md**: Auto-generated from git history using conventional commits

### 13b. Operational Documentation
Generate runbooks using `/runbook` patterns:
- **DEPLOYMENT.md**: Step-by-step deployment guide for staging and production
- **RUNBOOK.md**: Incident response procedures, common issues, escalation paths
- **BACKUP_RESTORE.md**: Database backup and restore procedures

### 13c. Supplementary Documentation
- **BRAND_GUIDE.md**: From Phase -0.5 market research
- **MARKET_RESEARCH.md**: From Phase -1 competitive analysis
- Admin panel documentation
- API authentication guide

**Commit:** `docs: comprehensive documentation suite`

---

## PHASE 14: CI/CD & DOCKER

**⚡ DELEGATE TO SUBAGENT** — spawn Task for Docker + CI/CD.

Generate production-ready CI/CD using `/gen-ci` patterns:

### 14a. Docker Setup
- **Dockerfile**: Multi-stage build (builder → runner), non-root user, health check
- **docker-compose.yml**: Full stack — app + MySQL + MongoDB + Redis + Meilisearch + Celery + Flower + MinIO
- **docker-compose.prod.yml**: Production overrides (no debug, resource limits)
- **.dockerignore**: Exclude unnecessary files

### 14b. CI/CD Pipeline (GitHub Actions)
Generate using `/gen-ci github-actions` patterns:
- **Lint stage**: ruff check + mypy type check
- **Test stage**: pytest with coverage + E2E tests
- **Security stage**: bandit + pip-audit + secret detection
- **Build stage**: Docker build + push to registry
- **Deploy stage**: Staging (auto) + Production (manual approval)
- **Notifications**: Slack/email on failure

### 14c. Environment Configuration
- Staging + Production environment separation
- Environment-specific .env files (.env.staging, .env.production)
- Secret management via platform secrets (GitHub Secrets / GCP Secret Manager)
- Sentry release tracking + source map upload on deploy
- CDN configuration for static assets

### 14d. Infrastructure as Code (Optional)
If the PRD specifies cloud deployment, generate using `/gen-infra` patterns:
- Terraform for cloud resources
- Kubernetes manifests for container orchestration
- Helm charts for packaged deployment

### 14e. K3s Deployment (if self-hosted K3s cluster)

**Auto-detect**: If `k8s/` directory exists with Traefik IngressRoute manifests, OR if the user specifies K3s deployment.

**Ask user**: "Are you deploying to a self-hosted K3s cluster? If yes, provide:
  1. Node IPs/hostnames (VPN or private IPs)
  2. Which node runs the Docker registry? (IP:port)
  3. Which node runs databases (MySQL, MongoDB, Redis)? (IPs:ports)
  4. Does your cluster use Traefik IngressRoute or nginx Ingress?
  5. Where does SSL terminate? (HAProxy / Traefik / cloud LB)
  6. Do you use a self-hosted GitHub runner? (runner name + node)"

**Load reference**: Read `skills/alpha-architecture/references/INFRA_HOSTINGER_K3S.md` for architecture patterns and templates.

Generate using `/gen-infra k3s` + `/gen-ci --k3s` patterns, substituting user-provided values:
- **k8s/ directory** (flat, no overlays): Secret + Deployment + Service + IngressRoute per app
- **Ingress**: Traefik IngressRoute or nginx Ingress (per user answer)
- **External databases**: Connect to user-provided database node IPs (not in-cluster StatefulSets)
- **Private registry**: Push to user-provided registry IP:port
- **Deploy workflow**: `.github/workflows/deploy.yml` with self-hosted runner (if provided) or standard runner
- **SSL**: Respect user's SSL termination point (no cert-manager if HAProxy/cloud handles it)
- **Celery workers** (if Python): Separate worker + beat Deployments in k8s/

**Commit:** `ci: Docker, CI/CD pipeline, and infrastructure setup`

---

## PHASE 15: FINAL VALIDATION

```bash
# Quality checks
ruff check app/ tests/
mypy app/ --ignore-missing-imports
pytest tests/ -v --cov=app --cov-report=term-missing

# Layer segregation enforcement
! grep -rn "from app.repositories" app/api/ && echo "✅ API layer clean"
! grep -rn "from app.api" app/services/ && echo "✅ Service layer clean"
! grep -rn "from app.services" app/repositories/ && echo "✅ Repository layer clean"
! grep -rn "localStorage\|sessionStorage" . --include="*.ts" --include="*.tsx" --include="*.js" && echo "✅ No browser storage for auth"

# Feature verification
python -c "from app.core.oauth import oauth; print('✅ Google OAuth configured')"
python -c "from app.services.email_service import EmailService; print('✅ Email service configured')"
python -c "from app.services.storage_service import StorageService; print('✅ File upload configured')"
python -c "from app.services.search_service import SearchService; print('✅ Search configured')"
python -c "from app.services.push_service import PushService; print('✅ Push notifications configured')"
python -c "from app.services.analytics_service import AnalyticsService; print('✅ Analytics configured')"
python -c "from app.core.sentry_config import init_sentry; print('✅ Sentry configured')"
ls app/templates/emails/welcome.html && echo "✅ Email templates exist"

# Docker build
docker-compose -f docker/docker-compose.yml build

# Lighthouse (frontend)
# lighthouse http://localhost:3000 --only-categories=performance,accessibility --output=json
```

If ALL pass → `git tag -a v1.0.0 -m "Release v1.0.0"` → Generate BUILD_REPORT.md

---

## SPRINT PLAN PROGRESS TRACKING (Throughout All Phases)

After completing each phase, update both `AUTO_BUILD_STATE.json` and `SPRINT_PLAN.md`:

### After each task/phase completion:
1. Read `SPRINT_PLAN.md`
2. Find the matching tasks for the phase just completed
3. Update their status: `⬜` → `✅`
4. Update `AUTO_BUILD_STATE.json` sprint_plan counters:
   - Increment `tasks_completed`
   - Recalculate `completion_percentage`
5. If all tasks in current sprint are done, increment `current_sprint`

### Phase → Sprint Task Mapping:
| Auto-Build Phase | Sprint Tasks Completed |
|-----------------|----------------------|
| Phase 0 (Scaffold) | Project scaffold, config, Docker setup |
| Phase 1 (Scaffold code) | Folder structure, base files |
| Phase 2 (DB Connections) | MySQL, MongoDB, Redis setup |
| Phase 3 (Models) | All database model tasks |
| Phase 4 (Repositories) | Repository layer tasks |
| Phase 5 (Services) | Service layer tasks |
| Phase 6 (Auth) | Auth system tasks (JWT, OAuth, email) |
| Phase 6.5 (Payments) | Razorpay, credit points, subscription tasks |
| Phase 6.8 (File/Search/Push) | S3 upload, Meilisearch, FCM tasks |
| Phase 7 (APIs) | API endpoint tasks |
| Phase 9 (Frontend) | Frontend page and component tasks |
| Phase 9.5 (Mobile) | Mobile app tasks |
| Phase 10 (Analytics) | Analytics, feature flags, admin tasks |
| Phase 11 (Testing) | All testing tasks |
| Phase 12 (Security) | Security hardening, compliance tasks |
| Phase 13 (Docs) | Documentation tasks |
| Phase 14 (CI/CD) | CI/CD pipeline, Docker production tasks |
| Phase 15 (Validation) | Final validation, launch readiness |

### Progress Display:
After each phase, print a progress summary:
```
Sprint Progress: Sprint [n] of [total]
Tasks: [completed]/[total] ([percentage]%)
Current Sprint Tasks:
  ✅ Create project scaffold (1 pt)
  ✅ Setup databases (2 pts)
  🔄 Create User model (2 pts) ← IN PROGRESS
  ⬜ Implement JWT auth (5 pts)
  ⬜ Login/Register pages (3 pts)
Points: [completed_points]/[total_points]
```

---

Output `<promise>PRODUCT_COMPLETE</promise>` when done.
