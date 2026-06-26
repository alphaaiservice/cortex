# Product Requirements Document — Cortex Cloud

> Generated from `docs/CORTEX_CLOUD_BACKEND_DESIGN.md` + `CORTEX_CLOUD_MARKET_RESEARCH.md`.
> This is the spec `/auto-build` consumes. Source of truth for the build.

## 1. Product Overview
- **Name**: Cortex Cloud
- **Description**: The hosted backend that monetizes the free Cortex Claude Code plugin.
  It authenticates the plugin (OAuth device flow), ingests build/command telemetry and
  project-state snapshots, and serves a team dashboard so an org can see every project's
  status in one place. The plugin stays free and copyable; Cortex Cloud is the gateable,
  revenue-bearing layer attached to it.
- **Target Users**: Engineering teams/orgs using the Cortex plugin who want shared
  visibility and (later) centrally-managed standards. Buyer = team lead / eng manager.
- **Core Value Proposition**: "See everything your team built with Cortex, in one place —
  and control who can." Anything stateful, multi-user, or server-side is sellable; local
  markdown files are not.
- **Market Research**: See `CORTEX_CLOUD_MARKET_RESEARCH.md`.
- **Key Differentiators**:
  1. SDLC **build telemetry**, not just code review (no incumbent owns this).
  2. **Token-revocation kill switch** — the thing that makes a copyable plugin actually gateable.
  3. **Open-core honesty** — sell the hosted spine, not hidden prompts.
- **Competitor Gaps We Address**: CodeRabbit reviews PRs but has zero view of the *build*
  lifecycle; usage-analytics tools (Mixpanel/Amplitude) aren't dev-SDLC-aware.
- **Brand Personality**: precise, trustworthy, developer-native, unobtrusive.
- **Brand Voice**: technical, direct, no marketing fluff.

## 2. Tech Stack (Alpha AI Standard — with documented deviations)

> Canonical reference: `commands/references/AUTO_BUILD_STACK.md`. This section selects from it
> per the FEATURE_PROFILE below. **Two deliberate, user-directed deviations from CORE defaults
> are documented inline — do not "correct" them during build.**

### FEATURE_PROFILE (drives everything below)
| Capability | Included? | Why |
|------------|-----------|-----|
| Backend framework | ✅ Python/FastAPI | Default; dogfoods Cortex. |
| JWT auth | ✅ | Dashboard = HTTP-Only cookies. CLI = device-grant Bearer tokens. |
| **MySQL** | ❌ **DEVIATION** | **User-directed: MongoDB is the single datastore.** See note below. |
| MongoDB | ✅ | Single store: orgs/users/tokens/projects + append-only events firehose. |
| Redis | ✅ | Device-code pending state, rate-limit buckets, revocation denylist. |
| Google OAuth2 (social login) | ✅ | Dashboard login (email/password + Google). |
| Layer segregation | ✅ | controllers → services → repositories → models. |
| Testing & quality | ✅ | pytest + pytest-asyncio, ruff, mypy, >80% coverage. |
| Frontend Web (dashboard) | ✅ | Next.js 15 + TS + Tailwind + shadcn/ui. Separate app. |
| Multi-theme (light/dark/system) | ✅ | Dark-first developer tool. |
| Rate limiting | ✅ | Redis sliding window, per-org on ingest. |
| Error tracking (Sentry) | ✅ | Production readiness. |
| Payments / Razorpay / GST | ❌ | **Deferred to post-v1. Future billing = Stripe USD, NOT Razorpay/India.** |
| Mobile (React Native) | ❌ | Back-office web view only. |
| GenAI / RAG / LiteLLM | ❌ | The backend ingests telemetry; it runs no LLM. |
| Full-text search (Meilisearch) | ❌ | Not needed v1. |
| Real-time / WebSocket | ❌ | Dashboard is request/response; no live stream v1. |
| File uploads / S3 | ❌ | No user file content. |
| Transactional email | ❌ | No email in v1 (no password reset emails needed if Google-first; revisit). |
| i18n | ❌ | Internal/dev audience, English v1. |

> **DEVIATION 1 — MongoDB instead of MySQL (CORE default).** The Alpha AI standard mandates
> MySQL for ACID-critical entities. The user explicitly chose **MongoDB as the single datastore**.
> Entities that would be relational (orgs, users, api_tokens) live as MongoDB documents with
> unique indexes; the events firehose is append-only with a TTL index. Accept this; do not
> scaffold MySQL/SQLAlchemy/Alembic.
>
> **DEVIATION 2 — Stripe (future), not Razorpay.** Cortex Cloud is a global developer tool.
> When billing is added post-v1 it will be **Stripe in USD**, not Razorpay/UPI/GST. No payment
> code in v1 at all.

### CORE stack (always)
- **FastAPI** (Python 3.11+) + Uvicorn, async throughout.
- **Auth**: JWT. Dashboard sessions = JWT in **HTTP-Only cookies** (access 30 min / refresh 7 day),
  CSRF double-submit, Redis logout blacklist — NEVER localStorage/sessionStorage. CLI = device-grant
  JWT (RS256) stored client-side in `~/.cortex/credentials.json`, sent as `Authorization: Bearer`.
- **MongoDB** (Motor async driver) — single datastore (see Deviation 1).
- **Redis** — ephemeral device-code state, rate limiting, revocation denylist cache.
- **Layer segregation**: `app/api/ → app/services/ → app/repositories/ → app/models/`. Thin
  controllers; no DB access above repositories; no business logic in controllers.
- **Quality**: ruff + mypy (strict) + pytest/pytest-asyncio, >80% coverage (>95% on auth/ingest).
- **Frontend**: Next.js 15 App Router + TypeScript + Tailwind 4 + shadcn/ui, light/dark/system themes.
- **Dependencies**: `fastapi`, `uvicorn[standard]`, `motor`, `redis`, `python-jose[cryptography]`,
  `passlib[bcrypt]`, `pydantic-settings`, `authlib` (Google OAuth), `sentry-sdk`, `httpx`,
  `pytest`, `pytest-asyncio`.

## 3. Data Models

> **All MongoDB** (Deviation 1). No MySQL. Indexes are load-bearing.

### Collection: `orgs`
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| _id | ObjectId | PK | Org id |
| name | string | NOT NULL | Org/company name |
| plan | string | enum free/team/enterprise, default free | Billing tier (no billing logic v1) |
| seats | int | default 3 | Allowed seats |
| created_at | datetime | auto | |

### Collection: `users`
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| _id | ObjectId | PK | |
| org_id | ObjectId | FK→orgs, INDEX | Owning org |
| email | string | UNIQUE | Login email |
| name | string | | Display name |
| password_hash | string | nullable | bcrypt (NULL for Google-only) |
| auth_provider | string | enum password/google | |
| google_sub | string | unique, nullable | Google OAuth subject |
| role | string | enum owner/admin/member, default member | Org RBAC |
| is_active | bool | default true | |
| created_at | datetime | auto | |

Indexes: `email` unique, `org_id`, `google_sub` unique sparse.

### Collection: `api_tokens` (device tokens — the revocation table)
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| _id | ObjectId | PK | == JWT `tid` claim |
| org_id | ObjectId | FK→orgs, INDEX | |
| user_id | ObjectId | FK→users | |
| token_hash | string | sha256, UNIQUE | NEVER store raw token |
| label | string | | e.g. "kajal's macbook" |
| created_at | datetime | auto | |
| last_seen_at | datetime | | Updated (throttled) on ingest |
| expires_at | datetime | | 30–90 day lifetime |
| revoked | bool | default false | **Kill switch** |

Indexes: `token_hash` unique, `org_id`.

### Collection: `projects` (latest state snapshot, one doc per project)
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| _id | string | client-generated project_id | |
| org_id | ObjectId | INDEX | |
| name | string | | |
| lang | string | | python/nestjs/springboot |
| latest_phase | string | | e.g. "Phase 9 / 16" |
| gap_score | float | nullable | 0–1 standards score |
| cost_estimate_usd | float | nullable | |
| state | object | | Full AUTO_BUILD_STATE snapshot — metadata only |
| created_at | datetime | auto | |
| updated_at | datetime | auto | |

Index: `{ org_id: 1, updated_at: -1 }`.

### Collection: `events` (append-only firehose)
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| _id | ObjectId | PK | |
| org_id | ObjectId | INDEX | |
| user_id | ObjectId | | |
| project_id | string | nullable, INDEX | |
| type | string | enum command_run/phase_complete/build_start/build_done/error | |
| command | string | | e.g. "/auto-build" |
| phase | string | nullable | |
| success | bool | nullable | |
| duration_ms | int | nullable | |
| event_id | string | nullable, unique sparse | Client uuid for idempotent batch dedupe |
| ts | datetime | INDEX | |

Indexes: `{ org_id:1, ts:-1 }`, `{ project_id:1, ts:-1 }`, **TTL** on `ts` (180 days),
`event_id` unique sparse.

> **Privacy contract (enforce server-side):** whitelist exactly the fields above. Reject/strip
> anything else — no code, file contents, PRD text, secrets, or absolute paths.

### Redis Keys
| Key Pattern | Type | TTL | Purpose |
|-------------|------|-----|---------|
| device:{device_code} | hash | 600s | Pending device-grant state (user_code, status, org_id) |
| revoked:{tid} | string | token_exp | Revocation denylist cache |
| ratelimit:{org_id} | sorted_set | 60s | Ingest rate limiting (token bucket) |
| ratelimit:auth:{ip} | sorted_set | 60s | Device/token endpoint protection |
| oauth_state:{state} | string | 600s | Google OAuth CSRF state |
| blacklist:{jti} | string | token_exp | Dashboard logout blacklist |

## 4. API Endpoints

### Auth — Device Grant (CLI) (/auth)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /auth/device | None | Start device grant → { device_code, user_code, verification_url, interval, expires_in } |
| POST | /auth/token | None (device_code) | Poll for device JWT. 428 authorization_pending / 429 slow_down / 200 token |
| POST | /auth/activate | Dashboard cookie | Browser submits user_code → approve device, bind to org |
| POST | /auth/logout | Device JWT | Revoke this device token (set revoked=true) |

### Auth — Dashboard (web) (/api/v1/auth)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /register | No | Create org + owner user, set HTTP-Only cookies |
| POST | /login | No | Email/password → cookies |
| POST | /refresh | Cookie | Rotate tokens |
| POST | /logout | Cookie | Blacklist jti + clear cookies |
| GET | /me | Cookie or Device JWT | Whoami (org, plan, role, seat) |
| GET | /google | No | Redirect to Google consent |
| GET | /google/callback | No | Handle callback → create/login → cookies |

### Ingest & State (plugin → backend) (/v1)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /v1/events | Device JWT | Append one telemetry event (fire-and-forget, 202) |
| POST | /v1/events/batch | Device JWT | Append a batch (preferred — flushed on Stop) |
| POST | /v1/projects/{project_id}/state | Device JWT | Upsert latest AUTO_BUILD_STATE snapshot |

### Dashboard read (browser → backend) (/v1/dashboard)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /v1/dashboard/summary | Cookie | Org rollups (project count, recent activity counts) |
| GET | /v1/dashboard/projects | Cookie | List org projects + latest phase/score |
| GET | /v1/dashboard/projects/{id} | Cookie | One project: state + recent events |
| GET | /v1/dashboard/activity | Cookie | Org-wide recent event feed (paginated) |

### Org / Seats (light admin) (/v1/org)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /v1/org/members | Cookie (admin) | List org users + seats |
| POST | /v1/org/invite | Cookie (admin) | Invite a member (email) |
| PATCH | /v1/org/members/{id} | Cookie (admin) | Change role / deactivate |
| GET | /v1/org/tokens | Cookie (admin) | List device tokens in org |
| DELETE | /v1/org/tokens/{tid} | Cookie (admin) | **Revoke a device token (kill switch)** |

### Ops
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /health | None | Liveness — `make verify` boot gate / k8s probe |

## 5. Pages / Screens (dashboard — Next.js)

- `/login` — email/password + "Sign in with Google".
- `/register` — create org + owner account.
- `/activate` — **device-grant approval page**: enter `user_code` from the CLI → approve.
- `/dashboard` — summary: project count, recent activity, status badges.
- `/projects` — list of org projects (name, lang, latest phase, gap score, updated_at).
- `/projects/[id]` — project detail: state snapshot + recent event timeline.
- `/activity` — org-wide event feed.
- `/settings/members` — seats/roles, invite, deactivate.
- `/settings/tokens` — device tokens list + **revoke** button (the kill switch UI).

## 6. User Flows

### Device Login (CLI → Cloud)
1. User runs `/cortex-login` → plugin `POST /auth/device` → gets `user_code` + verification URL.
2. Plugin prints: "Go to cloud.cortex.alphaai.com/activate and enter WXYZ-7788".
3. User opens `/activate` in browser (logs in if needed) → `POST /auth/activate` approves the code, binds it to their org.
4. Plugin polls `POST /auth/token` (respecting `interval`) → receives device JWT.
5. Plugin writes token to `~/.cortex/credentials.json` (chmod 600). Done.

### Event Ingest (hot path)
1. A Cortex hook fires (SessionStart / Stop / selected PostToolUse).
2. `collect.sh` reads event JSON on stdin, reads the token, `curl -m 2` to `/v1/events` (fire-and-forget).
3. Backend validates JWT → checks `revoked:{tid}` in Redis (401 → plugin silently degrades) →
   rate-limits per org → whitelists fields → inserts into `events` → returns 202.
4. Plugin ignores failures entirely (offline / down / 401 = no-op).

### State Push
1. `/auto-build` completes a phase → reads AUTO_BUILD_STATE.json (metadata only) →
   `POST /v1/projects/{id}/state` (Bearer).
2. Backend upserts the `projects` doc by `_id`, scoped to `org_id`, sets `updated_at`.

### Dashboard Read
1. Browser (cookie) → `GET /v1/dashboard/projects`.
2. Backend validates session → queries `projects {org_id}` sort `updated_at` desc → renders list.

### Revocation (kill switch)
1. Admin opens `/settings/tokens` → clicks Revoke → `DELETE /v1/org/tokens/{tid}`.
2. Backend sets `revoked=true`, writes `revoked:{tid}` to Redis.
3. That device's next event POST 401s; premium plugin commands degrade to "renew/upgrade".

## 7. Product Branding
- **Brand Name**: Cortex Cloud
- **Tagline**: "See everything your team built."
- **Brand Voice**: technical, direct.
- **Primary Color**: inherit Cortex brand (carry from plugin BRAND_GUIDE if present).
- **Theme**: dark-first, light + system available.
- **Typography**: Inter (body) + a geometric sans for headings.

## 8. Non-Functional Requirements
- Ingest endpoint p95 < 100ms; **must never block the plugin** (client uses `curl -m 2`, fire-and-forget).
- Dashboard API p95 < 200ms.
- JWT access 30 min / refresh 7 day (dashboard); device JWT 30–90 day with revocation denylist.
- Rate limiting: per-org token bucket on ingest (e.g. 100 req/10s); stricter on auth endpoints.
- CORS: allowed origins = dashboard domain only.
- CSRF: double-submit cookie on dashboard mutations.
- Passwords: bcrypt cost 12.
- JWT signing: **RS256** (asymmetric) so services verify without the signing key.
- Tokens stored hashed (sha256) server-side; raw token only on user disk.
- Org isolation: every query scoped by `org_id` from the verified token — never client-supplied.
- Config via pydantic-settings (env-driven); structured JSON logging; Sentry for errors.
- Local dev: `make dev` one-command boot (api + mongo + redis via docker-compose), `make verify` → `/health` 200.

## 9. Acceptance Criteria

### Core (always)
- [ ] All endpoints working with correct auth (device JWT vs cookie separation enforced).
- [ ] Device Authorization Grant flow works end-to-end (`/cortex-login` → approve → token stored).
- [ ] Dashboard JWT in HTTP-Only cookies; **zero** localStorage/sessionStorage token use.
- [ ] CSRF protection active on dashboard POST/PUT/PATCH/DELETE.
- [ ] **MongoDB is the only datastore** — no MySQL/SQLAlchemy/Alembic scaffolded (Deviation 1 honored).
- [ ] Layer segregation enforced (no cross-layer imports).
- [ ] Ingest is fire-and-forget: a down backend never hangs a plugin build; 202 returned fast.
- [ ] Privacy whitelist enforced — events reject code/PRD/secrets/absolute paths.
- [ ] Token revocation kill switch works: revoke → next event 401s.
- [ ] Org isolation verified — a user cannot read/write another org's data.
- [ ] All tests passing, >80% coverage (>95% on auth + ingest).
- [ ] ruff + mypy clean.
- [ ] `make dev` boots all services; `make verify` returns `/health` 200.

### Conditional (this product's features)
- [ ] **Redis**: device-code state, rate limiting, and revocation denylist all working.
- [ ] **Google OAuth**: consent redirect + callback + account create/link working.
- [ ] **Events TTL**: `events` self-prune at 180 days via TTL index.
- [ ] **Batch ingest**: `/v1/events/batch` dedupes by client `event_id`.
- [ ] **Sentry**: errors reported with org/user context (no PII beyond ids).

### Explicitly OUT of scope for v1 (do NOT build)
- [ ] ❌ No payments / Stripe / Razorpay / invoices / GST.
- [ ] ❌ No mobile app.
- [ ] ❌ No GenAI / RAG / LiteLLM.
- [ ] ❌ No full-text search, WebSocket, file uploads, i18n, email.
- [ ] ❌ No Standards Registry (post-v1 — see design doc §11).
