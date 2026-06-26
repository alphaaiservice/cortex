# LOCAL_DEV_STANDARD.md — "Always Runs Locally" Contract
# ═══════════════════════════════════════════════════════════════════
# Canonical standard for how EVERY Cortex-built app runs on a developer's
# machine. The goal is absolute: a fresh clone runs locally with ONE command
# and NEVER fails for an avoidable reason (missing env, unready DB, wrong
# port, pending migration, missing seed, version drift).
#
# Consumers (reference this — do NOT duplicate):
#   - commands/auto-build.md  →  Phase 1 (scaffold), Phase 13 (docs), Phase 15 (boot gate)
#   - commands/init-project.md  →  scaffolds the bootstrap + LOCAL_DEV.md
#   - commands/gen-docs.md  →  generates LOCAL_DEV.md
#   - skills/project-setup/SKILL.md + skills/devops/SKILL.md  →  enforcement
#   - commands/onboard-dev.md  →  points new devs here
#
# THE PROMISE (print it in the README): "git clone → cp .env.example .env →
# make dev → open http://localhost:3000. That's it. If it doesn't work, the
# Troubleshooting table tells you exactly why."


# ╔══════════════════════════════════════════════════════════════════╗
# ║  1. PRINCIPLES (non-negotiable)                                  ║
# ╚══════════════════════════════════════════════════════════════════╝
#
#   ✅ ONE COMMAND boots the FULL stack: `make dev` (app + every datastore +
#      workers it needs). No multi-step ritual, no "now also start X".
#   ✅ WORKING DEFAULTS: `.env.example` has real, local-runnable values for
#      EVERY variable. Copying it to `.env` is enough to boot — no value is
#      left blank that the app needs to start. Secrets that need real creds
#      (Stripe, OAuth) have safe dev stubs + feature-flag the feature off
#      so a missing real key NEVER crashes startup.
#   ✅ NO MISSING-VAR CRASH: config loading validates env at startup and, for
#      any required-but-unset var, prints a precise, friendly message naming
#      the var and the line in .env.example to copy — never a raw stack trace.
#   ✅ DEPENDENCIES WAIT FOR EACH OTHER: app waits for MySQL/Mongo/Redis to be
#      healthy (compose `depends_on: condition: service_healthy` + app-side
#      retry/backoff). The app NEVER dies because a DB wasn't ready yet.
#   ✅ MIGRATIONS + SEED RUN AUTOMATICALLY on `make dev` (idempotent), so the
#      app always opens to a working, populated state — never an empty/broken DB.
#   ✅ VERIFIED BOOT: `make verify` starts the stack, polls `/health` until
#      green, hits one real endpoint, and reports PASS/FAIL. This is the gate.
#   ✅ PORTS ARE DOCUMENTED and overridable via env; conflicts produce a clear
#      message, not a cryptic bind error.
#   ✅ PINNED TOOLCHAIN: `.nvmrc` / `.python-version` / Gradle wrapper so the
#      right runtime is used; the bootstrap checks versions and warns clearly.
#   ✅ TWO MODES, both first-class: (A) Full-Docker (zero host deps) and
#      (B) Hybrid (datastores in Docker, app runs native for hot reload).
#
#   ❌ NEVER assume a globally-installed DB/Redis/tool on the host.
#   ❌ NEVER require editing source or hunting for undocumented env to boot.
#   ❌ NEVER let a missing optional integration (payments, email, OAuth) block
#      startup — degrade the feature, keep the app up.
#   ❌ NEVER ship a README "setup" that's just `pip install -r requirements`.


# ╔══════════════════════════════════════════════════════════════════╗
# ║  2. THE ONE-COMMAND BOOTSTRAP (Makefile — every project)         ║
# ╚══════════════════════════════════════════════════════════════════╝
#
# A root `Makefile` is the universal entrypoint regardless of language.
# `make dev` is the only command a developer must remember.

```makefile
# Makefile — universal local-dev entrypoint (works for Python / NestJS / Spring)
.DEFAULT_GOAL := help
SHELL := /bin/bash

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

env: ## Create .env from .env.example if missing (working local defaults)
	@test -f .env || (cp .env.example .env && echo "✅ Created .env from .env.example")

dev: env ## Boot the FULL stack locally (one command). Migrations + seed run automatically.
	docker compose up --build -d
	$(MAKE) wait-healthy
	$(MAKE) migrate
	$(MAKE) seed
	@echo "🚀 App up:   http://localhost:$${APP_PORT:-3000}"
	@echo "🩺 Health:   http://localhost:$${API_PORT:-8000}/health"

wait-healthy: ## Block until every service reports healthy
	@bash scripts/wait-for-healthy.sh

migrate: ## Run DB migrations (idempotent)
	docker compose exec -T app sh -lc "$$MIGRATE_CMD"   # Alembic | prisma migrate deploy | flyway migrate

seed: ## Seed realistic dev data (idempotent)
	docker compose exec -T app sh -lc "$$SEED_CMD"

verify: ## START → /health green → one real request → PASS/FAIL (the boot gate)
	@bash scripts/dev-verify.sh

logs: ## Tail all service logs
	docker compose logs -f

down: ## Stop the stack
	docker compose down

reset: ## Nuke volumes + rebuild from scratch (fixes 90% of "it broke" cases)
	docker compose down -v && $(MAKE) dev

dev-native: env ## Hybrid mode: datastores in Docker, app native (hot reload)
	docker compose up -d mysql mongo redis
	$(MAKE) wait-healthy
	@echo "Now run the app natively (see LOCAL_DEV.md §Hybrid)"
```

> `MIGRATE_CMD` / `SEED_CMD` / port vars come from `.env`. Set per stack:
> - **Python/FastAPI**: `MIGRATE_CMD="alembic upgrade head"`, `SEED_CMD="python -m app.seed"`
> - **NestJS**: `MIGRATE_CMD="pnpm prisma migrate deploy"`, `SEED_CMD="pnpm seed"`
> - **Spring Boot**: Flyway runs on boot; `SEED_CMD` = a seed profile/CommandLineRunner.


# ╔══════════════════════════════════════════════════════════════════╗
# ║  3. HEALTH-WAIT + BOOT-VERIFY SCRIPTS                            ║
# ╚══════════════════════════════════════════════════════════════════╝

```bash
# scripts/wait-for-healthy.sh — block until the stack is actually ready
#!/usr/bin/env bash
set -euo pipefail
API_PORT="${API_PORT:-8000}"
echo "⏳ Waiting for services to become healthy..."
for i in $(seq 1 60); do
  unhealthy=$(docker compose ps --format '{{.Service}} {{.Health}}' | grep -Ev 'healthy|^$' || true)
  if [ -z "$unhealthy" ] && curl -fsS "http://localhost:${API_PORT}/health" >/dev/null 2>&1; then
    echo "✅ All services healthy."; exit 0
  fi
  sleep 2
done
echo "❌ Services did not become healthy in time. Run 'make logs' — see LOCAL_DEV.md Troubleshooting."
docker compose ps
exit 1
```

```bash
# scripts/dev-verify.sh — the boot gate: proves the app runs locally
#!/usr/bin/env bash
set -euo pipefail
API_PORT="${API_PORT:-8000}"
make dev
echo "🔎 Verifying /health ..."
curl -fsS "http://localhost:${API_PORT}/health" | grep -q '"status":\s*"ok"' \
  && echo "✅ BOOT VERIFIED: app is running and healthy at http://localhost:${API_PORT}" \
  || { echo "❌ BOOT FAILED — /health not OK. See LOCAL_DEV.md Troubleshooting."; docker compose logs --tail=50; exit 1; }
```

> Every app MUST expose `GET /health` → `200 {"status":"ok"}` (liveness) and
> `GET /health/dependencies` → per-datastore status (readiness). These already
> exist in the stack (Phase 8 middleware) — the boot gate depends on them.


# ╔══════════════════════════════════════════════════════════════════╗
# ║  4. LOCAL_DEV.md — the document generated for EVERY project       ║
# ╚══════════════════════════════════════════════════════════════════╝
#
# Generate `LOCAL_DEV.md` at the project root and link it from the README's
# "Run Locally" section. It MUST contain ALL of:
#
#   1. **Promise** — the one-command quickstart, verbatim:
#        ```
#        git clone <repo> && cd <repo>
#        cp .env.example .env      # working local defaults
#        make dev                  # boots full stack + migrations + seed
#        # open http://localhost:3000
#        ```
#   2. **Prerequisites** — exact tools + versions (Docker ≥ X, and for hybrid:
#      Node via .nvmrc / Python via .python-version / JDK 21). One install line each.
#   3. **What `make dev` does** — plain-English list of every step.
#   4. **Ports table** — every service, its port, its URL, the env var to override:
#        | Service | Port | URL | Env |
#        |---------|------|-----|-----|
#        | Web     | 3000 | http://localhost:3000 | APP_PORT |
#        | API     | 8000 | http://localhost:8000 | API_PORT |
#        | MySQL   | 3306 | — | MYSQL_PORT |
#        | Mongo   | 27017| — | MONGO_PORT |
#        | Redis   | 6379 | — | REDIS_PORT |
#        | MinIO   | 9000 | http://localhost:9001 | MINIO_PORT |
#        | Meili   | 7700 | http://localhost:7700 | MEILI_PORT |
#   5. **Default credentials & seed accounts** — e.g. `admin@local.test / password`.
#   6. **Common commands** — `make logs`, `make migrate`, `make seed`,
#      `make verify`, `make down`, `make reset`.
#   7. **Hybrid mode (§B)** — how to run the app native with hot reload while
#      datastores stay in Docker (faster inner loop).
#   8. **Verifying it works** — `make verify` and what a healthy result looks like.
#   9. **Troubleshooting matrix** — §6 below, rendered in full.
#
# README must carry a "## Run Locally" section: the 3-line quickstart + a link
# to LOCAL_DEV.md. The promise lives at the TOP of the README, not buried.


# ╔══════════════════════════════════════════════════════════════════╗
# ║  5. .env.example — WORKING LOCAL DEFAULTS (never blank-blocks)    ║
# ╚══════════════════════════════════════════════════════════════════╝
#
#   - Every variable present, grouped + commented (## what it does).
#   - Local infra vars have REAL working values (DB URLs point at the compose
#     service hostnames, ports match the table, dev passwords filled in).
#   - Third-party creds (Stripe, Razorpay, Google OAuth, SMTP, LLM keys) get
#     a clearly-marked dev placeholder AND the feature checks for a real value
#     at runtime — if absent, it logs "X disabled (no key)" and the app still boots.
#   - Mark required-vs-optional inline: `# REQUIRED` / `# OPTIONAL (feature: payments)`.
#   - `APP_PORT`, `API_PORT`, and every datastore port are overridable here.
#
# Example (excerpt):
#   APP_PORT=3000                 # REQUIRED — web port
#   API_PORT=8000                 # REQUIRED — api port
#   DATABASE_URL=mysql://app:devpass@mysql:3306/app   # REQUIRED — points at compose service
#   REDIS_URL=redis://redis:6379/0                    # REQUIRED
#   JWT_SECRET=dev-only-change-in-prod                # REQUIRED — dev value works
#   STRIPE_SECRET_KEY=                                # OPTIONAL (payments) — blank = payments disabled, app still boots
#   GOOGLE_CLIENT_ID=                                 # OPTIONAL (oauth)     — blank = Google login hidden


# ╔══════════════════════════════════════════════════════════════════╗
# ║  6. TROUBLESHOOTING MATRIX (render into LOCAL_DEV.md)            ║
# ╚══════════════════════════════════════════════════════════════════╝
#
# | Symptom | Cause | Fix |
# |---------|-------|-----|
# | `make dev` fails immediately | Docker not running | Start Docker Desktop, retry |
# | `port is already allocated` | Port in use by another process | Change the port in `.env` (APP_PORT/API_PORT/…) or `make down` the other stack |
# | App restarts / "connection refused" to DB | App started before DB ready | Already handled by health-wait; if persists `make reset` |
# | `Missing required env: X` at startup | A REQUIRED var is unset | Copy the line for X from `.env.example` into `.env` |
# | Migrations error / unknown column | Schema drift in local DB | `make reset` (drops volumes, re-migrates, re-seeds) |
# | Empty app / no data | Seed didn't run | `make seed` |
# | Wrong Node/Python version (hybrid) | Host runtime ≠ pinned | `nvm use` / `pyenv local` (reads .nvmrc / .python-version) |
# | Slow first boot | Images building | One-time; subsequent `make dev` is fast |
# | "It's just broken" | Stale containers/volumes | `make reset` fixes ~90% of local issues |
# | Frontend can't reach API | API_URL misconfigured | Confirm `NEXT_PUBLIC_API_URL` in `.env` matches API_PORT |
#
# Keep this table CURRENT: when a real local-run failure is hit during the
# build, add its row here so the next person never gets stuck.


# ╔══════════════════════════════════════════════════════════════════╗
# ║  7. ENFORCEMENT CHECKLIST (run before declaring a build done)     ║
# ╚══════════════════════════════════════════════════════════════════╝
#
#   □ Root `Makefile` with `dev`, `verify`, `migrate`, `seed`, `reset`, `down`.
#   □ `scripts/wait-for-healthy.sh` + `scripts/dev-verify.sh` present + executable.
#   □ `docker compose` uses healthchecks + `depends_on: service_healthy`.
#   □ `.env.example` boots as-is (no required var left blank); optional creds
#     degrade gracefully (app boots without them).
#   □ Startup config validation prints friendly "missing env: X" (no stack trace).
#   □ Migrations + seed run on `make dev`, idempotently.
#   □ `GET /health` → 200 `{"status":"ok"}`; `/health/dependencies` per store.
#   □ `LOCAL_DEV.md` generated with ALL of §4, incl. the full Troubleshooting table.
#   □ README has a top-level "Run Locally" 3-line quickstart linking LOCAL_DEV.md.
#   □ `.nvmrc` / `.python-version` / Gradle wrapper pin the toolchain.
#   □ **`make verify` actually passes** on a clean checkout — this is the gate.
#
# If `make verify` does not pass on a fresh clone, the app is NOT done.
