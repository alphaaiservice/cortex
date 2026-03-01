---
description: "Resume an interrupted autonomous build from the last saved state. Supports Agent Teams upgrade. Usage: /resume-build"
---

# Resume Autonomous Build

Resume the autonomous build from the last checkpoint. Supports upgrading from sequential to Agent Teams parallel mode mid-build.

## Step 1: Load State

```bash
cat AUTO_BUILD_STATE.json 2>/dev/null
```

If no state file exists:
- Check git log for auto-build commits
- Check for MASTER_PLAN.md
- Check for PRD.md
- If nothing found, inform user and suggest `/auto-build`

## Step 2: Determine Resume Point

Read the state file and identify:
1. **Current phase** — which phase was in progress
2. **Completed tasks** — what's already done
3. **Blockers** — any unresolved issues
4. **Test status** — current test results
5. **Build status** — last build result
6. **Build mode** — was it `sequential` or `parallel` (Agent Teams)?

## Step 3: Agent Teams Detection — MANDATORY (Check EVERY Resume)

**BEFORE doing any work**, check if Agent Teams should be activated or upgraded:

```
Read ~/.claude/settings.json → check env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS

CASE 1: Agent Teams NOW enabled + State has build_mode "sequential" (or missing):
  → UPGRADE to parallel mode!
  → Announce: "⚡ UPGRADE DETECTED — Agent Teams is now enabled! Upgrading from sequential to parallel mode for remaining phases."
  → Call TeamCreate tool:
      team_name = "cortex"
      description = "Alpha AI auto-build team — resuming {project_name} from Phase {current_phase}"
  → Spawn teammates for remaining work (see Step 3a below)
  → Update AUTO_BUILD_STATE.json:
      "build_mode": "parallel"
      "agent_teams_enabled": true
      "team_name": "cortex"
      "active_teammates": [list of spawned teammate names]
      "upgraded_from_sequential": true
      "upgrade_point": "{current_phase}"

CASE 2: Agent Teams enabled + State already has build_mode "parallel":
  → Check if team still exists at ~/.claude/teams/cortex/
  → If team exists: reconnect to existing teammates
  → If team gone: recreate team + spawn new teammates
  → Announce: "⚡ PARALLEL MODE — Reconnecting to Agent Teams build squad..."

CASE 3: Agent Teams NOT enabled + State has build_mode "sequential" (or missing):
  → Stay in sequential mode
  → Announce: "📋 SEQUENTIAL MODE — Resuming one phase at a time."
  → Update state: "build_mode": "sequential"

CASE 4: Agent Teams NOT enabled + State has build_mode "parallel":
  → DOWNGRADE to sequential mode (teams no longer available)
  → Announce: "⚠️ Agent Teams was disabled. Downgrading to sequential mode for remaining phases."
  → Update state: "build_mode": "sequential"
```

### Step 3a: Spawn Teammates — MANDATORY BEFORE ANY WORK

**⛔ HARD RULE: You MUST spawn ALL teammates BEFORE running ANY command (pytest, ruff, bash, etc.)**
**⛔ Do NOT "analyze failures first" — that analysis IS a task for a teammate (Liam).**
**⛔ Do NOT run tests, lint, or any verification in the main context — delegate to teammates.**

When upgrading from sequential to parallel, spawn teammates for **remaining** work.
**Call the Agent tool with BOTH `team_name` and `name` parameters** — this is what creates real teammates vs regular subagents.

```
STEP 1: Spawn teammates IMMEDIATELY after TeamCreate (do NOT do anything else first)

Agent tool call #1:
  name = "viktor"
  team_name = "cortex"
  subagent_type = "general-purpose"
  mode = "bypassPermissions"
  description = "Backend lead: models, migrations, services, repos"
  prompt = "You are Viktor Petrov from Russia, Backend Lead for the Alpha AI Global Dev Squad.
You are methodical and love clean schemas. Start every message with: '🇷🇺 Viktor here from Moscow — let me model this with precision.'
YOUR DOMAIN: app/models/, app/db/, app/repositories/, app/services/, alembic/
WORKFLOW: Check TaskList → claim tasks with TaskUpdate (set owner='viktor', status='in_progress') → do the work → mark completed with TaskUpdate → check TaskList for next task.
COMMUNICATE: Use SendMessage tool to message teammates or team lead by name.
End each task with: '🇷🇺 Viktor — Backend Lead — Done! [summary of files created/modified]'"

Agent tool call #2:
  name = "marcus"
  team_name = "cortex"
  subagent_type = "general-purpose"
  mode = "bypassPermissions"
  description = "API engineer: routes, controllers, middleware"
  prompt = "You are Marcus Chen from USA, API Engineer. Thin-controller purist.
Start every message with: '🇺🇸 Marcus from SF — keeping controllers razor-thin.'
YOUR DOMAIN: app/api/ (except auth/), app/schemas/, app/middleware/
RULES: Thin controllers only. NO business logic in handlers. Pydantic v2 schemas.
WORKFLOW: Check TaskList → claim tasks → do work → mark completed → check for next.
COMMUNICATE: Use SendMessage tool to message teammates or team lead by name.
End each task with: '🇺🇸 Marcus — API Engineer — Done! [summary]'"

Agent tool call #3:
  name = "liam"
  team_name = "cortex"
  subagent_type = "general-purpose"
  mode = "bypassPermissions"
  description = "QA lead: test fixes, coverage improvement, lint cleanup"
  prompt = "You are Liam O'Connor from Ireland, QA Lead. Coverage fanatic >80%.
Start every message with: '🇮🇪 Liam from Dublin — if it can break, I will find it.'
YOUR DOMAIN: tests/
RULES: pytest + pytest-asyncio, AAA pattern, mock externals only. Coverage >80% overall, >95% critical, 100% new.
WORKFLOW: Check TaskList → claim tasks → do work → mark completed → check for next.
COMMUNICATE: Use SendMessage tool to message teammates or team lead by name.
End each task with: '🇮🇪 Liam — QA Lead — Done! [summary]'"

Agent tool call #4 (if auth/security work remains):
  name = "yuki"
  team_name = "cortex"
  subagent_type = "general-purpose"
  mode = "bypassPermissions"
  description = "Auth engineer: JWT, OAuth, RBAC, security"
  prompt = "You are Yuki Tanaka from Japan, Auth Engineer. Security-first mindset.
Start every message with: '🇯🇵 Yuki here from Tokyo — nobody gets past this auth.'
YOUR DOMAIN: app/api/auth/, app/services/auth_service.py, app/middleware/, app/utils/security.py
AUTH RULES: JWT in HTTP-Only Cookies ONLY. Access 30min, Refresh 7d. CSRF double-submit. Redis blacklist on logout.
WORKFLOW: Check TaskList → claim tasks → do work → mark completed → check for next.
COMMUNICATE: Use SendMessage tool.
End each task with: '🇯🇵 Yuki — Auth Engineer — Done! [summary]'"

Agent tool call #5 (if CI/CD, Docker, deployment work remains):
  name = "oleksiy"
  team_name = "cortex"
  subagent_type = "general-purpose"
  mode = "bypassPermissions"
  description = "DevOps lead: Docker, CI/CD, deployment"
  prompt = "You are Oleksiy Koval from Ukraine, DevOps Lead. Container wizard.
Start every message with: '🇺🇦 Oleksiy from Kyiv — multi-stage build, optimized layers.'
YOUR DOMAIN: Dockerfile, docker-compose*.yml, .github/, scripts/, Makefile, monitoring/
RULES: Multi-stage Docker, pin versions, non-root. CI: Lint→TypeCheck→Test→Build→IntTest→SecScan→Deploy.
WORKFLOW: Check TaskList → claim tasks → do work → mark completed → check for next.
COMMUNICATE: Use SendMessage tool.
End each task with: '🇺🇦 Oleksiy — DevOps Lead — Done! [summary]'"

STEP 2: Wait for all Agent tool calls to return (teammates are now alive)
STEP 3: ONLY THEN proceed to Step 3b (create and assign tasks)
```

**Conditional squads** (spawn full squad of 5 per detected platform):

**CHROME EXTENSION SQUAD (5 devs)** — spawn if manifest.json MV3, src/background/, src/content/, or extension/ exist:
- `aditya` (Lead) — MV3 architecture, sidepanel UI
- `dmitri` — Content scripts, DOM inspection, selectors
- `mika` — Background service worker, message passing, storage
- `hana` — Options page, settings UI, permissions
- `oscar` — Vite build config, multi-target builds, testing

**WEB FRONTEND SQUAD (5 devs)** — spawn if frontend/ with next/react, src/app/, next.config.*, or PRD mentions frontend:
- `sofia` (Lead) — Pages, layouts, routing, SSR/SSG, SEO
- `emma` — Forms, validation, Zod schemas, file uploads
- `jinho` — State management (TanStack Query + Zustand), API client, WebSocket
- `isabella` — Animations (Framer Motion), dark mode, skeleton loaders, theming
- `nadia` — Shared components, design system (Shadcn/Radix), accessibility

**MOBILE SQUAD (5 devs)** — spawn if mobile/ with react-native/expo, app.json, or PRD mentions mobile:
- `rahul` (Lead) — Navigation, Expo Router, deep links
- `chioma` — Mobile UI, NativeWind, gestures, haptics, animations
- `lucas` — State management, offline sync, secure storage
- `priya_m` — Forms, camera, media, biometrics, device APIs
- `tomas` — Push notifications, EAS builds, app store distribution

**AI SQUAD (1 dev)** — spawn if PRD mentions GenAI, LLM, RAG, agents:
- `hiroshi` (Lead) — LiteLLM gateway, RAG pipeline, agents, guardrails

**For full teammate prompt templates, see /auto-build Step 0.5.3.**
Each teammate MUST be spawned with Agent tool using BOTH `team_name` and `name` parameters.

**IMPORTANT deconfliction rules:**
- Chrome Extension projects → extension squad (NOT web frontend squad)
- Next.js web apps → web frontend squad (NOT extension squad)
- A project can have BOTH (e.g., Chrome Extension + web dashboard) → spawn BOTH squads

### Step 3b: Create Tasks and Assign to Teammates

**⛔ Do NOT skip this step. Tasks MUST be created and assigned BEFORE teammates can work.**

```
For each pending phase/issue from AUTO_BUILD_STATE.json:

  1. Analyze what remains (read state, NOT by running commands yourself)
  2. Create tasks with TaskCreate:

  Example tasks for a resume with failing tests + lint errors:

  TaskCreate:
    subject = "Fix 16 failing tests"
    description = "Run pytest, analyze failures, fix all 16 failing tests. Report coverage after."
    activeForm = "Fixing failing tests"

  TaskCreate:
    subject = "Fix 72 lint errors"
    description = "Run ruff check, fix all 72 remaining lint errors. Run ruff format."
    activeForm = "Fixing lint errors"

  TaskCreate:
    subject = "Improve test coverage from 75% to 85%+"
    description = "Add tests for uncovered modules. Target >80% overall, >95% critical paths."
    activeForm = "Improving test coverage"

  TaskCreate:
    subject = "Generate API documentation"
    description = "Create comprehensive API docs for all endpoints."
    activeForm = "Generating API docs"

  3. Assign owners with TaskUpdate:

  TaskUpdate: taskId="{fix tests}", owner="liam"
  TaskUpdate: taskId="{fix lint}", owner="marcus"
  TaskUpdate: taskId="{improve coverage}", owner="liam", addBlockedBy=["{fix tests}"]
  TaskUpdate: taskId="{api docs}", owner="marcus", addBlockedBy=["{fix lint}"]

  4. Notify teammates with SendMessage:

  SendMessage:
    type = "message"
    recipient = "liam"
    content = "Tasks assigned — fix the 16 failing tests first, then improve coverage. Check TaskList."
    summary = "Test fix tasks assigned to Liam"

  SendMessage:
    type = "message"
    recipient = "marcus"
    content = "Tasks assigned — fix 72 lint errors first, then generate API docs. Check TaskList."
    summary = "Lint fix tasks assigned to Marcus"
```

## Step 4: Verify Existing Work

```bash
echo "=== Verifying existing code ==="
npm run lint 2>&1 || ruff check . 2>&1 || true
npm test 2>&1 || pytest 2>&1 || true
npm run build 2>&1 || true
```

## Step 5: Resume Execution

Pick up from the exact task that was interrupted:
1. Skip all completed tasks
2. Retry any previously blocked tasks (environment may have changed)
3. **If parallel mode**: coordinate via TaskList + SendMessage (teammates work concurrently)
4. **If sequential mode**: delegate each phase to a fresh Agent subagent
5. Maintain the same state file and logging

## Step 6: Progress Report

Show what was already done, build mode, and what remains:

```
╔══════════════════════════════════════════════════╗
║           RESUMING AUTO-BUILD                     ║
╠══════════════════════════════════════════════════╣
║ Build Mode: PARALLEL (Agent Teams)               ║
║ Teammates:  viktor, marcus, liam                 ║
║ Completed:  Phases 1-7                           ║
║ Resuming:   Phase 8 (Enterprise)                 ║
║ Remaining:  Phases 8-15                          ║
║ Progress:   75%                                  ║
║ Blockers:   0                                    ║
║ Upgraded:   Yes (sequential → parallel)          ║
╚══════════════════════════════════════════════════╝
```

Then continue with the autonomous loop, following all rules from `/auto-build`.

Output `<promise>PRODUCT_COMPLETE</promise>` when the entire product is done.
