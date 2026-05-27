---
name: cortex-debugging
description: "MUST USE when encountering any bug, test failure, unexpected behavior, error log, exception, regression, or 'it doesn't work' report — BEFORE proposing any fix. Enforces systematic debugging: reproduce → isolate to a Cortex layer (api/services/repositories/models) → minimal failing case → root cause → fix at the right layer → regression test. Integrates with Cortex personas (Yuki for security bugs, Daan for payment bugs, Carlos for DB bugs, etc.). Skipping this leads to symptom-fixes that hide root causes and resurface a week later."
license: "Proprietary — Alpha AI Service Pvt Ltd"
compatibility: "Designed for Claude Code with cortex plugin"
metadata:
  author: "Alpha AI Service Pvt Ltd"
  version: "1.0"
---

# Cortex Debugging — Systematic, Layer-Aware, Persona-Driven

Most bugs are "fixed" at the wrong layer (e.g., catching an exception in the controller that should have been validated in the service). Cortex's enforced layer segregation gives debugging a structure: every bug lives in exactly one layer, and the fix belongs at that layer. This skill teaches HOW to find which layer.

The hardest part of debugging is resisting the urge to guess and patch. This skill enforces the discipline of proving the cause before applying the cure.

---

## When to use this skill

Always fire when:
- A test fails (any test, any framework)
- An exception or error is reported by the user
- A user says "it doesn't work", "broken", "weird behavior", "regression", "this used to work"
- A `/health-check` flags a degradation
- A scheduled run (security-scan, dep-update) reports an unexpected issue
- A subagent reports a build failure
- Production logs surface an exception

Skip ONLY when:
- The user says "ignore this, I'll fix it later" and asks for something unrelated
- The "bug" is a documentation typo (just fix it)

---

## The Cortex Debugging Loop

### Step 1 — Reproduce the bug LOCALLY first

You cannot fix what you can't reproduce. Before touching any code:

1. **Get the exact failing input** — exact request body, exact user action, exact CLI command
2. **Get the exact failing output** — stack trace, error message, observed vs expected
3. **Get the environment** — which branch, which deploy, which DB state, which env vars
4. **Reproduce locally** — run the exact thing and confirm the same failure

If you cannot reproduce locally:
- Add logging to the suspected paths and ship to staging
- Use the actual prod database (read-only replica) if data-dependent
- DO NOT fix a bug you can't reproduce. You'll fix the wrong thing.

### Step 2 — Isolate to a Cortex layer

Cortex's strict layer segregation gives you a debugging coordinate system. Walk DOWN through layers asking "is the bug here or below?":

```
Browser / mobile app  ───► Network ───► API controller ───► Service ───► Repository ───► Database
                                            (layer 1)       (layer 2)    (layer 3)        (layer 4)
                                              └── api/v1/      └── services/  └── repositories/   └── MySQL/Mongo/Redis
```

| Layer | Symptoms | How to check |
|-------|----------|--------------|
| Browser / mobile | UI shows wrong thing, button doesn't respond | DevTools → console + network tab |
| Network | Request never reaches backend, CORS error, timeout | DevTools network tab; backend access log |
| API controller (`api/v1/`) | 4xx/5xx response, wrong shape, missing field | Backend access log; curl the endpoint directly |
| Service (`services/`) | Wrong business logic outcome, wrong calculation | Unit-test the service in isolation with mocked repo |
| Repository (`repositories/`) | Query returns wrong data, N+1, missing index | Run the query directly against the DB; check query log |
| Database | Data is wrong, missing migration, constraint violated | `SELECT` directly; check migration history |

The bug lives in ONE layer. Layers below are working correctly; layers above are surfacing the same wrong data the buggy layer produced. **Fix at the layer where the bug originates, NOT at the layer that surfaced it.**

### Step 3 — Minimal failing case

Once you've isolated the layer, reduce the input to the smallest thing that still reproduces. Each removal is a hypothesis test:
- Remove this field → still fails? The field is irrelevant.
- Remove this row → still fails? The row is irrelevant.
- Remove this concurrent request → still fails? Not a race condition.

The minimal case is the test you'll add later (Step 6). It's also the proof you understand the bug.

### Step 4 — Form a hypothesis, then test it

Now and ONLY now form a hypothesis: "I think the bug is X because Y". Write it down (in chat or in a debug note).

Test the hypothesis with the smallest possible change that would either confirm or refute it (NOT with the final fix). For example:
- Hypothesis: "the cache is stale". Test: bypass cache, see if bug disappears.
- Hypothesis: "the index isn't used". Test: `EXPLAIN` the query.
- Hypothesis: "the JWT is expired". Test: log the JWT expiry vs server clock.

If the test confirms the hypothesis, proceed to Step 5. If it refutes, go back to Step 2 — the bug is in a different layer.

### Step 5 — Fix at the right layer

The fix goes at the LAYER where the bug originates, not at the convenient layer.

| Wrong fix | Right fix |
|-----------|-----------|
| Catch exception in controller | Validate input in service |
| Add `if/else` in controller for special case | Add the case to the service or repository |
| `try/except: pass` to silence error | Find the root cause; fix it |
| Round numbers in the frontend to hide a calculation bug | Fix the calculation in the service |
| Add a sleep to "fix" a race condition | Add a proper lock / use Redis SETNX / use DB transaction |
| Hardcode a value to bypass a config bug | Fix the config loading |

Pick the right layer. The Cortex persona system can help — different personas own different layers:

| Bug surface | Likely owning persona | Layer |
|-------------|----------------------|-------|
| Auth/security bug | Yuki Tanaka 🇯🇵 | Service or middleware |
| Payment bug | Daan van der Berg 🇳🇱 | Service + webhook handler |
| N+1 / slow query | Carlos Rivera 🇧🇷 | Repository |
| Missing model field / wrong constraint | Viktor Petrov 🇷🇺 | Model / migration |
| Wrong API response shape | Marcus Chen 🇺🇸 | Controller (api/v1/) |
| Frontend state desync | Jin-Ho Park 🇰🇷 | State layer (Zustand/TanStack Query) |
| Mobile crash | Rahul Nair 🇮🇳 | Navigation / native bridge |
| LLM hallucination | Hiroshi Nakamura 🇯🇵 | AI gateway + prompts |
| RAG retrieval miss | Zara Okonkwo 🇳🇬 | RAG indexing + re-ranking |

"Who would have written this code?" → that's who debugs it.

### Step 6 — Regression test BEFORE merging

Add the minimal failing case from Step 3 as a test. Run it WITHOUT your fix to confirm it fails. Apply the fix. Run again to confirm it passes. This test prevents the bug from coming back.

The regression test goes in the test file matching the buggy layer (not at the surface where the user observed it).

### Step 7 — Document the root cause

In the commit message (NOT a code comment), describe:
- What the symptom was
- What the actual root cause was
- Why the previous code looked right but wasn't
- What the fix changes and why this layer is correct

This is what makes future debugging fast for whoever inherits the code.

---

## Debugging anti-patterns (DO NOT DO)

- ❌ **Pattern-matching fixes from past bugs.** "This looks like that other bug; let me apply the same fix." Each bug is different until proven otherwise.
- ❌ **Fixing the symptom at the layer that observed it.** A controller `try/except` for a service bug. A `if (x == null) x = default` for a missing migration. Fix at the source.
- ❌ **Multiple "fix attempts" without isolating first.** Shotgun debugging — change 5 things, see if anything sticks. Loses the ability to know WHICH change fixed it.
- ❌ **Skipping the reproduce step.** "I think I see the problem" — no, you don't. Reproduce, then claim.
- ❌ **Disabling tests that fail "intermittently".** Intermittent = race condition or flaky test. Both are real bugs. Don't `.skip()` them.
- ❌ **Adding `sleep()` or retries to mask races.** If two things racing produces wrong output, the lock is missing or the design is wrong.
- ❌ **Catch-and-ignore (`try: ... except: pass`).** This hides every future bug at that line. Catch SPECIFIC exceptions; rethrow or log everything else.
- ❌ **Fixing without a regression test.** The bug will come back. Add the test.
- ❌ **Trusting your gut over `EXPLAIN`, profiler output, or stack traces.** Measure, don't guess.
- ❌ **Debugging in production.** Reproduce locally first. If you can't, instrument, reproduce in staging, then fix.

---

## Tooling per language

| Language | Interactive debugger | Profiler | Trace |
|----------|---------------------|----------|-------|
| Python | `pdb` / `ipdb` / VS Code Python debugger | `py-spy` / `cProfile` | structlog with `request_id` |
| Node.js / NestJS | `node --inspect` + Chrome DevTools / VS Code | `clinic.js` / 0x | pino with `requestId` |
| Java / Spring Boot | jdb / IntelliJ debugger | YourKit / async-profiler | Logback MDC with `traceId` |
| Next.js | Chrome DevTools + React DevTools | Lighthouse / `next build --profile` | sentry breadcrumbs |
| React Native | Flipper + Hermes profiler | Hermes inspector | sentry breadcrumbs |

When a Cortex persona spawns to debug, the prompt MUST include the language so the persona picks the right tools. "Yuki, debug this auth bug in NestJS" → Yuki uses `node --inspect`, not `pdb`.

---

## When debugging escalates

Escalate when:
- You've spent 2+ hours and the minimal failing case is still not isolated → spawn a parallel debug agent with a fresh perspective
- The bug is intermittent in production but never reproduces locally → it's a concurrency or data-shape issue; check production data with read-only access
- The bug involves multiple services / network boundaries → use distributed tracing (Sentry / Langfuse for AI flows)
- The bug crosses the Cortex/external-service boundary (e.g., Razorpay webhook, Google OAuth callback) → check the EXTERNAL side first (their logs, their dashboard) before suspecting your code

Don't sit on a bug. Two hours stuck = ask for a fresh pair of eyes.

---

## Integration with Cortex commands

- `/debug` — uses this skill to drive its workflow. The command is the entry point; this skill is the method.
- `/self-healer` agent — when `/auto-build` hits a build failure, the self-healer uses this skill's loop autonomously.
- `cortex-tdd` — the regression test from Step 6 follows TDD discipline.
- `cortex-verification` — the regression test is part of the verification gate that proves "done".
- `/code-review` — flags symptom-fixes (try/except: pass, hardcoded bypasses) per this skill's anti-patterns.
