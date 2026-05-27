---
description: "Scaffold a new Claude Code plugin (commands, agents, skills, hooks, MCP servers, validator, GitHub Actions). Dogfoods every plugin best practice Cortex itself has learned through v1.0–v1.2. Usage: /init-claude-plugin <plugin-name> [--with-commands] [--with-agents] [--with-skills] [--with-hooks] [--with-mcp] [--license=MIT|Proprietary]"
---

# Init Claude Plugin — Scaffold a Claude Code Plugin

Create: **$ARGUMENTS**

This command scaffolds a Claude Code plugin with the structure Cortex itself uses. It encodes every plugin best practice we've learned: single-source-of-truth references, extracted hook scripts (no inline bash soup), worktree-safety preamble for risky commands, plugin validator, GitHub Actions CI, and proper semver/CHANGELOG discipline.

> **📖 CANONICAL REFERENCE**: `skills/alpha-architecture/references/CODE_PATTERNS_CLAUDE_PLUGIN.md` contains the full plugin development patterns (frontmatter rules, hook event matrix, skill trigger discipline, validator port, marketplace.json schema). Load that file for all templates referenced below.

---

## Step 0: Parse arguments

Extract from `$ARGUMENTS`:
- **`plugin-name`** (required, first positional arg) — kebab-case, e.g. `my-plugin`, `acme-devops`. Becomes the plugin directory + the `name` field in `.claude-plugin/plugin.json`.
- **`--with-commands`** (default ON) — scaffold the `commands/` directory with 1 example command.
- **`--with-agents`** (default OFF) — scaffold the `agents/` directory with 1 example agent.
- **`--with-skills`** (default ON) — scaffold `skills/<plugin-name>/SKILL.md` with proper frontmatter.
- **`--with-hooks`** (default OFF) — scaffold `hooks/hooks.json` with PreToolUse safety check.
- **`--with-mcp`** (default OFF) — scaffold an embedded MCP server in `mcp/` + wire into `.mcp.json`.
- **`--license`** = `MIT` (default) | `Proprietary` | `Apache-2.0` | `GPL-3.0`. MIT is the Claude Code plugin ecosystem norm.
- **`--author-name`** + **`--author-email`** — populate plugin.json author field. If missing, prompt the user.

If `plugin-name` is missing, stop and ask. Validate it's kebab-case, lowercase, starts with a letter.

---

## Step 1: Confirm — is this the right tool?

Before scaffolding, confirm:

```
Ask: "What kind of plugin is this?"

  A) Internal team plugin (commands/skills for your own team)         → continue
  B) Open-source plugin to publish to a marketplace                   → continue + ensure --license=MIT
  C) Custom commands for a single project (not really a plugin)       → STOP. Use .claude/commands/ in the project directly instead — lighter weight.
  D) Replacing a /command in another plugin                           → STOP. Override the command in that plugin's directory or fork it.
  E) Just one slash command, nothing else                             → STOP. Create .claude/commands/<name>.md in your project; a full plugin is overkill.
```

For (A) and (B), continue. For others, redirect the user.

---

## Step 2: Create the plugin directory and git init

```bash
mkdir -p $PLUGIN_NAME && cd $PLUGIN_NAME
git init -b main
```

Create the **mandatory baseline** (these exist regardless of flags):

```
$PLUGIN_NAME/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── scripts/
│   └── validate-plugin.sh         # PORT FROM CORTEX — this is the quality gate
├── .github/
│   └── workflows/
│       └── validate-plugin.yml    # runs validator on push + PR
├── README.md
├── CHANGELOG.md
├── LICENSE
├── .gitignore
└── CLAUDE.md                       # context doc for future Claude sessions
```

---

## Step 3: Scaffold `.claude-plugin/plugin.json`

Use this exact template — all fields are required for a healthy plugin (Cortex's validator enforces them):

```json
{
  "name": "$PLUGIN_NAME",
  "description": "<one-line description from user — keep under 120 chars; will show in /plugin list>",
  "version": "0.1.0",
  "author": {
    "name": "<from --author-name>",
    "email": "<from --author-email>"
  },
  "homepage": "<optional URL>",
  "repository": "<git URL — required for marketplace install>",
  "license": "<from --license, default MIT>",
  "category": "Development Tools",
  "keywords": [
    "<3-8 keywords for marketplace search>"
  ],
  "tags": [
    "<2-5 short tags>"
  ]
}
```

**Anti-patterns enforced by the validator** (per `CODE_PATTERNS_CLAUDE_PLUGIN.md` Section 2):
- ❌ Plugin name must NOT contain spaces, uppercase, underscores, or special chars
- ❌ Version must follow semver — `0.x.x` until stable, `1.0.0` is a public commitment
- ❌ Description must be one line, under 120 chars
- ❌ Repository should be set even for private plugins (allows `/plugin install` from git URL)

---

## Step 4: Scaffold `.claude-plugin/marketplace.json`

Marketplace catalog format. Used when you publish the plugin via a marketplace repo (`/plugin marketplace add <owner>/<repo>`).

```json
{
  "name": "<your-marketplace-namespace>",
  "owner": {
    "name": "<from --author-name>",
    "email": "<from --author-email>"
  },
  "metadata": {
    "description": "<marketplace description>",
    "version": "0.1.0"
  },
  "plugins": [
    {
      "name": "$PLUGIN_NAME",
      "source": "./",
      "description": "<same as plugin.json>",
      "version": "0.1.0",
      "author": { /* same as plugin.json */ },
      "license": "<same>",
      "repository": "<same>",
      "homepage": "<same>",
      "keywords": [ /* same */ ],
      "tags": [ /* same */ ],
      "category": "Development Tools"
    }
  ]
}
```

**Cross-check**: plugin.json `version` MUST equal marketplace.json `plugins[0].version`. The validator catches drift between these two.

---

## Step 5: Scaffold `commands/` (if --with-commands)

Create one example command — a complete, working `/hello` command demonstrating frontmatter, args, and structure:

`commands/hello.md`:
```markdown
---
description: "Example command — say hello to someone. Usage: /hello <name>"
---

# Hello Command

Greet: **$ARGUMENTS**

## Step 1: Parse arguments

Extract `name` from $ARGUMENTS. If missing, default to "world".

## Step 2: Greet

Output: `Hello, <name>! 👋`

That's it. This command exists to demonstrate the command file structure. Replace
with your real commands.

## Reference

See `skills/alpha-architecture/references/CODE_PATTERNS_CLAUDE_PLUGIN.md` Section 3
for the full command authoring guide (frontmatter rules, $ARGUMENTS handling,
Step structure, output formatting, multi-step commands, etc.).
```

Add a brief `commands/README.md` listing each command in the plugin.

---

## Step 6: Scaffold `agents/` (if --with-agents)

Create one example agent demonstrating frontmatter, system prompt, and persona structure:

`agents/example-agent.md`:
```markdown
---
description: "Example subagent. Triggered when the user asks for X, Y, or Z. Demonstrates agent structure — replace with your real agent."
---

You are **Example Agent** — a specialized subagent for [domain].

## When to fire
- Triggered by tasks involving [keywords from frontmatter description]
- Don't fire for [counter-examples]

## Your job
[Concrete responsibilities. What inputs you take, what outputs you produce.]

## Working style
- Always announce yourself at start and end
- Use the [specific tools] you're best suited for
- Defer to the main agent for [out-of-scope work]

## Reference
See `skills/alpha-architecture/references/CODE_PATTERNS_CLAUDE_PLUGIN.md` Section 4
for the full agent authoring guide (when to use agents vs commands vs skills,
how to write trigger descriptions, persona patterns).
```

---

## Step 7: Scaffold `skills/$PLUGIN_NAME/SKILL.md` (if --with-skills)

This is the auto-invoked skill that fires when the plugin's domain matches the user's task. Use this template:

`skills/$PLUGIN_NAME/SKILL.md`:
```markdown
---
name: $PLUGIN_NAME
description: "<TRIGGER CONDITION — when this skill should auto-invoke. Be aggressive and specific. Example: 'Auto-invoked when user writes code in [language], works with [domain], or asks about [topic]. Enforces [your standard].'>"
license: "<from --license>"
compatibility: "Designed for Claude Code with $PLUGIN_NAME plugin"
metadata:
  author: "<from --author-name>"
  version: "0.1.0"
---

# $PLUGIN_NAME Skill

[1-2 sentences explaining what this skill enforces or teaches.]

## When this skill is active

- [Concrete trigger 1]
- [Concrete trigger 2]
- [Skip case 1]

## Rules

[Your rules / patterns / standards, structured by topic.]

## Anti-patterns

[Things explicitly NOT to do.]

## Reference

See `skills/alpha-architecture/references/CODE_PATTERNS_CLAUDE_PLUGIN.md` Section 5
for the full skill authoring guide — especially the trigger-description discipline
(skill descriptions are how Claude decides whether to invoke; vague triggers = skill
never fires; over-aggressive triggers = noise; see the "trigger phrase recipe").
```

---

## Step 8: Scaffold `hooks/hooks.json` (if --with-hooks)

Hooks are event-driven scripts. **CRITICAL LESSON** from Cortex v1.1.2: **NEVER put inline bash in hooks.json** — extract to `scripts/*.sh` for testability and readability.

`hooks/hooks.json`:
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/safe-bash-check.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-context.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

Scaffold two starter scripts:

`scripts/safe-bash-check.sh` — basic dangerous-command blocker (matches Cortex's pattern, but minimal — extend per your plugin's risk profile):
```bash
#!/bin/bash
# Pre-tool hook — block dangerous bash commands from being executed
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$COMMAND" ] && exit 0

# Patterns to BLOCK (add your own)
CRITICAL=("rm -rf /" "mkfs\\." "dd if=" ":(){ :|:& };:")
for pattern in "${CRITICAL[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    echo "BLOCKED: dangerous command detected: $pattern" >&2
    exit 2
  fi
done
exit 0
```

`scripts/session-context.sh` — runs at session start to log plugin context:
```bash
#!/bin/bash
# Session start hook — print plugin context to the conversation
PLUGIN_NAME=$(basename "${CLAUDE_PLUGIN_ROOT:-$(pwd)}")
echo "[$PLUGIN_NAME plugin loaded]"
```

`chmod +x scripts/*.sh` after creating.

**The validator (Step 9) enforces that every script referenced by hooks.json exists and is executable.**

For the full hook event matrix (all 8 events: PreToolUse, PostToolUse, Stop, SessionStart, SessionEnd, PreCompact, TeammateIdle, TaskCompleted), see `CODE_PATTERNS_CLAUDE_PLUGIN.md` Section 6.

---

## Step 9: Scaffold `scripts/validate-plugin.sh` (MANDATORY — port from Cortex)

This is the **quality gate** every plugin should have. Copy Cortex's `scripts/validate-plugin.sh` verbatim into the new plugin, then customize.

The validator checks:
1. `plugin.json` is valid JSON + has required fields
2. `marketplace.json` is valid JSON + version matches plugin.json
3. `hooks.json` is valid JSON + every referenced script exists + is executable
4. Every `commands/*.md` has frontmatter.description
5. Every `skills/*/SKILL.md` has name + description
6. Every `agents/*.md` has description
7. Every `commands/references/*.md` citation resolves
8. Every `skills/*/references/*.md` citation resolves
9. No stale `*.backup` / `*.bak` / `*.old` files
10. All `scripts/*.sh` are executable

Run `chmod +x scripts/validate-plugin.sh`.

After scaffolding, run it once to confirm everything passes:
```bash
bash scripts/validate-plugin.sh
```

If it doesn't pass, the scaffold has a bug — fix before declaring init complete.

---

## Step 10: Scaffold `.github/workflows/validate-plugin.yml`

GitHub Actions workflow that runs the validator on every push and PR:

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
      - name: Install jq
        run: sudo apt-get update && sudo apt-get install -y jq
      - name: Make scripts executable
        run: chmod +x scripts/*.sh
      - name: Run validator
        run: bash scripts/validate-plugin.sh
```

---

## Step 11: Scaffold embedded MCP server (if --with-mcp)

For plugins that want to expose tools/resources to Claude beyond what slash commands can do, embed an MCP server.

Create `mcp/` directory and call `/init-mcp-server $PLUGIN_NAME-mcp --lang=python --transport=stdio --with-tools` to scaffold the server under `mcp/$PLUGIN_NAME-mcp/`.

Then wire it into the plugin via `.mcp.json`:

```json
{
  "mcpServers": {
    "$PLUGIN_NAME": {
      "command": "uv",
      "args": ["--directory", "${CLAUDE_PLUGIN_ROOT}/mcp/$PLUGIN_NAME-mcp", "run", "python", "-m", "$PLUGIN_NAME_SNAKE.server"]
    }
  }
}
```

When the plugin is installed, the MCP server starts automatically and its tools become available.

---

## Step 12: Scaffold `CHANGELOG.md`, `README.md`, `LICENSE`, `.gitignore`, `CLAUDE.md`

### `CHANGELOG.md` — Keep-a-Changelog format starting at 0.1.0:
```markdown
# Changelog

All notable changes to this plugin are documented in this file.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
Semver: [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — <today's date YYYY-MM-DD>

### Added
- Initial plugin scaffold
- [list scaffolded components per flags]
```

### `README.md` — comprehensive:
- What the plugin does (1-paragraph)
- Installation: `/plugin marketplace add <owner>/<repo>` then `/plugin install $PLUGIN_NAME@<marketplace>`
- List of commands / agents / skills with one-line purpose each
- Configuration (env vars, .mcp.json if applicable)
- Development: how to test locally with `--plugin-dir`
- Contributing
- License

### `LICENSE` — pick template based on `--license` flag (MIT is the default).

### `.gitignore`:
```
.cortex/
.DS_Store
node_modules/
__pycache__/
.venv/
*.pyc
.env
.env.local
```

### `CLAUDE.md` — context doc for future Claude sessions working on this plugin:
- What this plugin does
- Directory layout overview
- Where to find each kind of component
- The plugin's tech stack / standards
- "When making changes, run `bash scripts/validate-plugin.sh` before committing"

(Mirrors Cortex's own CLAUDE.md — see Cortex root for the template.)

---

## Step 13: Verify the scaffold

Run all verification gates per `cortex-verification` skill:

```bash
# JSON validity
jq -e . .claude-plugin/plugin.json
jq -e . .claude-plugin/marketplace.json
[ -f hooks/hooks.json ] && jq -e . hooks/hooks.json

# Full validator
bash scripts/validate-plugin.sh

# Initial commit
git add -A
git commit -m "feat: initial scaffold of $PLUGIN_NAME plugin (v0.1.0)"
```

All checks MUST pass. If validator returns non-zero, the scaffold has a bug — fix before declaring init complete.

---

## Step 14: Output summary

```
╔══════════════════════════════════════════════════════════════╗
║         CLAUDE CODE PLUGIN SCAFFOLDED                        ║
╠══════════════════════════════════════════════════════════════╣
║  Name:       $PLUGIN_NAME                                     ║
║  Version:    0.1.0                                            ║
║  License:    [MIT | Proprietary | ...]                       ║
║                                                               ║
║  Scaffolded:                                                  ║
║    [✓] .claude-plugin/plugin.json + marketplace.json         ║
║    [✓] scripts/validate-plugin.sh + GitHub Actions           ║
║    [if --with-commands] commands/hello.md                    ║
║    [if --with-agents] agents/example-agent.md                ║
║    [if --with-skills] skills/$PLUGIN_NAME/SKILL.md           ║
║    [if --with-hooks] hooks/hooks.json + scripts/*.sh         ║
║    [if --with-mcp] mcp/$PLUGIN_NAME-mcp/ + .mcp.json         ║
║                                                               ║
║  Validator:  ALL CHECKS PASSED                                ║
║                                                               ║
║  Test locally:                                                ║
║    claude --plugin-dir $(pwd)                                ║
║                                                               ║
║  Publish:                                                     ║
║    1. Push to GitHub: git push -u origin main                ║
║    2. Add to a marketplace: edit your marketplace repo's     ║
║       marketplace.json to include this plugin                ║
║    3. Users install: /plugin marketplace add <owner>/<repo>  ║
║       then /plugin install $PLUGIN_NAME                       ║
║                                                               ║
║  Reference: skills/alpha-architecture/references/             ║
║             CODE_PATTERNS_CLAUDE_PLUGIN.md                    ║
╚══════════════════════════════════════════════════════════════╝
```

---

## Anti-patterns (DO NOT DO — these are the exact mistakes Cortex itself made and fixed)

- ❌ **Inline bash in `hooks.json`.** Extract to `scripts/*.sh` from day one. Cortex hit 300+ char one-liners that were untestable; we extracted them in v1.1.2.
- ❌ **Duplicating content across command files.** Use `commands/references/<TOPIC>.md` as a single source of truth and cite from commands. Cortex DRY'd a tech stack out of 4 files in v1.1.1.
- ❌ **Plugin manifest counts that don't match reality.** Don't claim "9 skills" if you have 14 — the marketplace card lies. The validator enforces this.
- ❌ **Shipping `*.backup` files.** Cortex shipped a 288 KB `auto-build.md.backup` in v1.0.0; the validator now refuses these.
- ❌ **No version bumps on changes.** Every meaningful change should bump version + add a CHANGELOG entry. Cortex sat at 1.0.0 for months despite many feature additions.
- ❌ **Mutating commands without worktree safety.** Any command that touches many files should default to running in a `git worktree add` to protect the user's main checkout. See Cortex's `WORKTREE_SAFETY.md` reference.
- ❌ **Aggressive triggering that fires on everything.** Skill `description:` should be specific. Cortex's `cortex-brainstorming` skill description names the exact verbs ("add", "build", "create") that trigger it.
- ❌ **No validator.** Scaffold the validator from day one. It catches manifest drift, missing frontmatter, and broken refs before they hit users.
- ❌ **Skipping CHANGELOG.md.** Users (and your future self) need to understand what changed between versions.
