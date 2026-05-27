---
name: cortex-verification
description: "MUST USE before claiming any work is 'done', 'fixed', 'complete', 'passing', 'shipped', or 'ready' — including before /ship, before opening a PR, before merging, and before reporting task completion to the user. Enforces evidence-before-assertion: run the language-specific verify commands (ruff+mypy+pytest | ESLint+TypeScript+Jest | Checkstyle+JUnit5), capture the output, and only claim done if the output is green. Skipping this leads to 'I think it works' regressions and false-positive ship reports."
license: "Proprietary — Alpha AI Service Pvt Ltd"
compatibility: "Designed for Claude Code with cortex plugin"
metadata:
  author: "Alpha AI Service Pvt Ltd"
  version: "1.0"
---

# Cortex Verification — Evidence Before Assertion

Every "it works" claim must be backed by command output proving it works. Every "the bug is fixed" claim must be backed by a previously-failing test now passing. Every "the build is green" claim must be backed by a green build log. No exceptions.

This skill is the discipline that turns Cortex from "Claude wrote some code" into "Cortex shipped verified code". It is the last gate before any user-visible completion claim.

---

## When to use this skill

Always fire BEFORE:
- Saying "done", "complete", "fixed", "ready", "shipped", "merged", "passing"
- Running `/ship` (which runs lint + test + commit + push + PR)
- Running `/deploy`
- Closing a task in `AUTO_BUILD_STATE.json`
- Reporting "Phase N complete" in `/auto-build`
- Opening a PR
- Telling the user any task succeeded

Skip ONLY when:
- The work is genuinely just documentation (README, CHANGELOG, comments only) AND no code/config was touched
- Explicit user opt-out: "skip verification, I'll run it" (rare — only honor when the user is actively monitoring)

When in doubt, verify. The cost of running tests is seconds; the cost of a false-positive ship claim is hours of debugging in prod.

---

## The Verification Checklist

The exact commands depend on the project's language (use Step 0a from alpha-architecture to detect). Run ALL applicable checks and capture the output verbatim.

### Backend — Python / FastAPI

```bash
# 1. Linter (must be silent)
ruff check . && ruff format --check .

# 2. Type checker (must be clean)
mypy app/ --strict

# 3. Unit + integration tests (must all pass)
pytest tests/ -v --tb=short

# 4. Coverage (must be ≥80% overall, ≥95% on critical paths)
pytest --cov=app --cov-report=term-missing --cov-fail-under=80

# 5. Boot smoke test (app starts without exceptions)
timeout 5 uvicorn app.main:app --host 0.0.0.0 --port 8000 &
SERVER_PID=$!
sleep 2
curl -fsS http://localhost:8000/health || { kill $SERVER_PID; exit 1; }
kill $SERVER_PID 2>/dev/null || true
```

### Backend — Node.js / NestJS

```bash
# 1. Linter
pnpm lint

# 2. Type check (TypeScript)
pnpm exec tsc --noEmit

# 3. Tests
pnpm test -- --coverage --coverageThreshold='{"global":{"branches":80,"functions":80,"lines":80}}'

# 4. Boot smoke test
timeout 5 pnpm start:dev &
SERVER_PID=$!
sleep 3
curl -fsS http://localhost:3000/health || { kill $SERVER_PID; exit 1; }
kill $SERVER_PID 2>/dev/null || true
```

### Backend — Java / Spring Boot

```bash
# 1. Linter + style
./gradlew checkstyleMain spotbugsMain

# 2. Compile + tests (compilation is the type check for Java)
./gradlew clean build

# 3. Coverage report
./gradlew jacocoTestReport jacocoTestCoverageVerification

# 4. Boot smoke test
./gradlew bootRun &
SERVER_PID=$!
sleep 10
curl -fsS http://localhost:8080/actuator/health || { kill $SERVER_PID; exit 1; }
kill $SERVER_PID 2>/dev/null || true
```

### Frontend — Next.js

```bash
# 1. Linter
pnpm lint

# 2. Type check
pnpm exec tsc --noEmit

# 3. Tests (Vitest + RTL)
pnpm test -- --coverage

# 4. Build (catches build-time errors)
pnpm build

# 5. Smoke (page renders without error)
pnpm exec playwright test tests/smoke/
```

### Mobile — React Native + Expo

```bash
# 1. Linter
pnpm lint

# 2. Type check
pnpm exec tsc --noEmit

# 3. Tests
pnpm test -- --coverage

# 4. EAS build (preview profile) — catches native-build errors
eas build --profile preview --platform all --non-interactive --no-wait
```

### Database / Migrations

If any migration was added or changed:

```bash
# Python / Alembic
alembic upgrade head && alembic downgrade -1 && alembic upgrade head

# NestJS / Prisma
pnpm exec prisma migrate deploy && pnpm exec prisma migrate reset --force --skip-seed

# Spring Boot / Flyway
./gradlew flywayMigrate flywayInfo
```

Run UP then DOWN then UP again — proves the migration is reversible.

---

## The Cortex Verification Rules

### Rule 1 — Capture exit codes, not vibes

Every verification step has an exit code. The check passes ONLY if exit code is 0. Do NOT eyeball log output and say "looks fine". The exit code is the truth.

```bash
ruff check .
if [ $? -eq 0 ]; then echo "✓ linter clean"; else echo "✗ linter FAILED"; exit 1; fi
```

### Rule 2 — Run the FULL suite, not just the file you touched

A change to one service can break tests in another. `pytest tests/test_my_service.py` is not verification — it's a checkpoint. The real verification is `pytest tests/`.

### Rule 3 — Coverage isn't quality, but uncovered code is suspect

If your change brought coverage DOWN, you added untested code paths. Either add tests or document why (e.g., a `pragma: no cover` with a comment explaining).

### Rule 4 — Boot smoke test is non-optional

A green test suite doesn't prove the app starts. `uvicorn` / `pnpm start` / `./gradlew bootRun` for 5 seconds + a `/health` curl proves the app boots. Many bugs (missing env var, circular import, port conflict) only surface here.

### Rule 5 — Manual smoke for UI changes

For ANY frontend change, the verification includes a manual visual check. Use the `chrome-devtools` or `claude-in-chrome` skill to open the page, take a screenshot, and confirm the change looks right. Type checks + tests don't catch "the button is invisible" or "the text overflows".

### Rule 6 — Print the evidence in your final message

When you tell the user "done" or report a task complete, include the verification output (or at minimum the exit-code summary). Example:

```
✓ Phase 5 complete.
  • ruff check . — 0 issues
  • mypy app/ --strict — Success: no issues found in 47 source files
  • pytest tests/ -v — 124 passed in 8.32s
  • coverage — 87% (target: 80%)
  • boot smoke — GET /health returned 200 in 1.8s
```

The user must SEE the evidence, not be told it exists.

### Rule 7 — Failing verification is NOT "almost done"

If any check fails, the task is NOT done. Do NOT say "tests pass except for one that I think is flaky" — fix the flake or convince yourself it's actually flaky with 10 reruns, then file a separate ticket. The bar is binary: green or not done.

---

## Anti-patterns (DO NOT DO)

- ❌ **Claiming "done" without running tests.** "I made the change, should be good." NO. Run the verification.
- ❌ **Running only the new test, not the suite.** New test green ≠ no regressions.
- ❌ **Reporting "tests pass" when 1 is skipped.** Skipped tests are red flags, not green checks.
- ❌ **`--no-verify` on git commit/push.** This bypasses pre-commit hooks for a reason — verify locally first instead.
- ❌ **Trusting "it builds" as verification.** Build success ≠ correct behavior.
- ❌ **Saying "the test I'd write would pass" instead of writing it.** Write it. Run it.
- ❌ **Verifying after pushing.** Verify BEFORE pushing. A failing push contaminates CI for the team.
- ❌ **Vague success language.** "I think it works", "should be fine", "looks correct" — these are not verification. Run the commands and quote the output.
- ❌ **Verifying once, then making more changes, then claiming done without re-verifying.** Every change requires a fresh verification.
- ❌ **Verification by reading the code.** Reading is not running. Run the verification.

---

## Verification for autonomous loops

When `/auto-build` is running unattended:
- Verification runs at the end of EVERY phase, captured in `AUTO_BUILD_STATE.json`
- If verification fails, the self-healer agent attempts up to 3 fixes (using `cortex-debugging`)
- After 3 failed self-heals, the phase is marked `blocked` and logged for human review
- Verification output is appended to `.cortex/logs/phase-N-verify.log` for audit
- The `Stop` hook (`auto-build-stop-hook.sh`) refuses to let Claude exit until verification on the current phase passes

This is non-negotiable. An autonomous loop without verification gates becomes an autonomous loop that ships broken code at scale.

---

## Integration with other Cortex skills + commands

- `cortex-brainstorming` → produces FEATURE_PROFILE → drives which verification commands apply
- `cortex-planning` → declares verification gates in `PLAN.md` → this skill runs them
- `cortex-tdd` → produces the tests → this skill runs them as part of the gate
- `cortex-debugging` → fix → this skill verifies the fix actually worked
- `/ship` — calls this skill before commit/push/PR
- `/health-check` — uses a subset of verification commands for a fast pulse check
- `/code-review` — flags PRs where the description claims "tested" but CI shows failures
- `/auto-build` Phase N — runs verification at end of every phase, gates progress to N+1
