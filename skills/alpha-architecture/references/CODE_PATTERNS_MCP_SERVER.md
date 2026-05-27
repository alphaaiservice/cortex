# CODE_PATTERNS_MCP_SERVER — Standalone MCP Server Patterns

> Referenced by `commands/init-mcp-server.md`. Contains the full library of
> patterns for standalone MCP server projects (Python and TypeScript SDKs).

---

## 1. MCP Overview

**MCP (Model Context Protocol)** is an open standard for connecting AI assistants
to external systems. An MCP server exposes three kinds of primitives over
JSON-RPC 2.0:

| Primitive | Purpose | Direction | Example |
|-----------|---------|-----------|---------|
| **Tools** | Functions the LLM can invoke | Host → Server | `send_slack_message`, `execute_sql_query`, `list_files` |
| **Prompts** | Pre-templated message bundles | Host → Server | `code_review_prompt`, `summarize_meeting` |
| **Resources** | URI-addressable read-only data | Host → Server | `file://README.md`, `db://schema/users` |

The server runs as a subprocess of the host (Claude Desktop, Claude Code, Cursor, etc.)
and communicates via **stdio** (recommended default) or **HTTP/SSE** (for network use).

**SDKs:**
- Python: `mcp` (official, mature) — https://github.com/modelcontextprotocol/python-sdk
- TypeScript: `@modelcontextprotocol/sdk` (official, mature) — https://github.com/modelcontextprotocol/typescript-sdk

---

## 2. Server Skeleton

### 2.1 — Python (stdio transport)

`src/<server_name>/server.py`:

```python
"""MCP server entry point — stdio transport."""
import asyncio
from typing import Any

from mcp.server import Server
from mcp.server.stdio import stdio_server
import mcp.types as types

from .tools import TOOL_REGISTRY, list_tool_descriptors, dispatch_tool
from .prompts import PROMPT_REGISTRY, list_prompt_descriptors, dispatch_prompt
from .resources import list_resource_descriptors, read_resource

# Server name advertised in the MCP handshake. Must match plugin.json name field.
app = Server("<server-name>")


# ---- Tools ----------------------------------------------------------------

@app.list_tools()
async def handle_list_tools() -> list[types.Tool]:
    """Advertise available tools to the host."""
    return list_tool_descriptors()


@app.call_tool()
async def handle_call_tool(name: str, arguments: dict[str, Any]) -> list[types.TextContent]:
    """Dispatch a tool call. Always catches exceptions and returns structured errors."""
    return await dispatch_tool(name, arguments or {})


# ---- Prompts --------------------------------------------------------------

@app.list_prompts()
async def handle_list_prompts() -> list[types.Prompt]:
    return list_prompt_descriptors()


@app.get_prompt()
async def handle_get_prompt(name: str, arguments: dict[str, str] | None = None) -> types.GetPromptResult:
    return await dispatch_prompt(name, arguments or {})


# ---- Resources ------------------------------------------------------------

@app.list_resources()
async def handle_list_resources() -> list[types.Resource]:
    return list_resource_descriptors()


@app.read_resource()
async def handle_read_resource(uri: str) -> str:
    return await read_resource(uri)


# ---- Lifecycle ------------------------------------------------------------

async def serve() -> None:
    """Run the server over stdio."""
    async with stdio_server() as (read_stream, write_stream):
        await app.run(read_stream, write_stream, app.create_initialization_options())


def run() -> None:
    """Synchronous entry point referenced by pyproject.toml [project.scripts]."""
    asyncio.run(serve())


async def smoke_test() -> None:
    """Programmatic smoke test — used by `pytest` and the post-scaffold verify step."""
    tools = await handle_list_tools()
    assert len(tools) > 0, "smoke test: no tools registered"
    print(f"smoke ok: {len(tools)} tools registered")


if __name__ == "__main__":
    run()
```

### 2.2 — TypeScript (stdio transport)

`src/index.ts`:

```typescript
#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  ListToolsRequestSchema,
  CallToolRequestSchema,
  ListPromptsRequestSchema,
  GetPromptRequestSchema,
  ListResourcesRequestSchema,
  ReadResourceRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

import { TOOL_DESCRIPTORS, dispatchTool } from "./tools.js";
import { PROMPT_DESCRIPTORS, dispatchPrompt } from "./prompts.js";
import { RESOURCE_DESCRIPTORS, readResource } from "./resources.js";

const server = new Server(
  { name: "<server-name>", version: "0.1.0" },
  { capabilities: { tools: {}, prompts: {}, resources: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOL_DESCRIPTORS }));
server.setRequestHandler(CallToolRequestSchema, async ({ params }) =>
  dispatchTool(params.name, params.arguments ?? {})
);

server.setRequestHandler(ListPromptsRequestSchema, async () => ({ prompts: PROMPT_DESCRIPTORS }));
server.setRequestHandler(GetPromptRequestSchema, async ({ params }) =>
  dispatchPrompt(params.name, params.arguments ?? {})
);

server.setRequestHandler(ListResourcesRequestSchema, async () => ({ resources: RESOURCE_DESCRIPTORS }));
server.setRequestHandler(ReadResourceRequestSchema, async ({ params }) =>
  readResource(params.uri)
);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
```

---

## 3. Tools — Implementation Pattern

### 3.1 — Python

`src/<server_name>/tools.py`:

```python
"""Tool implementations — input validation via Pydantic, errors as MCP responses."""
from typing import Any

from pydantic import BaseModel, Field, ValidationError
import mcp.types as types


# ---- Input schemas (Pydantic = type-safe + auto JSON Schema) --------------

class EchoInput(BaseModel):
    """Echo input back. Trivial example for smoke-testing the server."""
    message: str = Field(..., description="Message to echo back to the caller.")


class SearchInput(BaseModel):
    """Domain-relevant placeholder. Replace with your real tool."""
    query: str = Field(..., description="Search query (1-200 chars).", min_length=1, max_length=200)
    limit: int = Field(10, description="Max results to return (1-100).", ge=1, le=100)


# ---- Tool registry --------------------------------------------------------

TOOL_REGISTRY: dict[str, tuple[type[BaseModel], str]] = {
    "echo":   (EchoInput,   "Echo a message back. Useful for testing the server is reachable."),
    "search": (SearchInput, "Search the underlying data store. Returns up to `limit` results."),
}


def list_tool_descriptors() -> list[types.Tool]:
    """Build MCP Tool descriptors from the registry — schemas auto-derived from Pydantic."""
    return [
        types.Tool(
            name=name,
            description=description,
            inputSchema=schema.model_json_schema(),
        )
        for name, (schema, description) in TOOL_REGISTRY.items()
    ]


# ---- Tool dispatch with structured error handling ------------------------

async def dispatch_tool(name: str, arguments: dict[str, Any]) -> list[types.TextContent]:
    if name not in TOOL_REGISTRY:
        return [types.TextContent(type="text", text=f"Error: unknown tool '{name}'")]

    schema_cls, _ = TOOL_REGISTRY[name]
    try:
        inputs = schema_cls(**arguments)
    except ValidationError as e:
        return [types.TextContent(type="text", text=f"Error: invalid arguments — {e}")]

    try:
        if name == "echo":
            return await _echo(inputs)
        if name == "search":
            return await _search(inputs)
    except Exception as e:
        # NEVER let raw exceptions bubble to the host — return structured errors.
        return [types.TextContent(type="text", text=f"Error: internal — {type(e).__name__}: {e}")]

    return [types.TextContent(type="text", text=f"Error: tool '{name}' has no implementation")]


# ---- Tool implementations ------------------------------------------------

async def _echo(inputs: EchoInput) -> list[types.TextContent]:
    return [types.TextContent(type="text", text=inputs.message)]


async def _search(inputs: SearchInput) -> list[types.TextContent]:
    # REPLACE with your real search logic — DB query, API call, etc.
    results = [f"result {i+1} for '{inputs.query}'" for i in range(inputs.limit)]
    return [types.TextContent(type="text", text="\n".join(results))]
```

### 3.2 — TypeScript

`src/tools.ts`:

```typescript
import { z } from "zod";
import type { Tool } from "@modelcontextprotocol/sdk/types.js";

// ---- Input schemas (Zod = type-safe + auto JSON Schema) ----------------

const EchoSchema = z.object({
  message: z.string().describe("Message to echo back to the caller."),
});

const SearchSchema = z.object({
  query: z.string().min(1).max(200).describe("Search query (1-200 chars)."),
  limit: z.number().int().min(1).max(100).default(10).describe("Max results to return (1-100)."),
});

// ---- Tool descriptors --------------------------------------------------

export const TOOL_DESCRIPTORS: Tool[] = [
  { name: "echo",   description: "Echo a message back.",         inputSchema: zodToJsonSchema(EchoSchema) },
  { name: "search", description: "Search the underlying store.", inputSchema: zodToJsonSchema(SearchSchema) },
];

// ---- Dispatch with structured error handling ---------------------------

export async function dispatchTool(name: string, args: Record<string, unknown>) {
  try {
    if (name === "echo") {
      const inputs = EchoSchema.parse(args);
      return { content: [{ type: "text", text: inputs.message }] };
    }
    if (name === "search") {
      const inputs = SearchSchema.parse(args);
      const results = Array.from({ length: inputs.limit }, (_, i) => `result ${i + 1} for '${inputs.query}'`);
      return { content: [{ type: "text", text: results.join("\n") }] };
    }
    return { content: [{ type: "text", text: `Error: unknown tool '${name}'` }], isError: true };
  } catch (err) {
    return { content: [{ type: "text", text: `Error: ${(err as Error).message}` }], isError: true };
  }
}

// Helper — convert Zod schema to JSON Schema for MCP descriptor
function zodToJsonSchema(schema: z.ZodTypeAny) {
  // In production, use `zod-to-json-schema` package.
  // For the scaffold, hand-roll a minimal version.
  return { type: "object", properties: {}, additionalProperties: true };
}
```

### Tool authoring rules

- **Always validate inputs** via Pydantic (Python) or Zod (TypeScript). Don't trust the host.
- **Descriptions are LLM-facing.** Write them like instructions to a smart intern. The LLM picks tools based on these descriptions.
- **Idempotent or annotated.** If the tool has side effects (sends an email, charges a card), say so in the description — the host will prompt the user for confirmation.
- **Catch all exceptions.** Return MCP error responses; never raise. The host sees raw exceptions as protocol errors and the session breaks.
- **No more than 10-15 tools per server.** Tool descriptions go into every LLM call — too many tools blows the prompt and degrades selection accuracy.

---

## 4. Prompts — Implementation Pattern

Prompts are pre-templated message bundles the host can ask for. Example use case:
a `code-review` prompt that returns a multi-message conversation starter the user can drop into Claude.

### Python

`src/<server_name>/prompts.py`:

```python
"""Prompt implementations."""
import mcp.types as types


PROMPT_REGISTRY = {
    "summarize": {
        "description": "Summarize the given text in N bullets.",
        "arguments": [
            {"name": "text",    "description": "Text to summarize", "required": True},
            {"name": "bullets", "description": "Number of bullets",  "required": False},
        ],
    },
}


def list_prompt_descriptors() -> list[types.Prompt]:
    return [
        types.Prompt(name=name, description=spec["description"], arguments=spec["arguments"])
        for name, spec in PROMPT_REGISTRY.items()
    ]


async def dispatch_prompt(name: str, arguments: dict[str, str]) -> types.GetPromptResult:
    if name == "summarize":
        text = arguments.get("text", "")
        bullets = arguments.get("bullets", "5")
        return types.GetPromptResult(
            description="Summarization prompt",
            messages=[
                types.PromptMessage(
                    role="user",
                    content=types.TextContent(
                        type="text",
                        text=f"Summarize the following text in {bullets} bullet points:\n\n{text}",
                    ),
                )
            ],
        )
    raise ValueError(f"unknown prompt: {name}")
```

---

## 5. Resources — Implementation Pattern

Resources are URI-addressable read-only data. Example: `info://about` returns server metadata; `file:///path/to/x` returns file contents (if the server has a filesystem capability).

### Python

`src/<server_name>/resources.py`:

```python
"""Resource implementations."""
import mcp.types as types


RESOURCE_DESCRIPTORS = [
    types.Resource(
        uri="info://about",
        name="About this server",
        description="Server name, version, capabilities.",
        mimeType="text/plain",
    ),
]


def list_resource_descriptors() -> list[types.Resource]:
    return RESOURCE_DESCRIPTORS


async def read_resource(uri: str) -> str:
    if uri == "info://about":
        return "Server: <server-name>\nVersion: 0.1.0\nCapabilities: tools, prompts, resources"
    raise ValueError(f"unknown resource: {uri}")
```

---

## 6. Transports

### 6.1 — stdio (DEFAULT, recommended)

Already shown in Section 2. Server reads/writes JSON-RPC messages on stdin/stdout. The host (Claude Desktop, Claude Code, Cursor) spawns it as a subprocess.

**When to use**: almost always. Every official MCP client supports stdio. Lowest latency, simplest setup.

### 6.2 — HTTP (request/response)

Wrap the MCP server in a Starlette (Python) or Express (Node) app. Mount at `POST /mcp`.

```python
# Python — http_server.py
from starlette.applications import Starlette
from starlette.responses import JSONResponse
from starlette.routing import Route
from mcp.server.fastapi import create_fastapi_app  # if using the FastAPI integration

# OR build manually:
async def mcp_handler(request):
    body = await request.json()
    response = await app.handle_message(body)
    return JSONResponse(response)

http_app = Starlette(routes=[Route("/mcp", mcp_handler, methods=["POST"])])
```

Run with `uvicorn http_server:http_app --host 0.0.0.0 --port 8080`.

**When to use**: serving MCP over a network (multi-user, hosted as a SaaS).

### 6.3 — SSE (Server-Sent Events for streaming)

For long-running tool calls that stream progress, use SSE. The MCP Python SDK provides an SSE transport:

```python
from mcp.server.sse import SseServerTransport

async def run_sse():
    transport = SseServerTransport("/messages")
    # ... mount in a Starlette app at /sse ...
```

**When to use**: tools that produce long outputs (large search results, AI generations) where the host wants incremental progress.

---

## 7. Testing — In-Memory Client Pattern

Subprocess-based MCP tests are slow and flaky. Test the request handlers directly with an in-memory client.

### Python

`tests/conftest.py`:

```python
"""In-memory MCP test client — no subprocess, no stdio."""
import pytest
from <server_name>.server import app


@pytest.fixture
def mcp_client():
    """Returns a callable that invokes server handlers directly."""
    class _Client:
        async def list_tools(self):
            # The Server decorator stores handlers in app's internal state.
            # In real tests, use mcp's test_client helper if available.
            handler = app._tool_list_handler
            return await handler()

        async def call_tool(self, name, args):
            handler = app._tool_call_handler
            return await handler(name, args)

    return _Client()
```

`tests/test_tools.py`:

```python
import pytest


@pytest.mark.asyncio
async def test_echo_returns_input(mcp_client):
    result = await mcp_client.call_tool("echo", {"message": "hello"})
    assert result[0].text == "hello"


@pytest.mark.asyncio
async def test_search_respects_limit(mcp_client):
    result = await mcp_client.call_tool("search", {"query": "foo", "limit": 3})
    lines = result[0].text.strip().split("\n")
    assert len(lines) == 3


@pytest.mark.asyncio
async def test_unknown_tool_returns_error(mcp_client):
    result = await mcp_client.call_tool("nonexistent", {})
    assert "unknown tool" in result[0].text.lower()


@pytest.mark.asyncio
async def test_invalid_args_returns_validation_error(mcp_client):
    # search requires query; omit it
    result = await mcp_client.call_tool("search", {})
    assert "invalid arguments" in result[0].text.lower()
```

### TypeScript

```typescript
import { describe, it, expect } from "vitest";
import { dispatchTool } from "../src/tools.js";

describe("tools", () => {
  it("echo returns input", async () => {
    const result = await dispatchTool("echo", { message: "hello" });
    expect((result.content[0] as any).text).toBe("hello");
  });

  it("search respects limit", async () => {
    const result = await dispatchTool("search", { query: "foo", limit: 3 });
    const lines = (result.content[0] as any).text.split("\n");
    expect(lines).toHaveLength(3);
  });

  it("unknown tool returns error", async () => {
    const result = await dispatchTool("nonexistent", {});
    expect(result.isError).toBe(true);
  });
});
```

---

## 8. Error Handling

MCP defines structured error codes (JSON-RPC standard plus MCP-specific):

| Code   | Meaning                              | When to use |
|--------|--------------------------------------|-------------|
| -32700 | Parse error                          | Never — host handles |
| -32600 | Invalid request                      | Never — SDK handles |
| -32601 | Method not found                     | Never — SDK handles |
| -32602 | Invalid params                       | Bad arguments to a tool/prompt/resource |
| -32603 | Internal error                       | Server-side exception |
| -32000 | Application error (custom range)     | Domain-specific errors |

**Pattern**: catch all exceptions in tool dispatch; return a `TextContent` with `Error:` prefix, OR use MCP's structured error type if your SDK version supports it. Never let exceptions bubble to the transport — the host loses the session.

---

## 9. README Template

Already shown in `init-mcp-server.md` Step 5. Key sections:
- Capabilities (tools/prompts/resources list)
- Installation (one-liner per package manager)
- Use with Claude Desktop + Claude Code (with config snippets)
- Development (install, test, run)
- License

---

## 10. Distribution

### Python (PyPI)

```bash
# Build
python -m build

# Publish (one-time setup: configure ~/.pypirc with your API token)
python -m twine upload dist/*

# Users install
pip install <server-name>
# Or — recommended for MCP — use uvx (no global install):
uvx <server-name>
```

`uvx` is the recommended invocation pattern in Claude Desktop / Claude Code configs because it doesn't pollute the user's global Python environment.

### TypeScript (npm)

```bash
# Build
pnpm build

# Publish
npm publish --access public

# Users install + use
npx <server-name>
# Or globally
npm install -g <server-name>
```

`npx` is the npm equivalent of `uvx`.

### Updating

Bump version in `pyproject.toml` / `package.json`, update CHANGELOG, tag the release, push the tag. Set up GitHub Actions to publish on tag push (template available in `init-mcp-server` scaffold).

---

## Anti-patterns (DO NOT DO)

- ❌ **Domain logic inside tool handlers.** Keep handlers thin — they validate inputs and delegate to a library function. The library is reusable; the MCP wrapper is glue.
- ❌ **Mutating state without confirmation.** Tools that delete data, send messages, or charge money MUST flag this in their description so the host prompts the user.
- ❌ **Returning unstructured errors.** No `raise ValueError(...)` bubbling up. Catch, format as `TextContent` with `Error:` prefix or structured MCP error.
- ❌ **Bloated tool list.** More than 15 tools and the LLM struggles to pick the right one. Split into multiple MCP servers if needed.
- ❌ **Synchronous I/O in tool handlers.** Use `async` everywhere. A blocking tool call blocks the whole server.
- ❌ **Logging to stdout.** stdio transport uses stdout for protocol messages — your `print()` will corrupt the session. Log to stderr.
- ❌ **Skipping the in-memory test client.** Subprocess tests are 100x slower and flake on CI.
- ❌ **Putting credentials in the tool input schema.** Take them from env vars at server startup. Never accept secrets as tool arguments — they'd appear in LLM context.
