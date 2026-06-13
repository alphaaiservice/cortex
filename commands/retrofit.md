---
description: "Add missing Alpha AI features to an existing app without breaking existing code. Supports all 36 features. Usage: /retrofit <feature-name> [--all] [--from-gap-analysis]"
---

# Retrofit — Add Missing Features to Existing App

Add feature: **$ARGUMENTS**

This command adds Alpha AI standard features to an existing application, respecting existing code patterns and conventions.

---

## Supported Features (use any of these as $ARGUMENTS)

### Auth & Security
- `jwt-cookies` — Migrate token storage to HTTP-only cookies
- `google-oauth` — Add Google OAuth2 via authlib
- `email-system` — Add transactional email system (fastapi-mail + Celery + templates)
- `csrf` — Add CSRF double-submit cookie protection
- `rbac` — Add role-based access control with granular permissions
- `2fa` — Add TOTP two-factor authentication (pyotp + QR codes)
- `session-management` — Add active session tracking and revocation
- `rate-limiting` — Add Redis sliding window rate limiting (per-plan)

### Payments & Billing
- `razorpay` — Add Razorpay subscription + one-time payment integration
- `credit-points` — Add credit point billing system (subscription gives points, deduct per action)
- `topup-packs` — Add top-up point pack purchases
- `invoices` — Add invoice generation with GST (18%)
- `free-trial` — Add 7-day free trial with moderate free points

### Frontend
- `dark-mode` — Add Light + Dark + System theme support
- `i18n` — Add multi-language support (English + Hindi minimum)
- `pwa` — Add Progressive Web App support (service worker, install prompt)
- `search-palette` — Add Cmd+K command palette with Meilisearch
- `framer-motion` — Add page transitions and micro-interactions

### Mobile
- `mobile-app` — Add React Native + Expo SDK 55+ mobile app scaffold
- `mobile-auth` — Add expo-secure-store + Google OAuth + Apple Sign-In
- `mobile-offline` — Add offline support (NetInfo + query persist + mutation queue)
- `mobile-push` — Add push notifications (expo-notifications + FCM)

### Infrastructure
- `file-upload` — Add S3/MinIO presigned URL upload system
- `meilisearch` — Add full-text search engine
- `websocket` — Add WebSocket real-time notifications
- `push-notifications` — Add FCM push notifications
- `sentry` — Add Sentry error tracking (backend + frontend + mobile)
- `posthog` — Add PostHog analytics event tracking
- `feature-flags` — Add feature flag system (MySQL + Redis cache + admin toggle)
- `admin-panel` — Add admin API routes + frontend section
- `feedback` — Add in-app feedback widget (bug reports, feature requests)
- `onboarding` — Add product tour / setup checklist
- `backup` — Add automated daily MySQL + MongoDB backup to S3
- `gdpr` — Add GDPR/DPDPA compliance (data export, account deletion, consent)
- `legal-pages` — Add Terms, Privacy, Cookie, Refund policy pages

### GenAI / Agentic AI
- `genai-gateway` — Add LiteLLM unified LLM gateway
- `ai-agents` — Add agentic framework (Google ADK / LangGraph / CrewAI)
- `rag-pipeline` — Add RAG pipeline (Qdrant + embeddings + semantic chunking)
- `agentic-rag` — Add Agentic RAG (dynamic retrieval agent)
- `ai-chat` — Add AI chat with SSE streaming
- `ai-eval` — Add AI evaluation (DeepEval + RAGAS + promptfoo)
- `structured-output` — Add instructor + Pydantic validated LLM extraction
- `semantic-cache` — Add Redis semantic caching for LLM calls
- `reranking` — Add Cohere Rerank / FlashRank post-retrieval
- `multimodal` — Add multi-modal AI (vision, image gen, audio)
- `voice-ai` — Add Voice AI (Whisper STT + OpenAI/Gemini/ElevenLabs TTS)
- `hitl` — Add Human-in-the-Loop review queue
- `context-management` — Add context window management (tiktoken)
- `batch-processing` — Add batch AI processing (Celery + Redis progress)
- `ai-observability` — Add Langfuse/LangSmith LLM tracing
- `ai-guardrails` — Add input/output filtering + cost caps
- `prompt-management` — Add Jinja2/YAML prompt templates

### Open Standards
- `mcp` — Add MCP server (tools + prompts + resources)
- `a2a` — Add A2A Agent Card + task handler
- `--all` — Add ALL missing features (reads GAP_ANALYSIS.md for priority order)
- `--from-gap-analysis` — Add features identified as missing in GAP_ANALYSIS.md

---

## Step 0: Safety — Worktree Isolation (MANDATORY before any mutation)

> **📖 CANONICAL REFERENCE**: `commands/references/WORKTREE_SAFETY.md` defines the safety decision tree for all file-mutation commands. Load it and follow it BEFORE any `Write` / `Edit` / `Bash` mutation in this run.

Retrofits add new code into a working application — a botched run risks breaking the existing app. The user MUST review the diff before anything lands in their main checkout.

Quick summary (full tree + rationale in the reference file):

1. **Confirm scope with the user**, then ask: isolated worktree (DEFAULT, recommended) vs current checkout (risky, requires opt-in) vs cancel.
2. **Isolated worktree** (default): either spawn the mutation phase as `Agent({ ..., isolation: "worktree" })`, OR manually `git worktree add ../<repo>-retrofit-$(date +%s) -b retrofit/auto`. After completion, show the diff and let the user merge / cherry-pick / discard.
3. **Current checkout** (only with explicit user opt-in AND a single small feature like `dark-mode` or `sentry`): refuse if `git status --porcelain` is non-empty; create a savepoint commit before any mutation.
4. **No git**: refuse to proceed.

When `--all` or `--from-gap-analysis` is set, the worktree is non-negotiable (too many features at once for in-place mutation to be safe).

---

## Step 1: Analyze Existing Codebase

Before adding anything, understand what exists:

1. **Read PROJECT_ANALYSIS.md** (if exists) for tech stack baseline
2. **Read GAP_ANALYSIS.md** (if exists) for known gaps
3. **Scan the specific area** being retrofitted:

```
Use Glob + Grep to find:
- Existing auth code (if adding auth features)
- Existing payment code (if adding billing)
- Existing AI code (if adding GenAI)
- Existing infra code (if adding infrastructure)
- Project structure and conventions
- Import patterns and coding style
```

**CRITICAL**: Identify:
- **Naming convention** (snake_case vs camelCase, file naming pattern)
- **Directory structure** (where new code should go)
- **Import style** (absolute vs relative, how deps are injected)
- **Error handling pattern** (custom exceptions? HTTP exceptions directly?)
- **Config pattern** (env vars loaded how? Pydantic BaseSettings?)
- **Test pattern** (where tests live, naming convention, fixtures used)

---

## Step 2: Plan the Retrofit

Generate a retrofit plan:

```markdown
# Retrofit Plan: [feature-name]

## What will be added
- [list of new files]
- [list of modified files]
- [new dependencies]
- [new environment variables]
- [database migrations needed]

## What will NOT be changed
- [existing files that stay untouched]
- [existing behavior that won't change]

## Integration Points
- [how new code connects to existing code]
- [which existing services/routes need updating]

## Risk Assessment
- Breaking changes: [yes/no — details]
- Data migration: [yes/no — details]
- Downtime required: [yes/no — details]
```

**Ask for user confirmation** before proceeding (unless `--yes` flag).

---

## Step 3: Implement the Retrofit

### Rules for retrofitting:

1. **NEVER overwrite existing files** — only add new code or append to existing
2. **Follow existing patterns** — match the project's coding style, not Alpha AI's ideal
3. **Add new files** in the right directories (respect existing structure)
4. **Update existing routers** — add new routes to existing router files
5. **Add dependencies** — append to requirements.txt / package.json (don't replace)
6. **Add env vars** — append to .env.example (don't replace existing)
7. **Create migrations** — if DB changes needed, create proper Alembic/Prisma migrations
8. **Add tests** — create test files for all new code
9. **Update docker-compose** — add new services if needed (don't replace existing)

### Implementation order:

1. **Dependencies first** — Add new packages
2. **Models/schemas** — Add new database models
3. **Repositories** — Add data access layer
4. **Services** — Add business logic
5. **API routes** — Add new endpoints
6. **Frontend** — Add new pages/components (if applicable). MUST meet the production bar in `skills/alpha-architecture/references/CODE_PATTERNS_FRONTEND_PRODUCTION.md`: real next/font pairing + OKLCH tokens (no system fonts / raw hex / bg-blue-500), real-data wiring, friendly branded errors (NO HTTP codes, exceptions, or stack traces shown to users). Match the existing app's BRAND_GUIDE/token system — never introduce ad-hoc colors.
7. **Tests** — Add test coverage
8. **Config** — Update env vars, docker-compose, docs

### If `--all` or `--from-gap-analysis`:

Read GAP_ANALYSIS.md and implement features in priority order:
1. P0 (Critical) first
2. P1 (High) next
3. P2 (Medium) then
4. P3 (Low) last

Use **Agent tool** (mode = "bypassPermissions") to parallelize independent features.

---

## Step 4: Verify Integration

After implementing:

```bash
# Check code compiles
ruff check app/ 2>/dev/null || npx tsc --noEmit 2>/dev/null

# Run existing tests (make sure nothing broke)
pytest 2>/dev/null || npm test 2>/dev/null

# Run new tests
pytest app/tests/test_[new_feature]* 2>/dev/null
```

If any existing tests break, **fix them immediately** — retrofitting must not break existing functionality.

---

## Step 5: Output Summary

```
╔══════════════════════════════════════════════════════════════╗
║  RETROFIT COMPLETE: [feature-name]                            ║
╠══════════════════════════════════════════════════════════════╣
║                                                               ║
║  New Files Created:                                           ║
║  ├── [file1.py] — [purpose]                                   ║
║  ├── [file2.py] — [purpose]                                   ║
║  └── [file3.py] — [purpose]                                   ║
║                                                               ║
║  Modified Files:                                              ║
║  ├── [existing1.py] — [what changed]                          ║
║  └── [existing2.py] — [what changed]                          ║
║                                                               ║
║  New Dependencies: [list]                                     ║
║  New Env Vars: [list]                                         ║
║  Migrations: [yes/no]                                         ║
║                                                               ║
║  Tests: [X] new tests, [Y] existing tests still passing      ║
║                                                               ║
║  ⚠️ Manual Steps Required:                                    ║
║  1. [any manual setup steps]                                  ║
║  2. [env var values to fill in]                               ║
║  3. [run migrations: alembic upgrade head]                    ║
╚══════════════════════════════════════════════════════════════╝
```
