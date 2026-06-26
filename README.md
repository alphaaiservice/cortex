# Cortex — SDLC Automation Engine

**Forge Production-Ready Software — From Idea to Deployment**

Built by [Alpha AI Service Pvt Ltd](https://www.alphaaiservice.com)

```
Plugin         : Cortex v1.3.1
Commands       : 54 slash commands
Agents         : 13 specialized subagents
Skills         : 27 auto-invoked skills (13 domain + 5 analysis + 5 meta-process + 3 design/media + 1 integration)
Hooks          : 7 event-driven automations
Reference Docs : 16 progressive-disclosure references
Validator      : scripts/validate-plugin.sh (CI on every push)
License        : MIT
```

---

## Table of Contents

- [What Is This?](#what-is-this)
- [Setup Guide](#setup-guide)
  - [Prerequisites](#prerequisites)
  - [Step 1: Clone the Plugin](#step-1-clone-the-plugin)
  - [Step 2: Choose a Loading Method](#step-2-choose-a-loading-method)
  - [Step 3: Configure Permissions](#step-3-configure-permissions)
  - [Step 4: Enable Agent Teams (Optional)](#step-4-enable-agent-teams-optional)
  - [Step 5: Verify Installation](#step-5-verify-installation)
- [Quick Start](#quick-start)
- [All 54 Commands](#all-54-commands)
- [Subagents](#subagents)
- [Auto-Invoked Skills](#auto-invoked-skills)
- [Hooks](#hooks)
- [Enforced Tech Stack](#enforced-tech-stack)
- [Architecture](#architecture)
- [Usage Examples](#usage-examples)
- [Agent Teams](#agent-teams)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Uninstall](#uninstall)
- [Contributing](#contributing)
- [License](#license)

---

## What Is This?

Cortex is a **Claude Code plugin** that automates every phase of the software development lifecycle:

```
Idea -> PRD -> Sprint Plan -> Scaffold -> Build -> Test -> Review -> Ship -> Deploy -> Monitor -> Maintain
 |       |         |            |          |       |        |        |       |         |          |
 v       v         v            v          v       v        v        v       v         v          v
/gen-prd /sprint-plan /init-project /auto-build /gen-tests /code-review /ship /deploy /monitoring /dep-update
```

It enforces **Alpha AI's engineering standards** across every project, supporting **3 backend languages**:

- **Backend**: Python/FastAPI | Node.js/NestJS | Java/Spring Boot (auto-detected or `--lang` flag)
- **Auth**: JWT in HTTP-Only Cookies (NEVER localStorage) — same rules, all languages
- **Databases**: MySQL + ORM (SQLAlchemy | Prisma | Spring Data JPA), MongoDB, Redis
- **Payments**: Razorpay (India SaaS with GST, credit points, subscriptions)
- **Frontend**: Next.js 15+ TypeScript + Tailwind
- **Mobile**: React Native + Expo SDK 55+ (New Architecture)
- **GenAI**: LiteLLM | Vercel AI SDK | Spring AI + Qdrant RAG
- **Open Standards**: MCP Protocol, A2A Protocol, Agent Skills

The plugin includes a **fully autonomous build system** (Ralph Loop) that can take a PRD and build the entire product — backend, frontend, auth, payments, tests, docs, CI/CD — with zero human intervention.

---

## Setup Guide

Complete step-by-step guide to set up the Cortex plugin on your machine.

### Prerequisites

Before you begin, make sure you have:

| Requirement | Version | Check Command |
|-------------|---------|---------------|
| **Claude Code CLI** | v2.0+ | `claude --version` |
| **Node.js** | 18+ | `node --version` |
| **Git** | any | `git --version` |
| **OS** | macOS, Linux, or WSL2 | — |

```bash
# Verify Claude Code is installed and authenticated
claude --version
# Should show: 2.x.x (Claude Code)

# If not installed, install it first:
npm install -g @anthropic-ai/claude-code
claude login
```

### Step 1: Clone the Plugin

```bash
# Clone the repository
git clone https://github.com/alphaaiservice/cortex.git

# Or clone to a specific location
git clone https://github.com/alphaaiservice/cortex.git ~/claude-plugins/cortex

# Enter the directory
cd cortex

# Make all hook scripts executable (REQUIRED)
chmod +x scripts/*.sh
```

### Step 2: Choose a Loading Method

You have **3 options** to load the plugin. Pick the one that fits your workflow.

#### Option A: Persistent Settings (Recommended)

Add the plugin directory to your global Claude Code settings so it loads **automatically in every session**.

Edit `~/.claude/settings.json` and add the `plugins.directories` entry:

```json
{
  "plugins": {
    "directories": [
      "/absolute/path/to/cortex"
    ]
  }
}
```

**Example for macOS:**

```json
{
  "plugins": {
    "directories": [
      "/Users/yourname/claude-plugins/cortex"
    ]
  }
}
```

After saving, **every new Claude Code session** automatically loads all 54 commands, 13 agents, 27 skills, and 7 hooks.

> **Important:** Use the **absolute path** (not `~` or relative paths).

#### Option B: CLI Flag (Per-Session)

Load the plugin for a single session using the `--plugin-dir` flag:

```bash
claude --plugin-dir /path/to/cortex
```

**Tip:** Create a shell alias so you don't have to type the full path every time:

```bash
# Add to ~/.zshrc or ~/.bashrc
alias cortex='claude --plugin-dir /path/to/cortex'

# Reload your shell
source ~/.zshrc

# Now just run:
cortex
```

#### Option C: Local Marketplace Install

Install via the built-in marketplace system for a permanent installation without editing settings files.

```bash
# Inside a Claude Code session:
/plugin marketplace add alphaaiservice/cortex
/plugin install cortex@alphaai
```

After installation, the plugin loads automatically in every session.

### Step 3: Configure Permissions

The plugin needs permissions to read/write files and run bash commands. Add these to your `~/.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash",
      "Read",
      "Edit",
      "Write",
      "Glob",
      "Grep",
      "WebFetch",
      "Agent",
      "MCP"
    ]
  }
}
```

> **What each permission does:**
> - `Bash` — Run shell commands (builds, tests, git, linters)
> - `Read` / `Edit` / `Write` — Read and modify project files
> - `Glob` / `Grep` — Search files by name and content
> - `WebFetch` — Fetch web content (for `/market-research`, `/gen-prd`)
> - `Agent` — Spawn subagents for parallel work
> - `MCP` — Use MCP server tools

If you skip this step, Claude Code will ask for permission on each tool call during the session.

### Step 4: Enable Agent Teams (Optional)

Agent Teams enables **true multi-agent parallelism** — multiple Claude Code instances working as teammates with shared task lists and inter-agent messaging. This is used by `/auto-build`, `/code-review`, and `/debug` for faster execution.

Add to your `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

#### Full Recommended settings.json

Here's the complete recommended `~/.claude/settings.json` with all options:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "permissions": {
    "allow": [
      "Bash",
      "Read",
      "Edit",
      "Write",
      "Glob",
      "Grep",
      "WebFetch",
      "Agent",
      "MCP"
    ]
  },
  "plugins": {
    "directories": [
      "/absolute/path/to/cortex"
    ]
  }
}
```

> **Note:** If your `~/.claude/settings.json` already has other settings (like `enabledPlugins`), merge the keys above into your existing file. Don't overwrite the whole file.

### Step 5: Verify Installation

Start a new Claude Code session and verify everything loaded correctly:

```bash
# Start Claude Code (fresh session required after settings changes)
claude

# You should see the Cortex banner on startup:
#
# +----------------------------------------------------------+
# |                                                          |
# |     ____           _                                     |
# |    / ___|___  _ __| |_ _____  __                         |
# |   | |   / _ \| '__| __/ _ \ \/ /                         |
# |   | |__| (_) | |  | ||  __/>  <                          |
# |    \____\___/|_|   \__\___/_/\_\                         |
# |                                                          |
# |  Cortex v1.3.1 -- SDLC Automation Engine                 |
# |  Forge Production-Ready Software                         |
# |  Alpha AI Service Pvt Ltd                                |
# |                                                          |
# |  54 commands | 13 agents | 27 skills | 7 hooks           |
# +----------------------------------------------------------+
#
# (Banner version + counts read dynamically from plugin.json
#  at invocation time, so they never go stale.)
```

**Verification checklist:**

```bash
# 1. Check all commands are available
/help
# Should list all 54 slash commands

# 2. Run a quick health check
/health-check

# 3. Test a simple command
/gen-prd "simple todo app"
# Should generate a PRD document

# 4. Verify hooks are active
/hooks
# Should show 7 hooks (PreToolUse, SessionStart, PostToolUse for Write+Edit,
# Stop, PreCompact, TeammateIdle, TaskCompleted)

# 5. Run the plugin validator (catches drift between manifest and reality)
bash scripts/validate-plugin.sh
# Should report: Passed: 23, Warnings: 0, Failed: 0
```

### Team-Wide Setup

To share the plugin across your entire team:

**Option A: Repository-level** — Add to your project's `.claude/settings.json`:

```json
{
  "plugins": {
    "directories": [
      "/shared/path/to/cortex"
    ]
  }
}
```

**Option B: Per-developer** — Each team member adds to their `~/.claude/settings.json`:

```json
{
  "plugins": {
    "directories": [
      "/Users/dev-name/claude-plugins/cortex"
    ]
  }
}
```

**Option C: GitHub Marketplace** (when published):

```bash
/plugin marketplace add alphaaiservice/cortex
/plugin install cortex@alphaai
```

---

## Quick Start

### Build a Complete Product (Autonomous Mode)

```bash
# Step 1: Generate a PRD from an idea
/gen-prd "Build a multi-tenant SaaS project management tool with Kanban boards"

# Step 2: Launch fully autonomous build (zero human intervention)
/auto-build ./PRD.md

# The system will:
# 1. Scaffold the project
# 2. Create database models and migrations
# 3. Build API endpoints
# 4. Create frontend pages
# 5. Add auth, payments, GenAI features
# 6. Generate tests (>80% coverage)
# 7. Write documentation
# 8. Set up CI/CD and Docker
# All automatically, with self-healing error recovery.
```

### Work on an Existing Project

```bash
# Step 1: Analyze your codebase
/analyze-project

# Step 2: Check compliance with Alpha AI standards
/gap-analysis

# Step 3: Add missing features one by one
/retrofit jwt-cookies
/retrofit razorpay
/retrofit dark-mode

# Or migrate your tech stack
/migrate-stack PostgreSQL to MySQL
```

### Day-to-Day Development

```bash
# Plan sprints from a PRD
/sprint-plan ./PRD.md --sprints=4 --team-size=3

# Build a feature
/feature Add user profile with avatar upload

# Generate tests
/gen-tests app/services/user_service.py

# Debug an issue
/debug "TypeError: 'NoneType' object is not subscriptable in auth middleware"

# Code review
/code-review --staged

# Ship it
/ship "feat(profile): add avatar upload with S3 presigned URLs"

# Deploy
/deploy staging
```

---

## All 54 Commands

### Planning and Research (4)

| Command | Description |
|---------|-------------|
| `/gen-prd <idea>` | Generate a detailed PRD from a brief idea with web research |
| `/gen-brand <name\|prd-file>` | Generate SVG logos, color system, typography, and brand identity |
| `/market-research <topic>` | Deep competitive analysis, market trends, pricing intelligence |
| `/sprint-plan <prd-file>` | Break PRD into sprint-sized tasks with estimates and dependencies |

### Design and Media (3) — *added v1.5.0*

| Command | Description |
|---------|-------------|
| `/gen-mockup <idea\|prd> [--fidelity] [--mobile]` | Clickable UI screen mockups/wireframes as self-contained HTML/Next.js — brand-consistent, no API key |
| `/gen-pitch <prd> [--mode=investor\|hackathon]` | Pitch/demo deck from PRD + research as Marp/Slidev markdown → PDF/HTML/PPTX |
| `/gen-demo-video <prd> [--length] [--aspect]` | Product demo/marketing video as a Remotion project: script → TTS voiceover + captions → MP4 |

### Project Setup (6)

| Command | Description |
|---------|-------------|
| `/init-project <name> [--lang=python\|nestjs\|springboot] [--existing]` | Scaffold new or upgrade existing FastAPI/NestJS/Spring Boot project |
| `/init-mcp-server <name> [--lang=python\|typescript] [--with-tools]` | **NEW in v1.3.0** — Scaffold standalone MCP server (Python `mcp` SDK or TypeScript `@modelcontextprotocol/sdk`) |
| `/init-claude-plugin <name> [--with-commands\|agents\|skills\|hooks\|mcp]` | **NEW in v1.3.0** — Scaffold a Claude Code plugin using Cortex's own structure as the template (dogfoods every plugin best practice) |
| `/analyze-project [path]` | Scan existing codebase, detect tech stack, map architecture |
| `/gap-analysis [path]` | Compare app against Alpha AI's 36 engineering standards |
| `/seed-data [--count=100]` | Generate realistic seed data factories and database seeders |

### Building (7)

| Command | Description |
|---------|-------------|
| `/auto-build <prd-file>` | Fully autonomous product builder (12-phase, self-healing) |
| `/resume-build` | Resume interrupted auto-build from last checkpoint |
| `/feature <description>` | Guided feature development from spec to PR |
| `/retrofit <feature-name>` | Add missing Alpha AI features to existing app (50+ features) |
| `/migrate-stack <from> to <to>` | Safely migrate technology components (DB, auth, payments) |
| `/refactor <file-or-module>` | AI-powered code refactoring (extract, decompose, rename, cleanup) |
| `/debug <error-or-log>` | AI-powered debugging with root cause analysis and auto-fix |

### Quality and Testing (8)

| Command | Description |
|---------|-------------|
| `/code-review [--staged]` | Automated multi-agent code review (5 parallel analyzers) |
| `/gen-tests <file>` | Auto-generate unit and integration tests |
| `/e2e-test [flow-name\|--all]` | Generate Playwright (web) and Detox (mobile) E2E tests |
| `/perf-test [endpoint\|all]` | Performance/load testing with k6 and Locust |
| `/security-scan [--fix]` | SAST + DAST + secret detection + OWASP Top 10 audit |
| `/accessibility [--fix]` | WCAG 2.1 AA compliance audit with auto-fix |
| `/tech-debt [--fix-quick-wins]` | Scan and prioritize technical debt with scoring |
| `/health-check` | Full project health audit with overall score |

### Shipping and Release (5)

| Command | Description |
|---------|-------------|
| `/ship <commit-message>` | Lint -> test -> commit -> push -> create PR |
| `/release [major\|minor\|patch]` | Semver bump, changelog, git tag, GitHub Release |
| `/changelog [--since=v1.0.0]` | Auto-generate CHANGELOG.md from git history |
| `/deploy <environment>` | Deploy with pre-flight checks and safety validations |
| `/gen-ci [github-actions\|gitlab-ci]` | Generate CI/CD pipelines with caching, matrix testing, security |

### Infrastructure and DevOps (9)

| Command | Description |
|---------|-------------|
| `/gen-infra [docker\|k8s\|k3s\|terraform\|helm]` | Generate IaC: Docker Compose, Kubernetes, K3s (Hostinger VPS), Terraform, Helm |
| `/db-migrate <action>` | Database migration management (generate, run, rollback) |
| `/docker-clean` | Clean unused Docker containers, images, volumes, networks |
| `/monitoring` | Set up Prometheus + Grafana monitoring stack |
| `/runbook [--type=incident\|all]` | Generate operational runbooks and incident playbooks |
| `/backup-dr` | Automated backups, restore verification, DR runbooks (MySQL/MongoDB/Redis/S3) |
| `/env-sync` | Environment parity checks, config drift detection, secret rotation |
| `/feature-flags` | Feature flag system: MySQL + Redis cache + admin UI |
| `/audit-setup` | Security audit logging, compliance trails, suspicious-activity alerts |

### Documentation and People (3)

| Command | Description |
|---------|-------------|
| `/gen-docs [--type=all]` | Generate README, Architecture, API Reference, Deployment Guide |
| `/api-docs` | Auto-generate OpenAPI specs and endpoint documentation |
| `/onboard-dev <name> (<role>)` | Generate personalized onboarding plan and starter tasks |

### Analysis and Intelligence (5)

Added in v1.1.0 — codebase analysis and AI capability discovery.

| Command | Description |
|---------|-------------|
| `/suggest-ai-features [path]` | Scan codebase, recommend where AI/ML adds value, generate AI_ENHANCEMENT_PLAN.md |
| `/ai-upgrade <feature>` | Implementation counterpart to `/suggest-ai-features` — add AI to a specific feature |
| `/trace-impact "<change>"` | Trace full-stack blast radius of a code change (DB → service → API → frontend) |
| `/estimate-cost ["scenario"]` | Project infra + API costs at 100 / 1K / 10K / 100K users; compare service alternatives |
| `/feature-map [feature]` | Build visual feature dependency map of the codebase as a Mermaid diagram |

### Maintenance (1)

| Command | Description |
|---------|-------------|
| `/dep-update [--security-only]` | Auto-update dependencies safely with test-after-each-bump |

### Cortex Cloud (3)

| Command | Description |
|---------|-------------|
| `/cortex-login` | Authenticate the plugin to Cortex Cloud via RFC 8628 device-grant login |
| `/cortex-logout` | Log out — revoke and clear local Cortex Cloud credentials |
| `/cortex-status` | Show Cortex Cloud connection + project status |

---

## Subagents

13 specialized AI agents that can be spawned in parallel for faster execution:

| Agent | Expertise |
|-------|-----------|
| **Architect** | Architecture analysis, design reviews, scalability assessment |
| **Brand Designer** | SVG logo generation, color systems, typography, design tokens |
| **Security Auditor** | Vulnerability scanning, secret detection, OWASP compliance |
| **Onboarding Mentor** | Interactive codebase Q&A for new developers |
| **Test Strategist** | Test coverage analysis and quality improvement |
| **Parallel Builder** | Multi-agent parallel task execution for autonomous builds |
| **Self-Healer** | Auto-diagnoses and fixes errors during auto-build |
| **DB Optimizer** | Slow query analysis, missing indexes, N+1 detection |
| **DevOps Engineer** | CI/CD pipelines, Docker, Kubernetes, Terraform, deployment |
| **Performance Profiler** | API profiling, bottleneck analysis, load testing |
| **Documentation Writer** | README, architecture docs, API reference, deployment guides |
| **Feature Analyzer** (Priya Sharma 🇮🇳) — *new v1.1.0* | Dissects existing codebases, maps features to code, detects patterns and anti-patterns |
| **AI Integration Specialist** (Marcus Chen 🇺🇸) — *new v1.1.0* | Designs LLM integration, vector search, semantic analysis with cost-awareness |

---

## Auto-Invoked Skills

27 skills that automatically activate when Claude detects matching task context.
Split into five categories:

**Domain enforcement** (13 — fire when writing code matching their domain):

| Skill | Triggers When |
|-------|---------------|
| **alpha-architecture** | Writing ANY code — enforces tech stack and layer segregation |
| **project-setup** | Initializing or scaffolding projects |
| **onboarding** | Onboarding developers or explaining codebase |
| **code-review** | Reviewing code changes |
| **testing** | Generating or running tests |
| **deployment** | Deploying or configuring releases |
| **security** | Writing auth code, handling user input, managing secrets |
| **devops** | Creating Docker files, CI/CD pipelines, K8s manifests |
| **performance** | Writing database queries, caching logic, async code |
| **frontend** *(v1.5.0)* | Writing any UI — Next.js/React, Tailwind/shadcn, React Native, Chrome extensions; enforces the production bar (fonts, OKLCH tokens, real data, polish, friendly errors) |
| **genai** *(v1.5.0)* | Writing LLM/RAG/agent code — enforces LiteLLM gateway, guardrails, cost caps, structured output, observability, evals |
| **accessibility** *(v1.5.0)* | Writing UI — enforces WCAG 2.1 AA at authoring time (semantic HTML, ARIA, contrast, keyboard nav, focus) |
| **database** *(v1.5.0)* | Schema/migration/model code — enforces safe reversible zero-downtime migrations, datastore selection, repository boundary |

**Analysis & advisory** (5 — added v1.1.0):

| Skill | Triggers When |
|-------|---------------|
| **cost-estimator** | User asks about costs, pricing, budgets, infrastructure estimates |
| **dependency-mapper** | Architecture planning, refactor planning, "what depends on what" |
| **feature-impact-analysis** | Schema changes, migrations, feature removal, API deprecation |
| **metric-recommender** | Adding new features, setting up monitoring, KPI discussions |
| **smart-retrofit** | "Add AI to X", "make X smarter", "integrate AI", "enhance X" |

**Meta-process** (5 — added v1.2.0, makes Cortex self-contained — no Superpowers dependency):

| Skill | Triggers When |
|-------|---------------|
| **cortex-brainstorming** | Before creating any new feature/product — runs the 5-question FEATURE_PROFILE builder |
| **cortex-planning** | Before any multi-step implementation (3+ files OR 30+ min OR multi-layer OR hard-to-reverse) |
| **cortex-tdd** | Before writing any implementation code — enforces red→green→refactor per language |
| **cortex-debugging** | On any bug/failure/regression — enforces systematic reproduce→isolate→fix-at-right-layer loop |
| **cortex-verification** | Before any "done/fixed/complete" claim — runs the language-specific verify suite |

**Design & media** (3 — added v1.5.0, paired with /gen-mockup, /gen-pitch, /gen-demo-video):

| Skill | Triggers When |
|-------|---------------|
| **mockup** | "Mock up / wireframe / prototype this screen" — brand-consistent screens as self-contained HTML/Next.js before building |
| **pitch-deck** | "Make a pitch deck / slides / investor presentation" — Marp/Slidev markdown → PDF/HTML/PPTX, proven narrative arc |
| **video-producer** | "Make a demo / marketing video" — Remotion (React) project: script → TTS voiceover + captions → branded MP4 |

**Integration** (1 — added v1.4.0):

| Skill | Triggers When |
|-------|---------------|
| **jira-integration** | Any Jira work — bidirectional sync via the Atlassian MCP server (no command; the skill is the whole surface) |

---

## Hooks

7 event-driven automations that run automatically. Every hook is a real
script under `scripts/` (no inline bash — extracted in v1.1.2 for testability):

| Hook | Event | Script | What It Does |
|------|-------|--------|--------------|
| **Safe Bash** | `PreToolUse` (Bash) | `safe-bash-check.sh` | Blocks dangerous commands (`rm -rf /`, `mkfs.`, fork bombs, etc.) |
| **Session Context** | `SessionStart` | `session-context.sh` | Loads project context, git status, plugin banner |
| **Auto-Format** | `PostToolUse` (Write + Edit) | `auto-format.sh` | Auto-formats per language (ruff/black for Python, prettier for JS/TS, google-java-format for Java) |
| **Build Guard** | `Stop` | `auto-build-stop-hook.sh` | Blocks exit during `/auto-build` until product is complete |
| **PreCompact Checkpoint** *(v1.1.x)* | `PreCompact` | `precompact-checkpoint.sh` | Snapshots `AUTO_BUILD_STATE.json` + auto-commits dirty changes before compaction |
| **Teammate Reassign** *(experimental)* | `TeammateIdle` | `teammate-idle-reassign.sh` | Agent Teams: reassigns pending tasks to idle teammates |
| **Task Gate** *(experimental, v1.3.1 secrets fix)* | `TaskCompleted` | `task-completed-quality-gate.sh` | Agent Teams: rejects task output with unresolved TODOs, skipped tests, or hardcoded secrets |

---

## Enforced Tech Stack

The plugin enforces these technologies across all projects. Backend language is auto-detected or set via `--lang` flag.

### Backend Stack (per language)

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

### Shared Stack (all languages)

| Layer | Technology |
|-------|-----------|
| Auth | JWT in HTTP-Only Cookies + CSRF double-submit |
| Social Login | Google OAuth2 (server-side Authorization Code Grant) |
| SQL Database | MySQL 8.0 + ORM per language |
| NoSQL Database | MongoDB 7 |
| Cache | Redis 7 |
| Payments | Razorpay (Subscriptions + Credit Points + GST) |
| Frontend Web | Next.js 15+ + TypeScript + Tailwind CSS |
| Frontend Mobile | React Native 0.83+ + Expo SDK 55+ + NativeWind |
| Themes | Light + Dark + System Auto |
| Search | Meilisearch (full-text search) |
| File Storage | S3/MinIO + presigned URL uploads |
| Real-Time | WebSocket + Redis pub/sub |
| Push Notifications | FCM via firebase-admin |
| Error Tracking | Sentry (backend + frontend + mobile) |
| Analytics | PostHog (self-hosted) |
| RAG Pipeline | Qdrant + text-embedding-3-large + semantic chunking |
| AI Observability | Langfuse or LangSmith (LLM tracing) |
| MCP Protocol | MCP server (tools + prompts + resources) |
| A2A Protocol | Agent Card discovery + task lifecycle |

---

## Architecture

```
cortex/
|
|-- .claude-plugin/
|   |-- plugin.json                  # Plugin metadata
|   +-- marketplace.json             # Marketplace catalog for distribution
|
|-- commands/                        # 37 SLASH COMMANDS
|   |
|   |  # Planning & Research
|   |-- gen-prd.md                   # /gen-prd
|   |-- gen-brand.md                 # /gen-brand
|   |-- market-research.md           # /market-research
|   |-- sprint-plan.md               # /sprint-plan
|   |
|   |  # Design & Media (v1.5.0)
|   |-- gen-mockup.md                 # /gen-mockup
|   |-- gen-pitch.md                  # /gen-pitch
|   |-- gen-demo-video.md            # /gen-demo-video
|   |
|   |  # Project Setup
|   |-- init-project.md              # /init-project
|   |-- analyze-project.md           # /analyze-project
|   |-- gap-analysis.md              # /gap-analysis
|   |-- seed-data.md                 # /seed-data
|   |
|   |  # Building
|   |-- auto-build.md                # /auto-build (CORE)
|   |-- resume-build.md              # /resume-build
|   |-- feature.md                   # /feature
|   |-- retrofit.md                  # /retrofit
|   |-- migrate-stack.md             # /migrate-stack
|   |-- refactor.md                  # /refactor
|   |-- debug.md                     # /debug
|   |
|   |  # Quality & Testing
|   |-- code-review.md               # /code-review
|   |-- gen-tests.md                 # /gen-tests
|   |-- e2e-test.md                  # /e2e-test
|   |-- perf-test.md                 # /perf-test
|   |-- security-scan.md             # /security-scan
|   |-- accessibility.md             # /accessibility
|   |-- tech-debt.md                 # /tech-debt
|   |-- health-check.md              # /health-check
|   |
|   |  # Shipping & Release
|   |-- ship.md                      # /ship
|   |-- release.md                   # /release
|   |-- changelog.md                 # /changelog
|   |-- deploy.md                    # /deploy
|   |-- gen-ci.md                    # /gen-ci
|   |
|   |  # Infrastructure & DevOps
|   |-- gen-infra.md                 # /gen-infra
|   |-- db-migrate.md                # /db-migrate
|   |-- docker-clean.md              # /docker-clean
|   |-- monitoring.md                # /monitoring
|   |-- runbook.md                   # /runbook
|   |
|   |  # Documentation & People
|   |-- gen-docs.md                  # /gen-docs
|   |-- api-docs.md                  # /api-docs
|   |-- onboard-dev.md               # /onboard-dev
|   |
|   |  # Maintenance
|   |-- dep-update.md                # /dep-update
|   |
|   |  # Cortex Cloud (auth + telemetry)
|   |-- cortex-login.md              # /cortex-login
|   |-- cortex-logout.md             # /cortex-logout
|   +-- cortex-status.md             # /cortex-status
|
|-- agents/                          # 11 SUBAGENTS
|   |-- architect.md                 # Architecture analysis
|   |-- brand-designer.md            # SVG logos & brand identity
|   |-- security-auditor.md          # Vulnerability scanning
|   |-- onboarding-mentor.md         # Developer Q&A
|   |-- test-strategist.md           # Test coverage
|   |-- parallel-builder.md          # Parallel execution
|   |-- self-healer.md               # Auto error fixing
|   |-- db-optimizer.md              # Database optimization
|   |-- devops-engineer.md           # CI/CD and infrastructure
|   |-- performance-profiler.md      # Performance analysis
|   +-- documentation-writer.md      # Documentation generation
|
|-- skills/                          # 27 AUTO-INVOKED SKILLS
|   |-- alpha-architecture/
|   |   |-- SKILL.md                 # Tech stack enforcement
|   |   +-- references/              # CODE_PATTERNS_* per language + frontend + genai (progressive disclosure)
|   |-- project-setup/SKILL.md
|   |-- onboarding/SKILL.md
|   |-- code-review/SKILL.md
|   |-- testing/SKILL.md
|   |-- deployment/SKILL.md
|   |-- security/SKILL.md            # OWASP, auth, secrets enforcement
|   |-- devops/SKILL.md              # Docker, CI/CD, K8s enforcement
|   |-- performance/SKILL.md         # DB, caching, async enforcement
|   |-- frontend/SKILL.md            # Frontend production bar (fonts, OKLCH tokens, real data, friendly errors)
|   |-- genai/SKILL.md               # LLM gateway, guardrails, cost caps, RAG, evals
|   |-- accessibility/SKILL.md       # WCAG 2.1 AA at authoring time
|   |-- database/SKILL.md            # Safe migrations, datastore selection, repo boundary
|   |-- mockup/SKILL.md              # UI screen mockups/wireframes as code (paired with /gen-mockup)
|   |-- pitch-deck/SKILL.md          # Pitch/demo decks via Marp/Slidev (paired with /gen-pitch)
|   |-- video-producer/SKILL.md      # Demo/marketing video via Remotion (paired with /gen-demo-video)
|   |-- cost-estimator/ dependency-mapper/ feature-impact-analysis/   # analysis & advisory
|   |-- metric-recommender/ smart-retrofit/
|   |-- cortex-brainstorming/ cortex-planning/ cortex-tdd/            # meta-process
|   |-- cortex-debugging/ cortex-verification/
|   +-- jira-integration/SKILL.md    # bidirectional Jira sync via Atlassian MCP
|
|-- hooks/
|   +-- hooks.json                   # 6 event-driven hooks
|
|-- scripts/
|   |-- auto-loop.sh                 # Persistent autonomous loop runner
|   |-- auto-build-stop-hook.sh      # Prevents exit during auto-build
|   |-- session-context.sh           # Session initialization
|   +-- safe-bash-check.sh           # Dangerous command detection
|
|-- .gitignore                       # Git ignore rules
|-- CLAUDE.md                        # Plugin development context
|-- README.md                        # This file
+-- LICENSE                          # MIT License
```

---

## Usage Examples

### Fully Autonomous Product Build

```bash
# Generate PRD from an idea
/gen-prd "Build a SaaS invoicing platform for Indian freelancers with GST compliance"

# Build the entire product autonomously
/auto-build ./PRD.md

# If interrupted, resume from where it left off
/resume-build

# Or use the shell script for persistent execution
./scripts/auto-loop.sh ./PRD.md --max-iterations 100
```

### Migrate an Existing Project

```bash
# Step 1: Understand the existing codebase
/analyze-project ./my-existing-app

# Step 2: Check what's missing vs Alpha AI standards
/gap-analysis

# Step 3: Migrate technology stack
/migrate-stack PostgreSQL to MySQL
/migrate-stack localStorage JWT to HTTP-Only Cookie JWT
/migrate-stack Stripe to Razorpay

# Step 4: Add missing features
/retrofit jwt-cookies
/retrofit google-oauth
/retrofit razorpay
/retrofit credit-points
/retrofit dark-mode
/retrofit meilisearch
/retrofit sentry
```

### Generate Complete CI/CD and Infrastructure

```bash
# Generate CI/CD pipeline
/gen-ci github-actions

# Generate Infrastructure as Code
/gen-infra docker          # Docker Compose (dev + prod + test)
/gen-infra k8s             # Kubernetes manifests with Kustomize
/gen-infra k3s             # K3s manifests for Hostinger VPS (Traefik IngressRoute)
/gen-infra terraform       # AWS Terraform modules
/gen-infra helm            # Helm chart

# Generate operational runbooks
/runbook --type=all
```

### Security and Quality Audit

```bash
# Full security scan
/security-scan --full

# Auto-fix security issues
/security-scan --fix

# Check accessibility
/accessibility --fix

# Scan technical debt
/tech-debt --fix-quick-wins

# Performance testing
/perf-test all --users=100 --duration=60s

# End-to-end tests
/e2e-test --all --visual
```

### Release Management

```bash
# Auto-generate changelog
/changelog

# Create a release (auto-detects version bump from commits)
/release patch
/release minor
/release major

# Dry run first
/release minor --dry-run

# Update dependencies safely
/dep-update                  # All updates
/dep-update --security-only  # Only security patches
/dep-update --dry-run        # Preview what would change
```

### Documentation

```bash
# Generate all documentation
/gen-docs --type=all

# Generate specific docs
/gen-docs --type=readme
/gen-docs --type=architecture
/gen-docs --type=api
/gen-docs --type=deployment
/gen-docs --type=contributing

# Generate Docusaurus site
/gen-docs --type=all --format=docusaurus
```

---

## Agent Teams

Agent Teams is an **experimental feature** that enables true multi-agent parallelism. When enabled, commands like `/auto-build`, `/code-review`, and `/debug` spawn multiple Claude Code instances that work as coordinated teammates.

### How It Works

```
Team Lead (you/Arjun)
├── Creates team with TeamCreate
├── Spawns teammates (each is a full Claude instance)
├── Creates shared tasks with TaskCreate
├── Assigns tasks with TaskUpdate
└── Coordinates via SendMessage

Teammates (viktor, yuki, marcus, liam, oleksiy, sofia, ...)
├── Check TaskList for assigned tasks
├── Work on tasks independently (true parallelism)
├── Communicate with SendMessage
├── Mark tasks completed with TaskUpdate
└── Auto-unblock dependent tasks
```

### Enabling Agent Teams

Add to `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

### Agent Teams Hooks

The plugin includes 2 hooks for Agent Teams coordination:

| Hook | What It Does |
|------|--------------|
| **TeammateIdle** | When a teammate finishes and goes idle, checks for pending tasks and reassigns (exit code 2 = keep working) |
| **TaskCompleted** | Quality gate — validates task output before accepting |

### Fallback

When Agent Teams is **not enabled**, all commands automatically fall back to standard Agent subagents. No configuration changes needed — the plugin detects the setting and adapts.

---

## Configuration

### Disabling the Plugin

```bash
# If installed via marketplace
/plugin disable cortex@alphaai

# If using settings.json, remove the directory entry:
# Remove from ~/.claude/settings.json → plugins.directories

# If using --plugin-dir, just stop passing the flag
claude  # without --plugin-dir
```

### Development Mode

For plugin development and testing:

```bash
# Load with --plugin-dir (changes take effect immediately, no reinstall)
claude --plugin-dir /path/to/cortex

# Check loaded commands
/help

# Check loaded agents
/agents

# Check loaded hooks
/hooks
```

---

## Uninstall

```bash
# If installed via marketplace
/plugin uninstall cortex@alphaai

# If using --plugin-dir, just stop passing the flag
claude  # without --plugin-dir
```

---

## Troubleshooting

### Plugin not loading / No banner on startup

1. **Check the path is absolute** in `~/.claude/settings.json` — relative paths and `~` don't work
2. **Verify plugin.json exists**: `ls /path/to/cortex/.claude-plugin/plugin.json`
3. **Restart Claude Code** — plugins load at session start, not mid-session
4. **Check settings.json is valid JSON**: `cat ~/.claude/settings.json | python3 -m json.tool`

### Commands not showing in /help

1. Verify plugin directory has `commands/` folder with `.md` files
2. Check each command file has valid YAML frontmatter (starts with `---`)
3. Restart Claude Code after any command file changes

### Hooks not firing

1. **Scripts must be executable**: `chmod +x scripts/*.sh`
2. **Restart required** — hooks load at session start only
3. **Validate hooks.json**: `cat hooks/hooks.json | python3 -m json.tool`
4. **Check script paths** — hooks.json uses `${CLAUDE_PLUGIN_ROOT}` which resolves at runtime

### Auto-build stops unexpectedly

1. Check rate limits — the auto-loop script handles rate limit pauses
2. Use `/resume-build` to continue from the last checkpoint
3. For persistent execution: `./scripts/auto-loop.sh ./PRD.md`
4. Verify `AUTO_BUILD_STATE.json` exists in project root during active builds

### Agent Teams not working

1. **Verify the env flag**: Check `~/.claude/settings.json` has `"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"` under `env`
2. **Restart Claude Code** — env vars load at session start
3. **Check permissions**: Agent Teams requires `Agent` in the `permissions.allow` list
4. **Teammates not responding**: Teammates go idle between turns — this is normal. Send them a message to wake them up

### Permission prompts on every action

Add the required permissions to `~/.claude/settings.json` → `permissions.allow` (see [Step 3: Configure Permissions](#step-3-configure-permissions))

### "command not found" errors in hooks

1. Ensure `jq` is installed: `brew install jq` (macOS) or `apt install jq` (Linux)
2. Ensure `ruff` or `black` is installed for Python auto-formatting: `pip install ruff`

---

## Contributing

1. Fork this repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make changes following the plugin architecture (see `CLAUDE.md`)
4. Test locally: `claude --plugin-dir .`
5. Commit with conventional commits: `git commit -m "feat: add my feature"`
6. Push and open a Pull Request

### Adding a New Command

1. Create `commands/my-command.md` with YAML frontmatter
2. Add `description` and `allowed-tools` fields
3. Write the instruction body
4. Update `CLAUDE.md` directory structure
5. Test with `--plugin-dir`

### Adding a New Agent

1. Create `agents/my-agent.md` with YAML frontmatter
2. Write the system prompt
3. Reference from commands using the Agent tool

### Adding a New Skill

1. Create `skills/my-skill/SKILL.md` with YAML frontmatter
2. Set the `description` as a trigger condition
3. Claude auto-invokes it when task context matches

---

## License

MIT License - See [LICENSE](LICENSE) for details.

Copyright (c) 2025-2026 Alpha AI Service Pvt Ltd

---

**Built by Alpha AI Service Pvt Ltd** | [alphaaiservice.com](https://alphaaiservice.com)
# cortex
