---
description: "Break PRD or feature list into sprint-sized tasks with estimates, dependencies, and assignments. Generates SPRINT_PLAN.md. Usage: /sprint-plan <prd-file-or-feature-description> [--sprints=4] [--team-size=3]"
---

# Sprint Planner — Automated Task Breakdown & Scheduling

Break down requirements into actionable, dependency-aware sprint plans: **$ARGUMENTS**

**Integration with other commands:**
- `/gen-prd` auto-calls this logic after generating PRD.md
- `/auto-build` reads SPRINT_PLAN.md to track task progress per sprint
- `/feature` can reference sprint task IDs (e.g., `/feature "task 2.3 from sprint plan"`)
- `/resume-build` restores sprint progress from AUTO_BUILD_STATE.json

---

## Step 0: Parse Arguments & Configuration

Extract configuration from `$ARGUMENTS`:

```
INPUT PARSING RULES:
1. If $ARGUMENTS contains a file path (ends in .md, .txt, .doc, .pdf, or starts with ./ or /)
   → Read that file as the requirements source
2. If $ARGUMENTS contains raw text (no file extension detected)
   → Parse it directly as a feature description
3. Extract optional flags:
   --sprints=N     → Number of sprints to plan (default: 4)
   --team-size=N   → Number of developers (default: 3)
   --sprint-days=N → Working days per sprint (default: 10, i.e., 2 weeks)
   --create-issues  → Flag to create GitHub issues after plan generation
   --velocity=N    → Override story points per dev per sprint (default: 40 — tasks are micro-sized)
   --buffer=N      → Buffer percentage for bugs/tech debt (default: 20)
   --start-date=YYYY-MM-DD → Sprint 1 start date (default: next Monday)
```

**Set defaults:**
```
SPRINTS = extracted --sprints or 4
TEAM_SIZE = extracted --team-size or 3
SPRINT_DAYS = extracted --sprint-days or 10
VELOCITY = extracted --velocity or 40
BUFFER_PERCENT = extracted --buffer or 20
CREATE_ISSUES = true if --create-issues flag present, else false
START_DATE = extracted --start-date or next Monday from today
```

**Calculate capacity:**
```
POINTS_PER_SPRINT = TEAM_SIZE * VELOCITY
BUFFER_POINTS = POINTS_PER_SPRINT * (BUFFER_PERCENT / 100)
AVAILABLE_POINTS = POINTS_PER_SPRINT - BUFFER_POINTS
TOTAL_AVAILABLE = AVAILABLE_POINTS * SPRINTS
```

---

## Step 1: Parse Requirements

### 1A: Load the Source Document

If the input is a file path, read it:

```bash
# Check if file exists
ls "$FILE_PATH" 2>/dev/null
```

Use the `Read` tool to load the full contents of the file.

If the input is a text description, use it directly as the feature specification.

### 1B: Check for Related Project Context

Search the project for additional context that informs planning:

```bash
# Look for existing project analysis, PRDs, or architecture docs
ls PROJECT_ANALYSIS.md GAP_ANALYSIS.md MARKET_RESEARCH.md BRAND_GUIDE.md 2>/dev/null
```

Use `Glob` to find:
- `**/PRD*.md` — Product requirements documents
- `**/SPRINT_PLAN*.md` — Previous sprint plans (avoid duplication)
- `**/CHANGELOG.md` — What has been built already
- `**/package.json` or `**/pyproject.toml` — Tech stack detection

Read any found files to understand what already exists.

### 1C: Extract Requirements

From the source document, systematically extract:

**1. Features / Epics:**
- Each major capability or system component
- Group related user stories under their parent feature
- Identify if a feature is backend-only, frontend-only, or full-stack

**2. User Stories:**
- Extract all user stories (look for "As a [user], I want [action], so that [benefit]" patterns)
- If no formal user stories exist, decompose features into implicit user stories
- Each user story becomes one or more tasks

**3. Acceptance Criteria:**
- Extract all acceptance criteria (look for checkbox lists, "must have", "should", "given/when/then")
- Map acceptance criteria to their parent features
- These become the sprint acceptance criteria

**4. Technical Requirements:**
- Database models and schema needs
- API endpoints required
- Authentication and authorization requirements
- Third-party integrations
- Infrastructure needs (caching, queuing, file storage, etc.)
- AI/ML pipeline requirements (if applicable)

**5. Non-Functional Requirements:**
- Performance targets
- Security requirements
- Testing requirements
- Documentation requirements
- Deployment requirements

Store all extracted requirements in a structured internal format before proceeding.

---

## Step 2: Decompose Into Tasks & Estimate Effort

### 2A: Task Decomposition

For EACH feature/user story, break it down into **micro-tasks** — the smallest possible unit of work. Each task should be:
- Completable in **30 minutes to 2 hours MAX** (fits within a single Claude context window)
- ONE file or ONE function per task (never "build entire feature")
- Independently testable and committable
- Clearly scoped (no ambiguity about "done")

**CRITICAL RULE — TASK SIZE LIMIT:**
```
❌ NEVER create tasks that take more than 2 hours (3 story points)
❌ NEVER create tasks like "Build auth system" or "Create payment flow"
❌ NEVER bundle model + service + API + tests into ONE task
✅ ALWAYS split into single-layer tasks: one model, one service, one endpoint
✅ ALWAYS split large features into 5-15 micro-tasks
✅ Each task = ONE file change or ONE small logical unit
```

**WHY:** Large tasks fill the Claude context window before completing.
Small tasks = faster completion, better commits, easier debugging.
If a task description is more than 3 sentences, it's TOO BIG — split it.

**Task types to generate:**
```
BACKEND tasks:
  - Database model creation (SQLAlchemy models, MongoDB documents)
  - Database migration scripts (Alembic)
  - Repository layer (CRUD operations)
  - Service layer (business logic)
  - API endpoint (controller + route registration)
  - Background tasks (Celery workers)
  - Webhook handlers
  - Third-party API integrations

FRONTEND tasks:
  - Page/screen component
  - Reusable UI component
  - Form with validation
  - API integration (hooks, services)
  - State management setup
  - Navigation/routing setup

INFRASTRUCTURE tasks:
  - Project scaffolding
  - Docker/Docker Compose setup
  - CI/CD pipeline configuration
  - Environment configuration
  - Database setup and seeding
  - Cache layer setup (Redis)
  - Search engine setup (Meilisearch)

TESTING tasks:
  - Unit tests for services
  - Integration tests for API endpoints
  - E2E tests for critical flows
  - Test fixtures and factories

DOCUMENTATION tasks:
  - API documentation (OpenAPI/Swagger)
  - README updates
  - Architecture decision records
  - Deployment runbook
```

### 2B: Estimate Using T-Shirt Sizes

For EACH task, assign a T-shirt size based on complexity, uncertainty, and scope:

```
SIZE DEFINITIONS (MAX size is M — never bigger):

XS (15-30 min) → 1 story point
  Examples:
  - Config file change (.env, settings, one constant)
  - Add ONE Pydantic schema or DTO (< 5 fields)
  - Add ONE route to an existing controller
  - Install and configure ONE package
  - Add ONE enum or type definition
  - Simple CSS/styling fix
  - Add ONE environment variable

S (30-60 min) → 2 story points
  Examples:
  - Create ONE database model file (single table)
  - Create ONE repository file (CRUD for one model)
  - Create ONE service method (single business operation)
  - Create ONE API endpoint (single route: GET, POST, etc.)
  - Create ONE UI component (button, card, badge, input)
  - Write unit tests for ONE service method
  - Add Redis caching for ONE entity
  - Create ONE Celery/background task
  - Create ONE form component (3-5 fields)

M (1-2 hours) → 3 story points — THIS IS THE MAX ALLOWED SIZE
  Examples:
  - Create ONE service file with 2-3 related methods
  - Create ONE page component with layout + API call
  - Create ONE API controller with 2-3 endpoints for same resource
  - Create integration tests for ONE endpoint
  - Configure ONE third-party integration (single provider)
  - Create ONE complex UI component (data table OR chart OR modal)
  - Create ONE migration file with indexes
  - Set up ONE middleware (auth OR CORS OR rate-limit)

❌ L AND XL ARE BANNED — ALWAYS SPLIT INTO SMALLER TASKS:

Instead of L "OAuth2 integration (full flow)" → split into:
  S: Create Google OAuth config + env vars
  S: Create OAuth callback endpoint
  S: Create OAuth service (token exchange)
  S: Create user upsert on OAuth login
  S: Add JWT cookie setting after OAuth
  XS: Add OAuth button to login page

Instead of XL "Complete auth system" → split into:
  S: Create User model + migration
  S: Create User repository (CRUD)
  S: Create password hashing utility
  S: Create register endpoint + service
  S: Create login endpoint + service
  S: Create JWT token generation utility
  S: Create JWT cookie setting middleware
  S: Create auth dependency (get_current_user)
  S: Create refresh token endpoint
  S: Create logout endpoint + Redis blacklist
  XS: Create auth schemas (request/response DTOs)
  S: Write unit tests for auth service
  S: Write integration tests for auth endpoints
```

### 2C: Classify Task Type

Tag each task with:
- **Type**: Backend / Frontend / Infrastructure / Testing / Documentation
- **Layer**: Model / Repository / Service / API / UI / Config
- **Category**: Auth / Core / Feature / Admin / AI / Infra

---

## Step 3: Build Dependency Graph

### 3A: Identify Dependencies

For every task, determine what MUST be completed before it can start. Apply these universal dependency rules:

```
UNIVERSAL DEPENDENCY RULES (always apply):

1. INFRASTRUCTURE FIRST
   Project scaffold → Everything else
   Docker setup → Local development tasks
   CI/CD → Deployment tasks
   Database setup → All model tasks

2. DATABASE BEFORE API
   Database model → Repository → Service → API endpoint
   NEVER create an API endpoint before its model exists
   NEVER create a service before its repository exists

3. AUTH BEFORE PROTECTED ROUTES
   User model → Auth service → Auth middleware → Protected endpoints
   JWT setup → Token refresh → Logout/blacklist
   OAuth provider config → OAuth flow → Account linking

4. BACKEND BEFORE FRONTEND INTEGRATION
   API endpoint → Frontend API hook/service
   WebSocket server → Frontend WebSocket client
   Auth API → Frontend auth context/provider

5. CORE BEFORE ADVANCED
   Basic CRUD → Advanced filtering/search
   Simple auth → 2FA/TOTP
   Basic notifications → Real-time WebSocket
   Text chat → Multi-modal AI

6. MODELS BEFORE MIGRATIONS
   All models for a feature → Alembic migration
   Schema changes → Data migration scripts

7. PARENT BEFORE CHILD ENTITIES
   User model → Profile model
   User model → Subscription model
   Subscription model → CreditBalance model
   Product model → Order model

8. SERVICES BEFORE BACKGROUND TASKS
   Service with business logic → Celery task wrapping that service
   Email service → Email sending Celery task

9. CONFIGURATION BEFORE USAGE
   Redis setup → Caching, rate limiting, JWT blacklist
   S3/MinIO setup → File upload endpoints
   Meilisearch setup → Search endpoints
   Razorpay config → Payment endpoints

10. TESTING AFTER IMPLEMENTATION
    Feature implementation → Unit tests for that feature
    API endpoint → Integration tests for that endpoint
    All features → E2E tests
```

### 3B: Build the Graph

Create an internal dependency mapping:

```
DEPENDENCY MAP FORMAT:
task_id: [list of task_ids that MUST complete before this task can start]

Example:
1.1 (project scaffold): []           ← no dependencies, can start immediately
1.2 (user model): [1.1]              ← needs scaffold first
1.3 (auth service): [1.2]            ← needs user model
1.4 (login endpoint): [1.3]          ← needs auth service
1.5 (frontend setup): []             ← independent, can parallel with backend
1.6 (login page): [1.4, 1.5]         ← needs both backend endpoint AND frontend setup
```

### 3C: Identify the Critical Path

The critical path is the longest chain of dependent tasks from start to finish. This determines the minimum project duration regardless of team size.

```
CRITICAL PATH ALGORITHM:
1. Find all tasks with no dependencies (entry points)
2. For each entry point, trace the longest chain to a task with no dependents
3. The longest chain is the critical path
4. Sum the story points along this chain
5. Any delay on critical path tasks delays the entire project
```

Mark all critical path tasks explicitly so they get scheduling priority.

---

## Step 4: Assign to Sprints

### 4A: Sprint Allocation Rules

Distribute tasks across sprints following these rules (in priority order):

```
RULE 1: DEPENDENCY ORDER
  A task CANNOT be scheduled in a sprint if ANY of its dependencies
  are scheduled in the same sprint or a later sprint.
  Dependencies must complete in a PREVIOUS sprint.

  Exception: If two tasks are both small (XS or S) and one depends
  on the other, they CAN be in the same sprint if assigned to the
  same developer (sequential within sprint).

RULE 2: CAPACITY LIMITS
  Total story points per sprint MUST NOT exceed AVAILABLE_POINTS.
  AVAILABLE_POINTS = (TEAM_SIZE * VELOCITY) - BUFFER_POINTS

  Example with defaults:
  Team of 3, velocity 40 = 120 raw points
  20% buffer = 24 points reserved
  Available = 96 points per sprint (more micro-tasks, same total work)

RULE 3: CRITICAL PATH PRIORITY
  Tasks on the critical path get scheduled FIRST.
  Never push a critical path task to a later sprint if it can
  fit in the current sprint.

RULE 4: BALANCED WORKLOAD
  Distribute points roughly equally across developers.
  No single developer should have > 130% of the average load.
  No single developer should have < 70% of the average load.

RULE 5: SKILL-BASED ASSIGNMENT
  Group related tasks by type for each developer:
  - Dev1: Backend-heavy sprints (models, services, APIs)
  - Dev2: Frontend-heavy sprints (pages, components, integration)
  - Dev3: Mixed (infra, testing, integration, AI pipeline)

  Adjust based on actual team size. With team of 1, all tasks
  go to the same developer.

RULE 6: SPRINT THEMES
  Each sprint should have a coherent theme:
  - Sprint 1: Foundation (scaffold, models, auth, basic setup)
  - Sprint 2: Core Features (main CRUD, primary workflows)
  - Sprint 3: Advanced Features (real-time, AI, integrations)
  - Sprint 4: Polish + Launch (testing, docs, deployment, optimization)

  Adjust themes based on actual sprint count and project scope.

RULE 7: BUFFER USAGE
  The 20% buffer in each sprint is reserved for:
  - Bug fixes discovered during development
  - Technical debt from shortcuts in previous sprints
  - Unexpected blockers and scope adjustments
  - Code review feedback requiring rework
  Do NOT schedule tasks into the buffer. It absorbs variance.

RULE 8: TESTING DISTRIBUTION
  Do NOT pile all testing into the final sprint.
  Each sprint should include tests for the features built in that sprint.
  Final sprint gets E2E tests and integration testing only.

RULE 9: DOCUMENTATION
  Inline documentation happens alongside development (same sprint).
  API docs and READMEs go in the final sprint.
  Architecture docs go in Sprint 1.
```

### 4B: Sprint Date Calculation

```
SPRINT DATE FORMULA:
  Sprint N start = START_DATE + ((N-1) * SPRINT_DAYS) working days
  Sprint N end = Sprint N start + (SPRINT_DAYS - 1) working days

  Working days = Monday through Friday (skip weekends)
  Do NOT account for holidays (team can adjust manually)
```

### 4C: Developer Assignment

Assign developers as Dev1, Dev2, ..., DevN based on TEAM_SIZE.

```
ASSIGNMENT STRATEGY:
1. Group tasks by type (backend, frontend, infra)
2. Assign each developer a primary focus area
3. For each sprint, assign tasks to developers based on:
   a. Their focus area match
   b. Dependency chains (keep related tasks with same dev)
   c. Load balancing (equalize points across devs)
4. Track per-developer points per sprint to ensure balance
```

---

## Step 5: Generate SPRINT_PLAN.md

Detect the project name from the PRD title, directory name, or package.json/pyproject.toml.

Calculate all summary statistics:
```
STATISTICS:
  total_tasks = count of all tasks
  total_points = sum of all task story points
  backend_tasks = count of Backend type tasks
  frontend_tasks = count of Frontend type tasks
  infra_tasks = count of Infrastructure + Testing + Documentation tasks
  duration_weeks = SPRINTS * (SPRINT_DAYS / 5)
  avg_points_per_sprint = total_points / SPRINTS
  critical_path_length = sum of points on critical path
  critical_path_duration = estimated working days for critical path
```

Write the complete plan to `SPRINT_PLAN.md` using this exact structure:

```markdown
# Sprint Plan: [Project Name]

**Generated**: [current date YYYY-MM-DD]
**Source**: [PRD file path or "inline description"]
**Total Sprints**: [SPRINTS]
**Sprint Duration**: [SPRINT_DAYS] working days ([SPRINT_DAYS/5] weeks)
**Team Size**: [TEAM_SIZE] developers
**Velocity**: [VELOCITY] points/dev/sprint
**Buffer**: [BUFFER_PERCENT]% reserved for bugs/tech debt
**Total Story Points**: [total_points]
**Total Available Capacity**: [TOTAL_AVAILABLE] points ([SPRINTS] sprints x [AVAILABLE_POINTS] pts)
**Estimated Duration**: [duration_weeks] weeks ([START_DATE] to [end date])

---

## Executive Summary

[2-3 sentence overview of what will be built across all sprints, the critical path, and key risks]

---

## Sprint Overview

| Sprint | Theme | Dates | Capacity | Planned | Buffer | Utilization |
|--------|-------|-------|----------|---------|--------|-------------|
| Sprint 1 | [theme] | [start] - [end] | [AVAILABLE_POINTS] | [planned_pts] | [BUFFER_POINTS] | [planned/available * 100]% |
| Sprint 2 | [theme] | [start] - [end] | [AVAILABLE_POINTS] | [planned_pts] | [BUFFER_POINTS] | [planned/available * 100]% |
| Sprint 3 | [theme] | [start] - [end] | [AVAILABLE_POINTS] | [planned_pts] | [BUFFER_POINTS] | [planned/available * 100]% |
| Sprint 4 | [theme] | [start] - [end] | [AVAILABLE_POINTS] | [planned_pts] | [BUFFER_POINTS] | [planned/available * 100]% |
| **Total** | | | **[total_available]** | **[total_points]** | **[total_buffer]** | **[overall_util]%** |

---

## Team Allocation

| Developer | Focus Area | Sprint 1 | Sprint 2 | Sprint 3 | Sprint 4 | Total Points |
|-----------|-----------|----------|----------|----------|----------|-------------|
| Dev1 | [area] | [pts] | [pts] | [pts] | [pts] | [total] |
| Dev2 | [area] | [pts] | [pts] | [pts] | [pts] | [total] |
| Dev3 | [area] | [pts] | [pts] | [pts] | [pts] | [total] |

---

## Sprint 1: [Theme] ([start date] - [end date])

**Theme**: [descriptive theme, e.g., "Foundation — Project Setup + Core Models + Authentication"]
**Capacity**: [AVAILABLE_POINTS] points | **Planned**: [planned] points | **Utilization**: [util]%

### Tasks

| # | Task | Type | Layer | Size | Points | Assignee | Depends On | Status |
|---|------|------|-------|------|--------|----------|------------|--------|
| 1.1 | [task description] | Backend | Infra | XS | 1 | Dev1 | -- | To Do |
| 1.2 | [task description] | Backend | Model | S | 2 | Dev1 | 1.1 | To Do |
| 1.3 | [task description] | Backend | Service | L | 5 | Dev1 | 1.2 | To Do |
| 1.4 | [task description] | Frontend | Infra | S | 2 | Dev2 | -- | To Do |
| 1.5 | [task description] | Frontend | UI | M | 3 | Dev2 | 1.4 | To Do |
| ... | ... | ... | ... | ... | ... | ... | ... | ... |

### Developer Breakdown — Sprint 1

| Developer | Tasks | Points | Focus |
|-----------|-------|--------|-------|
| Dev1 | 1.1, 1.2, 1.3 | [pts] | [Backend: models + auth] |
| Dev2 | 1.4, 1.5 | [pts] | [Frontend: setup + pages] |
| Dev3 | 1.6, 1.7 | [pts] | [Infra: Docker + CI] |

### Sprint 1 Acceptance Criteria

- [ ] [Criterion 1 — verifiable outcome]
- [ ] [Criterion 2 — verifiable outcome]
- [ ] [Criterion 3 — verifiable outcome]
- [ ] All Sprint 1 tasks pass code review
- [ ] All Sprint 1 unit tests passing
- [ ] Deployed to development environment

### Sprint 1 Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| [risk description] | Low/Medium/High | Low/Medium/High | [mitigation strategy] |

---

## Sprint 2: [Theme] ([start date] - [end date])

**Theme**: [descriptive theme, e.g., "Core Features — Primary CRUD + Business Logic + Key Integrations"]
**Capacity**: [AVAILABLE_POINTS] points | **Planned**: [planned] points | **Utilization**: [util]%

### Tasks

| # | Task | Type | Layer | Size | Points | Assignee | Depends On | Status |
|---|------|------|-------|------|--------|----------|------------|--------|
| 2.1 | [task description] | [type] | [layer] | [size] | [pts] | [dev] | [deps] | To Do |
| ... | ... | ... | ... | ... | ... | ... | ... | ... |

### Developer Breakdown — Sprint 2

| Developer | Tasks | Points | Focus |
|-----------|-------|--------|-------|
| Dev1 | ... | [pts] | [...] |
| Dev2 | ... | [pts] | [...] |
| Dev3 | ... | [pts] | [...] |

### Sprint 2 Acceptance Criteria

- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] [Criterion 3]
- [ ] All Sprint 2 tasks pass code review
- [ ] All Sprint 2 unit tests passing
- [ ] Deployed to staging environment

### Sprint 2 Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| [risk description] | [prob] | [impact] | [mitigation] |

---

## Sprint 3: [Theme] ([start date] - [end date])

**Theme**: [descriptive theme, e.g., "Advanced Features — Real-Time + AI/ML + Third-Party Integrations"]
**Capacity**: [AVAILABLE_POINTS] points | **Planned**: [planned] points | **Utilization**: [util]%

### Tasks

| # | Task | Type | Layer | Size | Points | Assignee | Depends On | Status |
|---|------|------|-------|------|--------|----------|------------|--------|
| 3.1 | [task description] | [type] | [layer] | [size] | [pts] | [dev] | [deps] | To Do |
| ... | ... | ... | ... | ... | ... | ... | ... | ... |

### Developer Breakdown — Sprint 3

| Developer | Tasks | Points | Focus |
|-----------|-------|--------|-------|
| Dev1 | ... | [pts] | [...] |
| Dev2 | ... | [pts] | [...] |
| Dev3 | ... | [pts] | [...] |

### Sprint 3 Acceptance Criteria

- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] [Criterion 3]
- [ ] All Sprint 3 tasks pass code review
- [ ] Integration tests covering cross-feature flows
- [ ] Deployed to staging environment

### Sprint 3 Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| [risk description] | [prob] | [impact] | [mitigation] |

---

## Sprint 4: [Theme] ([start date] - [end date])

**Theme**: [descriptive theme, e.g., "Polish + Launch — Testing + Performance + Documentation + Deployment"]
**Capacity**: [AVAILABLE_POINTS] points | **Planned**: [planned] points | **Utilization**: [util]%

### Tasks

| # | Task | Type | Layer | Size | Points | Assignee | Depends On | Status |
|---|------|------|-------|------|--------|----------|------------|--------|
| 4.1 | [task description] | [type] | [layer] | [size] | [pts] | [dev] | [deps] | To Do |
| ... | ... | ... | ... | ... | ... | ... | ... | ... |

### Developer Breakdown — Sprint 4

| Developer | Tasks | Points | Focus |
|-----------|-------|--------|-------|
| Dev1 | ... | [pts] | [...] |
| Dev2 | ... | [pts] | [...] |
| Dev3 | ... | [pts] | [...] |

### Sprint 4 Acceptance Criteria

- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] E2E test suite passing for all critical user flows
- [ ] Performance benchmarks met (API < 200ms p95)
- [ ] Security audit completed (no critical/high findings)
- [ ] API documentation complete and accurate
- [ ] Deployed to production environment
- [ ] Monitoring and alerting configured

### Sprint 4 Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| [risk description] | [prob] | [impact] | [mitigation] |

---

[REPEAT for Sprint 5, 6, ... N if SPRINTS > 4]

---

## Critical Path

The critical path represents the longest chain of dependent tasks. Any delay on these tasks directly delays the project completion date.

```
[task_id: description (Xpts)] → [task_id: description (Xpts)] → ... → [task_id: description (Xpts)]

Total critical path: [N] points | Estimated [N] working days
```

### Critical Path Tasks (must not slip)

| Task ID | Description | Sprint | Points | Assignee | Risk Level |
|---------|-------------|--------|--------|----------|------------|
| [id] | [desc] | [sprint] | [pts] | [dev] | [High/Medium/Low] |
| ... | ... | ... | ... | ... | ... |

---

## Dependency Graph (Simplified)

```
Sprint 1:
  1.1 (scaffold) ─┬─→ 1.2 (user model) ──→ 1.3 (auth service) ──→ 1.4 (auth API)
                   └─→ 1.5 (frontend setup) ──→ 1.6 (login page)

Sprint 2:
  1.4 (auth API) ──→ 2.1 (protected endpoints) ──→ 2.2 (frontend integration)
  1.2 (user model) ──→ 2.3 (domain models) ──→ 2.4 (domain services)

Sprint 3:
  2.4 (domain services) ──→ 3.1 (advanced features)
  2.2 (frontend integration) ──→ 3.2 (real-time UI)

Sprint 4:
  All features ──→ 4.1 (E2E tests) ──→ 4.2 (deployment)
```

[Generate the actual dependency graph based on real tasks, not this example]

---

## Risk Register

| # | Risk | Category | Probability | Impact | Severity | Sprint | Mitigation | Contingency |
|---|------|----------|------------|--------|----------|--------|------------|-------------|
| R1 | [description] | Technical | Low/Med/High | Low/Med/High | [P*I score] | [N] | [proactive action] | [reactive plan] |
| R2 | [description] | Scope | Low/Med/High | Low/Med/High | [P*I score] | [N] | [proactive action] | [reactive plan] |
| R3 | [description] | Resource | Low/Med/High | Low/Med/High | [P*I score] | [N] | [proactive action] | [reactive plan] |
| R4 | [description] | External | Low/Med/High | Low/Med/High | [P*I score] | [N] | [proactive action] | [reactive plan] |
| R5 | [description] | Schedule | Low/Med/High | Low/Med/High | [P*I score] | [N] | [proactive action] | [reactive plan] |

### Risk Categories:
- **Technical**: Technology unknowns, integration complexity, performance concerns
- **Scope**: Feature creep, unclear requirements, changing priorities
- **Resource**: Team availability, skill gaps, key person dependencies
- **External**: Third-party API changes, vendor reliability, regulatory changes
- **Schedule**: Dependency delays, estimation errors, testing bottlenecks

---

## Definition of Done

A task is considered DONE when ALL of the following are satisfied:

### Code Quality
- [ ] Code follows project coding standards and conventions
- [ ] Code reviewed and approved by at least one other developer
- [ ] No linting errors (ruff clean)
- [ ] No type errors (mypy clean)
- [ ] No hardcoded secrets, API keys, or credentials

### Testing
- [ ] Unit tests written for all business logic (>80% coverage)
- [ ] Integration tests written for API endpoints
- [ ] All existing tests still passing (no regressions)
- [ ] Edge cases and error paths tested

### Documentation
- [ ] Inline code comments for complex logic
- [ ] API documentation updated (OpenAPI/Swagger auto-generated)
- [ ] CHANGELOG.md updated with notable changes

### Deployment
- [ ] Deployed to staging/development environment
- [ ] No critical errors in error tracking (Sentry)
- [ ] Feature verified in staging by task owner

### Sprint Completion
A sprint is DONE when:
- [ ] All planned tasks are Done or explicitly deferred with justification
- [ ] Sprint acceptance criteria met
- [ ] Sprint retrospective completed
- [ ] Sprint backlog groomed for next sprint
- [ ] Demo delivered to stakeholders

---

## Story Point Reference Guide

| Size | Points | Time Estimate | Example Tasks |
|------|--------|--------------|---------------|
| XS | 1 | < 2 hours | Config changes, copy updates, simple UI tweaks, adding a constant |
| S | 2 | 2-4 hours | Single endpoint, simple component, unit test file, basic form |
| M | 3 | 4-8 hours | Full CRUD, complex component, integration test suite, file upload |
| L | 5 | 1-2 days | Multi-model feature, full page, OAuth flow, payment integration |
| XL | 8 | 2-5 days | Complete auth system, AI pipeline, admin dashboard, full RBAC |

---

## Status Legend

| Status | Meaning |
|--------|---------|
| To Do | Not started, not blocked |
| Blocked | Cannot start — dependency not complete |
| In Progress | Actively being worked on |
| In Review | Code complete, awaiting review |
| Done | Reviewed, tested, deployed to staging |
| Deferred | Moved to a future sprint with justification |

---

## Revision History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| [current date] | 1.0 | Sprint Planner | Initial plan generated |
```

Save the complete plan as `SPRINT_PLAN.md` in the project root (or the current working directory).

---

## Step 6: Generate GitHub Issues (Conditional)

**ONLY execute this step if `--create-issues` flag was present in $ARGUMENTS.**

If the flag is NOT present, skip entirely and proceed to Step 7.

### 6A: Verify GitHub CLI

```bash
gh auth status 2>/dev/null
```

If `gh` is not authenticated, warn the user and skip issue creation:
```
WARNING: GitHub CLI not authenticated. Skipping issue creation.
Run 'gh auth login' to authenticate, then re-run with --create-issues.
```

### 6B: Create Milestones (One Per Sprint)

```bash
# Create milestone for each sprint
gh api repos/{owner}/{repo}/milestones --method POST \
  -f title="Sprint 1: [Theme]" \
  -f description="[Sprint 1 description with dates and capacity]" \
  -f due_on="[Sprint 1 end date ISO format]"
```

Repeat for each sprint.

### 6C: Create Labels

```bash
# Create sprint labels
gh label create "sprint-1" --color "0E8A16" --description "Sprint 1 tasks" 2>/dev/null
gh label create "sprint-2" --color "1D76DB" --description "Sprint 2 tasks" 2>/dev/null
gh label create "sprint-3" --color "D93F0B" --description "Sprint 3 tasks" 2>/dev/null
gh label create "sprint-4" --color "5319E7" --description "Sprint 4 tasks" 2>/dev/null

# Create type labels
gh label create "backend" --color "0075CA" --description "Backend task" 2>/dev/null
gh label create "frontend" --color "7057FF" --description "Frontend task" 2>/dev/null
gh label create "infrastructure" --color "008672" --description "Infrastructure task" 2>/dev/null
gh label create "testing" --color "E4E669" --description "Testing task" 2>/dev/null
gh label create "documentation" --color "D4C5F9" --description "Documentation task" 2>/dev/null

# Create size labels
gh label create "size:XS" --color "EDEDED" --description "Extra small (1 point)" 2>/dev/null
gh label create "size:S" --color "C2E0C6" --description "Small (2 points)" 2>/dev/null
gh label create "size:M" --color "FEF2C0" --description "Medium (3 points)" 2>/dev/null
gh label create "size:L" --color "F9D0C4" --description "Large (5 points)" 2>/dev/null
gh label create "size:XL" --color "E99695" --description "Extra large (8 points)" 2>/dev/null

# Create priority labels
gh label create "critical-path" --color "B60205" --description "On the critical path - must not slip" 2>/dev/null
```

### 6D: Create Issues (One Per Task)

For EACH task in the sprint plan:

```bash
gh issue create \
  --title "[task_id] [task description]" \
  --body "$(cat <<'EOF'
## Task Details

**Sprint**: Sprint [N] — [Theme]
**Type**: [Backend/Frontend/Infrastructure/Testing/Documentation]
**Layer**: [Model/Repository/Service/API/UI/Config]
**Size**: [XS/S/M/L/XL] ([N] story points)
**Assignee**: [DevN]

## Description

[Detailed description of what needs to be implemented]

## Acceptance Criteria

- [ ] [criterion 1]
- [ ] [criterion 2]
- [ ] [criterion 3]

## Dependencies

[If dependencies exist:]
- Blocked by #[issue_number] — [dependency description]

[If no dependencies:]
- No blockers — can start immediately

## Technical Notes

[Any implementation guidance, patterns to follow, files to modify]

---
*Generated by /sprint-plan*
EOF
)" \
  --label "sprint-[N]" \
  --label "[type]" \
  --label "size:[size]" \
  --milestone "Sprint [N]: [Theme]"
```

Track the created issue numbers so dependencies can reference actual GitHub issue numbers (use "Blocked by #X" format).

### 6E: Update Issue Dependencies

After all issues are created, go back and update issue bodies to reference actual GitHub issue numbers for dependencies:

```bash
# For each issue that has dependencies, update the body
gh issue edit [ISSUE_NUMBER] --body "[updated body with correct #issue references]"
```

### 6F: Report Issue Creation

```
Created [N] GitHub issues across [SPRINTS] milestones.
Labels: sprint-1 through sprint-[N], backend, frontend, infrastructure, testing, documentation
Milestones: Sprint 1 through Sprint [N] with due dates
```

---

## Step 7: Output Summary

After generating SPRINT_PLAN.md (and optionally creating GitHub issues), display this summary:

```
+================================================================+
|  SPRINT PLAN GENERATED                                          |
+================================================================+
|                                                                  |
|  Project: [Project Name]                                         |
|  Source:  [PRD file or "inline description"]                     |
|                                                                  |
|  Duration: [SPRINTS] sprints x [SPRINT_DAYS/5] weeks             |
|            = [duration_weeks] weeks total                        |
|  Timeline: [START_DATE] to [end date]                            |
|  Team:     [TEAM_SIZE] developers                                |
|                                                                  |
+----------------------------------------------------------------+
|  TASK BREAKDOWN                                                  |
+----------------------------------------------------------------+
|  Total Tasks:    [total_tasks]                                   |
|    Backend:      [backend_tasks] tasks                           |
|    Frontend:     [frontend_tasks] tasks                          |
|    Infra/Test:   [infra_tasks] tasks                             |
|  Total Points:   [total_points]                                  |
|  Capacity:       [TOTAL_AVAILABLE] points                        |
|  Utilization:    [total_points/TOTAL_AVAILABLE * 100]%           |
|                                                                  |
+----------------------------------------------------------------+
|  SPRINT SUMMARY                                                  |
+----------------------------------------------------------------+
|  Sprint 1: [theme]                                               |
|            [planned_pts]/[AVAILABLE_POINTS] pts ([N] tasks)      |
|                                                                  |
|  Sprint 2: [theme]                                               |
|            [planned_pts]/[AVAILABLE_POINTS] pts ([N] tasks)      |
|                                                                  |
|  Sprint 3: [theme]                                               |
|            [planned_pts]/[AVAILABLE_POINTS] pts ([N] tasks)      |
|                                                                  |
|  Sprint 4: [theme]                                               |
|            [planned_pts]/[AVAILABLE_POINTS] pts ([N] tasks)      |
|                                                                  |
+----------------------------------------------------------------+
|  CRITICAL PATH                                                   |
+----------------------------------------------------------------+
|  [task_id] -> [task_id] -> [task_id] -> ... -> [task_id]        |
|  [critical_path_points] points | [critical_path_days] days      |
|                                                                  |
+----------------------------------------------------------------+
|  FILES                                                           |
+----------------------------------------------------------------+
|  Plan:   SPRINT_PLAN.md                                          |
|  Issues: [N issues created / "skipped (use --create-issues)"]   |
|                                                                  |
+----------------------------------------------------------------+
|  NEXT STEPS                                                      |
+----------------------------------------------------------------+
|  1. Review SPRINT_PLAN.md and adjust estimates                   |
|  2. Assign real developer names to Dev1, Dev2, Dev3              |
|  3. Start Sprint 1 with: /feature [task 1.1 description]        |
|  4. Track progress by updating Status column                    |
|  5. Run /sprint-plan again to re-plan after scope changes       |
|                                                                  |
+================================================================+
```

---

## Error Handling

Handle these cases gracefully:

```
CASE: No arguments provided
  → Display usage: "Usage: /sprint-plan <prd-file-or-description> [--sprints=4] [--team-size=3]"
  → List available PRD files in current directory

CASE: File path provided but file not found
  → Show error: "File not found: [path]"
  → Search for similar files: Glob for *.md, *PRD*, *requirements*
  → Suggest alternatives

CASE: Requirements too small (< 3 story points total)
  → Warn: "Requirements may be too small for sprint planning."
  → Suggest: "Consider using /feature for single-feature development."
  → Still generate the plan if user confirms

CASE: Requirements too large (> TOTAL_AVAILABLE points)
  → Warn: "Requirements exceed capacity for [SPRINTS] sprints."
  → Suggest increasing sprints: "--sprints=[calculated_needed]"
  → Suggest increasing team: "--team-size=[calculated_needed]"
  → Generate the plan anyway, marking overflow tasks as "Backlog"

CASE: Circular dependencies detected
  → Error: "Circular dependency detected: [task A] <-> [task B]"
  → Suggest resolution: "Remove dependency from [task] or split into sub-tasks"

CASE: GitHub issues requested but gh CLI not available
  → Warn: "GitHub CLI (gh) not found. Install from https://cli.github.com/"
  → Skip issue creation, generate SPRINT_PLAN.md only
```

---

## Tips for Best Results

```
HIGH-QUALITY INPUT = HIGH-QUALITY PLAN

Best inputs (in order of quality):
1. Full PRD with data models, API endpoints, and user flows
   → /gen-prd "your idea" first, then /sprint-plan ./PRD.md

2. Detailed feature list with acceptance criteria
   → /sprint-plan "User auth with JWT, CRUD for products, shopping cart, checkout with Razorpay, admin dashboard"

3. Brief description (will require more inference)
   → /sprint-plan "e-commerce platform for handmade crafts"

Combine with other commands:
  /gen-prd "your idea"              → Generate PRD
  /sprint-plan ./PRD.md             → Plan sprints from PRD
  /auto-build ./PRD.md              → Build autonomously following the plan
  /feature [task 1.1 description]   → Build one task at a time
```
