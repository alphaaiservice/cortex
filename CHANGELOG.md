# Changelog

All notable changes to the Cortex plugin are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.1] — 2026-05-27

### Fixed

- **`task-completed-quality-gate.sh` secrets check now actually fires.**
  The hook surfaced in v1.1.2 carried a latent bug from the original
  inline-bash version: the secrets check used `grep -q | grep -q` to
  detect "lines matching secret keywords NOT in safe context", but `-q`
  suppresses stdout, so the second grep received no input and the
  check silently never fired. The hook was rejecting TODO/FIXME and
  skipped tests correctly, but hardcoded secrets passed through.

  Replaced with a proper two-pass filter:
  1. Find candidate lines matching `password`, `secret`, or `api[._-]?key`
  2. Filter out lines in obviously safe contexts: `.env`, `.example`,
     `example.`, `config.`, `template`, `placeholder`, `TODO`, `FIXME`,
     `<your-`, `YOUR_`, `${...}` interpolation, `process.env`,
     `os.environ`, `os.getenv`, `System.getenv`
  3. If any candidate lines remain, flag as a quality gate failure.

  Verified with 6 test scenarios:
  - Clean output → exit 0
  - TODO marker → exit 2 (existing check, still works)
  - Hardcoded `const password = "hunter2"` → exit 2 (the fix)
  - `const password = process.env.DB_PASSWORD` → exit 0 (safe ctx)
  - Reference to `.env.example` → exit 0 (safe ctx)
  - Hardcoded `api_key = "sk-..."` → exit 2 (fix catches snake_case too)

  Removed the "KNOWN ISSUE" annotation from the script header — the
  issue is now resolved.

## [1.3.0] — 2026-05-27

### Added — Cortex can now scaffold MCP servers and Claude plugins

Closes two structural gaps a user surfaced: Cortex previously had zero
support for building standalone MCP servers or Claude Code plugins. It
covered MCP only as an embedded standard inside auto-built apps; it
covered plugins not at all. Cortex now self-bootstraps both project
types — eating its own dogfood for plugin development.

**New commands (2):**
- **`/init-mcp-server`** — scaffold a standalone MCP server project.
  Supports `--lang=python` (official `mcp` SDK) or `--lang=typescript`
  (`@modelcontextprotocol/sdk`). Transports: stdio (default), http,
  sse. Flags for `--with-tools`, `--with-prompts`, `--with-resources`.
  Generates complete project with pyproject.toml/package.json, server
  skeleton, example primitives, in-memory test client, README with
  Claude Desktop + Claude Code config snippets, GitHub Actions, and
  publishing instructions for PyPI/npm.
  Distinguishes standalone MCP servers (this command) from embedded
  ones (use /auto-build or /retrofit for those — they live inside the
  host app under `app/ai/mcp/`).

- **`/init-claude-plugin`** — scaffold a Claude Code plugin with
  Cortex's own structure as the template. Flags: `--with-commands`,
  `--with-agents`, `--with-skills`, `--with-hooks`, `--with-mcp`.
  Generates: .claude-plugin/{plugin.json,marketplace.json}, optional
  commands/agents/skills directories with starter files, hooks.json
  with extracted scripts (never inline bash), a port of Cortex's own
  validate-plugin.sh (Section 9 of CODE_PATTERNS_CLAUDE_PLUGIN), CI
  workflow, CHANGELOG.md, README.md, LICENSE, CLAUDE.md context doc.
  Bakes in every lesson Cortex itself learned through v1.0 → v1.2.

**New reference docs (2):**
- `skills/alpha-architecture/references/CODE_PATTERNS_MCP_SERVER.md`
  — 10 sections covering MCP overview, Python + TypeScript server
  skeletons, tools/prompts/resources patterns, transport (stdio/http/
  sse), in-memory testing pattern, error handling, README template,
  distribution (PyPI/npm/uvx/npx). Includes complete working code
  for every section.
- `skills/alpha-architecture/references/CODE_PATTERNS_CLAUDE_PLUGIN.md`
  — 11 sections covering plugin structure, plugin.json schema,
  command/agent/skill authoring, skill trigger-phrase discipline
  (the "trigger phrase recipe" — the single most important section
  for skill authors), hook event matrix for all 8 events, DRY ref
  doc pattern, worktree safety pattern, validator port, versioning/
  CHANGELOG discipline, marketplace distribution. Every anti-pattern
  is a mistake Cortex itself made and fixed — citations to the v1.1.x
  commits that fixed each one.

### Changed

- plugin.json + marketplace.json description: 45 → 47 commands, 14 →
  16 reference docs, "scaffolders for apps, standalone MCP servers,
  and Claude Code plugins themselves" added to value proposition.
- CLAUDE.md: added the two new commands under the Project Setup
  section of the directory tree.
- plugin.json + marketplace.json bumped 1.2.0 → 1.3.0 (MINOR — new
  public commands).

## [1.2.0] — 2026-05-27

### Added — 5 meta-process skills (Cortex is now self-contained)

Cortex used to rely on the external Superpowers plugin for meta-process
(brainstorming, planning, TDD, debugging, verification). It now ships
its own Cortex-flavored versions, integrated with FEATURE_PROFILE,
language detection, the persona system, and the alpha-architecture
layer rules.

- **`cortex-brainstorming`** — fires before any new feature/product
  work. Walks 5 questions (audience, core action, FEATURE_PROFILE,
  out-of-scope, persona ownership) and writes BRAINSTORM.md as the
  input contract for /gen-prd, /init-project, /auto-build, /retrofit,
  /ai-upgrade.
- **`cortex-planning`** — fires before any multi-step implementation
  (3+ files, 30+ min, multi-layer, or hard-to-reverse). Produces
  PLAN.md with affected Cortex layers, build order, verification
  gates, risks/rollback, and persona ownership. Compatible with
  AUTO_BUILD_STATE.json for ingestion by /auto-build.
- **`cortex-tdd`** — fires before writing any implementation code.
  Enforces red→green→refactor using the project's language-specific
  framework (pytest+pytest-asyncio | Jest+supertest | JUnit 5+Mockito).
  Includes per-layer test patterns and Cortex persona delegation
  templates. Documents the ONE exception (genuine spike, marked and
  deleted before merge).
- **`cortex-debugging`** — fires on any bug/failure/regression BEFORE
  proposing a fix. Enforces the systematic loop: reproduce → isolate
  to layer → minimal failing case → hypothesis test → fix at right
  layer → regression test → root-cause commit message. Maps bug
  surfaces to owning personas (Yuki for auth, Daan for payments,
  Carlos for DB, Hiroshi for LLM, Zara for RAG, etc.).
- **`cortex-verification`** — fires before any "done/fixed/complete"
  claim. Runs the language-specific verify suite (ruff+mypy+pytest
  with --cov-fail-under=80 | pnpm lint+tsc+test+coverage | gradle
  checkstyle+spotbugs+test+jacoco), captures exit codes, requires
  boot smoke test, requires manual UI smoke for frontend changes,
  and mandates printing evidence in the completion message.

Why these were added: a user observed Claude pulling in Superpowers
skills (brainstorming, writing-plans, TDD, systematic-debugging,
verification-before-completion) when running Cortex commands, because
Superpowers' aggressive trigger descriptions win the trigger-match
race over Cortex's domain-specific skills. The 5 new skills cover
the same meta-process layer but with Cortex-flavored bodies that
know about FEATURE_PROFILE, layer segregation, language detection,
and the persona roster. Users can now uninstall Superpowers if they
want a fully self-contained Cortex.

### Changed

- plugin.json description: skill count corrected 14 → 19, added
  self-contained note.
- marketplace.json description: same.
- plugin.json + marketplace.json bumped 1.1.7 → 1.2.0 (MINOR — new
  public skills added).

## [1.1.7] — 2026-05-27

### Added

- **Model-aware context strategy in `/auto-build`.** The CONTEXT
  MANAGEMENT section's strict "never write code in main context"
  rule was designed for 200K context windows and is counterproductive
  on Opus 4.7 / Sonnet 4.6 with the `[1m]` suffix (1M tokens).

  New "Model-Aware Strategy" sub-section adds three tiers:
  - **1M context (Opus 4.7+ `[1m]`)**: relaxed delegation. Inline
    single-file phases (≤300 LoC output). Group adjacent small
    phases into one subagent — Phase 6 Auth + 6.5 Payments + 6.8
    Upload can now be one subagent on 1M models (they were split
    for context budget, not logical separation).
  - **200K context** (default Opus/Sonnet): strict delegation
    (existing rules 1-7, unchanged).
  - **Haiku / smaller models**: aggressive delegation, subdivide
    phases into ~5-file subagents, checkpoint to git after every
    sub-step.

  Includes guidance on what compaction checkpoints look like on
  1M models (sparser, often not triggered at all for sub-2-hour
  builds — that's expected and fine; the Stop hook is the real
  autonomy mechanism).

  Default behavior preserved: when in doubt, behave as if on 200K.
  The relaxed 1M strategy is opt-in based on detected model.

## [1.1.6] — 2026-05-27

### Added

- **`/loop` integration as a complementary autonomy mechanism.**
  Documents when to use Claude Code's built-in `/loop` skill versus
  the existing shell-level `scripts/auto-loop.sh`. They are
  complementary, not substitutes — kept both rather than replacing.

  - `commands/auto-build.md`: new "Execution Mode" comparison table
    inside the AUTONOMOUS EXECUTION ENGINE section. Three options
    documented with their resilience characteristics and "best for"
    use cases:
    1. `scripts/auto-loop.sh` (most resilient — outside Claude,
       survives crashes, has circuit breaker + backoff)
    2. `/loop` (in-session — survives compaction via PreCompact hook
       + Stop hook, lighter weight)
    3. Stop hook only (minimal — relies entirely on in-Claude loop)
  - `commands/deploy.md`: new "Live Polling Mode" section showing
    `/loop 30s /deploy --status-only` for watching a deploy without
    refreshing manually.
  - `commands/perf-test.md`: new "Live Polling Mode" section for
    in-session progress reports during long stress tests.

  Recommendation in auto-build: use shell `auto-loop.sh` for any
  build you'd be sad to lose if Claude crashed; use `/loop` for
  everything else.

## [1.1.5] — 2026-05-27

### Added

- **Plugin CI: structure + manifest validator.** New
  `scripts/validate-plugin.sh` runs 10 checks against the plugin
  structure, manifests, and content. Catches the regressions most
  likely to bite us in future:

  1. `plugin.json` is valid JSON + has required fields (name, version,
     description, author).
  2. `marketplace.json` is valid JSON + plugin version matches
     `plugin.json` (the exact bug present in v1.0.0 before this work).
  3. `hooks/hooks.json` is valid JSON + every referenced script exists
     and is executable.
  4. Every `commands/*.md` has `frontmatter.description`.
  5. Every `skills/*/SKILL.md` has `name` + `description`.
  6. Every `agents/*.md` has `description`.
  7. Every cited `commands/references/*.md` path resolves to a real
     file (no broken refs from the v1.1.1/v1.1.3 DRY refactors).
  8. Every cited `skills/*/references/*.md` path resolves.
  9. No stale `*.backup` / `*.bak` / `*.old` files in the tree (the
     exact category we cleaned up in v1.1.0).
  10. All `scripts/*.sh` are executable.

  Run locally with `bash scripts/validate-plugin.sh` before any commit
  to the plugin. Color-coded output, exits 1 on any failure with a
  summary of issues.

- **GitHub Actions workflow.** `.github/workflows/validate-plugin.yml`
  runs the validator on every push to `main` and every PR. Catches
  regressions before they're merged.

Current state passes all 23 checks (46 commands, 14 skills, 13 agents,
7 hook scripts, 2 reference docs verified).

## [1.1.4] — 2026-05-27

### Added

- **Scheduled execution guidance for recurring-value commands.**
  `/dep-update`, `/security-scan`, `/health-check`, and `/backup-dr`
  each have a new "Scheduled Execution" section that recommends:

  1. Per-command cadence tables (e.g., security-scan: nightly fast pass
     + weekly deep scan; dep-update: weekly Monday with `--patch-only`;
     health-check: daily 06:00; backup-dr: quarterly drift detection
     plus the generated backup scripts run daily/weekly).
  2. Three scheduling options: Claude Code `/schedule` skill
     (recommended), OS-level cron with one-shot Claude CLI invocation,
     and CI/CD hooks for pre-release scans / pre-push health checks.
  3. Mandatory hygiene rules for scheduled runs — always alert on
     failure, never auto-fix on schedule, always log to
     `.cortex/scheduled-<command>.log` for audit.

  This makes cortex's "ongoing maintenance" surface actionable instead
  of theoretical. Users can now move from "I'll run /security-scan
  before each release" to "I get a Slack alert if last night's CVE
  scan found anything HIGH+" with a single `/schedule` invocation.

## [1.1.3] — 2026-05-27

### Added

- **Worktree-safety preamble for risky file-mutation commands.**
  `/migrate-stack`, `/refactor`, and `/retrofit` now have a mandatory
  Step 0 that runs a safety decision tree before any `Write`/`Edit`/`Bash`
  mutation. The default execution mode for all three is now an isolated
  git worktree (either via `Agent({ isolation: "worktree" })` when
  delegating, or a manual `git worktree add` when running inline).
  This protects the user's main checkout from botched runs.

  New canonical reference: `commands/references/WORKTREE_SAFETY.md`
  defines the decision tree. Each of the 3 commands cites it with a
  short summary inline (DRY pattern matching `AUTO_BUILD_STACK.md`).

  Per-command nuances:
  - `/migrate-stack` — isolated worktree is non-negotiable for
    migrations rated 🟡 Medium / 🔴 Large / ⚫ XL. Current-checkout
    mode is only offered for trivial swaps like flake8→ruff.
  - `/refactor` — existing "Pre-Flight Validation" renamed to Step 0.5;
    new Step 0 handles worktree decision first.
  - `/retrofit` — current-checkout only acceptable for a single small
    feature. `--all` and `--from-gap-analysis` force isolated worktree.

  All three refuse to proceed when there's no git repository at all.

## [1.1.2] — 2026-05-27

### Changed

- **Extracted inline bash from `hooks/hooks.json` into proper scripts.**
  The 300+ char one-liners in PostToolUse (Write + Edit), PreCompact,
  TeammateIdle, and TaskCompleted were unreadable and untestable.
  Each is now a real `scripts/*.sh` file with a shebang, header
  comment, and consistent style matching the existing
  `safe-bash-check.sh` / `session-context.sh` / `auto-build-stop-hook.sh`.
  Behavior is identical — this is a pure refactor.

  New scripts:
  - `scripts/auto-format.sh` — PostToolUse hook for Write and Edit.
    Picks ruff/black for Python, prettier for JS/TS, google-java-format
    for Java. Both Write and Edit now invoke the same script (was
    duplicated inline before).
  - `scripts/precompact-checkpoint.sh` — PreCompact hook. Backs up
    `AUTO_BUILD_STATE.json` and auto-commits dirty changes before
    context compaction so `/auto-build` can resume cleanly.
  - `scripts/teammate-idle-reassign.sh` — TeammateIdle hook (Agent Teams).
    Reads pending tasks from `~/.claude/tasks/<team>` and exits 2 when
    work remains.
  - `scripts/task-completed-quality-gate.sh` — TaskCompleted hook
    (Agent Teams). Rejects task output containing unresolved TODO/FIXME
    markers, skipped tests, or (intended) hardcoded secrets.

  `hooks/hooks.json` shrank from 5.9 KB to 2.3 KB (~60% smaller).

### Known Issues

- `task-completed-quality-gate.sh` preserves a latent bug from the
  original inline hook: the hardcoded-secrets check pipes two `grep -q`
  invocations together, and `-q` suppresses stdout, so the second grep
  receives no input and the check never fires. Preserved verbatim in
  this refactor so behavior is unchanged. Annotated with a `KNOWN ISSUE`
  comment in the script; fix in a follow-up if you want secrets
  rejection to actually trigger.

## [1.1.1] — 2026-05-27

### Changed

- **Tech stack now has a single source of truth.** `commands/references/AUTO_BUILD_STACK.md`
  is canonical. The 4 consumers (`commands/auto-build.md`,
  `skills/alpha-architecture/SKILL.md`, `commands/init-project.md`,
  `commands/gen-prd.md`) now reference it instead of duplicating stack
  content inline. Removes ~234 lines of duplication and eliminates the
  "keep 4 files in sync" maintenance burden flagged in CLAUDE.md note #7.

  - `commands/gen-prd.md`: Tech Stack section shrank from 253 lines of
    duplicated tables to a 40-line instruction telling the agent which
    sections of AUTO_BUILD_STACK.md to copy based on FEATURE_PROFILE.
  - `skills/alpha-architecture/SKILL.md`: 92-line Tech Stack tables
    replaced with a terse enforcement summary that defers to
    AUTO_BUILD_STACK.md for the technology catalog (progressive disclosure
    pattern, matching how alpha-architecture already uses references for
    code patterns).
  - `commands/init-project.md`: Stack Configuration now covers only
    init-time scaffolding decisions (which directories to skip when a
    feature is out of scope), consulting AUTO_BUILD_STACK.md for actual
    library names and versions.
  - `CLAUDE.md`: Notes #7 and #275 updated to document the new SOT and
    instruct future modifications to happen in AUTO_BUILD_STACK.md only.

## [1.1.0] — 2026-05-27

### Added

**Analysis & Intelligence commands (5)**
- `/suggest-ai-features` — scans an existing codebase and recommends where AI/ML
  can add value, producing a prioritized `AI_ENHANCEMENT_PLAN.md`.
- `/ai-upgrade` — implementation counterpart to `/suggest-ai-features`; adds
  AI capabilities to a single named feature (search, metrics, catalog, ...).
- `/trace-impact` — full-stack blast-radius analysis for a proposed change
  (DB → service → API → frontend) with severity-tagged migration plan.
- `/estimate-cost` — projects infra + API costs at 100 / 1K / 10K / 100K users
  and compares service alternatives (Stripe vs Razorpay, GPT-4 vs Claude, etc).
- `/feature-map` — builds a visual feature-dependency map of the codebase
  as a Mermaid diagram.

**Subagents (2)**
- `feature-analyzer` (Priya Sharma) — dissects existing codebases, maps
  features to code, surfaces architectural patterns and anti-patterns.
- `ai-integration-specialist` (Marcus Chen) — designs and implements LLM
  integration, vector search, semantic analysis with cost awareness.

**Auto-invoked skills (5)**
- `cost-estimator` — triggers on cost / pricing / budget questions.
- `dependency-mapper` — triggers on architecture / coupling / refactor planning.
- `feature-impact-analysis` — triggers on schema changes, migrations, deprecations.
- `metric-recommender` — triggers on monitoring / KPI / observability planning.
- `smart-retrofit` — triggers on "add AI to X" / "make X smarter" requests.

**Reference documentation (2)**
- `skills/alpha-architecture/references/CODE_PATTERNS_GENAI.md` — GenAI code
  patterns (LiteLLM, agent frameworks, structured output, evaluation).
- `skills/alpha-architecture/references/RAG_BEST_PRACTICES.md` — RAG pipeline
  best practices (chunking, embeddings, re-ranking, agentic retrieval).

**Auto-build phases**
- Phase 9l — Frontend Smoke Tests (Vitest + React Testing Library + Playwright)
  now MANDATORY for every web frontend.
- Phase 9.6 — Chrome Extension Build + Smoke Tests (MV3, conditional on PRD).
- Phase 10 — Analytics + Feature Flags + Growth split out as a discrete phase.
- Phase 12 — Security + Compliance + Polish elevated to a named phase.

**Agent Teams hooks (experimental)**
- `TeammateIdle` — reassigns pending tasks to idle teammates (exit code 2
  keeps them working).
- `TaskCompleted` — quality gate that rejects task output containing
  unresolved TODO/FIXME markers, skipped tests, or hardcoded secrets.

**Plugin manifest**
- `plugin.json` now carries `homepage`, `repository`, `license`, `category`,
  `keywords`, and `tags` for richer marketplace cards.

### Changed

- `auto-build.md` phase outline updated to reflect the reorganized 15-phase
  flow (Phase 9l smoke tests, 9.6 Chrome extension, 10 analytics, 12 security).
- `marketplace.json` plugin description corrected: `14 skills, 7 hooks`
  (previously stale at `9 skills, 6 hooks`).
- `plugin.json` description corrected: `14 skills, 7 hooks, 14 reference docs`
  (previously stale at `9 skills, 6 hooks`).

### Removed

- `commands/auto-build.md.backup` (288 KB stale snapshot from 2026-03-01 that
  was shipping to every install).

## [1.0.0] — 2026-02-22

Initial release of Cortex (renamed from AlphaForge).

- 37 slash commands covering planning, scaffolding, building, quality,
  shipping, and DevOps for Python/FastAPI, Node.js/NestJS, and Java/Spring Boot.
- 11 specialized subagents (architect, brand-designer, security-auditor,
  onboarding-mentor, test-strategist, parallel-builder, self-healer,
  db-optimizer, devops-engineer, performance-profiler, documentation-writer).
- 9 auto-invoked skills (alpha-architecture + project-setup, onboarding,
  code-review, testing, deployment, security, devops, performance).
- 6 hooks (PreToolUse safety check, SessionStart context, PostToolUse
  formatter for Write + Edit, Stop autonomy loop, PreCompact checkpoint).
- 4 DevOps commands added late-cycle: `/backup-dr`, `/env-sync`,
  `/feature-flags`, `/audit-setup`.
- Full autonomy: PreCompact hook, auto-resume, state recovery, stall detection.
