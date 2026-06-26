# Sprint Plan: Cortex Cloud
**Generated**: 2026-06-21
**From**: CORTEX_CLOUD_PRD.md
**Total Sprints**: 3
**Total Tasks**: 34
**Total Story Points**: 96

> Scoped to v1 spine: device-auth → ingest → dashboard → revoke. No payments/AI/mobile/search.
> MongoDB-only (Deviation 1). 3 sprints, not 4 — there's no payments/GenAI/mobile sprint.

## Sprint Overview
| Sprint | Theme | Story Points | Key Deliverables |
|--------|-------|-------------|------------------|
| 1 | Foundation + Identity | 34 | Scaffold, Mongo/Redis, models, dashboard auth + Google OAuth, device-grant flow |
| 2 | Ingest + Dashboard API | 33 | Events ingest (batch, rate-limit, whitelist), project-state, dashboard read, org/seats, revocation |
| 3 | Frontend + Hardening | 29 | Next.js dashboard pages, plugin-side `/cortex-login` + `collect.sh`, tests, security, CI/CD, docs |

## Sprint 1: Foundation + Identity
| # | Task | Type | Size | Points | Phase | Depends On | Status |
|---|------|------|------|--------|-------|------------|--------|
| 1.1 | Scaffold FastAPI project (layer dirs, config.py, main.py, Makefile, .env.example) | Infra | S | 2 | 0 | — | ⬜ |
| 1.2 | docker-compose: api + mongo + redis; `make dev` one-command boot | Infra | M | 3 | 0 | 1.1 | ⬜ |
| 1.3 | Motor Mongo client + index bootstrap; Redis pool (core/mongo.py, core/redis.py) | Backend | M | 3 | 2 | 1.2 | ⬜ |
| 1.4 | Pydantic models + repos: orgs, users, api_tokens (indexes, unique constraints) | Backend | L | 5 | 1 | 1.3 | ⬜ |
| 1.5 | core/security.py: RS256 JWT issue/verify, bcrypt hashing, CSRF double-submit | Backend | L | 5 | 3 | 1.3 | ⬜ |
| 1.6 | Dashboard auth: register (org+owner), login, refresh, logout (HTTP-Only cookies) | Backend | L | 5 | 3 | 1.4,1.5 | ⬜ |
| 1.7 | Google OAuth2: /google + /google/callback, state in Redis, account create/link | Backend | L | 5 | 3 | 1.6 | ⬜ |
| 1.8 | Device Authorization Grant: /auth/device, /auth/token (poll), /auth/activate, /auth/logout | Backend | XL | 6 | 3 | 1.5,1.6 | ⬜ |

### Sprint 1 Acceptance Criteria
- [ ] `make dev` boots api+mongo+redis; `/health` returns 200.
- [ ] Dashboard register/login/refresh/logout works with HTTP-Only cookies (no localStorage).
- [ ] Google OAuth consent → callback → user create/link works.
- [ ] Device-grant flow issues a JWT after browser approval; token persists an `api_tokens` doc with `tid`.
- [ ] No MySQL anywhere (Deviation 1 honored).

## Sprint 2: Ingest + Dashboard API
| # | Task | Type | Size | Points | Phase | Depends On | Status |
|---|------|------|------|--------|-------|------------|--------|
| 2.1 | Device-JWT auth dependency + Redis revocation denylist check (`revoked:{tid}`) | Backend | M | 3 | 8 | 1.8 | ⬜ |
| 2.2 | core/ratelimit.py: Redis token-bucket; per-org ingest + per-ip auth limits | Backend | M | 3 | 8 | 1.3 | ⬜ |
| 2.3 | events model + repo + TTL index (180d) + event_id unique-sparse | Backend | M | 3 | 1 | 1.3 | ⬜ |
| 2.4 | ingest_service: field whitelist (strip code/secrets/paths), validation | Backend | L | 5 | 5 | 2.3 | ⬜ |
| 2.5 | POST /v1/events + /v1/events/batch (fire-and-forget, 202, batch dedupe) | Backend | M | 3 | 5 | 2.1,2.2,2.4 | ⬜ |
| 2.6 | projects model + repo; POST /v1/projects/{id}/state (org-scoped upsert) | Backend | M | 3 | 5 | 2.1 | ⬜ |
| 2.7 | Dashboard read: /summary, /projects, /projects/{id}, /activity (paginated, org-scoped) | Backend | L | 5 | 5 | 2.6,2.3 | ⬜ |
| 2.8 | Org/seats: members list/invite/patch, tokens list, **DELETE token (revoke)** | Backend | L | 5 | 5 | 2.1 | ⬜ |
| 2.9 | Sentry integration + structured JSON logging | Infra | S | 2 | 10 | 1.1 | ⬜ |
| 2.10 | /v1/me (whoami — device JWT or cookie) | Backend | XS | 1 | 5 | 2.1 | ⬜ |

### Sprint 2 Acceptance Criteria
- [ ] Ingest is fire-and-forget; down backend never hangs the plugin; 202 fast path.
- [ ] Privacy whitelist rejects code/PRD/secrets/absolute paths.
- [ ] Rate limiting active per org; revocation denylist enforced (revoke → 401).
- [ ] Project-state upsert + dashboard read are org-isolated (no cross-org leakage).
- [ ] Revoke endpoint flips `revoked=true` and kills the pipe.

## Sprint 3: Frontend + Hardening
| # | Task | Type | Size | Points | Phase | Depends On | Status |
|---|------|------|------|--------|-------|------------|--------|
| 3.1 | Next.js 15 scaffold: TS, Tailwind, shadcn/ui, themes (light/dark/system), API client | Frontend | M | 3 | 6 | — | ⬜ |
| 3.2 | Auth pages: /login, /register, Google button; cookie session handling | Frontend | M | 3 | 6 | 3.1,1.7 | ⬜ |
| 3.3 | **/activate** device-approval page (enter user_code → approve) | Frontend | S | 2 | 6 | 3.2,1.8 | ⬜ |
| 3.4 | /dashboard summary + /projects list + /projects/[id] detail (timeline) | Frontend | L | 5 | 6 | 3.2,2.7 | ⬜ |
| 3.5 | /activity feed + /settings/members + /settings/tokens (revoke UI) | Frontend | L | 5 | 6 | 3.4,2.8 | ⬜ |
| 3.6 | **Plugin-side**: `commands/cortex-login.md` (+ logout/status), writes credentials.json | Plugin | M | 3 | 6 | 1.8 | ⬜ |
| 3.7 | **Plugin-side**: `scripts/collect.sh` + hooks.json (SessionStart/Stop/PostToolUse), batch queue | Plugin | M | 3 | 6 | 2.5,3.6 | ⬜ |
| 3.8 | Backend tests: auth, device-grant, ingest, revocation, org-isolation (>80%, >95% auth/ingest) | Testing | XL | 6 | 11 | 2.* | ⬜ |
| 3.9 | Security pass: org-isolation audit, token hashing, CORS, CSRF, rate-limit verification | Security | M | 3 | 12 | 3.8 | ⬜ |
| 3.10 | CI/CD (lint→type→test→build→deploy), Dockerfile prod, gen-docs (README + LOCAL_DEV.md) | DevOps | M | 3 | 14 | 3.8 | ⬜ |

### Sprint 3 Acceptance Criteria
- [ ] Full loop works: `/cortex-login` → approve at /activate → build emits events → dashboard shows project → admin revokes → pipe dies.
- [ ] Dashboard responsive, dark-first, no token in localStorage.
- [ ] `collect.sh` never blocks a build (curl -m 2, ignore failure).
- [ ] Tests pass >80% (>95% auth/ingest); ruff+mypy clean; CI green.

## Critical Path
1.1 → 1.2 → 1.3 → 1.4 → 1.5 → 1.6 → 1.8 → 2.1 → 2.5 → 3.6 → 3.7 → 3.8 → 3.10 → launch

## Auto-Build Phase Mapping
| Sprint | Maps to Auto-Build Phases |
|--------|---------------------------|
| Sprint 1 | Phase 0 (scaffold), 1 (models), 2 (db), 3 (auth) |
| Sprint 2 | Phase 5 (API), 8 (middleware), 10 (analytics/logging) |
| Sprint 3 | Phase 6 (frontend), 11 (testing), 12 (security), 13 (docs), 14 (CI/CD) |

## Agent Teams Ownership (parallel mode — env var enabled)
| Domain | Owner | Tasks |
|--------|-------|-------|
| Models / repos / services | **viktor** | 1.3, 1.4, 2.3, 2.6 |
| Auth / JWT / OAuth / device-grant / revocation | **yuki** | 1.5, 1.6, 1.7, 1.8, 2.1 |
| API routes / ingest / dashboard / org | **marcus** | 2.4, 2.5, 2.7, 2.8, 2.10 |
| Frontend dashboard (Next.js) | **sofia + squad** | 3.1–3.5 |
| Tests / QA | **liam** | 3.8, 3.9 |
| Docker / CI/CD / rate-limit infra / Sentry | **oleksiy** | 1.1, 1.2, 2.2, 2.9, 3.10 |
| Plugin-side login + collect hook | Team Lead or **marcus** | 3.6, 3.7 |

> No **hiroshi** (AI lead) — this product has no GenAI. No frontend forms-heavy squad needed
> beyond core pages; sofia's squad covers it.
