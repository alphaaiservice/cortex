---
name: genai
description: "Auto-invoked when writing ANY GenAI/LLM/agent code — LLM calls, prompts, RAG pipelines, embeddings, vector search, agents/tools (MCP/A2A), structured output, or AI evaluation. Enforces Alpha AI's AI-engineering standards: LiteLLM gateway with fallbacks (NEVER raw provider SDKs), input/output guardrails, hard cost caps, structured output, semantic caching, observability (Langfuse/LangSmith), and evals."
---

# GenAI / AI-Engineering Standards

This skill enforces Alpha AI's standards on every AI surface — LLM calls, prompts, RAG, agents, and evals. It is the AI counterpart to the backend layer rules in `alpha-architecture`. AI code that skips guardrails, cost caps, or the gateway is **not production-ready**.

Detailed patterns and gold-standard code live in `alpha-architecture/references/` — load them on demand (progressive disclosure):

- **`CODE_PATTERNS_GENAI.md`** — ⭐ LiteLLM gateway, prompts, agents, structured output, guardrails, caching
- **`RAG_BEST_PRACTICES.md`** — chunking, embeddings, retrieval, re-ranking, agentic RAG, eval

---

## Hard Rules (NON-NEGOTIABLE)

### 1. Gateway, never raw SDKs
- ✅ ALL LLM calls go through the **GenAI gateway** — LiteLLM (Python) · Vercel AI SDK (Node) · Spring AI (Java).
- ✅ Configure **fallback models** (same `model_name` = fallback chain) so one provider outage doesn't take down the feature.
- ❌ NEVER call `openai`, `anthropic`, `google.generativeai` SDKs directly in feature code.
- Default to the **latest Claude models** where the task fits: Opus 4.8 (`claude-opus-4-8`), Sonnet 4.6 (`claude-sonnet-4-6`), Haiku 4.5 (`claude-haiku-4-5-20251001`), Fable 5 (`claude-fable-5`).

### 2. Cost caps — ALWAYS
- ✅ Enforce per-request and per-user/tenant **token + spend caps** before the call.
- ✅ Track cost per request (input/output tokens × model price) and attribute it to a user/feature.
- ✅ Use **semantic caching** (Redis + embedding similarity > 0.95) to avoid paying twice for equivalent prompts.
- ❌ NEVER ship an LLM endpoint with no spend ceiling — it's a runaway-bill incident waiting to happen.

### 3. Guardrails — input AND output
- ✅ **Input**: prompt-injection / jailbreak detection, PII redaction, max-length + content filters before the model sees user text.
- ✅ **Output**: filter unsafe/off-policy content, validate shape, strip leaked secrets/system prompt before returning.
- ✅ **HITL** for low-confidence or high-impact actions: confidence threshold → review queue → approve/reject.

### 4. Structured output
- ✅ Force structured output via `instructor` + Pydantic (Python) · Zod (Node) · Spring AI structured — never regex-parse free text.
- ✅ Validate at the boundary and retry on schema mismatch.

### 5. Observability & evals
- ✅ Trace every LLM/agent call with **Langfuse or LangSmith** (latency, tokens, cost, prompt version).
- ✅ Version prompts (Jinja2/YAML templates or MCP Prompts) — no inline magic-string prompts scattered across files.
- ✅ Gate prompt/model changes with **evals** (DeepEval/RAGAS · Jest AI · JUnit AI + promptfoo) — don't ship a prompt change unmeasured.

### 6. RAG (when retrieval is involved) — see `RAG_BEST_PRACTICES.md`
- ✅ Semantic chunking · `text-embedding-3-large` (or current best) · **Qdrant** vector store.
- ✅ **Re-rank** post-retrieval (Cohere Rerank v3.5 / FlashRank) before stuffing context.
- ✅ Agentic RAG for hard queries: query decomposition + tool/web search fallback.
- ✅ Cite sources; evaluate retrieval quality (context precision/recall), not just generation.

### 7. Protocols (when exposing/consuming agents)
- ✅ **MCP** servers expose tools + prompts + resources over JSON-RPC 2.0 (scaffold with `/init-mcp-server`).
- ✅ **A2A**: publish an Agent Card at `/.well-known/agent.json`; honor the task lifecycle.

---

## Layer placement (with `alpha-architecture`)
AI logic lives in the **service layer** behind a gateway/client — controllers stay thin, repositories own data. Vector stores and embedding clients are infrastructure, accessed via repositories/clients, not from controllers.

## How this skill works with others
- `alpha-architecture` — owns the GenAI tech-stack catalog; this skill enforces it on AI code.
- `security` — prompt-injection, secrets, PII handling overlap here.
- `cost-estimator` — AI spend estimation; this skill enforces the runtime caps.
- `performance` — semantic caching + async/batch (Celery/BullMQ/@Async) for heavy AI jobs.
- The `ai-integration-specialist` agent does the deep build-out; this skill keeps every AI edit compliant by default.
