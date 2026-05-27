# CODE_PATTERNS_GENAI.md — GenAI / LLM Code Patterns

> **Domain**: GenAI, LLM, RAG, Agents | See also: [RAG_BEST_PRACTICES.md](RAG_BEST_PRACTICES.md)
>
> Load this file on demand when writing GenAI, LLM, RAG, or Agent code.

---

## 1. LiteLLM Gateway Setup with Fallback Models

LiteLLM provides a unified interface to 100+ LLM providers. ALWAYS use LiteLLM instead of direct provider SDKs.

### Python/FastAPI Setup

```python
# core/llm_gateway.py
import litellm
from litellm import Router
from app.core.config import settings

# Configure LiteLLM
litellm.set_verbose = False  # True only in dev
litellm.drop_params = True   # Auto-drop unsupported params per model
litellm.success_callback = ["langfuse"]  # Optional: LLM observability
litellm.failure_callback = ["langfuse"]

# Model Router with fallbacks
model_list = [
    {
        "model_name": "primary",
        "litellm_params": {
            "model": "gpt-4o-mini",
            "api_key": settings.OPENAI_API_KEY,
        },
    },
    {
        "model_name": "primary",  # Same name = fallback
        "litellm_params": {
            "model": "claude-3-5-haiku-20241022",
            "api_key": settings.ANTHROPIC_API_KEY,
        },
    },
    {
        "model_name": "primary",
        "litellm_params": {
            "model": "gemini/gemini-2.0-flash",
            "api_key": settings.GOOGLE_API_KEY,
        },
    },
    {
        "model_name": "powerful",
        "litellm_params": {
            "model": "gpt-4o",
            "api_key": settings.OPENAI_API_KEY,
        },
    },
    {
        "model_name": "powerful",
        "litellm_params": {
            "model": "claude-3-5-sonnet-20241022",
            "api_key": settings.ANTHROPIC_API_KEY,
        },
    },
]

router = Router(
    model_list=model_list,
    routing_strategy="simple-shuffle",  # or "latency-based-routing"
    num_retries=2,
    timeout=30,
    retry_after=5,
    fallbacks=[
        {"primary": ["primary"]},   # Fallback within same tier
        {"powerful": ["powerful"]},
    ],
)


async def generate(
    messages: list[dict],
    model: str = "primary",
    temperature: float = 0.7,
    max_tokens: int = 1000,
    response_format: dict | None = None,
    **kwargs,
) -> str:
    """Unified LLM call with automatic fallbacks."""
    response = await router.acompletion(
        model=model,
        messages=messages,
        temperature=temperature,
        max_tokens=max_tokens,
        response_format=response_format,
        **kwargs,
    )
    return response.choices[0].message.content


async def embed(
    texts: list[str],
    model: str = "text-embedding-3-small",
) -> list[list[float]]:
    """Unified embedding call."""
    response = await litellm.aembedding(
        model=model,
        input=texts,
    )
    return [item["embedding"] for item in response.data]
```

### Node.js/NestJS Setup

```typescript
// core/llm-gateway.service.ts
import { Injectable, OnModuleInit } from '@nestjs/common';
import OpenAI from 'openai';
import Anthropic from '@anthropic-ai/sdk';

@Injectable()
export class LLMGatewayService implements OnModuleInit {
  private openai: OpenAI;
  private anthropic: Anthropic;
  private models = {
    primary: ['gpt-4o-mini', 'claude-3-5-haiku-20241022'],
    powerful: ['gpt-4o', 'claude-3-5-sonnet-20241022'],
  };

  onModuleInit() {
    this.openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
    this.anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
  }

  async generate(
    messages: Array<{ role: string; content: string }>,
    tier: 'primary' | 'powerful' = 'primary',
  ): Promise<string> {
    const modelList = this.models[tier];
    for (const model of modelList) {
      try {
        if (model.startsWith('gpt') || model.startsWith('o1')) {
          const response = await this.openai.chat.completions.create({
            model, messages: messages as any, max_tokens: 1000,
          });
          return response.choices[0].message.content ?? '';
        } else if (model.startsWith('claude')) {
          const response = await this.anthropic.messages.create({
            model, max_tokens: 1000,
            messages: messages.filter((m) => m.role !== 'system') as any,
            system: messages.find((m) => m.role === 'system')?.content,
          });
          return response.content[0].type === 'text' ? response.content[0].text : '';
        }
      } catch (error) {
        console.warn(`Model ${model} failed, trying next fallback...`, error.message);
        continue;
      }
    }
    throw new Error('All LLM models failed');
  }
}
```

---

## 2. RAG Pipeline (Embed -> Store -> Retrieve -> Rerank -> Generate)

### Complete Python RAG Pipeline

```python
# services/rag_service.py
from typing import Optional
import litellm
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct, Filter, FieldCondition, MatchValue
import hashlib
import json

class RAGService:
    """Full RAG pipeline: embed -> store -> retrieve -> rerank -> generate."""

    def __init__(self):
        self.qdrant = QdrantClient(url=settings.QDRANT_URL)
        self.collection = "knowledge_base"
        self.embed_model = "text-embedding-3-small"
        self.gen_model = "primary"  # Uses LiteLLM router

    # ---- EMBED ----
    async def embed_texts(self, texts: list[str]) -> list[list[float]]:
        """Batch embed texts. Process in batches of 100 for efficiency."""
        all_embeddings = []
        batch_size = 100
        for i in range(0, len(texts), batch_size):
            batch = texts[i:i + batch_size]
            response = await litellm.aembedding(
                model=self.embed_model,
                input=batch,
            )
            all_embeddings.extend([item["embedding"] for item in response.data])
        return all_embeddings

    # ---- STORE ----
    async def index_documents(
        self, documents: list[dict], collection: str | None = None
    ):
        """Index documents into vector store.
        Each document: {"id": str, "text": str, "metadata": dict}
        """
        coll = collection or self.collection
        texts = [doc["text"] for doc in documents]
        embeddings = await self.embed_texts(texts)

        points = [
            PointStruct(
                id=hashlib.md5(doc["id"].encode()).hexdigest()[:16],
                vector=embedding,
                payload={
                    "text": doc["text"],
                    "doc_id": doc["id"],
                    **doc.get("metadata", {}),
                },
            )
            for doc, embedding in zip(documents, embeddings)
        ]

        # Upsert in batches
        batch_size = 100
        for i in range(0, len(points), batch_size):
            self.qdrant.upsert(
                collection_name=coll,
                points=points[i:i + batch_size],
            )

    # ---- RETRIEVE ----
    async def retrieve(
        self,
        query: str,
        top_k: int = 10,
        filters: dict | None = None,
        score_threshold: float = 0.3,
    ) -> list[dict]:
        """Retrieve relevant documents for a query."""
        query_vector = (await self.embed_texts([query]))[0]

        qdrant_filter = None
        if filters:
            conditions = [
                FieldCondition(key=k, match=MatchValue(value=v))
                for k, v in filters.items()
            ]
            qdrant_filter = Filter(must=conditions)

        results = self.qdrant.search(
            collection_name=self.collection,
            query_vector=query_vector,
            limit=top_k,
            score_threshold=score_threshold,
            query_filter=qdrant_filter,
        )

        return [
            {
                "text": r.payload["text"],
                "score": r.score,
                "doc_id": r.payload.get("doc_id"),
                "metadata": {k: v for k, v in r.payload.items() if k not in ("text", "doc_id")},
            }
            for r in results
        ]

    # ---- RERANK ----
    async def rerank(
        self, query: str, documents: list[dict], top_k: int = 5
    ) -> list[dict]:
        """Rerank retrieved documents using a cross-encoder or LLM."""
        if not documents:
            return []

        # Option 1: Use Cohere Rerank
        try:
            import cohere
            co = cohere.Client(settings.COHERE_API_KEY)
            rerank_response = co.rerank(
                query=query,
                documents=[d["text"] for d in documents],
                top_n=top_k,
                model="rerank-english-v3.0",
            )
            return [
                {**documents[r.index], "rerank_score": r.relevance_score}
                for r in rerank_response.results
            ]
        except (ImportError, Exception):
            pass

        # Option 2: Reciprocal Rank Fusion (no external API needed)
        # Already sorted by score from vector search, just take top_k
        return documents[:top_k]

    # ---- GENERATE ----
    async def generate(
        self,
        query: str,
        context_docs: list[dict],
        system_prompt: str | None = None,
        conversation_history: list[dict] | None = None,
    ) -> dict:
        """Generate answer using retrieved context."""
        context = "\n\n---\n\n".join([
            f"[Source: {d.get('doc_id', 'unknown')}]\n{d['text']}"
            for d in context_docs
        ])

        default_system = (
            "You are a helpful assistant. Answer the user's question based on the "
            "provided context. If the answer is not in the context, say so clearly. "
            "Cite sources when possible using [Source: id] format."
        )

        messages = [
            {"role": "system", "content": system_prompt or default_system},
            {"role": "user", "content": f"Context:\n{context}\n\nQuestion: {query}"},
        ]

        if conversation_history:
            messages = [messages[0]] + conversation_history + [messages[-1]]

        from app.core.llm_gateway import generate as llm_generate
        answer = await llm_generate(messages=messages, model=self.gen_model)

        return {
            "answer": answer,
            "sources": [
                {"doc_id": d.get("doc_id"), "score": d.get("score", 0)}
                for d in context_docs
            ],
        }

    # ---- FULL PIPELINE ----
    async def query(
        self,
        question: str,
        top_k: int = 5,
        filters: dict | None = None,
        rerank: bool = True,
        system_prompt: str | None = None,
        conversation_history: list[dict] | None = None,
    ) -> dict:
        """Full RAG pipeline: retrieve -> rerank -> generate."""
        # Step 1: Retrieve
        candidates = await self.retrieve(
            query=question, top_k=top_k * 2 if rerank else top_k, filters=filters,
        )

        # Step 2: Rerank (optional)
        if rerank and len(candidates) > top_k:
            candidates = await self.rerank(question, candidates, top_k=top_k)
        else:
            candidates = candidates[:top_k]

        # Step 3: Generate
        result = await self.generate(
            query=question,
            context_docs=candidates,
            system_prompt=system_prompt,
            conversation_history=conversation_history,
        )

        return result
```

---

## 3. Function Calling / Tool Use Patterns

```python
# services/tool_use_service.py
import litellm
import json
from typing import Callable

# Define tools
tools = [
    {
        "type": "function",
        "function": {
            "name": "search_database",
            "description": "Search the database for records matching a query",
            "parameters": {
                "type": "object",
                "properties": {
                    "table": {"type": "string", "description": "Table name to search"},
                    "query": {"type": "string", "description": "Search query"},
                    "limit": {"type": "integer", "default": 10},
                },
                "required": ["table", "query"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "calculate_metric",
            "description": "Calculate a business metric for a given time range",
            "parameters": {
                "type": "object",
                "properties": {
                    "metric_name": {"type": "string"},
                    "start_date": {"type": "string", "format": "date"},
                    "end_date": {"type": "string", "format": "date"},
                },
                "required": ["metric_name", "start_date", "end_date"],
            },
        },
    },
]

# Tool implementations
tool_registry: dict[str, Callable] = {}

def register_tool(name: str):
    def decorator(func):
        tool_registry[name] = func
        return func
    return decorator

@register_tool("search_database")
async def search_database(table: str, query: str, limit: int = 10) -> dict:
    # Implementation
    return {"results": [], "count": 0}

@register_tool("calculate_metric")
async def calculate_metric(metric_name: str, start_date: str, end_date: str) -> dict:
    # Implementation
    return {"metric": metric_name, "value": 0}


async def agent_loop(
    user_message: str,
    system_prompt: str,
    max_iterations: int = 5,
) -> str:
    """Tool-use agent loop with automatic function calling."""
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_message},
    ]

    for _ in range(max_iterations):
        response = await litellm.acompletion(
            model="gpt-4o",
            messages=messages,
            tools=tools,
            tool_choice="auto",
        )

        choice = response.choices[0]

        # If no tool call, return the final answer
        if choice.finish_reason == "stop":
            return choice.message.content

        # Execute tool calls
        if choice.message.tool_calls:
            messages.append(choice.message.model_dump())
            for tool_call in choice.message.tool_calls:
                func_name = tool_call.function.name
                func_args = json.loads(tool_call.function.arguments)

                if func_name in tool_registry:
                    result = await tool_registry[func_name](**func_args)
                else:
                    result = {"error": f"Unknown tool: {func_name}"}

                messages.append({
                    "role": "tool",
                    "tool_call_id": tool_call.id,
                    "content": json.dumps(result),
                })

    return "Max iterations reached without a final answer."
```

---

## 4. Streaming SSE Responses

```python
# api/routes/chat.py
from fastapi import APIRouter, Request
from fastapi.responses import StreamingResponse
import litellm
import json
import asyncio

router = APIRouter()

@router.post("/api/chat/stream")
async def chat_stream(request: Request):
    body = await request.json()
    messages = body.get("messages", [])

    async def event_generator():
        try:
            response = await litellm.acompletion(
                model="gpt-4o-mini",
                messages=messages,
                stream=True,
            )
            async for chunk in response:
                delta = chunk.choices[0].delta
                if delta.content:
                    data = json.dumps({"type": "content", "text": delta.content})
                    yield f"data: {data}\n\n"
                if chunk.choices[0].finish_reason == "stop":
                    yield f"data: {json.dumps({'type': 'done'})}\n\n"
        except Exception as e:
            yield f"data: {json.dumps({'type': 'error', 'message': str(e)})}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",  # Disable nginx buffering
        },
    )
```

### Frontend SSE Consumer

```typescript
// hooks/useChat.ts
import { useState, useCallback, useRef } from 'react';

interface Message {
  role: 'user' | 'assistant';
  content: string;
}

export function useChat() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [isStreaming, setIsStreaming] = useState(false);
  const abortRef = useRef<AbortController | null>(null);

  const sendMessage = useCallback(async (content: string) => {
    const userMessage: Message = { role: 'user', content };
    const newMessages = [...messages, userMessage];
    setMessages([...newMessages, { role: 'assistant', content: '' }]);
    setIsStreaming(true);

    abortRef.current = new AbortController();

    try {
      const response = await fetch('/api/chat/stream', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ messages: newMessages }),
        signal: abortRef.current.signal,
      });

      const reader = response.body?.getReader();
      const decoder = new TextDecoder();
      let assistantContent = '';

      while (reader) {
        const { done, value } = await reader.read();
        if (done) break;

        const text = decoder.decode(value, { stream: true });
        const lines = text.split('\n').filter((line) => line.startsWith('data: '));

        for (const line of lines) {
          const data = JSON.parse(line.slice(6));
          if (data.type === 'content') {
            assistantContent += data.text;
            setMessages((prev) => [
              ...prev.slice(0, -1),
              { role: 'assistant', content: assistantContent },
            ]);
          } else if (data.type === 'done') {
            break;
          } else if (data.type === 'error') {
            console.error('Stream error:', data.message);
          }
        }
      }
    } catch (error) {
      if ((error as Error).name !== 'AbortError') {
        console.error('Chat error:', error);
      }
    } finally {
      setIsStreaming(false);
    }
  }, [messages]);

  const stopStreaming = useCallback(() => {
    abortRef.current?.abort();
    setIsStreaming(false);
  }, []);

  return { messages, sendMessage, isStreaming, stopStreaming };
}
```

---

## 5. Prompt Templates with Jinja2

```python
# core/prompt_templates.py
from jinja2 import Environment, FileSystemLoader, select_autoescape
from pathlib import Path

# Load templates from prompts/ directory
env = Environment(
    loader=FileSystemLoader(Path(__file__).parent.parent / "prompts"),
    autoescape=select_autoescape(),
    trim_blocks=True,
    lstrip_blocks=True,
)

def render_prompt(template_name: str, **kwargs) -> str:
    """Render a prompt template with variables."""
    template = env.get_template(f"{template_name}.j2")
    return template.render(**kwargs)


# Example template: prompts/rag_answer.j2
"""
You are a helpful assistant for {{ app_name }}.

## Instructions
- Answer based ONLY on the provided context
- If the answer is not in the context, say "I don't have information about that"
- Cite sources using [Source: ID] format
- Be concise and accurate

## Context
{% for doc in context_docs %}
[Source: {{ doc.doc_id }}]
{{ doc.text }}
---
{% endfor %}

## Conversation History
{% for msg in history %}
{{ msg.role }}: {{ msg.content }}
{% endfor %}

## Current Question
{{ question }}
"""

# Usage:
prompt = render_prompt(
    "rag_answer",
    app_name="SmartQL",
    context_docs=retrieved_docs,
    history=conversation_history,
    question=user_query,
)
```

---

## 6. Token Counting and Cost Tracking

```python
# core/token_tracker.py
import tiktoken
from dataclasses import dataclass

# Model pricing per 1M tokens (input, output) in USD
MODEL_PRICING = {
    "gpt-4o": (2.50, 10.00),
    "gpt-4o-mini": (0.15, 0.60),
    "claude-3-5-sonnet-20241022": (3.00, 15.00),
    "claude-3-5-haiku-20241022": (0.25, 1.25),
    "gemini-2.0-flash": (0.10, 0.40),
    "text-embedding-3-small": (0.02, 0.0),
    "text-embedding-3-large": (0.13, 0.0),
}

@dataclass
class TokenUsage:
    input_tokens: int
    output_tokens: int
    model: str

    @property
    def total_tokens(self) -> int:
        return self.input_tokens + self.output_tokens

    @property
    def cost_usd(self) -> float:
        input_price, output_price = MODEL_PRICING.get(self.model, (0.15, 0.60))
        return (
            self.input_tokens * input_price / 1_000_000
            + self.output_tokens * output_price / 1_000_000
        )


def count_tokens(text: str, model: str = "gpt-4o-mini") -> int:
    """Count tokens for a given text and model."""
    try:
        encoding = tiktoken.encoding_for_model(model)
    except KeyError:
        encoding = tiktoken.get_encoding("cl100k_base")
    return len(encoding.encode(text))


def count_messages_tokens(messages: list[dict], model: str = "gpt-4o-mini") -> int:
    """Count tokens in a messages array (includes message overhead)."""
    total = 0
    for msg in messages:
        total += 4  # message overhead tokens
        total += count_tokens(msg.get("content", ""), model)
        total += count_tokens(msg.get("role", ""), model)
    total += 2  # reply priming
    return total


def fits_context(
    messages: list[dict], max_tokens: int, model: str = "gpt-4o-mini"
) -> bool:
    """Check if messages fit within the model's context window."""
    return count_messages_tokens(messages, model) < max_tokens
```

---

## 7. Guardrails (Input Validation, Output Filtering, PII Redaction)

```python
# core/guardrails.py
import re
import litellm
import json

class LLMGuardrails:
    """Input/output guardrails for LLM calls."""

    # Input guardrails
    PII_PATTERNS = {
        "email": r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}",
        "phone": r"(\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}",
        "ssn": r"\d{3}-\d{2}-\d{4}",
        "credit_card": r"\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}",
    }

    INJECTION_PATTERNS = [
        r"ignore.*previous.*instructions",
        r"ignore.*all.*prior",
        r"disregard.*system.*prompt",
        r"you are now",
        r"pretend you are",
        r"act as if",
        r"reveal.*system.*prompt",
        r"output.*your.*instructions",
    ]

    def redact_pii(self, text: str) -> str:
        """Redact PII from input text before sending to LLM."""
        for pii_type, pattern in self.PII_PATTERNS.items():
            text = re.sub(pattern, f"[REDACTED_{pii_type.upper()}]", text)
        return text

    def detect_injection(self, text: str) -> bool:
        """Detect prompt injection attempts."""
        text_lower = text.lower()
        for pattern in self.INJECTION_PATTERNS:
            if re.search(pattern, text_lower):
                return True
        return False

    def validate_input(self, text: str, max_length: int = 10000) -> dict:
        """Validate user input before LLM call."""
        issues = []
        if len(text) > max_length:
            issues.append(f"Input too long: {len(text)} chars (max {max_length})")
        if self.detect_injection(text):
            issues.append("Potential prompt injection detected")
        if not text.strip():
            issues.append("Empty input")
        return {"valid": len(issues) == 0, "issues": issues}

    # Output guardrails
    def validate_output(self, output: str) -> dict:
        """Validate LLM output before returning to user."""
        issues = []
        # Check for leaked system prompts
        if any(phrase in output.lower() for phrase in [
            "my instructions are", "i was told to", "system prompt"
        ]):
            issues.append("Possible system prompt leakage")

        # Check for PII in output
        for pii_type, pattern in self.PII_PATTERNS.items():
            if re.search(pattern, output):
                issues.append(f"Output contains {pii_type}")

        return {"valid": len(issues) == 0, "issues": issues}

    # Cost guardrails
    async def check_budget(
        self, user_id: int, estimated_cost: float, redis_client
    ) -> bool:
        """Check if user has remaining budget for this request."""
        key = f"llm_cost:{user_id}:daily"
        current = await redis_client.get(key)
        current_cost = float(current) if current else 0.0
        daily_limit = 1.0  # $1/day default
        return (current_cost + estimated_cost) <= daily_limit
```

---

## 8. Semantic Caching with Redis

```python
# core/semantic_cache.py
import json
import hashlib
import numpy as np
from redis.asyncio import Redis
import litellm

class SemanticCache:
    """Cache LLM responses based on semantic similarity of queries."""

    def __init__(self, redis: Redis, similarity_threshold: float = 0.92):
        self.redis = redis
        self.threshold = similarity_threshold
        self.prefix = "sem_cache:"
        self.ttl = 3600  # 1 hour default

    async def get(self, query: str, context_hash: str = "") -> str | None:
        """Check if a semantically similar query was cached."""
        query_embedding = await self._embed(query)

        # Check exact match first (fast path)
        exact_key = self._exact_key(query, context_hash)
        exact = await self.redis.get(exact_key)
        if exact:
            return json.loads(exact)["response"]

        # Check semantic similarity (slower path)
        cache_keys = []
        async for key in self.redis.scan_iter(f"{self.prefix}vec:*"):
            cache_keys.append(key)

        for key in cache_keys[:100]:  # Limit scan for performance
            cached = await self.redis.get(key)
            if not cached:
                continue
            data = json.loads(cached)
            if data.get("context_hash") != context_hash:
                continue
            cached_embedding = data["embedding"]
            similarity = self._cosine_similarity(query_embedding, cached_embedding)
            if similarity >= self.threshold:
                return data["response"]

        return None

    async def set(
        self, query: str, response: str, context_hash: str = "", ttl: int | None = None
    ):
        """Cache a response for a query."""
        embedding = await self._embed(query)
        data = {
            "query": query,
            "response": response,
            "embedding": embedding,
            "context_hash": context_hash,
        }
        # Store exact match
        exact_key = self._exact_key(query, context_hash)
        await self.redis.setex(exact_key, ttl or self.ttl, json.dumps(data))
        # Store vector match
        vec_key = f"{self.prefix}vec:{hashlib.md5(query.encode()).hexdigest()}"
        await self.redis.setex(vec_key, ttl or self.ttl, json.dumps(data))

    async def _embed(self, text: str) -> list[float]:
        response = await litellm.aembedding(
            model="text-embedding-3-small",
            input=[text],
        )
        return response.data[0]["embedding"]

    def _exact_key(self, query: str, context_hash: str) -> str:
        h = hashlib.md5(f"{query}:{context_hash}".encode()).hexdigest()
        return f"{self.prefix}exact:{h}"

    @staticmethod
    def _cosine_similarity(a: list[float], b: list[float]) -> float:
        a_arr = np.array(a)
        b_arr = np.array(b)
        return float(np.dot(a_arr, b_arr) / (np.linalg.norm(a_arr) * np.linalg.norm(b_arr)))
```

---

## 9. Multi-Modal Patterns (Vision, Audio)

```python
# services/multimodal_service.py
import litellm
import base64
from pathlib import Path

class MultiModalService:

    async def analyze_image(self, image_path: str, prompt: str) -> str:
        """Analyze an image using vision model."""
        with open(image_path, "rb") as f:
            image_data = base64.b64encode(f.read()).decode("utf-8")
        ext = Path(image_path).suffix.lstrip(".")
        mime = {"png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "gif": "image/gif", "webp": "image/webp"}.get(ext, "image/png")

        response = await litellm.acompletion(
            model="gpt-4o",
            messages=[{
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {"type": "image_url", "image_url": {"url": f"data:{mime};base64,{image_data}"}},
                ],
            }],
            max_tokens=1000,
        )
        return response.choices[0].message.content

    async def analyze_image_url(self, image_url: str, prompt: str) -> str:
        """Analyze an image from URL."""
        response = await litellm.acompletion(
            model="gpt-4o",
            messages=[{
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {"type": "image_url", "image_url": {"url": image_url}},
                ],
            }],
            max_tokens=1000,
        )
        return response.choices[0].message.content

    async def transcribe_audio(self, audio_path: str) -> str:
        """Transcribe audio using Whisper."""
        from openai import AsyncOpenAI
        client = AsyncOpenAI()
        with open(audio_path, "rb") as f:
            transcript = await client.audio.transcriptions.create(
                model="whisper-1",
                file=f,
                response_format="text",
            )
        return transcript
```

---

## 10. Agent Patterns (ReAct, Plan-and-Execute)

```python
# services/agent_service.py
import litellm
import json

class ReActAgent:
    """ReAct (Reasoning + Acting) agent pattern."""

    def __init__(self, tools: list[dict], tool_registry: dict):
        self.tools = tools
        self.tool_registry = tool_registry
        self.system_prompt = (
            "You are an AI agent that solves tasks step by step.\n"
            "For each step:\n"
            "1. THINK: Reason about what to do next\n"
            "2. ACT: Call a tool if needed\n"
            "3. OBSERVE: Review the tool result\n"
            "4. Repeat until you have the final answer\n"
            "When you have the final answer, respond directly without tool calls."
        )

    async def run(self, task: str, max_steps: int = 10) -> str:
        messages = [
            {"role": "system", "content": self.system_prompt},
            {"role": "user", "content": task},
        ]

        for step in range(max_steps):
            response = await litellm.acompletion(
                model="gpt-4o",
                messages=messages,
                tools=self.tools,
                tool_choice="auto",
            )

            choice = response.choices[0]

            if choice.finish_reason == "stop":
                return choice.message.content

            if choice.message.tool_calls:
                messages.append(choice.message.model_dump())
                for tc in choice.message.tool_calls:
                    func = self.tool_registry.get(tc.function.name)
                    args = json.loads(tc.function.arguments)
                    result = await func(**args) if func else {"error": "Unknown tool"}
                    messages.append({
                        "role": "tool",
                        "tool_call_id": tc.id,
                        "content": json.dumps(result),
                    })

        return "Agent did not converge within max steps."
```

---

## 11. Evaluation Patterns (DeepEval, RAGAS)

```python
# tests/test_rag_quality.py
"""RAG quality evaluation using DeepEval and RAGAS metrics."""

# DeepEval evaluation
from deepeval import evaluate
from deepeval.test_case import LLMTestCase
from deepeval.metrics import (
    AnswerRelevancyMetric,
    FaithfulnessMetric,
    ContextualRelevancyMetric,
)

def test_rag_quality():
    test_cases = [
        LLMTestCase(
            input="What is the return policy?",
            actual_output="Our return policy allows returns within 30 days...",
            retrieval_context=["Return policy: Items can be returned within 30 days..."],
            expected_output="Returns are accepted within 30 days of purchase.",
        ),
    ]

    metrics = [
        AnswerRelevancyMetric(threshold=0.7),
        FaithfulnessMetric(threshold=0.7),
        ContextualRelevancyMetric(threshold=0.7),
    ]

    evaluate(test_cases, metrics)


# RAGAS evaluation
from ragas import evaluate as ragas_evaluate
from ragas.metrics import faithfulness, answer_relevancy, context_recall, context_precision
from datasets import Dataset

def evaluate_rag_with_ragas(test_data: list[dict]):
    dataset = Dataset.from_list(test_data)
    # Each item: {"question": str, "answer": str, "contexts": list[str], "ground_truth": str}
    result = ragas_evaluate(
        dataset,
        metrics=[faithfulness, answer_relevancy, context_recall, context_precision],
    )
    return result
```

---

## 12. Error Handling (Rate Limits, Timeouts, Fallbacks)

```python
# core/llm_error_handling.py
import asyncio
import litellm
from litellm.exceptions import (
    RateLimitError,
    APIConnectionError,
    Timeout,
    ServiceUnavailableError,
)

async def resilient_llm_call(
    messages: list[dict],
    model: str = "gpt-4o-mini",
    max_retries: int = 3,
    timeout: float = 30.0,
    **kwargs,
) -> str:
    """LLM call with retry logic, timeouts, and fallbacks."""
    fallback_models = {
        "gpt-4o": ["claude-3-5-sonnet-20241022", "gemini-1.5-pro"],
        "gpt-4o-mini": ["claude-3-5-haiku-20241022", "gemini-2.0-flash"],
    }

    models_to_try = [model] + fallback_models.get(model, [])

    for current_model in models_to_try:
        for attempt in range(max_retries):
            try:
                response = await asyncio.wait_for(
                    litellm.acompletion(
                        model=current_model,
                        messages=messages,
                        **kwargs,
                    ),
                    timeout=timeout,
                )
                return response.choices[0].message.content

            except RateLimitError:
                wait = 2 ** attempt * 5  # 5s, 10s, 20s
                await asyncio.sleep(wait)
                continue

            except (Timeout, asyncio.TimeoutError):
                if attempt < max_retries - 1:
                    continue
                break  # Try next model

            except APIConnectionError:
                await asyncio.sleep(2)
                continue

            except ServiceUnavailableError:
                break  # Try next model immediately

            except Exception as e:
                if attempt == max_retries - 1:
                    break
                await asyncio.sleep(1)
                continue

    raise RuntimeError(f"All LLM models failed after retries: {models_to_try}")
```
