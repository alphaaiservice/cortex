# CODE_PATTERNS_CLAUDE_PLUGIN — Claude Code Plugin Authoring Patterns

> Referenced by `commands/init-claude-plugin.md`. Encodes every plugin best
> practice Cortex itself has learned through v1.0 → v1.2. Most of the
> anti-patterns here are mistakes Cortex made and fixed — the validator
> (Section 9) catches them automatically.

---

## 1. Plugin Structure Overview

A Claude Code plugin is a directory with this layout:

```
<plugin-name>/
├── .claude-plugin/
│   ├── plugin.json              # MANDATORY — plugin metadata
│   └── marketplace.json         # for distribution via /plugin marketplace
├── commands/                     # slash commands (one .md file per command)
├── agents/                       # subagents (one .md file per agent)
├── skills/                       # auto-invoked skills (one dir per skill, contains SKILL.md)
│   └── <skill-name>/
│       ├── SKILL.md
│       └── references/          # progressive disclosure — load on demand
├── hooks/
│   └── hooks.json               # event-driven hook config (NEVER inline bash)
├── scripts/                      # bash scripts invoked by hooks + dev tools
│   ├── validate-plugin.sh       # MANDATORY quality gate (see Section 9)
│   └── *.sh
├── .mcp.json                     # optional — wires MCP servers into the plugin
├── mcp/                          # optional — embedded MCP server source
├── .github/
│   └── workflows/
│       └── validate-plugin.yml  # CI for the validator
├── CHANGELOG.md
├── README.md
├── LICENSE
├── .gitignore
└── CLAUDE.md                     # context doc for future Claude sessions
```

**Discovery rules:**
- `commands/*.md` — every `.md` becomes a slash command named after the filename
- `agents/*.md` — every `.md` becomes a subagent
- `skills/*/SKILL.md` — every directory with a `SKILL.md` becomes an auto-invoked skill
- Hooks in `hooks/hooks.json` — fire automatically per their matchers
- `.mcp.json` — MCP servers start when the plugin is loaded

---

## 2. `plugin.json` — Schema and Frontmatter Rules

### Required fields

```json
{
  "name": "kebab-case-name",
  "description": "One-line description, under 120 chars. Shown in /plugin list and marketplace cards.",
  "version": "0.1.0",
  "author": {
    "name": "Author Name",
    "email": "author@example.com"
  }
}
```

### Recommended fields (the validator will warn if missing)

```json
{
  "homepage": "https://example.com/your-plugin",
  "repository": "https://github.com/owner/repo",
  "license": "MIT",
  "category": "Development Tools",
  "keywords": ["3-8", "search", "keywords"],
  "tags": ["2-5", "short", "tags"]
}
```

### Rules

- **`name`**: kebab-case, lowercase, starts with a letter, no spaces / underscores / special chars
- **`version`**: strict semver — `MAJOR.MINOR.PATCH`. Stay below `1.0.0` until you commit to backwards-compatibility
- **`description`**: one line, under 120 chars (marketplace card cuts off)
- **`repository`**: set even for private plugins — enables `/plugin install <git-url>`
- **`license`**: MIT is the ecosystem norm. Proprietary if you must, but reduces adoption

### marketplace.json cross-check

`marketplace.json` (when present) has its own `plugins[0].version` field. **It MUST match `plugin.json.version`.** Drift is the most common plugin bug. The validator (Section 9) catches this.

---

## 3. Commands — Authoring Pattern

### Minimal command

`commands/hello.md`:

```markdown
---
description: "Say hello to someone. Usage: /hello <name>"
---

# Hello

Greet: **$ARGUMENTS**

Output: `Hello, $ARGUMENTS! 👋`
```

### Frontmatter rules

- `description` is REQUIRED. Shows in `/help`. Be specific about USAGE and ARGS.
- Do NOT use `allowed-tools` — Claude Code doesn't recognize it for commands; all tools are available.
- Optional: `argument-hint`, `model` (rare — only for commands that need a specific model).

### Body structure

- **Title** (h1) restates the command name
- **Intent line** — what the command does in one sentence
- **`$ARGUMENTS`** — special variable; captures everything after the command name
- **Step structure** — number the steps. Claude follows them in order.
- **Output summary** — a final ASCII box showing what was done

### Multi-step commands

For complex commands (anything >50 lines of instructions), use the Step structure:

```markdown
## Step 0: Pre-flight / safety / arg parsing
## Step 1: ...
## Step 2: ...
...
## Step N: Output summary
```

This makes the command easier to debug and easier for Claude to resume after compaction.

### Reference-doc citations (DRY pattern)

For complex commands that share patterns (tech stack, code patterns, safety rules), don't inline the patterns — cite a canonical reference:

```markdown
> **📖 CANONICAL REFERENCE**: `commands/references/<TOPIC>.md` contains the full
> library of patterns referenced below. Load that file for all templates.
```

This is the pattern Cortex uses for `AUTO_BUILD_STACK.md`, `AUTO_BUILD_PHASES.md`,
`WORKTREE_SAFETY.md`. **Single source of truth** for any pattern that >1 command needs.

### Worktree safety for risky commands

Any command that mutates many files MUST include a Step 0 that runs the worktree-safety decision tree:

```markdown
## Step 0: Safety — Worktree Isolation (MANDATORY before any mutation)

> **📖 CANONICAL REFERENCE**: `commands/references/WORKTREE_SAFETY.md` defines
> the safety decision tree. Follow it BEFORE any Write/Edit/Bash mutation.

Quick summary:
1. Confirm scope with user; ask isolated worktree (DEFAULT) vs current checkout vs cancel.
2. Default: spawn the mutation phase as Agent({ ..., isolation: "worktree" }) OR `git worktree add ../<repo>-<cmd>-$(date +%s) -b <cmd>/auto`.
3. Current checkout (only with explicit opt-in): refuse if dirty; savepoint commit.
4. No git: refuse.
```

Cortex enforces this for `/migrate-stack`, `/refactor`, `/retrofit`.

### Command output format

End every multi-step command with an output summary in an ASCII box:

```
╔══════════════════════════════════════════════════════════╗
║   <COMMAND NAME> COMPLETE                                ║
╠══════════════════════════════════════════════════════════╣
║  <key fact 1>                                            ║
║  <key fact 2>                                            ║
║  <next steps>                                            ║
╚══════════════════════════════════════════════════════════╝
```

Users skim. The ASCII box is the most-noticed line in your output.

---

## 4. Agents — Authoring Pattern

### When to use an agent vs a command vs a skill

| Need | Use |
|------|-----|
| User wants to run a specific action explicitly | **Command** (`/foo`) |
| The action should fire automatically when conditions match | **Skill** (auto-invoked) |
| The action benefits from a focused system prompt + isolated context | **Agent** (spawned via Task tool) |
| Parallel work across independent sub-tasks | **Multiple agents** spawned at once |
| Single linear workflow | **Command** with Steps |

### Agent frontmatter

```markdown
---
description: "Specialized agent for X. Triggered when the task involves Y. Demonstrates specialized agent structure."
---
```

The `description` is how Claude (the parent) decides which agent to spawn for a given `Task` call. Write it like a job posting:
- **What the agent specializes in**
- **What kinds of tasks trigger it**
- **What it produces**

### Agent body — system prompt

The body of the file IS the agent's system prompt. Structure:

```markdown
You are **<Name>** — a specialized subagent for <domain>.

## When to fire
[Trigger conditions]

## Your job
[Concrete responsibilities, inputs, outputs]

## Working style
[Tools, style, how you communicate]

## Anti-patterns
[What NOT to do]
```

### Persona patterns (optional, but useful)

Cortex uses named personas (Arjun, Priya, Marcus, ...) with country flags + introductions. This:
- Makes log output scannable ("Yuki is debugging" vs "agent #4 is debugging")
- Helps the user trust specialized expertise ("Yuki for auth is the security specialist")
- Makes long autonomous runs more debuggable

For team-scale plugins, persona system is high-ROI. For single-author plugins, optional.

---

## 5. Skills — Trigger Discipline (THE most important section)

Skills are auto-invoked based on their `description:` field. **A vague description = the skill never fires.** **An over-aggressive description = noise on every task.** The trigger phrase is the most important thing about a skill.

### Skill frontmatter

```markdown
---
name: skill-name
description: "<TRIGGER CONDITION — see recipe below>"
license: "MIT"
compatibility: "Designed for Claude Code with <plugin-name> plugin"
metadata:
  author: "Your Name"
  version: "0.1.0"
---
```

### The trigger phrase recipe

A good skill description has 3 parts:

1. **When it fires** — concrete verbs/scenarios the user might use
2. **What it enforces** — the standard or pattern this skill applies
3. **Why skipping it matters** — what goes wrong without it

**Good example** (Cortex's `cortex-brainstorming` skill):

> "MUST USE before creating any new feature, product, service, or component —
> including any time a user says 'add', 'build', 'create', 'implement', 'make',
> 'design', or describes a new behavior. Explores intent, surfaces hidden
> constraints, and builds the FEATURE_PROFILE needed by /gen-prd, /init-project,
> /auto-build, /retrofit, and /ai-upgrade. Skipping this leads to scaffolding
> the wrong stack — e.g., installing Razorpay for a project that doesn't take
> payments, or building a mobile app the user didn't want."

Notice:
- **Concrete trigger words**: "add", "build", "create", "implement", "make", "design"
- **What it enforces**: FEATURE_PROFILE building
- **Cost of skipping**: wrong scaffolding, wasted hours

**Bad example** (too vague):

> "Helps with planning."

This never fires reliably because Claude can't tell from the description WHEN to invoke it.

**Bad example** (too aggressive):

> "ALWAYS USE for every task."

This fires constantly and adds noise to every interaction.

### Skill body structure

```markdown
# <Skill Name>

[1-2 sentence intro — what this enforces or teaches]

---

## When to use this skill

Always fire when:
- [concrete trigger 1]
- [concrete trigger 2]

Skip ONLY when:
- [explicit non-trigger case]

---

## Rules / Patterns / Methodology

[Substantial content — your standards, structured by topic]

---

## Anti-patterns (DO NOT DO)

- ❌ [bad pattern 1]
- ❌ [bad pattern 2]
```

### Progressive disclosure — references/ subdirectory

If your skill has heavy reference material (code patterns, long tables, multi-language examples), split into `skills/<name>/references/<TOPIC>.md` files. The SKILL.md cites them with `> **📖 REFERENCE**: ...` and Claude loads them on demand.

This is how Cortex's `alpha-architecture` skill handles 14 reference docs without bloating the always-loaded SKILL.md.

---

## 6. Hooks — Event Matrix

Hooks are event-driven scripts that fire automatically. They're configured in `hooks/hooks.json`.

### Hook events

| Event | When it fires | Exit code 2 effect | Common use |
|-------|---------------|--------------------|------------|
| `PreToolUse` | Before any tool use | **Blocks the tool call** | Safety check (e.g., block dangerous bash) |
| `PostToolUse` | After a tool use | Logged, doesn't block | Auto-format, run tests, lint |
| `SessionStart` | Session begins | Logged, doesn't block | Print plugin context, load state |
| `SessionEnd` | Session ends | Logged, doesn't block | Save state, cleanup |
| `Stop` | Claude tries to exit | **Blocks the exit** | Autonomous-loop continuation |
| `UserPromptSubmit` | User sends a message | Logged | Pre-process user input (use sparingly — fires every msg) |
| `PreCompact` | Before context compaction | Logged | Checkpoint state to git before compaction |
| `TeammateIdle` | Agent Teams: teammate has no tasks | **Forces them to keep working** | Reassign pending tasks |
| `TaskCompleted` | Agent Teams: teammate finishes task | **Rejects the task as incomplete** | Quality gate |

### Hook config — CRITICAL RULE: NEVER inline bash

The biggest plugin anti-pattern. Wrong:

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Write",
      "hooks": [{
        "type": "command",
        "command": "bash -c 'INPUT=$(cat); FILE=$(echo \"$INPUT\" | jq -r ...); if echo ...'",
        "timeout": 15
      }]
    }]
  }
}
```

Right — extract to a script:

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Write",
      "hooks": [{
        "type": "command",
        "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/auto-format.sh",
        "timeout": 15
      }]
    }]
  }
}
```

Reasons:
- Inline bash is unreadable (300+ char one-liners)
- Untestable in isolation
- No syntax highlighting in editors
- Stack traces don't show where the bash came from

**Always extract.** Cortex hit this and refactored in v1.1.2.

### Script template

Every hook script should follow this structure:

```bash
#!/bin/bash
# <Hook name> — <one-line purpose>
# Fires on: <event>
# Behavior: <what it does>, <exit-code semantics>

INPUT=$(cat)
# Parse INPUT (JSON) with jq

# Do the thing

exit 0   # or exit 2 to block
```

Make executable: `chmod +x scripts/your-hook.sh`. The validator checks for this.

### `${CLAUDE_PLUGIN_ROOT}` variable

Special variable that resolves to the plugin's root directory at hook execution time. Always use this in hook command paths — never hardcode `/Users/...` or relative paths.

---

## 7. Reference Docs — DRY Pattern

When the same content appears in 2+ command/skill files, extract to a reference doc:

```
commands/
├── command-a.md       (cites references/<TOPIC>.md)
├── command-b.md       (cites references/<TOPIC>.md)
├── command-c.md       (cites references/<TOPIC>.md)
└── references/
    └── <TOPIC>.md     (canonical content — the source of truth)
```

Each command's citation looks like:

```markdown
> **📖 CANONICAL REFERENCE**: `commands/references/<TOPIC>.md` contains the
> full library of <topic>. Do NOT re-template it here. <Short summary
> instructing the agent what to do with the reference.>
```

Benefits (proven by Cortex's v1.1.1 DRY refactor):
- Update once, all commands pick up the change
- Eliminates manual sync burden
- Reduces total content (Cortex removed 204 lines of duplication)

---

## 8. Worktree Safety Pattern

For commands that mutate many files (refactor, migrate, retrofit), bake in a worktree-safety decision tree. See `commands/references/WORKTREE_SAFETY.md` in Cortex for the full pattern.

Three-mode safety tree:
1. **Isolated worktree** (DEFAULT) — `git worktree add` OR `Agent({ isolation: "worktree" })`. Surface diff to user before merge.
2. **Current checkout** (explicit opt-in only) — refuse if dirty; savepoint commit before mutations.
3. **No git** — refuse.

This protects the user's working tree from botched runs.

---

## 9. Validator — Port from Cortex

**Every plugin should have `scripts/validate-plugin.sh`** as a quality gate. Port from Cortex's version (this plugin's `scripts/validate-plugin.sh`). It checks:

1. `plugin.json` is valid JSON + has required fields
2. `marketplace.json` is valid JSON + version matches plugin.json
3. `hooks.json` is valid JSON + every referenced script exists + is executable
4. Every `commands/*.md` has `frontmatter.description`
5. Every `skills/*/SKILL.md` has `name` + `description`
6. Every `agents/*.md` has `description`
7. Every cited `commands/references/*.md` path resolves
8. Every cited `skills/*/references/*.md` path resolves
9. No stale `*.backup` / `*.bak` / `*.old` files
10. All `scripts/*.sh` are executable

**Wire it into CI** with `.github/workflows/validate-plugin.yml`:

```yaml
name: Validate Plugin
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: sudo apt-get update && sudo apt-get install -y jq
      - run: chmod +x scripts/*.sh
      - run: bash scripts/validate-plugin.sh
```

Validator failures should block PR merge.

---

## 10. Versioning + CHANGELOG Discipline

### Semver rules

- **MAJOR** (`X.0.0`) — backwards-incompatible: removed command, renamed skill, breaking hook event change. Rare.
- **MINOR** (`0.X.0`) — added: new command, new skill, new agent, new hook event handler. Common.
- **PATCH** (`0.0.X`) — refactor, bug fix, internal cleanup, content update with no API change. Most common.

### CHANGELOG format

Keep-a-Changelog format:

```markdown
# Changelog

## [0.1.1] — 2026-05-27

### Added
- New `/foo` command for X

### Changed
- `/bar` command now defaults to Y instead of Z

### Fixed
- `/baz` no longer crashes on empty input

### Removed
- Deprecated `/old-thing` command (use `/new-thing` instead)

## [0.1.0] — 2026-05-26

### Added
- Initial plugin scaffold
```

Bump version + add CHANGELOG entry EVERY meaningful commit. Skipping CHANGELOG means users can't tell what changed; skipping version means `/plugin update` doesn't know to refresh.

---

## 11. Distribution — Marketplace.json

To distribute via marketplace (the common pattern):

1. Create a marketplace repo: `github.com/<owner>/<marketplace-name>`
2. Add a `marketplace.json` listing your plugins
3. Users add the marketplace: `/plugin marketplace add <owner>/<marketplace-name>`
4. Users install: `/plugin install <plugin-name>@<marketplace-name>`

Your plugin's own `.claude-plugin/marketplace.json` is for marketplace-publishing. For pure GitHub distribution (no marketplace), users can install directly from git URL:

```
/plugin install https://github.com/<owner>/<repo>
```

---

## Anti-patterns (DO NOT DO) — All of these are mistakes Cortex itself made and fixed

- ❌ **Inline bash in `hooks.json`.** Extract to `scripts/*.sh`. (Cortex v1.1.2)
- ❌ **Content duplicated across command files.** Use reference docs + citations. (Cortex v1.1.1, v1.1.3)
- ❌ **Manifest counts that don't match reality.** Validator catches drift. (Cortex v1.1.0 → v1.1.5)
- ❌ **`*.backup` files shipped to installs.** Validator refuses these. (Cortex v1.1.0)
- ❌ **No version bumps on changes.** Bump every commit, even patches. (Cortex sat at 1.0.0 for months)
- ❌ **Mutating commands without worktree safety.** Add WORKTREE_SAFETY citation. (Cortex v1.1.3)
- ❌ **Skill descriptions that are too vague.** Skill never fires. Use the trigger phrase recipe (Section 5).
- ❌ **Skill descriptions that are too aggressive.** Skill fires on everything. Be specific.
- ❌ **No validator.** Catches everything above before users see it. (Cortex v1.1.5)
- ❌ **No CHANGELOG.** Users can't tell what changed; bug reports lose context.
- ❌ **Putting plugin.json outside `.claude-plugin/`.** It MUST live there. Commands/agents/skills/hooks go at plugin ROOT.
- ❌ **Plugin name with spaces, uppercase, underscores, or special chars.** kebab-case only.
- ❌ **Hardcoded paths in hooks.** Use `${CLAUDE_PLUGIN_ROOT}`.
- ❌ **No README, or README that doesn't explain installation.** Users will not figure it out.
- ❌ **MIT-licensed plugin without a LICENSE file.** Validator should check this.
