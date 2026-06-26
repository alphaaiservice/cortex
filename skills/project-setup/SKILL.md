---
name: project-setup
description: "Auto-invoked when Claude detects project initialization, scaffolding, or boilerplate setup tasks. Provides best practices for project structure, Docker multi-stage builds, CI/CD pipeline stages, environment management, and configuration file conventions."
license: "Proprietary — Alpha AI Service Pvt Ltd"
compatibility: "Designed for Claude Code with cortex plugin"
metadata:
  author: "Alpha AI Service Pvt Ltd"
  version: "2.0"
---

# Project Setup Skill

This skill is automatically activated when the task involves setting up a new project or adding standard configurations to an existing one.

## When to Use

- Creating a new project from scratch
- Adding CI/CD pipelines
- Setting up Docker configurations
- Adding linting, formatting, or testing infrastructure
- Creating standard documentation templates

## Best Practices

### Project Structure
- Keep a flat structure for small projects, nested for large ones
- Separate concerns: `src/`, `tests/`, `docs/`, `scripts/`, `config/`
- Use barrel files (index.ts) for clean imports
- Keep configuration files at the root

### Configuration Files Priority
1. `.editorconfig` — Consistent editor settings
2. Linter config — Code quality enforcement
3. Formatter config — Consistent formatting
4. `.gitignore` — Proper exclusions
5. `CLAUDE.md` — AI assistant context

### CI/CD Pipeline Stages
1. Lint → 2. Type Check → 3. Unit Tests → 4. Build → 5. Integration Tests → 6. Security Scan → 7. Deploy

### Docker Best Practices
- Use multi-stage builds
- Pin base image versions
- Don't run as root
- Use .dockerignore
- Minimize layers
- Put frequently changing steps last

### Environment Management
- Never commit .env files
- Always provide .env.example **with working local defaults** — a plain `cp .env.example .env` must be enough to boot. No required var left blank.
- Document every environment variable (`# REQUIRED` / `# OPTIONAL (feature)`)
- Use different configs per environment
- Validate env vars at startup → friendly "missing required env: X" message, never a stack trace
- Third-party creds blank by default and feature-degrading (missing key = feature off, app still boots)

### Always Runs Locally (HARD — see `commands/references/LOCAL_DEV_STANDARD.md`)
Every project MUST run on a fresh clone with ONE command and never fail for an
avoidable reason. Enforce the full standard:
- **One command**: `make dev` boots the FULL stack (app + every datastore + workers)
  and runs migrations + seed automatically. `make reset` nukes volumes + rebuilds.
- **Boot gate**: `make verify` starts the stack, waits for health, hits
  `GET /health` (200 `{"status":"ok"}`), reports PASS/FAIL. A build/scaffold is NOT
  done until `make verify` passes on a clean checkout.
- **Dependency readiness**: compose healthchecks + `depends_on: service_healthy` +
  app-side connect retry — the app never dies because a DB wasn't ready.
- **Docs**: generate `LOCAL_DEV.md` (quickstart, prerequisites, ports table, seed
  creds, common commands, hybrid native-hot-reload mode, full Troubleshooting matrix)
  and a top-level README "Run Locally" section linking it.
- **Pinned toolchain**: `.nvmrc` / `.python-version` / Gradle wrapper.
