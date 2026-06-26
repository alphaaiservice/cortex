# Auto-Build Reference: Workflow Mode — Native Claude Code Workflows

> **This file is referenced by `/auto-build` and `/resume-build`.**
> Loaded when `$ARGUMENTS` contains the **`--workflow`** flag (see auto-build PHASE 0.5).
> It explains how to orchestrate the entire build as a single deterministic **Workflow**
> script via the `Workflow` tool — instead of the interactive Agent-Teams / sequential loop.

---

## When to use Workflow mode (vs Agent Teams)

| | **Workflow mode** (`--workflow`) | **Agent Teams** (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) |
|---|---|---|
| Control flow | **Deterministic script** (loops, conditionals, fan-out) | Reactive — lead coordinates turn-by-turn |
| Intermediate results | Live in **script variables** (not the context window) | Live in the conversation / task board |
| Run location | **Background**, returns a task id; notifies on completion | In-session, lead steers as it runs |
| Resumable | **Yes** — longest unchanged prefix of `agent()` calls is cached | Reconnect to team + task list |
| Mid-run human/lead steering | **No** (only pauses on permission prompts) | **Yes** — catch races, reroute bugs, judgment calls |
| Best for | **Large, unattended, batch builds**; CI; "fire and forget" | Guided builds where a lead reacts to what happens |

**Pick Workflow mode when nobody is watching the build.** Because there's no lead to catch a
mid-run problem, the script MUST bake in its own quality gates (adversarial verify + a hard
test gate — see §4). Ecosystem note: this same primitive will later power autonomous **Tempest**
test-runs and **GraphMind** ingestion, so the orchestration you write here generalizes.

---

## 1. The Workflow primitive (what you'll author)

You call the **`Workflow`** tool with an inline `script` (plain JavaScript, NOT TypeScript).
Every script starts with a pure-literal `meta`, then a body using these hooks:

- `phase(title)` — start a phase; subsequent `agent()` calls group under it.
- `agent(prompt, opts?)` — spawn a subagent. `opts`: `{label, phase, schema, model, isolation:'worktree', agentType}`.
  With `schema` (a JSON Schema) the agent returns a validated object; without, it returns text.
  Returns `null` if the agent dies — `.filter(Boolean)` before use.
- `pipeline(items, stage1, stage2, …)` — run each item through all stages independently (no barrier between stages). **Default for multi-stage work.**
- `parallel(thunks)` — run thunks concurrently; **barrier** (awaits all). A thrown thunk → `null`.
- `log(message)` — progress line to the user.
- `args` — the value passed as the Workflow tool's `args` (use it to pass the SPEC path + FEATURE_PROFILE).
- `budget` — token target (`budget.total`, `budget.remaining()`); scale fleet/loops to it.
- Concurrency is capped (~min(16, cores-2)); a single `parallel`/`pipeline` accepts ≤4096 items.

**File-collision rule (critical for a single build dir):** agents writing the SAME files in
parallel will clobber each other. So: **phases are sequential** (each depends on the prior),
and you only `parallel()` WITHIN a phase across **non-overlapping domains/dirs** (e.g.
`auth_service.py` ∥ `ingest_service.py`). If two agents must touch the same files, either
sequence them or give each `isolation:'worktree'` and merge after.

---

## 2. Map the build phases → a Workflow script

Read the SPEC + the FEATURE_PROFILE (from `/gen-prd`) and **include only the phases the product needs**
(skip Frontend if no UI, skip AI if no GenAI, etc.). Canonical phase order (dependency-correct):

```
Scaffold → DB/Models → Repos → Services → Auth → API → [Frontend ∥ Mobile] → Analytics → Tests → Security → Docs → CI/CD → Verify
```

Each phase is one or more `agent()` calls. Cross-phase dependencies are expressed by sequencing
(await the prior phase before starting the next). Within a phase, fan out across clean domains.

---

## 3. Skeleton script (tailor it to the SPEC, then pass to the `Workflow` tool)

```javascript
export const meta = {
  name: 'auto-build',
  description: 'Autonomously build the product from the SPEC per Alpha AI standards',
  phases: [
    { title: 'Scaffold' }, { title: 'Data Layer' }, { title: 'Auth' },
    { title: 'API' }, { title: 'Frontend' }, { title: 'Tests' }, { title: 'Ship' },
  ],
}

// args = { spec: '<abs path to PRD/spec>', dir: '<build dir>', profile: {...FEATURE_PROFILE} }
const { spec, dir, profile } = args
const STD = `Follow Alpha AI standards: layer segregation (api→services→repositories→models),
JWT in HTTP-Only cookies (never localStorage), the stack in the SPEC, tests + ruff/mypy clean.
Build in ${dir}. Read the SPEC at ${spec} first.`

const FILES = { type:'object', properties:{ summary:{type:'string'}, files:{type:'array', items:{type:'string'}} }, required:['summary','files'] }

// ── sequential phases (each depends on the prior) ──
phase('Scaffold')
await agent(`${STD}\nScaffold the project: dirs, config, deps, Dockerfile, compose, Makefile (make dev/verify), .env.example, lint/type config, git init. Commit a baseline.`, { schema: FILES, phase:'Scaffold' })

phase('Data Layer')
await agent(`${STD}\nBuild the data layer: DB client(s) + index bootstrap, all models + repositories per the SPEC's data section. Indexes are load-bearing.`, { schema: FILES, phase:'Data Layer' })

phase('Auth')
await agent(`${STD}\nBuild the auth system: JWT issue/verify, password + (if SPEC) OAuth/device-grant, CSRF, cookie helpers, auth dependencies + revocation. Tests for the auth surface.`, { schema: FILES, phase:'Auth' })

phase('API')
// fan out across NON-overlapping route groups (no shared files) — safe to parallelize
const groups = profile.routeGroups // e.g. ['ingest','dashboard','org','me'] from the SPEC
await parallel(groups.map(g => () =>
  agent(`${STD}\nBuild the ${g} API: thin controllers + Pydantic/DTO schemas + service logic per the SPEC. Org-scoped, validated.`, { label:`api:${g}`, phase:'API', schema: FILES })))

if (profile.hasFrontend) {
  phase('Frontend')
  // design-system first (everything depends on it), THEN pages in parallel
  await agent(`${STD}\nFrontend scaffold + design system + AppShell (Next.js, dark-first, shadcn).`, { phase:'Frontend', schema: FILES })
  await parallel(profile.pages.map(p => () =>
    agent(`${STD}\nBuild the ${p} page on the design system + typed API client. Cookie auth, skeleton/empty/error states.`, { label:`page:${p}`, phase:'Frontend', schema: FILES })))
}

// ── Tests + adversarial verify (no lead is watching — gate hard) ──
phase('Tests')
const tested = await agent(`${STD}\nWrite the full test suite (unit + integration). Run it. Report coverage + any failures.`, { phase:'Tests', schema:{ type:'object', properties:{ passed:{type:'number'}, failed:{type:'number'}, coverage:{type:'number'} }, required:['passed','failed'] } })
// independent skeptics verify the build actually works (don't trust a single "green")
const verdicts = await parallel(['boot','auth','data'].map(lens => () =>
  agent(`Adversarially verify the ${lens} path in ${dir} against the SPEC's acceptance criteria. Try to make it fail (fresh boot, real deps). Report {ok, findings}.`,
    { label:`verify:${lens}`, phase:'Tests', schema:{ type:'object', properties:{ ok:{type:'boolean'}, findings:{type:'array', items:{type:'string'}} }, required:['ok'] } })))
const blocking = verdicts.filter(Boolean).filter(v => !v.ok).flatMap(v => v.findings || [])
if (blocking.length) {
  log(`Verify found ${blocking.length} issue(s) — dispatching a fix pass`)
  await agent(`${STD}\nFix these verified issues, then re-run the suite until green:\n- ${blocking.join('\n- ')}`, { phase:'Tests' })
}

// ── Ship ──
phase('Ship')
const ship = await agent(`${STD}\nFinal gate: ruff+mypy clean, full pytest green, make verify (/health 200). Commit the complete build with a clear message. Report the result.`, { phase:'Ship', schema:{ type:'object', properties:{ green:{type:'boolean'}, commit:{type:'string'}, notes:{type:'string'} }, required:['green'] } })

return { tested, verify: verdicts, ship }
```

**Tailoring rules:** drop phases the FEATURE_PROFILE doesn't flag (no `hasFrontend` → no Frontend
phase; no payments/AI/search → no such agents). Add Mobile/Extension/AI phases the same way
(one `phase()` + `parallel()` over that domain). Scale the fleet to `budget` if a target is set.

---

## 4. Quality gates are MANDATORY in Workflow mode

There's no lead to catch problems mid-run, so the script must self-police:

1. **Hard test gate** — the Tests phase must end green; the fix-pass loop above re-runs until it is.
2. **Adversarial verify** — independent skeptics (different lenses: boot / auth / data / security)
   try to make the build fail against the SPEC's acceptance criteria. This is what catches the
   "passes in mocks, dies on fresh boot" class (the exact bug class that bit real builds).
3. **No silent caps** — `log()` anything dropped (skipped phase, unverified claim) so the final
   report is honest.

---

## 5. Invoke + resume

- **Invoke**: call the `Workflow` tool with `{ script, args: { spec, dir, profile } }`. It runs in the
  background and returns a `runId` + a script path; a `<task-notification>` arrives on completion.
  Watch live with `/workflows`.
- **Resume** (after a pause/edit): relaunch with `{ scriptPath, resumeFromRunId }` — the longest
  unchanged prefix of `agent()` calls returns cached results instantly; the first edited/new call
  and everything after runs live. Same script + same args → 100% cache hit. This is the Workflow-mode
  equivalent of `/resume-build`.

---

## 6. After the Workflow returns

Read the returned `{ tested, verify, ship }` object and report to the user honestly:
phases completed, coverage, any verify findings + whether they were fixed, the final commit, and
whether `ship.green` is true. Update `AUTO_BUILD_STATE.json` with `build_mode: "workflow"`,
the `runId`, and the phase outcomes so `/resume-build --workflow` can continue.
