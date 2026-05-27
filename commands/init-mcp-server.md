---
description: "Scaffold a standalone MCP (Model Context Protocol) server project. Supports Python (official mcp SDK) and TypeScript (@modelcontextprotocol/sdk). Use this for pure MCP servers (Slack-MCP, Postgres-MCP, GitHub-MCP, etc.) — for MCP servers embedded inside a SaaS app, use /auto-build or /retrofit instead. Usage: /init-mcp-server <server-name> [--lang=python|typescript] [--transport=stdio|http|sse] [--with-tools] [--with-prompts] [--with-resources]"
---

# Init MCP Server — Scaffold a Standalone MCP Server Project

Create: **$ARGUMENTS**

This command scaffolds a **standalone** MCP server project — the kind you publish to PyPI/npm and other people install. For MCP servers embedded INSIDE a SaaS app (under `app/ai/mcp/` of a FastAPI/NestJS/Spring Boot app), use `/auto-build` with AI in the FEATURE_PROFILE instead.

> **📖 CANONICAL REFERENCE**: `skills/alpha-architecture/references/CODE_PATTERNS_MCP_SERVER.md` contains the full library of MCP server patterns (tools/prompts/resources, error handling, JSON-RPC, transport choice, testing). Load that file for all code patterns referenced below.

---

## Step 0: Parse arguments

Extract from `$ARGUMENTS`:
- **`server-name`** (required, first positional arg) — kebab-case, e.g. `slack-mcp`, `postgres-mcp`. Becomes the project directory + the MCP server name advertised in the handshake.
- **`--lang`** = `python` (default) | `typescript`. Python recommended — the official SDK is more mature and the ecosystem is bigger for backend-style MCP servers.
- **`--transport`** = `stdio` (default) | `http` | `sse`. `stdio` is recommended for almost everything (Claude Code, Claude Desktop, Cursor, etc. all use stdio). Use `http`/`sse` only if you specifically need to serve MCP over the network.
- **`--with-tools`** (default ON) — include example tools (the most common MCP primitive).
- **`--with-prompts`** (default OFF) — include example prompts (slash-command-style prompts the host can call).
- **`--with-resources`** (default OFF) — include example resources (URI-addressable read-only content).

If `server-name` is missing, stop and ask the user for it.

If `--lang` is missing, ask: "Python (mature SDK, recommended) or TypeScript (better for web-facing MCP)?"

---

## Step 1: Decision tree — should they actually be doing this?

Before scaffolding, confirm the user wants a STANDALONE MCP server, not the embedded variant:

```
Ask: "Is this MCP server going to be a separate package that other people install
      (PyPI / npm), OR is it going to be part of an existing app you're building?"

  Standalone package        → continue with this command
  Inside an existing app    → STOP. Use /auto-build or /retrofit instead. The
                              embedded MCP server lives under app/ai/mcp/ of
                              the host application; don't create a separate repo.
  Not sure yet              → recommend standalone. Easy to publish; can also
                              vendor it into an app later as a submodule.
```

If standalone, continue.

---

## Step 2: Create project directory and git init

```bash
mkdir -p $SERVER_NAME && cd $SERVER_NAME
git init -b main
```

Create top-level files (apply to both languages):

- `.gitignore` — language-appropriate template (Python: `__pycache__`, `.venv`, `*.egg-info`, `dist/`, `build/`; TypeScript: `node_modules/`, `dist/`, `*.tsbuildinfo`)
- `LICENSE` — MIT by default (most permissive — MCP ecosystem norm); ask user if they want different
- `README.md` — see Step 5
- `CHANGELOG.md` — Keep-a-Changelog format, start at `0.1.0` (pre-1.0 — MCP servers are typically pre-1.0 until stable)
- `.github/workflows/test.yml` — runs tests on push + PR

---

## Step 3a: Scaffold Python MCP server (if --lang=python)

### Directory structure

```
$SERVER_NAME/
├── pyproject.toml
├── README.md
├── CHANGELOG.md
├── LICENSE
├── .gitignore
├── .python-version              # 3.11
├── src/
│   └── $SERVER_NAME_SNAKE/      # underscored version of name
│       ├── __init__.py
│       ├── server.py            # main MCP server
│       ├── tools.py             # tool implementations (if --with-tools)
│       ├── prompts.py           # prompt implementations (if --with-prompts)
│       ├── resources.py         # resource implementations (if --with-resources)
│       └── _version.py          # __version__ = "0.1.0"
├── tests/
│   ├── __init__.py
│   ├── conftest.py              # pytest fixtures for in-memory MCP client
│   ├── test_server.py           # server lifecycle tests
│   ├── test_tools.py            # tool tests (if --with-tools)
│   ├── test_prompts.py          # prompt tests (if --with-prompts)
│   └── test_resources.py        # resource tests (if --with-resources)
└── .github/
    └── workflows/
        └── test.yml             # pytest on push + PR
```

### `pyproject.toml`

Use the standard `mcp` SDK from Anthropic. Pin to a known-good version (current as of 2026: `>=1.2.0`).

```toml
[build-system]
requires = ["hatchling>=1.21.0"]
build-backend = "hatchling.build"

[project]
name = "$SERVER_NAME"
version = "0.1.0"
description = "<one-line description from user>"
readme = "README.md"
license = { text = "MIT" }
requires-python = ">=3.11"
dependencies = [
  "mcp>=1.2.0",
  "pydantic>=2.0.0",
]

[project.optional-dependencies]
dev = [
  "pytest>=8.0.0",
  "pytest-asyncio>=0.23.0",
  "ruff>=0.6.0",
  "mypy>=1.10.0",
]

[project.scripts]
$SERVER_NAME = "$SERVER_NAME_SNAKE.server:run"

[tool.ruff]
line-length = 100
target-version = "py311"

[tool.mypy]
strict = true
python_version = "3.11"

[tool.pytest.ini_options]
asyncio_mode = "auto"
```

### `src/$SERVER_NAME_SNAKE/server.py`

Copy the **stdio server skeleton** from `CODE_PATTERNS_MCP_SERVER.md` Section 2.1. Adapt to:
- Server name = `$SERVER_NAME`
- Wire in tools/prompts/resources modules based on flags
- Include the `run()` entry point that `pyproject.toml` references

### `src/$SERVER_NAME_SNAKE/tools.py` (if --with-tools)

Copy the **tool implementation template** from `CODE_PATTERNS_MCP_SERVER.md` Section 3. Include 2 example tools:
1. `echo` — trivial example (input: string, output: same string) — useful for smoke-testing
2. `<domain-relevant>` — placeholder tool the user will replace (e.g., for `slack-mcp` → `send_message`; for `postgres-mcp` → `execute_query`)

Each tool MUST have:
- A Pydantic `BaseModel` for inputs (type-safe, JSON-schema-derived)
- A docstring (becomes the description visible to the LLM)
- Error handling that returns MCP error responses, not raises
- A unit test

### `src/$SERVER_NAME_SNAKE/prompts.py` (if --with-prompts)

Copy the **prompts template** from `CODE_PATTERNS_MCP_SERVER.md` Section 4. One example prompt that the host can call to get a pre-templated message.

### `src/$SERVER_NAME_SNAKE/resources.py` (if --with-resources)

Copy the **resources template** from `CODE_PATTERNS_MCP_SERVER.md` Section 5. One example resource at URI `info://about` that returns server metadata.

### `tests/conftest.py`

In-memory MCP client fixture (no subprocess, no stdio — just the server's request handlers tested directly). Pattern from `CODE_PATTERNS_MCP_SERVER.md` Section 7.

### `tests/test_*.py`

Per-primitive test files. Each test:
1. Builds the in-memory client
2. Calls the primitive (`list_tools`, `call_tool`, `get_prompt`, `read_resource`)
3. Asserts the response shape

Coverage target: 90% (lower than 80% standard because MCP servers are smaller; bar should be higher).

---

## Step 3b: Scaffold TypeScript MCP server (if --lang=typescript)

### Directory structure

```
$SERVER_NAME/
├── package.json
├── tsconfig.json
├── README.md
├── CHANGELOG.md
├── LICENSE
├── .gitignore
├── .node-version                # 22
├── src/
│   ├── index.ts                 # main MCP server
│   ├── tools.ts                 # (if --with-tools)
│   ├── prompts.ts               # (if --with-prompts)
│   └── resources.ts             # (if --with-resources)
├── tests/
│   ├── server.test.ts
│   ├── tools.test.ts
│   ├── prompts.test.ts
│   └── resources.test.ts
└── .github/
    └── workflows/
        └── test.yml             # vitest on push + PR
```

### `package.json`

```json
{
  "name": "$SERVER_NAME",
  "version": "0.1.0",
  "description": "<one-line>",
  "type": "module",
  "bin": {
    "$SERVER_NAME": "dist/index.js"
  },
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "dev": "tsx src/index.ts",
    "test": "vitest run",
    "test:watch": "vitest",
    "lint": "eslint src tests"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0",
    "zod": "^3.23.0"
  },
  "devDependencies": {
    "@types/node": "^22.0.0",
    "typescript": "^5.5.0",
    "tsx": "^4.16.0",
    "vitest": "^2.0.0",
    "eslint": "^9.0.0"
  },
  "engines": {
    "node": ">=22.0.0"
  }
}
```

### `tsconfig.json`

Strict mode. Target ES2022. Output to `dist/`. Skip lib check for speed.

### `src/index.ts`

Copy the **TypeScript stdio server skeleton** from `CODE_PATTERNS_MCP_SERVER.md` Section 2.2.

### `src/tools.ts`, `src/prompts.ts`, `src/resources.ts`

Per-flag, using Zod for input schemas (TS equivalent of Pydantic).

### Tests

Vitest. In-memory client pattern from `CODE_PATTERNS_MCP_SERVER.md` Section 7 (TypeScript variant).

---

## Step 4: Transport configuration

If `--transport=stdio` (default), no extra config — the server reads/writes via stdio.

If `--transport=http`, add:
- **Python**: `uvicorn` dependency + `src/$SERVER_NAME_SNAKE/http_server.py` that wraps the MCP server in a Starlette app at `POST /mcp`
- **TypeScript**: `express` or native `node:http` wrapper at `POST /mcp`

If `--transport=sse`, scaffold the SSE handler per `CODE_PATTERNS_MCP_SERVER.md` Section 6.

Add a section to README explaining how clients connect (Claude Desktop config, etc.) per transport.

---

## Step 5: README.md

Generate a complete README with these sections (use `CODE_PATTERNS_MCP_SERVER.md` Section 9 as the template):

```markdown
# <Server Name>

<One-line description>

## Capabilities

- **Tools** (if --with-tools): [list each tool name + 1-line purpose]
- **Prompts** (if --with-prompts): [list]
- **Resources** (if --with-resources): [list]

## Installation

[Python] `pip install $SERVER_NAME` or `uvx $SERVER_NAME`
[TypeScript] `npm install -g $SERVER_NAME` or `npx $SERVER_NAME`

## Use with Claude Desktop

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "$SERVER_NAME": {
      "command": "$SERVER_NAME"
    }
  }
}
```

## Use with Claude Code

Add to `~/.claude/mcp.json` or per-project `.mcp.json`:

```json
{
  "mcpServers": {
    "$SERVER_NAME": {
      "command": "$SERVER_NAME"
    }
  }
}
```

## Development

[install + test + run instructions]

## License

MIT
```

---

## Step 6: Verify the scaffold works

Run verification gates per `cortex-verification` skill:

**Python:**
```bash
python3.11 -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"
ruff check src/ tests/ && ruff format --check src/ tests/
mypy src/
pytest tests/ -v --cov=src --cov-fail-under=80
# Smoke: run the server briefly, send a list_tools request via the test client
python -c "import asyncio; from $SERVER_NAME_SNAKE.server import smoke_test; asyncio.run(smoke_test())"
```

**TypeScript:**
```bash
pnpm install
pnpm lint
pnpm exec tsc --noEmit
pnpm test
pnpm build
# Smoke: import and call list_tools via the test client
```

All checks MUST be green. If any fail, fix before declaring init complete (use `cortex-debugging` skill).

---

## Step 7: Output summary

```
╔══════════════════════════════════════════════════════════════╗
║         MCP SERVER SCAFFOLDED                                ║
╠══════════════════════════════════════════════════════════════╣
║  Name:        $SERVER_NAME                                    ║
║  Language:    [python | typescript]                          ║
║  Transport:   [stdio | http | sse]                           ║
║  Primitives:  [tools? prompts? resources?]                   ║
║                                                               ║
║  Tests:       [N passed]                                      ║
║  Coverage:    [X]%                                            ║
║                                                               ║
║  Next steps:                                                  ║
║    1. Replace the placeholder tool/prompt with your domain   ║
║       logic in src/$SERVER_NAME_SNAKE/{tools,prompts,         ║
║       resources}.py                                           ║
║    2. Update README.md description and capabilities list     ║
║    3. Add to Claude Desktop / Claude Code config to test     ║
║    4. Publish: [pip publish | npm publish] when ready        ║
║                                                               ║
║  Reference: skills/alpha-architecture/references/             ║
║             CODE_PATTERNS_MCP_SERVER.md                       ║
╚══════════════════════════════════════════════════════════════╝
```

---

## Anti-patterns (DO NOT DO)

- ❌ **Building an MCP server for something that already has one.** Check the official MCP server registry (https://github.com/modelcontextprotocol/servers) first. If `slack`, `github`, `filesystem`, `postgres`, etc. already exist as reference servers, fork/extend rather than duplicating.
- ❌ **Putting business logic in the MCP server.** The MCP server is a thin protocol adapter. Domain logic belongs in the underlying library — the MCP server just exposes it.
- ❌ **Exposing dangerous tools without confirmation.** Any tool that mutates external state (deletes a file, sends a message, charges a card) MUST require explicit confirmation in the tool description so the host can prompt the user.
- ❌ **Returning raw exceptions to the client.** MCP errors are structured. Catch your code's exceptions; return `McpError` with appropriate codes (-32602 for invalid params, -32603 for internal errors).
- ❌ **Using `http` transport for local-only use.** stdio is faster, simpler, and what every official client expects. Only use http/sse when serving over a network.
- ❌ **Skipping the in-memory test client.** Subprocess-based MCP tests are slow and flaky. The in-memory pattern (test the request handlers directly) runs in milliseconds.
- ❌ **Versioning MCP servers above 1.0.0 before stability.** MCP is evolving; pre-1.0 is honest. Stay at 0.x until your tool set is stable for at least 2 months.
