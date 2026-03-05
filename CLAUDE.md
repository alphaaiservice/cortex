# CLAUDE.md — Cortex Plugin Development Context

## What Is This Project?

This is a **Claude Code Plugin** called `cortex` (Cortex) built by Alpha AI Service Pvt Ltd. It automates the entire software development lifecycle — from project scaffolding to autonomous product building — with zero human intervention.

The plugin enforces Alpha AI's engineering standards across **3 backend languages**: Python/FastAPI, Node.js/NestJS, Java/Spring Boot — plus JWT+HTTP-Only Cookies (NEVER localStorage/sessionStorage), MySQL+ORM, MongoDB, Redis, and strict layer segregation.

---

## Plugin Architecture

This is NOT a regular Python/Node project. It is a **Claude Code Plugin** — a collection of Markdown instruction files, bash scripts, and JSON configs that extend Claude Code's capabilities.

### Directory Structure

```
cortex/
│
├── .claude-plugin/
│   ├── plugin.json              # Plugin metadata (name, version, author)
│   └── marketplace.json         # Marketplace catalog (for distribution via alphaaiservice/cortex)
│
├── commands/                     # SLASH COMMANDS — user invokes with /command-name (41 total)
│   │
│   │  # ── Planning & Research ──
│   ├── gen-prd.md               # /gen-prd — Generate PRD from brief idea
│   ├── gen-brand.md             # /gen-brand — SVG logo & brand identity generation
│   ├── market-research.md       # /market-research — Deep competitive analysis
│   ├── sprint-plan.md           # /sprint-plan — Break PRD into sprint tasks with estimates
│   │
│   │  # ── Project Setup ──
│   ├── init-project.md          # /init-project — Scaffold new OR upgrade existing FastAPI project
│   ├── analyze-project.md       # /analyze-project — Scan existing codebase, map architecture
│   ├── gap-analysis.md          # /gap-analysis — Compare existing app vs Alpha AI 36 standards
│   ├── seed-data.md             # /seed-data — Generate realistic seed/test data factories
│   │
│   │  # ── Building ──
│   ├── auto-build.md            # /auto-build — Fully autonomous product builder (CORE)
│   ├── resume-build.md          # /resume-build — Resume interrupted auto-build
│   ├── feature.md               # /feature — Guided feature development
│   ├── retrofit.md              # /retrofit — Add missing features to existing app
│   ├── migrate-stack.md         # /migrate-stack — Safely migrate tech stack components
│   ├── refactor.md              # /refactor — AI-powered code refactoring
│   ├── debug.md                 # /debug — AI-powered debugging and troubleshooting
│   │
│   │  # ── Quality & Testing ──
│   ├── code-review.md           # /code-review — Automated multi-agent code review
│   ├── gen-tests.md             # /gen-tests — Auto-generate unit/integration tests
│   ├── e2e-test.md              # /e2e-test — Generate Playwright/Detox end-to-end tests
│   ├── perf-test.md             # /perf-test — Performance/load testing with k6/Locust
│   ├── security-scan.md         # /security-scan — SAST, DAST, secret detection, OWASP Top 10
│   ├── accessibility.md         # /accessibility — WCAG 2.1 AA compliance audit
│   ├── tech-debt.md             # /tech-debt — Scan and prioritize technical debt
│   ├── health-check.md          # /health-check — Project health audit
│   │
│   │  # ── Shipping & Release ──
│   ├── ship.md                  # /ship — Lint → test → commit → push → create PR
│   ├── release.md               # /release — Semver bump, changelog, git tag, GitHub Release
│   ├── changelog.md             # /changelog — Auto-generate CHANGELOG.md from git history
│   ├── deploy.md                # /deploy — Deploy with pre-flight checks
│   ├── gen-ci.md                # /gen-ci — Generate CI/CD pipelines (GitHub Actions/GitLab/Bitbucket)
│   │
│   │  # ── Infrastructure & DevOps ──
│   ├── gen-infra.md             # /gen-infra — Generate IaC (Docker, K8s, Terraform, Helm)
│   ├── db-migrate.md            # /db-migrate — Database migration helper
│   ├── docker-clean.md          # /docker-clean — Clean unused Docker resources
│   ├── monitoring.md            # /monitoring — Prometheus + Grafana setup
│   ├── runbook.md               # /runbook — Generate operational runbooks and playbooks
│   ├── backup-dr.md             # /backup-dr — Automated backups, restore testing, DR runbooks
│   ├── env-sync.md              # /env-sync — Environment parity checks, config drift, secret rotation
│   ├── feature-flags.md         # /feature-flags — Feature flag system with MySQL + Redis + admin UI
│   ├── audit-setup.md           # /audit-setup — Security audit logging, compliance, suspicious activity alerts
│   │
│   │  # ── Documentation & People ──
│   ├── gen-docs.md              # /gen-docs — Generate README, Architecture, API, Deployment docs
│   ├── api-docs.md              # /api-docs — Generate API documentation
│   ├── onboard-dev.md           # /onboard-dev — Onboard new developer
│   │
│   │  # ── Maintenance ──
│   └── dep-update.md            # /dep-update — Auto-update dependencies safely
│
├── agents/                       # SUBAGENTS — spawned via Agent tool for parallel work (11 total)
│   ├── architect.md             # Architecture analysis and design reviews
│   ├── brand-designer.md        # SVG logo generation, color systems, brand identity
│   ├── security-auditor.md      # Vulnerability scanning, secret detection
│   ├── onboarding-mentor.md     # Interactive codebase Q&A for new devs
│   ├── test-strategist.md       # Test coverage analysis and quality
│   ├── parallel-builder.md      # Orchestrates parallel Agent subagents for speed
│   ├── self-healer.md           # Auto-diagnoses and fixes errors during auto-build
│   ├── db-optimizer.md          # Slow query analysis, missing indexes, N+1 detection
│   ├── devops-engineer.md       # CI/CD, Docker, K8s, Terraform, deployment automation
│   ├── performance-profiler.md  # API profiling, N+1 detection, bottleneck analysis
│   └── documentation-writer.md  # README, architecture docs, API reference, guides
│
├── skills/                       # SKILLS — auto-invoked by Claude (Agent Skills open standard, 9 total)
│   ├── alpha-architecture/      # ⭐ MOST IMPORTANT — enforces tech stack + layer rules
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── CODE_PATTERNS_PYTHON.md     # Python/FastAPI code patterns
│   │       ├── CODE_PATTERNS_NESTJS.md     # NestJS/TypeScript code patterns
│   │       ├── CODE_PATTERNS_SPRINGBOOT.md # Java/Spring Boot code patterns
│   │       ├── CODE_PATTERNS_FRONTEND_CORE.md  # Frontend Part 1: Dir structure, App Router, Routes, Providers, Middleware, Page State
│   │       ├── CODE_PATTERNS_FRONTEND_PAGES.md # Frontend Part 2: Dashboard Layout, 6 Page Templates (List/Detail/Form/Settings/Dashboard/Auth)
│   │       ├── CODE_PATTERNS_FRONTEND_UX.md    # Frontend Part 3: Components, Responsive, Skeletons, SEO, Animations, Dark Mode, Cmd+K
│   │       ├── CODE_PATTERNS_CHROME_EXTENSION.md # Chrome Extension: MV3, Service Worker, Content Scripts, Messages, Storage, Security, AI Providers, Testing
│   │       ├── LANG_PROFILE_PYTHON.md      # Python stack: deps, dirs, configs, Docker
│   │       ├── LANG_PROFILE_NESTJS.md      # NestJS stack: deps, dirs, configs, Docker
│   │       ├── LANG_PROFILE_SPRINGBOOT.md  # Spring Boot stack: deps, dirs, configs, Docker
│   │       └── INFRA_HOSTINGER_K3S.md      # Hostinger VPS + K3s: 4-node arch, Traefik, CI/CD, templates
│   ├── project-setup/
│   │   └── SKILL.md
│   ├── onboarding/
│   │   └── SKILL.md
│   ├── code-review/
│   │   └── SKILL.md
│   ├── testing/
│   │   └── SKILL.md
│   ├── deployment/
│   │   └── SKILL.md
│   ├── security/                # 🔒 Auto-enforces OWASP Top 10, auth, input validation, secrets
│   │   └── SKILL.md
│   ├── devops/                  # 🐳 Auto-enforces Docker, CI/CD, K8s, monitoring standards
│   │   └── SKILL.md
│   └── performance/             # ⚡ Auto-enforces DB optimization, caching, async patterns
│       └── SKILL.md
│
├── hooks/                        # HOOKS — event-driven automation
│   └── hooks.json               # Defines when hooks fire and what they do
│
├── scripts/                      # BASH SCRIPTS — executed by hooks or standalone
│   ├── auto-loop.sh             # Persistent Ralph Loop runner (shell-level)
│   ├── auto-build-stop-hook.sh  # Stop hook: prevents exit during auto-build
│   ├── session-context.sh       # SessionStart hook: loads project context
│   └── safe-bash-check.sh       # PreToolUse hook: warns on dangerous commands
│
├── README.md
├── LICENSE
└── CLAUDE.md                     # ← THIS FILE
```

---

## How Each Component Works

### Commands (`commands/*.md`)

These are Markdown files that become slash commands. When a user types `/auto-build`, Claude Code reads `commands/auto-build.md` and follows its instructions.

**File format:**
```markdown
---
description: "Shown in /help. Describes what the command does."
---

# Title

Instructions for Claude to follow when this command is invoked.
$ARGUMENTS = whatever the user types after the command name.
```

**Key rule:** The `description` field in frontmatter is what appears in `/help`. Keep it concise and clear.
**Key rule:** Do NOT use `allowed-tools` in command frontmatter — Claude Code doesn't recognize it for commands. All tools are available by default.

**Key rule:** `$ARGUMENTS` is a special variable that captures user input after the command name. E.g., `/auto-build ./PRD.md` → `$ARGUMENTS` = `./PRD.md`

### Agents (`agents/*.md`)

Subagents are specialized Claude instances with focused system prompts. They are spawned via the `Task` tool from within commands.

**File format:**
```markdown
---
description: "Agent purpose. Shown in /agents."
---

You are a [role] agent. [System prompt instructions.]
```

**How agents are invoked:** From within a command, Claude uses the Agent tool:
```
Use Agent tool to spawn the architect agent to analyze the codebase structure.
```

Claude Code automatically matches the task description to the right agent based on the agent's `description` field.

### Skills (`skills/*/SKILL.md`)

Skills are **auto-invoked** — Claude reads them automatically when the task context matches. You don't call them manually.

**File format:**
```markdown
---
name: skill-name
description: "Triggers when Claude detects [specific task type]. This description is the trigger condition."
---

# Skill Title

Best practices, rules, and patterns Claude should follow.
```

**Key rule:** The `description` field is critical — it determines WHEN Claude activates this skill. Write it like a trigger condition.

**Example:** The `alpha-architecture` skill has:
```
description: "ALWAYS auto-invoked on ANY code writing task. Enforces Alpha AI's tech stack..."
```
This means Claude reads this skill every time it writes code, ensuring compliance.

### Hooks (`hooks/hooks.json`)

Hooks are event-driven — they fire automatically at specific points in Claude Code's lifecycle.

**Available events:**
- `PreToolUse` — fires BEFORE Claude uses a tool (can block with exit code 2)
- `PostToolUse` — fires AFTER a tool is used
- `SessionStart` — fires when Claude Code starts
- `SessionEnd` — fires when session ends
- `Stop` — fires when Claude tries to finish (critical for auto-build loop)
- `UserPromptSubmit` — fires when user sends a message (currently unused — removed due to timeout errors on every message)
- `PreCompact` — fires before context compaction
- `TeammateIdle` — fires when an Agent Teams teammate has no tasks (exit code 2 = keep working)
- `TaskCompleted` — fires when an Agent Teams teammate completes a task (exit code 2 = quality gate reject)

**Hook types:**
- `"type": "command"` — runs a bash script, reads stdin for event data
- `"type": "prompt"` — sends a prompt to Claude for AI-based evaluation

**Blocking behavior:**
- Exit code 0 = allow (continue normally)
- Exit code 2 = BLOCK (prevent the action, show stderr to Claude)

**The auto-build Stop hook** (`scripts/auto-build-stop-hook.sh`) uses exit code 2 to prevent Claude from stopping until the product is complete. This is the core of the autonomous loop.

### Scripts (`scripts/*.sh`)

Bash scripts executed by hooks or run standalone. They receive event data via stdin as JSON.

**`${CLAUDE_PLUGIN_ROOT}`** — Special variable that resolves to the plugin's root directory. Always use this in hooks.json paths.

### Agent Teams (Experimental)

When `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set, the plugin supports **Agent Teams** — multiple Claude Code instances coordinated as teammates with shared task lists and direct messaging.

**Agent Teams integration points:**
- **`agents/parallel-builder.md`** — Upgrades from Agent subagents to real teammates (backend, frontend, mobile, QA as independent Claude sessions)
- **`commands/code-review.md`** — 5 reviewers as teammates who debate findings and challenge each other
- **`commands/debug.md`** — Competing hypothesis mode where 3-5 teammates investigate different root cause theories in parallel
- **`commands/auto-build.md`** — Phase execution with teammates for true multi-agent parallelism

**Agent Teams hooks (in `hooks/hooks.json`):**
- `TeammateIdle` — Checks shared task list for pending tasks and reassigns to idle teammates (exit code 2 = keep working)
- `TaskCompleted` — Quality gate that validates task output (architecture, tests, security) before accepting (exit code 2 = reject)

**Enable:** Set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `~/.claude/settings.json` under `"env"`.

**Fallback:** When Agent Teams is not enabled, all commands fall back to the standard Agent tool subagent pattern automatically.

---

## Tech Stack — Core + Conditional (Modify With Care)

The stack is split into **CORE** (always enforced) and **CONDITIONAL** (only enforced if the project uses that technology). All 4 core files + 6 language reference files detect project context before applying rules.

These are defined in FOUR places (keep them in sync):

1. **`commands/auto-build.md`** — Tech Stack (Core + Conditional) section with PRD requirements profile
2. **`skills/alpha-architecture/SKILL.md`** — Step 0: Detect Project Context + Backend Language before enforcing rules
3. **`commands/init-project.md`** — Stack Configuration with Core + Conditional sections + `--lang` flag
4. **`commands/gen-prd.md`** — FEATURE_PROFILE analysis before generating PRD

Language-specific details are in reference files (keep in sync with core files):
- **`references/LANG_PROFILE_{LANG}.md`** — Directory structure, dependencies, configs, Docker, verify commands
- **`references/CODE_PATTERNS_{LANG}.md`** — Layer patterns, auth, email, payments, GenAI code examples
- **`references/INFRA_HOSTINGER_K3S.md`** — Hostinger VPS + K3s architecture, templates, CI/CD workflow, constraints

### Backend Stack (per detected language)

| Component | Python/FastAPI | Node.js/NestJS | Java/Spring Boot |
|-----------|---------------|----------------|------------------|
| Framework | FastAPI + Python 3.11+ | NestJS 11+ + TypeScript | Spring Boot 3.4+ + Java 21 |
| ORM | SQLAlchemy 2.0 async | Prisma | Spring Data JPA + Hibernate 6 |
| Auth lib | python-jose + passlib | @nestjs/jwt + bcryptjs | jjwt-api + Spring Security |
| Email | fastapi-mail + Celery | @nestjs-modules/mailer + BullMQ | spring-boot-starter-mail + @Async |
| Queue | Celery + Redis | BullMQ | Spring @Async + @Scheduled |
| Linter | ruff | ESLint + Prettier | Checkstyle + SpotBugs |
| Types | mypy (strict) | TypeScript (built-in) | Java compiler (built-in) |
| Tests | pytest + pytest-asyncio | Jest + supertest | JUnit 5 + Mockito + MockMvc |
| Migrations | Alembic | Prisma migrate | Flyway |
| Package | pip + requirements.txt | pnpm + package.json | Gradle (Kotlin DSL) |
| Docker base | python:3.11-slim | node:22-alpine | eclipse-temurin:21-jre-alpine |
| GenAI | LiteLLM + Google ADK | Vercel AI SDK + LangChain.js | Spring AI + LangChain4j |

### Current Stack (language-agnostic components):
| Component | Technology | Config Location |
|-----------|-----------|-----------------|
| Auth | JWT + HTTP-Only Cookies | auto-build.md (AUTH section), alpha-architecture SKILL |
| SQL DB | MySQL + ORM (per language) | auto-build.md, alpha-architecture SKILL |
| NoSQL DB | MongoDB | auto-build.md, alpha-architecture SKILL |
| Cache | Redis | auto-build.md, alpha-architecture SKILL |
| Payments | Razorpay (Subscriptions + Credit Points) | auto-build.md, alpha-architecture SKILL |
| Frontend Web | Next.js 15+ + TypeScript + Tailwind | auto-build.md, gen-prd.md |
| Frontend Mobile | React Native 0.83+ + Expo SDK 55+ + NativeWind (New Arch) | auto-build.md, init-project.md |
| Themes | Light + Dark + System Auto | auto-build.md, alpha-architecture SKILL |
| File Storage | S3/GCS + MinIO (local dev) | auto-build.md, alpha-architecture SKILL |
| Search | Meilisearch (full-text) | auto-build.md, alpha-architecture SKILL |
| Real-Time | WebSocket + Redis pub/sub | auto-build.md, alpha-architecture SKILL |
| Push Notifications | FCM via firebase-admin | auto-build.md, alpha-architecture SKILL |
| Error Tracking | Sentry | auto-build.md, alpha-architecture SKILL |
| Analytics | PostHog (self-hosted) | auto-build.md, alpha-architecture SKILL |
| i18n | next-intl (web) + i18next (mobile) | auto-build.md, alpha-architecture SKILL |
| RBAC | Custom roles + permissions | auto-build.md, alpha-architecture SKILL |
| 2FA | TOTP + QR generation (per language) | auto-build.md, alpha-architecture SKILL |
| Feature Flags | MySQL + Redis cache + admin toggle | auto-build.md, alpha-architecture SKILL |
| Admin Panel | Dedicated /admin API + frontend | auto-build.md, alpha-architecture SKILL |
| GenAI Gateway | LiteLLM \| Vercel AI SDK \| Spring AI | auto-build.md, alpha-architecture SKILL |
| Agentic Framework | ADK/LangGraph \| LangChain.js \| LangChain4j | auto-build.md, alpha-architecture SKILL |
| RAG Pipeline | Qdrant + text-embedding-3-large + semantic chunking | auto-build.md, alpha-architecture SKILL |
| AI Observability | Langfuse or LangSmith (LLM tracing) | auto-build.md, alpha-architecture SKILL |
| AI Safety | Guardrails: input/output filter + cost caps | auto-build.md, alpha-architecture SKILL |
| Prompt Mgmt | Jinja2/YAML templates + MCP Prompts (version-controlled) | auto-build.md, alpha-architecture SKILL |
| MCP Protocol | MCP server (tools + prompts + resources) via JSON-RPC 2.0 | auto-build.md, alpha-architecture SKILL |
| A2A Protocol | Agent Card discovery + task lifecycle (/.well-known/agent.json) | auto-build.md, alpha-architecture SKILL |
| Agent Skills | Open standard SKILL.md packaging (Anthropic spec) | all skills/ directories |
| AI Evaluation | DeepEval/RAGAS \| Jest AI \| JUnit AI + promptfoo | auto-build.md, alpha-architecture SKILL |
| Structured Output | instructor+Pydantic \| Zod \| Spring AI structured | auto-build.md, alpha-architecture SKILL |
| Semantic Caching | Redis + embedding similarity (>0.95 threshold) | auto-build.md, alpha-architecture SKILL |
| Agentic RAG | Retrieval agent + query decomposition + web search | auto-build.md, alpha-architecture SKILL |
| Re-ranking | Cohere Rerank v3.5 / FlashRank (post-retrieval) | auto-build.md, alpha-architecture SKILL |
| Multi-Modal AI | Vision + Image Gen + STT + TTS via LiteLLM | auto-build.md, alpha-architecture SKILL |
| HITL | Confidence threshold + review queue + approve/reject | auto-build.md, alpha-architecture SKILL |
| Context Management | tiktoken + auto-summarization + sliding window | auto-build.md, alpha-architecture SKILL |
| Voice AI | Whisper STT + OpenAI/Gemini/ElevenLabs TTS | auto-build.md, alpha-architecture SKILL |
| Batch Processing | Celery \| BullMQ \| @Async + Redis progress | auto-build.md, alpha-architecture SKILL |

### Auth Rules (HARD — same for ALL languages):
- JWT in HTTP-Only Cookies ONLY
- NEVER localStorage or sessionStorage
- Access token: 30 min, Refresh token: 7 days
- CSRF: Double-submit cookie pattern
- Logout: Blacklist tokens in Redis
- Google OAuth2: Server-side Authorization Code Grant (authlib | passport-google | Spring OAuth2)
- All login methods end with JWT cookies (same flow)

### Layer Segregation Rules (same concept, ALL languages):
```
controllers → services → repositories → models + database
  ❌ controllers NEVER import from repositories
  ❌ services NEVER import from controllers
  ❌ repositories NEVER import from services
  ❌ NO business logic in controllers (thin handlers only)
  ❌ NO DB queries in services (use repos)

Python paths:  app/api/ → app/services/ → app/repositories/ → app/models/
NestJS paths:  src/*/controllers/ → src/*/services/ → Prisma → src/*/entities/
Spring paths:  **/controller/ → **/service/ → **/repository/ → **/entity/
```

---

## How to Make Common Modifications

### Add a New Slash Command

1. Create `commands/my-command.md`
2. Add frontmatter with `description` and `allowed-tools`
3. Write the instruction body
4. Reinstall plugin or restart with `--plugin-dir`

### Add a New Subagent

1. Create `agents/my-agent.md`
2. Add frontmatter with `description` and `allowed-tools`
3. Write the system prompt
4. Reference it from commands using Agent tool

### Add a New Skill

1. Create `skills/my-skill/SKILL.md`
2. Add frontmatter with `name` and `description` (trigger condition)
3. Write the rules/patterns
4. Claude will auto-invoke it when the task matches the description

### Add a New Hook

1. Edit `hooks/hooks.json`
2. Add entry under the appropriate event (PreToolUse, Stop, etc.)
3. If `type: "command"`, create the script in `scripts/`
4. If `type: "prompt"`, write the evaluation prompt inline
5. Restart Claude Code (hooks load at session start)

### Change the Autonomous Loop Behavior

- **Max iterations:** Edit `scripts/auto-loop.sh` → `MAX_ITERATIONS` variable
- **Rate limit:** Edit `scripts/auto-loop.sh` → `RATE_LIMIT_MAX` variable
- **Circuit breaker:** Edit `scripts/auto-loop.sh` → `MAX_CONSECUTIVE_ERRORS`
- **Completion keyword:** Edit `scripts/auto-loop.sh` + `scripts/auto-build-stop-hook.sh` → `COMPLETION_PROMISE`
- **When to block exit:** Edit `scripts/auto-build-stop-hook.sh` logic

### Change the Project Structure Template

Edit the ENFORCED PROJECT STRUCTURE section in `commands/auto-build.md`. This is the ASCII tree that defines the folder layout for every auto-built project.

### Change Database Selection Rules

Edit the DATABASE USAGE PATTERNS section in `commands/auto-build.md` and the Database Selection Guide in `skills/alpha-architecture/SKILL.md`.

### Add Support for a New Backend Language

1. Create `references/LANG_PROFILE_{LANG}.md` — directory structure, deps, configs, Docker, verify commands
2. Create `references/CODE_PATTERNS_{LANG}.md` — layer patterns, auth, email, payments, GenAI code examples
3. Edit `skills/alpha-architecture/SKILL.md` — add language to Step 0a detection + Backend Stack table
4. Edit `commands/auto-build.md` — add language to Step 0.1 detection + Backend Stack table
5. Edit `commands/init-project.md` — add `--lang` option + per-language scaffolding
6. Edit `commands/gen-prd.md` — add language to tech stack section
7. Edit `CLAUDE.md` — add language to Backend Stack table

---

## Build & Test Commands

```bash
# Development mode (fast iteration, no install needed)
claude --plugin-dir ~/claude-plugins/cortex

# Install via marketplace
/plugin marketplace add alphaaiservice/cortex
/plugin install cortex@alphaai

# Uninstall
/plugin uninstall cortex@alphaai

# Check loaded commands
/help

# Check loaded agents
/agents

# Check loaded hooks
/hooks

# Test a specific command
/init-project test-app

# Test autonomous build
/gen-prd "todo app with user auth"
/auto-build ./PRD.md
```

---

## Important Notes

1. **plugin.json goes ONLY inside `.claude-plugin/`** — commands, agents, skills, hooks go at plugin ROOT level, NOT inside .claude-plugin/
2. **Hooks reload on restart** — after editing hooks.json, you must restart Claude Code
3. **Skills are auto-invoked** — you don't call them, Claude picks them up based on task context
4. **`$ARGUMENTS`** — captures user input after the command name
5. **`${CLAUDE_PLUGIN_ROOT}`** — resolves to plugin root in hooks.json paths
6. **Exit code 2 in hooks** — blocks the action (critical for auto-build loop)
7. **Keep the 4 tech stack files in sync** — auto-build.md, alpha-architecture SKILL, init-project.md, gen-prd.md
8. **Test with `--plugin-dir` flag** — fastest way to iterate during development
9. **41 slash commands** covering the COMPLETE SDLC (planning → building → testing → shipping → operations → maintenance)
10. **11 subagents** for parallel and specialized work (7 core + brand-designer + devops-engineer + performance-profiler + documentation-writer)
11. **9 auto-invoked skills** for enforcing standards (6 core + security + devops + performance)
12. **36 modern app features** consistently across all core files (23 app + 3 open standards + 10 advanced GenAI)
13. **Open standards adopted**: Agent Skills (Anthropic), MCP (Linux Foundation), A2A (Google/Linux Foundation)
14. **Skills follow progressive disclosure** — alpha-architecture uses references/ for code patterns per spec
15. **Existing app support**: /analyze-project → /gap-analysis → /retrofit or /migrate-stack workflow
16. **`/init-project --existing`** — upgrades existing projects without overwriting code
17. **Full SDLC coverage** organized by phase: Planning (4) → Setup (4) → Building (7) → Quality (8) → Shipping (5) → DevOps (9) → Docs (3) → Maintenance (1)
18. **Security auto-enforced** — security skill triggers on any auth/input/secrets code
19. **Performance auto-enforced** — performance skill triggers on DB queries, caching, async code
20. **DevOps auto-enforced** — devops skill triggers on Docker, CI/CD, K8s, infra code
21. **Agent Teams support (experimental)** — when `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set, parallel-builder, code-review, debug, and auto-build upgrade to real multi-agent coordination with shared task lists, inter-agent messaging, TeammateIdle reassignment, and TaskCompleted quality gate hooks
