---
description: "Compare existing app against Alpha AI engineering standards — ONLY checks what's relevant to YOUR project. Generates GAP_ANALYSIS.md with what's present, missing, and needs migration. Usage: /gap-analysis [path-to-project]"
---

# Gap Analysis — Alpha AI Standards Compliance (Context-Aware)

Analyze project at: **$ARGUMENTS** (default: current directory)

Compare the existing codebase against **ONLY the standards relevant to this project** — NOT every standard in the book.

**KEY PRINCIPLE: A project that doesn't need MongoDB should NOT be flagged for missing MongoDB. A project without payments should NOT be flagged for missing Razorpay. Only check what the project ACTUALLY requires.**

---

## Step 0: Detect Project Requirements

Before checking any standards, first understand WHAT this project needs.

### 0.1: Read Project Context

Gather requirements from these sources (check in order):

```
1. Read PRD.md or PRD_*.md (if exists) — most authoritative source of requirements
2. Read SPRINT_PLAN.md (if exists) — tells what features are planned
3. Read PROJECT_ANALYSIS.md (if exists, from /analyze-project)
4. Read README.md (if exists) — project description
5. Read CLAUDE.md (if exists) — project-specific standards
6. Quick scan of codebase (package.json, requirements.txt, docker-compose.yml)
```

### 0.2: Build Project Requirements Profile

Based on the context gathered, build a requirements profile by answering YES/NO to each:

```
PROJECT REQUIREMENTS PROFILE
═══════════════════════════════

Project Name:       [detected name]
Project Type:       [API only | Web app | Mobile app | Full-stack | AI/ML | Library]
Description:        [1-line from PRD/README]

Core Requirements:
  Has backend API?                    → [YES/NO]
  Has user authentication?            → [YES/NO]
  Has SQL database (relational data)? → [YES/NO]
  Has document/NoSQL storage needs?   → [YES/NO] — only YES if project stores:
                                        - Unstructured documents, logs, audit trails
                                        - Highly nested/variable-schema data
                                        - Chat messages, activity feeds, analytics events
                                        - If NO clear need → NO (do NOT default to YES)
  Has caching/session needs?          → [YES/NO] — only YES if project has:
                                        - High-traffic endpoints needing caching
                                        - Real-time session management
                                        - Rate limiting, queues, pub/sub
                                        - If simple CRUD app → NO
  Has payment processing?             → [YES/NO]
  Has India market / INR billing?     → [YES/NO] — determines Razorpay vs Stripe

Frontend Requirements:
  Has web frontend?                   → [YES/NO]
  Has mobile app?                     → [YES/NO]
  Needs dark mode?                    → [YES/NO] — YES if user-facing app
  Needs i18n (multilingual)?          → [YES/NO] — only if PRD mentions multiple languages
  Needs animations/transitions?       → [YES/NO]

Feature Requirements:
  Has file uploads?                   → [YES/NO]
  Has full-text search?               → [YES/NO] — only if search is a core feature
  Has real-time features?             → [YES/NO] — chat, live updates, notifications
  Has push notifications?             → [YES/NO] — only if mobile or PWA with push
  Has email sending?                  → [YES/NO]
  Has social login (Google/Apple)?    → [YES/NO]
  Has role-based access (RBAC)?       → [YES/NO] — only if multiple user roles
  Has 2FA/MFA?                        → [YES/NO] — only if high-security app
  Has background jobs/queues?         → [YES/NO]

AI/GenAI Requirements:
  Has AI/LLM features?                → [YES/NO]
  Has RAG/document search?            → [YES/NO]
  Has AI agents/tools?                → [YES/NO]
  Has MCP/A2A integration?            → [YES/NO]

Infrastructure:
  Needs error tracking (production)?  → [YES/NO] — YES if deploying to production
  Needs analytics?                    → [YES/NO] — only if tracking user behavior
  Needs monitoring?                   → [YES/NO] — YES if production deployment
```

### 0.3: Present Profile for Confirmation

**IMPORTANT:** Before proceeding, show the detected profile to the user:

```
I detected these requirements for your project:

  ✅ Backend API (FastAPI)
  ✅ User authentication (JWT)
  ✅ SQL database (MySQL)
  ❌ NoSQL database — not needed (no document storage requirements detected)
  ❌ Redis caching — not needed (simple CRUD, no high-traffic caching needs)
  ❌ Payments — not needed (no billing features in PRD)
  ✅ Web frontend (Next.js)
  ❌ Mobile app — not needed
  ❌ AI/GenAI — not needed

I will ONLY check standards relevant to these requirements.
Anything marked ❌ will be listed as "NOT APPLICABLE" (not as missing).

Does this look correct? (If wrong, tell me what to add/remove)
```

If the user corrects the profile, update it before proceeding.

---

## Step 1: Define Applicable Standards

Based on the requirements profile, classify each standard as **APPLICABLE** or **NOT APPLICABLE**.

### Standard Classification Rules

**ALWAYS APPLICABLE (every Alpha AI project with a backend):**

| # | Standard | Condition |
|---|----------|-----------|
| 1 | FastAPI + Python 3.11+ | Has backend API = YES |
| 7 | ruff linter | Has backend API = YES |
| 8 | mypy strict | Has backend API = YES |
| 9 | pytest + pytest-asyncio | Has backend API = YES |
| 10 | Layer segregation (api/services/repos) | Has backend API = YES |

**APPLICABLE ONLY IF AUTH EXISTS:**

| # | Standard | Condition |
|---|----------|-----------|
| 2 | JWT + HTTP-Only Cookies | Has authentication = YES |
| 13 | CSRF double-submit cookie | Has authentication = YES AND has web frontend = YES |
| 14 | RBAC roles + permissions | Has RBAC = YES |
| 15 | 2FA/TOTP (pyotp) | Has 2FA = YES |
| 16 | Session management | Has authentication = YES |

**APPLICABLE ONLY IF FEATURE IS NEEDED:**

| # | Standard | Condition |
|---|----------|-----------|
| 3 | MySQL + SQLAlchemy 2.0 async | Has SQL database = YES |
| 4 | MongoDB + PyMongo | Has document/NoSQL needs = YES |
| 5 | Redis (redis.asyncio) | Has caching/session/queue needs = YES |
| 6 | Razorpay | Has payments = YES AND India market = YES |
| 6b | Stripe (alternative) | Has payments = YES AND NOT India market |
| 11 | Google OAuth2 via authlib | Has social login = YES |
| 12 | Transactional emails | Has email sending = YES |
| 26 | S3/MinIO file upload | Has file uploads = YES |
| 27 | Meilisearch | Has full-text search = YES (as core feature) |
| 28 | WebSocket real-time | Has real-time features = YES |
| 29 | FCM push notifications | Has push notifications = YES |
| 30 | Sentry error tracking | Needs error tracking = YES (production deployment) |
| 31 | PostHog analytics | Needs analytics = YES |
| 32 | i18n (next-intl + i18next) | Needs i18n = YES |

**APPLICABLE ONLY IF FRONTEND EXISTS:**

| # | Standard | Condition |
|---|----------|-----------|
| 17 | Next.js 15+ TypeScript + Tailwind | Has web frontend = YES |
| 18 | Dark mode + System Auto | Has web frontend = YES AND needs dark mode = YES |
| 19 | Framer Motion | Has web frontend = YES AND needs animations = YES |
| 20 | React Hook Form + Zod | Has web frontend = YES |

**APPLICABLE ONLY IF MOBILE EXISTS:**

| # | Standard | Condition |
|---|----------|-----------|
| 21 | React Native + Expo SDK 55+ | Has mobile app = YES |
| 22 | NativeWind + Reanimated 3 | Has mobile app = YES |
| 23 | Drawer + Bottom Tabs navigation | Has mobile app = YES |
| 24 | expo-secure-store (NOT AsyncStorage) | Has mobile app = YES AND has auth = YES |
| 25 | Apple Sign-In | Has mobile app = YES AND has social login = YES |

**APPLICABLE ONLY IF AI/GENAI EXISTS:**

| # | Standard | Condition |
|---|----------|-----------|
| 33 | LiteLLM gateway | Has AI/LLM features = YES |
| 34 | Agentic framework (ADK/LangGraph) | Has AI agents = YES |
| 35 | RAG pipeline (Qdrant + embeddings) | Has RAG = YES |
| 36 | AI evaluation (DeepEval + RAGAS) | Has AI features = YES |

**APPLICABLE ONLY IF AGENT/MCP EXISTS:**

| # | Standard | Condition |
|---|----------|-----------|
| 37 | MCP Protocol | Has MCP integration = YES |
| 38 | A2A Protocol | Has A2A integration = YES |
| 39 | Agent Skills | Has agent skills = YES |

---

## Step 2: Check ONLY Applicable Standards

For each standard marked as APPLICABLE, check the codebase and classify:
- ✅ **PRESENT** — Already implemented correctly
- ⚠️ **PARTIAL** — Implemented but not fully compliant
- ❌ **MISSING** — Not implemented (needs to be added)
- 🔄 **MIGRATE** — Implemented with wrong technology

For NOT APPLICABLE standards, mark them as:
- ➖ **N/A** — Not required for this project

**Check methods** (same as before — grep deps, scan code, check directories).

---

## Step 3: Generate Compliance Score

Calculate score using ONLY applicable standards:

```
Total applicable standards = [count of APPLICABLE only, NOT counting N/A]
Present count     = [count of ✅]
Partial count     = [count of ⚠️]
Missing count     = [count of ❌]
Migration count   = [count of 🔄]

Compliance score  = (Present + Partial × 0.5) / Total Applicable × 100

NOT APPLICABLE standards are EXCLUDED from the score — they don't count against you.
```

---

## Step 4: Prioritize Actions

Classify each gap into priority tiers:

### P0 — Critical (Security & Auth)
- Token storage violations (localStorage → HTTP-Only cookies)
- Missing CSRF protection (if web frontend + cookies)
- Exposed API keys or hardcoded secrets
- No error tracking in production (if deploying to production)

### P1 — High (Architecture & Data)
- Wrong database technology (needs migration)
- Wrong payment provider (needs migration)
- Missing layer segregation
- No automated tests

### P2 — Medium (Required Features)
- Missing features that ARE in the requirements profile
- Partial implementations that need completion
- Missing linting/type checking setup

### P3 — Low (Polish)
- Nice-to-have improvements
- Analytics, monitoring (if not production-critical)
- Advanced features that could be added later

---

## Step 5: Estimate Effort

| Effort | Description | Examples |
|--------|-------------|---------|
| 🟢 Small | < 2 hours | Add dependency, config change, add dark mode toggle |
| 🟡 Medium | 2-8 hours | Add RBAC, add email templates, add file upload |
| 🔴 Large | 1-3 days | Migrate database, add payment system, add GenAI stack |
| ⚫ XL | 3+ days | Full auth migration, add mobile app, add full RAG pipeline |

---

## Step 6: Generate GAP_ANALYSIS.md

```markdown
# Gap Analysis Report — Alpha AI Standards
**Generated**: [date]
**Project**: [name]
**Project Type**: [API only | Web app | Full-stack | etc.]

## Requirements Profile
| Requirement | Needed? | Reason |
|-------------|---------|--------|
| Backend API | ✅ Yes | [reason from PRD/codebase] |
| Authentication | ✅ Yes | [reason] |
| SQL Database | ✅ Yes | [reason] |
| NoSQL (MongoDB) | ➖ No | [why not needed] |
| Redis Caching | ➖ No | [why not needed] |
| Payments | ➖ No | [why not needed] |
| Web Frontend | ✅ Yes | [reason] |
| Mobile App | ➖ No | [not in requirements] |
| AI/GenAI | ➖ No | [not in requirements] |
| [... etc for all requirement categories ...] |

**Standards Applicable:** [N] out of 39 total
**Standards Not Applicable:** [M] (excluded from scoring)

## Compliance Dashboard

| Category | Applicable | Present | Partial | Missing | Migrate | Score |
|----------|-----------|---------|---------|---------|---------|-------|
| Core Backend | [n]/[total] | [n] ✅ | [n] ⚠️ | [n] ❌ | [n] 🔄 | [x]% |
| Auth & Security | [n]/[total] | [n] ✅ | [n] ⚠️ | [n] ❌ | [n] 🔄 | [x]% |
| Frontend | [n]/[total] | [n] ✅ | [n] ⚠️ | [n] ❌ | [n] 🔄 | [x]% |
| Mobile | ➖ N/A | — | — | — | — | — |
| Infrastructure | [n]/[total] | [n] ✅ | [n] ⚠️ | [n] ❌ | [n] 🔄 | [x]% |
| GenAI / AI | ➖ N/A | — | — | — | — | — |
| Open Standards | ➖ N/A | — | — | — | — | — |
| **TOTAL** | **[n]** | **[n]** | **[n]** | **[n]** | **[n]** | **[x]%** |

## Detailed Findings

### ✅ PRESENT (Already Compliant)
| # | Standard | Status | Notes |
|---|----------|--------|-------|
| 1 | FastAPI + Python 3.11 | ✅ Present | Found in requirements.txt |

### ⚠️ PARTIAL (Needs Fixes)
| # | Standard | Issue | Fix Required |
|---|----------|-------|-------------|
| [n] | [standard] | [what's wrong] | [what to fix] |

### ❌ MISSING (Required but Not Implemented)
| # | Standard | Priority | Effort | Description |
|---|----------|----------|--------|-------------|
| [n] | [standard] | P[0-3] | [🟢🟡🔴⚫] | [what needs to be built] |

### 🔄 MIGRATE (Wrong Technology)
| # | Standard | Current | Target | Effort | Risk |
|---|----------|---------|--------|--------|------|
| [n] | [standard] | [current] | [alpha target] | [effort] | [risk] |

### ➖ NOT APPLICABLE (Not Required for This Project)
| # | Standard | Reason Not Needed |
|---|----------|-------------------|
| 4 | MongoDB | No document storage needs — all data is relational |
| 5 | Redis | Simple CRUD app, no caching/queue requirements |
| 6 | Razorpay | No payment features in project scope |
| 21-25 | Mobile | No mobile app in requirements |
| 33-36 | GenAI | No AI/ML features in requirements |
| [... all N/A items ...] |

## Priority Action Plan

### Sprint 1: Critical Security Fixes (P0)
1. [action item with effort]

### Sprint 2: Architecture Alignment (P1)
1. [action item]

### Sprint 3: Required Features (P2)
1. [action item]

### Sprint 4: Polish (P3)
1. [action item]

## Optional Enhancements (Not Required, But Recommended)

These are NOT gaps — they are optional improvements that could enhance your project if you choose to add them later:

| Enhancement | Benefit | Effort | Add With |
|-------------|---------|--------|----------|
| Redis caching | Faster API responses under load | 🟡 Medium | `/retrofit redis` |
| Meilisearch | Better search UX than SQL LIKE queries | 🟡 Medium | `/retrofit meilisearch` |
| PostHog analytics | User behavior insights | 🟢 Small | `/retrofit posthog` |
| [only list if genuinely useful for THIS project] |

## Recommended Commands
- `/retrofit [feature]` — Add missing features one by one
- `/migrate-stack [from] to [to]` — Migrate technology components
- `/init-project --existing` — Add missing Alpha AI project structure
```

---

## Step 7: Output Summary

```
╔══════════════════════════════════════════════════════════════╗
║  GAP ANALYSIS COMPLETE                                        ║
╠══════════════════════════════════════════════════════════════╣
║  Project: [name] ([type])                                    ║
║                                                               ║
║  Standards Applicable: [N] of 39                              ║
║  Standards Skipped:    [M] (not needed for this project)      ║
║                                                               ║
║  Compliance Score: [X]% (of applicable standards only)        ║
║                                                               ║
║  ✅ Present:  [n] standards                                   ║
║  ⚠️ Partial:  [n] standards (needs fixes)                     ║
║  ❌ Missing:  [n] standards (needs implementation)            ║
║  🔄 Migrate:  [n] standards (wrong technology)                ║
║  ➖ N/A:      [m] standards (not applicable)                  ║
║                                                               ║
║  Top 3 Actions:                                               ║
║  1. [highest priority — only from applicable standards]       ║
║  2. [second priority]                                         ║
║  3. [third priority]                                          ║
║                                                               ║
║  📄 Generated: GAP_ANALYSIS.md                                ║
║  Next: /retrofit [feature] or /migrate-stack [migration]      ║
╚══════════════════════════════════════════════════════════════╝
```

---

## Critical Rules

1. **NEVER flag a standard as MISSING if the project doesn't need it.** MongoDB, Redis, Razorpay, Meilisearch, push notifications, GenAI, mobile — these are ALL conditional. Only check them if the project requirements demand them.

2. **When in doubt, mark as N/A, not MISSING.** It's better to skip an optional standard than to create false alarms that make the report noisy and useless.

3. **Always show the requirements profile FIRST** and let the user confirm before scanning. This prevents wasting time checking irrelevant standards.

4. **The compliance score must ONLY count applicable standards.** A simple REST API with 10 applicable standards all passing should score 100%, not 25% because it's "missing" 30 irrelevant features.

5. **List N/A items transparently** in a separate section so the user knows what was skipped and why. If they think something should be checked, they can tell you to add it.

6. **Optional Enhancements section** should genuinely be optional — suggestions that COULD help the project, not requirements masquerading as suggestions. Only list enhancements that make sense for THIS specific project.
