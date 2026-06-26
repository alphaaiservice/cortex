# Cortex Cloud — Backend Design Document

**Status:** Draft v0.1
**Owner:** Alpha AI Service Pvt Ltd
**Stack:** FastAPI (Python 3.11+) · MongoDB (Motor async) · Redis
**Last updated:** 2026-06-21

---

## 1. Purpose

Cortex Cloud is the **paid, hosted backend** that turns the free Cortex Claude Code
plugin into a monetizable product. The plugin stays free and open (it is just
markdown + hooks, trivially copyable). The money lives in the *ecosystem services*
the plugin connects to — services we host and control:

1. **Identity** — a logged-in developer / org (the gateable unit).
2. **Event ingest** — the plugin streams lifecycle telemetry (command runs, build
   phases, gap scores) to us.
3. **Project state** — the plugin pushes `AUTO_BUILD_STATE.json` snapshots so a team
   can see every project's status in one place.
4. **Dashboard read-back** — a web app surfaces all of the above to the customer.

The defensible insight: **anything stateful, multi-user, or running on our servers
is chargeable; anything that is just text on the user's disk is not.** This backend
is the "lift it off the local filesystem" layer.

### What this is NOT (v1 scope guardrails)
- No billing in v1 (Stripe bolts onto this spine later — see §11).
- No real-time streaming / websockets.
- No ingest of user code, PRD content, or file contents — **command names + state metadata only**.
- No per-event analytics UI — just "list projects + latest state + recent activity".

---

## 2. High-Level Architecture

```
  Plugin (user's machine)                Cortex Cloud (we host)
 ─────────────────────────              ─────────────────────────────────────
  /cortex-login (device flow) ───────►  AUTH    /auth/device  /auth/token
  hooks → collect.sh (curl)   ───────►  INGEST  POST /v1/events
  /auto-build → push state    ───────►  STATE   POST /v1/projects/:id/state
                                        READ    GET  /v1/dashboard/*  ◄──── Dashboard (Next.js)

                              FastAPI (async)
                                 │
                   ┌────────────┼─────────────┐
                MongoDB        Redis        (Stripe — later)
             orgs, users,   device codes,
             tokens,        rate limits,
             projects,      token cache
             events
```

### Components
| Component | Tech | Responsibility |
|-----------|------|----------------|
| API | FastAPI + Uvicorn | Auth, ingest, state, dashboard read APIs |
| DB | MongoDB 7 (Motor async driver) | All persistent data |
| Cache/ephemeral | Redis 7 | Device-code pending state, rate-limit buckets, revocation cache |
| Auth | python-jose (JWT) + passlib (web pw) | Device-grant tokens + dashboard sessions |
| Dashboard | Next.js 15 (separate repo/app) | Customer-facing read UI |

This follows the Alpha AI Cortex stack (FastAPI + MongoDB + Redis + JWT-in-HTTP-only-cookies),
so it can be scaffolded with `/auto-build` / `/init-project --lang=python` and dogfoods the plugin.

---

## 3. Authentication

Two distinct credential types for the same human — **do not reuse them**:

| Credential | Holder | Lifetime | Transport | Purpose |
|------------|--------|----------|-----------|---------|
| **Device token (JWT)** | the CLI plugin | long (30–90 days) | `Authorization: Bearer` header | machine → ingest/state |
| **Dashboard session (JWT)** | the browser | short (30 min access / 7 day refresh) | HTTP-Only cookie | human → web dashboard |

### 3.1 Device Authorization Grant (OAuth 2.0 RFC 8628)

This is the "like Claude / gh / aws sso" login. No browser automation in the terminal.

```
Plugin: /cortex-login
   │
   ├─►  POST /auth/device                       (no auth)
   │      ← { device_code, user_code: "WXYZ-7788",
   │          verification_url: "https://cloud.cortex.alphaai.com/activate",
   │          interval: 5, expires_in: 600 }
   │
   ├─►  Show user: "Go to <url> and enter WXYZ-7788"
   │
   │    (meanwhile, user opens browser, logs in with Google/email,
   │     enters the code → backend marks device_code APPROVED, binds to their org)
   │
   └─►  POLL  POST /auth/token  { device_code }   every `interval` sec
          ← 428 { error: "authorization_pending" }   (keep polling)
          ← 200 { access_token, token_type: "bearer", expires_in, org_id }
                 → plugin writes to ~/.cortex/credentials.json (chmod 600)
```

**Server state for the flow** lives in Redis:
```
device:<device_code> = {
    user_code, status: "pending|approved|denied",
    org_id (set on approval), user_id, created_at
}   TTL = 600s
```

`POST /auth/token` outcomes:
- `pending`  → `428 authorization_pending`
- `approved` → issue device JWT, delete the Redis key, persist a token record (§5), return token
- expired/missing → `400 expired_token`
- polled faster than `interval` → `429 slow_down`

### 3.2 Device JWT claims
```json
{
  "sub": "<user_id>",
  "org": "<org_id>",
  "typ": "device",
  "tid": "<token_id>",      // maps to api_tokens doc → enables revocation
  "iat": 1690000000,
  "exp": 1697776000
}
```
`tid` is the linchpin of revocation (§3.4).

### 3.3 Dashboard auth
Standard Cortex web auth — email/password or Google OAuth2 (server-side Authorization
Code Grant), issuing **JWT in HTTP-Only cookies** (access 30 min, refresh 7 days),
CSRF double-submit, logout blacklists in Redis. Per Alpha AI hard auth rules — never
localStorage/sessionStorage.

### 3.4 Revocation = the kill switch

This is what makes a copyable plugin actually gateable. The files stay on disk,
but **the data pipe dies**:

- Every device JWT carries `tid`.
- Auth middleware checks a Redis denylist `revoked:<tid>` (cached from the `api_tokens`
  collection; `revoked=true` → 401).
- Cancelling a subscription / removing a seat flips `revoked=true` → the plugin's next
  event POST 401s and premium commands degrade to an "upgrade/renew" message.
- Short token TTL + denylist gives near-immediate cutoff without per-request DB hits.

---

## 4. API Surface (v1)

All ingest/state routes require a **valid device JWT**. Dashboard routes require a
**dashboard session cookie**.

### Auth
| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/auth/device` | none | start device-grant, return user_code |
| POST | `/auth/token` | none (device_code) | poll for the device JWT |
| POST | `/auth/activate` | dashboard session | browser submits user_code → approve device |
| POST | `/auth/logout` | device JWT | revoke this device token |

### Ingest & State (plugin → us)
| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/v1/events` | device JWT | append a telemetry event (fire-and-forget) |
| POST | `/v1/events/batch` | device JWT | append a batch (preferred — see §7) |
| POST | `/v1/projects/{project_id}/state` | device JWT | upsert latest AUTO_BUILD_STATE snapshot |

### Dashboard read (browser → us)
| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/v1/dashboard/projects` | cookie | list org's projects + latest phase/score |
| GET | `/v1/dashboard/projects/{id}` | cookie | one project's state + recent events |
| GET | `/v1/dashboard/activity` | cookie | recent org-wide event feed |
| GET | `/v1/dashboard/summary` | cookie | counts/rollups for the landing view |

### Ops
| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/health` | none | liveness (boot gate / k8s probe) |
| GET | `/v1/me` | device JWT or cookie | whoami (org, plan, seat) |

---

## 5. Data Model (MongoDB)

Single datastore. Mongo holds both the relational-ish entities (small, low-write) and
the event firehose (large, append-only). Indexes matter more than schema here.

### `orgs`
```json
{ "_id": ObjectId, "name": "Acme Corp", "plan": "free|team|enterprise",
  "seats": 5, "created_at": ISODate }
```

### `users`
```json
{ "_id": ObjectId, "org_id": ObjectId, "email": "dev@acme.com",
  "name": "...", "password_hash": "...", "role": "owner|admin|member",
  "auth_provider": "password|google", "created_at": ISODate }
```
Index: `{ email: 1 }` unique, `{ org_id: 1 }`.

### `api_tokens`  (device tokens — the revocation table)
```json
{ "_id": ObjectId, "org_id": ObjectId, "user_id": ObjectId,
  "token_hash": "sha256(...)",        // never store the raw token
  "label": "kajal's macbook",
  "created_at": ISODate, "last_seen_at": ISODate,
  "expires_at": ISODate, "revoked": false }
```
Index: `{ token_hash: 1 }` unique, `{ org_id: 1 }`. `_id` == JWT `tid`.

### `projects`  (latest state snapshot, one per project)
```json
{ "_id": "<client-generated project_id>", "org_id": ObjectId,
  "name": "insurance-agent-app",
  "lang": "python", "latest_phase": "Phase 9 / 16",
  "gap_score": 0.82, "cost_estimate_usd": 240,
  "state": { /* full AUTO_BUILD_STATE.json snapshot, metadata only */ },
  "created_at": ISODate, "updated_at": ISODate }
```
Index: `{ org_id: 1, updated_at: -1 }`.

### `events`  (append-only firehose)
```json
{ "_id": ObjectId, "org_id": ObjectId, "user_id": ObjectId,
  "project_id": "<project_id|null>",
  "type": "command_run|phase_complete|build_start|build_done|error",
  "command": "/auto-build",
  "phase": "Phase 9", "success": true, "duration_ms": 5300,
  "ts": ISODate }
```
Indexes: `{ org_id: 1, ts: -1 }`, `{ project_id: 1, ts: -1 }`.
**TTL index** on `ts` (e.g. 180 days) so the firehose self-prunes:
`db.events.createIndex({ ts: 1 }, { expireAfterSeconds: 15552000 })`.

> **Privacy contract (enforced server-side):** reject/strip any event field that
> could carry code, file contents, PRD text, secrets, or absolute paths. Whitelist
> the fields above; drop everything else. This mirrors the deferred-telemetry design
> already recorded in the plugin's CLAUDE.md (command-name + outcome only).

---

## 6. Request Flows

### 6.1 Login (device grant)
```
CLI ──POST /auth/device──► API ──set Redis device:<code> (pending)──► returns user_code
User ──browser login + POST /auth/activate{user_code}──► API ──Redis status=approved, bind org──►
CLI ──POST /auth/token (poll)──► API ──issue JWT, write api_tokens doc, del Redis key──► token
CLI ──write ~/.cortex/credentials.json (chmod 600)
```

### 6.2 Event ingest (the hot path)
```
hook fires (PostToolUse/Stop/SessionStart)
  → collect.sh reads event JSON on stdin
  → reads token from ~/.cortex/credentials.json
  → curl -m 2 -s POST /v1/events  (Bearer token)   [fire-and-forget, failure ignored]
API:
  → validate JWT + check revoked:<tid> in Redis  (401 → plugin silently degrades)
  → rate-limit bucket per org in Redis (429 if exceeded)
  → whitelist/strip fields → insert into events
  → update api_tokens.last_seen_at (async, throttled)
  → 202 Accepted  (empty body, cheap)
```

### 6.3 State push
```
/auto-build completes a phase
  → reads AUTO_BUILD_STATE.json (metadata only)
  → curl POST /v1/projects/{id}/state (Bearer)
API: upsert projects doc by _id, scoped to org_id, set updated_at → 200
```

### 6.4 Dashboard read
```
Browser (cookie) → GET /v1/dashboard/projects
API: validate session cookie → query projects {org_id} sort updated_at desc → 200 JSON
```

---

## 7. Performance & Reliability

The single rule that protects user experience: **ingest must never block the plugin.**

- **Client side:** every hook curl uses `-m 2` (2s timeout) and ignores non-zero exit.
  A down backend must never hang a build. The plugin works fully offline; telemetry is best-effort.
- **Batching:** hooks can burst (PostToolUse per tool call). Buffer events client-side
  in `~/.cortex/queue.jsonl` and flush via `/v1/events/batch` on `Stop`/SessionEnd, or
  sample noisy event types. This cuts write volume by ~10–50×.
- **Fast writes:** `events` inserts are unacknowledged-friendly (`w=1`, no transaction).
  `202 Accepted` returned immediately; no read-back on the hot path.
- **Rate limiting:** Redis token bucket per `org_id` (e.g. 100 req/10s burst). `429 slow_down`.
- **Idempotency:** state push is an upsert (naturally idempotent). Events may carry a
  client `event_id` (uuid) with a unique index to dedupe retried batches.
- **Backpressure:** if Mongo write queue grows, shed load by returning `202` and dropping
  to a sampled rate — telemetry is lossy-tolerant by design.

---

## 8. Security

- **JWT signing:** RS256 (asymmetric) so the dashboard/other services can verify without
  the signing key. Keys from env/secret store, never committed.
- **Token storage:** store only `sha256(token)` in `api_tokens`; the raw token lives only
  on the user's disk. DB leak ≠ usable tokens.
- **Transport:** TLS everywhere; HSTS on the dashboard.
- **Org isolation:** every query is scoped by `org_id` from the verified token — never
  trust a client-supplied org. A user can only ever read/write their own org's data.
- **Input validation:** Pydantic models on every endpoint; event field whitelist (§5).
- **CSRF:** double-submit cookie on dashboard mutations (per Alpha AI auth rules).
- **Revocation denylist:** `revoked:<tid>` in Redis, refreshed from `api_tokens`.
- **No secrets in telemetry:** server-side strip; plus a client-side guard in `collect.sh`
  that refuses to send if the payload matches secret-like patterns.
- **Rate limit auth endpoints** harder (device/token) to prevent code brute force —
  `user_code` is high-entropy (8 chars, ambiguous chars removed) and single-use.

---

## 9. Project Layout (FastAPI, layer-segregated)

Follows Alpha AI layer rules: `api → services → repositories → models`.

```
cortex-cloud/
├── app/
│   ├── main.py                      # FastAPI app, router mounts, lifespan (Mongo/Redis pools)
│   ├── config.py                    # pydantic-settings, env-driven
│   ├── api/                         # controllers — thin handlers only
│   │   ├── auth.py                  # /auth/device, /auth/token, /auth/activate, /auth/logout
│   │   ├── ingest.py                # /v1/events, /v1/events/batch
│   │   ├── projects.py              # /v1/projects/{id}/state
│   │   ├── dashboard.py             # /v1/dashboard/*
│   │   └── deps.py                  # auth dependencies (device JWT, session cookie)
│   ├── services/                    # business logic
│   │   ├── auth_service.py          # device grant, JWT issue/verify, revocation
│   │   ├── ingest_service.py        # field whitelist, rate-limit, write
│   │   └── project_service.py       # state upsert, dashboard aggregations
│   ├── repositories/                # all Mongo access (no queries above this layer)
│   │   ├── org_repo.py
│   │   ├── user_repo.py
│   │   ├── token_repo.py
│   │   ├── event_repo.py
│   │   └── project_repo.py
│   ├── models/                      # Pydantic schemas (request/response + DB docs)
│   │   ├── auth.py
│   │   ├── event.py
│   │   └── project.py
│   └── core/
│       ├── security.py              # JWT (RS256), hashing, CSRF
│       ├── mongo.py                 # Motor client + index bootstrap
│       ├── redis.py                 # Redis pool
│       └── ratelimit.py             # token-bucket
├── tests/                           # pytest + pytest-asyncio
├── scripts/seed.py
├── Dockerfile                       # python:3.11-slim
├── docker-compose.yml               # api + mongo + redis (local dev, make dev)
├── .env.example                     # working defaults
├── requirements.txt
└── README.md
```

Dependencies: `fastapi`, `uvicorn[standard]`, `motor`, `redis`, `python-jose[cryptography]`,
`passlib[bcrypt]`, `pydantic-settings`, `authlib` (Google OAuth), `pytest`, `pytest-asyncio`, `httpx`.

---

## 10. Plugin-Side Changes (the parts that don't exist yet)

The backend is textbook; the novel work is on the plugin. Two additions:

1. **`commands/cortex-login.md`** — runs the device-grant flow, polls `/auth/token`,
   writes `~/.cortex/credentials.json` (chmod 600). Plus `/cortex-logout`, `/cortex-status`.
2. **`scripts/collect.sh`** + `hooks/hooks.json` entries — on `SessionStart`, `Stop`,
   and selected `PostToolUse`, read the event JSON on stdin, attach the bearer token,
   `curl -m 2` to `/v1/events`. Buffers to `~/.cortex/queue.jsonl`; flushes a batch on `Stop`.
   Silent on any failure (no token / offline / 401 → no-op).

Premium command gating (later): premium commands check for a valid token via `/v1/me`
and degrade gracefully when absent/revoked.

---

## 11. Future Extensions (hang off this same spine)

- **Billing (Stripe):** `orgs.plan` + `seats` already model it. Add Stripe customer/subscription
  IDs, webhooks (`/webhooks/stripe`) that flip plan/seat → toggle `api_tokens.revoked`.
- **Team Standards Registry:** new `standards` collection (org-owned, versioned stack/layer
  rules); add `GET /v1/standards` the plugin pulls live at build time. The strongest moat.
- **Hosted integrations:** Jira/Linear/Slack sync as org-scoped services keyed off the same auth.
- **Managed deploy targets:** Hostinger/K3s deploy-as-a-service, per-deploy metered.
- **Private command/skill registry:** the marketplace/ecosystem-tax play.

---

## 12. Open Questions

- Token lifetime vs. UX: 30 days (more re-logins, tighter security) vs. 90 days?
- Event sampling policy — which `PostToolUse` events are worth keeping vs. noise?
- Single-region vs. data-residency needs for enterprise customers?
- Do we expose a read API for the plugin itself (so `/cortex-status` shows team activity in-terminal)?

---

## 13. v1 Definition of Done

A developer can:
1. Run `/cortex-login`, approve in the browser, get a stored token.
2. Run `/auto-build`; phases + command events appear in MongoDB scoped to their org.
3. Open the dashboard, log in, and see their project's latest phase/score + recent activity.
4. An admin revokes a seat → that developer's next event 401s and premium commands degrade.

That single loop — login → ingest → dashboard → revoke — proves the whole monetization spine.
Everything else (billing, standards registry, integrations) is additive.
