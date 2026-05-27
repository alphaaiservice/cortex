# Changelog

All notable changes to the Cortex plugin are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
