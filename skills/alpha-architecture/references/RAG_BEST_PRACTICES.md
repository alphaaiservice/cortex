# RAG_BEST_PRACTICES.md — Retrieval-Augmented Generation Best Practices

> **Domain**: RAG Pipelines | See also: [CODE_PATTERNS_GENAI.md](CODE_PATTERNS_GENAI.md)
>
> Load this file on demand when designing or optimizing RAG systems.

---

## 1. Chunking Strategies

The chunking strategy has the biggest impact on RAG quality. Choose based on your document types.

### 1.1 Fixed-Size Chunking

Simple, fast, works for homogeneous documents.

```python
def fixed_size_chunk(text: str, chunk_size: int = 500, overlap: int = 50) -> list[str]:
    """Split text into fixed-size chunks with overlap."""
    words = text.split()
    chunks = []
    for i in range(0, len(words), chunk_size - overlap):
        chunk = " ".join(words[i:i + chunk_size])
        if chunk.strip():
            chunks.append(chunk)
    return chunks
```

**When to use**: Uniform documents, logs, simple text files
**Pros**: Fast, predictable chunk sizes, simple to implement
**Cons**: Splits mid-sentence, loses context at boundaries

### 1.2 Recursive Character Chunking (LangChain default)

Splits by hierarchy of separators, preserving structure.

```python
from langchain.text_splitter import RecursiveCharacterTextSplitter

splitter = RecursiveCharacterTextSplitter(
    chunk_size=1000,       # Target chunk size in characters
    chunk_overlap=200,     # Overlap between chunks
    separators=["\n\n", "\n", ". ", " ", ""],  # Try these in order
    length_function=len,
)

chunks = splitter.split_text(document_text)
```

**When to use**: General-purpose, most common choice
**Pros**: Respects paragraph/sentence boundaries
**Cons**: Chunk sizes vary, may still split logical sections

### 1.3 Semantic Chunking

Groups text by semantic similarity — sentences about the same topic stay together.

```python
from langchain_experimental.text_splitter import SemanticChunker
from langchain_openai import OpenAIEmbeddings

semantic_chunker = SemanticChunker(
    OpenAIEmbeddings(model="text-embedding-3-small"),
    breakpoint_threshold_type="percentile",  # or "standard_deviation", "interquartile"
    breakpoint_threshold_amount=85,
)

chunks = semantic_chunker.split_text(document_text)
```

**When to use**: Long documents with topic shifts, mixed-content documents
**Pros**: Best retrieval quality, topic-coherent chunks
**Cons**: Requires embedding calls during chunking (slower, costs money)

### 1.4 Document-Aware Chunking

Respects document structure (headers, sections, code blocks).

```python
from langchain.text_splitter import MarkdownHeaderTextSplitter

# For Markdown documents
md_splitter = MarkdownHeaderTextSplitter(
    headers_to_split_on=[
        ("#", "h1"),
        ("##", "h2"),
        ("###", "h3"),
    ],
)

# For HTML documents
from langchain.text_splitter import HTMLHeaderTextSplitter

html_splitter = HTMLHeaderTextSplitter(
    headers_to_split_on=[
        ("h1", "h1"),
        ("h2", "h2"),
        ("h3", "h3"),
    ],
)

# For code files
from langchain.text_splitter import Language, RecursiveCharacterTextSplitter

code_splitter = RecursiveCharacterTextSplitter.from_language(
    language=Language.PYTHON,
    chunk_size=1000,
    chunk_overlap=100,
)
```

**When to use**: Structured documents (Markdown, HTML, code)
**Pros**: Preserves document hierarchy, great for technical docs
**Cons**: Requires format-specific splitters

### Chunking Decision Matrix

| Document Type | Recommended Strategy | Chunk Size | Overlap |
|---|---|---|---|
| Plain text / articles | Recursive character | 500-1000 chars | 100-200 |
| Technical documentation | Markdown header | Section-based | 0 (use headers) |
| Code files | Language-aware | Function-based | 50-100 |
| PDF reports | Semantic | Auto-determined | N/A |
| FAQ / Q&A pairs | No chunking (1 pair = 1 chunk) | N/A | N/A |
| Legal documents | Paragraph-based | 500 chars | 100 |
| Chat logs | Message-based | 5-10 messages | 2 messages |

### Chunk Size Guidelines

- **Too small** (< 200 chars): Loses context, fragments meaning
- **Sweet spot** (500-1000 chars): Good retrieval precision + enough context
- **Too large** (> 2000 chars): Dilutes relevance, wastes context window
- **Rule of thumb**: Chunk should be self-contained enough to answer a question

---

## 2. Embedding Model Selection and Comparison

### Model Comparison (as of 2025)

| Model | Dimensions | MTEB Score | Price (per 1M tokens) | Context Window | Best For |
|---|---|---|---|---|---|
| **text-embedding-3-small** (OpenAI) | 1536 | 62.3 | $0.02 | 8191 | Cost-efficient general use |
| **text-embedding-3-large** (OpenAI) | 3072 | 64.6 | $0.13 | 8191 | High accuracy requirements |
| **embed-v3** (Cohere) | 1024 | 64.5 | $0.10 | 512 | Multilingual, short docs |
| **voyage-3** (Voyage AI) | 1024 | 67.1 | $0.06 | 32000 | Code, technical content |
| **voyage-3-lite** (Voyage AI) | 512 | 62.4 | $0.02 | 32000 | Budget code search |
| **nomic-embed-text** (open) | 768 | 62.4 | Free (self-host) | 8192 | Self-hosted, no API cost |
| **bge-large-en-v1.5** (open) | 1024 | 63.5 | Free (self-host) | 512 | Self-hosted, good quality |
| **mxbai-embed-large** (open) | 1024 | 64.7 | Free (self-host) | 512 | Self-hosted, top quality |

### Selection Guidelines

```
IF budget is primary concern:
  → text-embedding-3-small ($0.02/1M) or self-host nomic-embed-text

IF accuracy is primary concern:
  → voyage-3 (best MTEB) or text-embedding-3-large

IF multilingual support needed:
  → Cohere embed-v3 (100+ languages)

IF code/technical content:
  → voyage-3 (optimized for code)

IF self-hosted requirement:
  → mxbai-embed-large or nomic-embed-text

IF long documents (>8K tokens):
  → voyage-3 (32K context) or chunk + embed
```

### Embedding Best Practices

```python
# 1. ALWAYS batch embeddings (not one-by-one)
# WRONG:
for text in texts:
    embedding = await embed([text])  # N API calls

# CORRECT:
embeddings = await embed(texts)  # 1 API call for up to 2048 texts

# 2. Normalize embeddings for cosine similarity
import numpy as np
embedding = np.array(raw_embedding)
normalized = embedding / np.linalg.norm(embedding)

# 3. Use matryoshka dimensions when available (text-embedding-3)
# Reduce dimensions for faster search with minimal quality loss
response = await litellm.aembedding(
    model="text-embedding-3-small",
    input=texts,
    dimensions=512,  # Reduce from 1536 to 512 (saves 66% storage)
)

# 4. Prefix queries vs documents (some models benefit from this)
# For nomic-embed-text:
query_text = "search_query: " + user_query
doc_text = "search_document: " + document_chunk
```

---

## 3. Vector Database Comparison

### Feature Comparison

| Feature | ChromaDB | Qdrant | Pinecone | Weaviate | Milvus |
|---|---|---|---|---|---|
| **Self-hosted** | Yes | Yes | No (cloud only) | Yes | Yes |
| **Cloud managed** | No | Yes | Yes | Yes | Yes (Zilliz) |
| **Open source** | Yes | Yes | No | Yes | Yes |
| **Filtering** | Basic | Advanced | Basic | Advanced | Advanced |
| **Hybrid search** | No | Yes (sparse+dense) | Yes (sparse+dense) | Yes (BM25+vector) | Yes |
| **Multi-tenancy** | Basic | Yes (payload-based) | Yes (namespaces) | Yes (classes) | Yes (partitions) |
| **Max vectors** | ~100K (in-memory) | Billions (disk) | Billions | Billions | Billions |
| **Replication** | No | Yes | Yes (auto) | Yes | Yes |
| **HNSW tuning** | Limited | Full control | None (managed) | Full control | Full control |
| **Price (managed)** | N/A | $25/mo+ | $70/mo+ | $25/mo+ | $65/mo+ |
| **Best for** | Prototyping, small RAG | Production, any scale | Enterprise, zero-ops | Multi-modal | Massive scale |

### Decision Matrix

```
IF prototyping / < 100K documents:
  → ChromaDB (simplest, in-memory, zero setup)

IF production / need hybrid search / filtering:
  → Qdrant (best balance of features, performance, cost)

IF enterprise / zero-ops / compliance:
  → Pinecone (fully managed, SOC2, no infrastructure)

IF multi-modal (text + images + video):
  → Weaviate (native multi-modal support)

IF massive scale (billions of vectors):
  → Milvus/Zilliz (designed for billion-scale)

IF self-hosted only / no cloud:
  → Qdrant or Milvus (best self-hosted options)
```

### Qdrant Setup (Recommended Default)

```python
# core/vector_store.py
from qdrant_client import QdrantClient
from qdrant_client.models import (
    Distance, VectorParams, OptimizersConfigDiff, HnswConfigDiff,
)

def create_qdrant_client() -> QdrantClient:
    return QdrantClient(
        url=settings.QDRANT_URL,
        api_key=settings.QDRANT_API_KEY,  # For cloud
        timeout=30,
    )

def create_collection(
    client: QdrantClient,
    name: str,
    vector_size: int = 1536,
    distance: Distance = Distance.COSINE,
):
    client.create_collection(
        collection_name=name,
        vectors_config=VectorParams(size=vector_size, distance=distance),
        optimizers_config=OptimizersConfigDiff(
            indexing_threshold=20000,  # Build index after 20K vectors
        ),
        hnsw_config=HnswConfigDiff(
            m=16,                 # Max connections per layer (16 is good default)
            ef_construct=100,     # Higher = better index, slower build
        ),
    )
```

---

## 4. Query Decomposition for Complex Questions

Complex questions need to be broken into sub-queries for better retrieval.

```python
# services/query_decomposition.py
import litellm
import json
import asyncio

async def decompose_query(query: str) -> list[str]:
    """Break a complex question into simpler sub-queries."""
    response = await litellm.acompletion(
        model="gpt-4o-mini",
        messages=[{
            "role": "system",
            "content": (
                "Break the user's question into 2-4 simpler sub-questions that, "
                "when answered together, fully answer the original question. "
                "Return JSON: {\"sub_queries\": [\"...\", \"...\"]}"
            )
        }, {
            "role": "user",
            "content": query,
        }],
        response_format={"type": "json_object"},
        max_tokens=200,
    )
    result = json.loads(response.choices[0].message.content)
    return result.get("sub_queries", [query])


async def multi_query_retrieve(
    query: str, retriever, top_k: int = 5
) -> list[dict]:
    """Decompose query, retrieve for each sub-query, merge results."""
    sub_queries = await decompose_query(query)
    
    # Retrieve in parallel for all sub-queries
    all_results = await asyncio.gather(*[
        retriever.retrieve(q, top_k=top_k) for q in sub_queries
    ])

    # Merge and deduplicate
    seen_ids = set()
    merged = []
    for results in all_results:
        for doc in results:
            doc_id = doc.get("doc_id", doc.get("id"))
            if doc_id not in seen_ids:
                seen_ids.add(doc_id)
                merged.append(doc)

    # Sort by score and return top_k
    merged.sort(key=lambda x: x.get("score", 0), reverse=True)
    return merged[:top_k]
```

---

## 5. Reranking Strategies

Reranking significantly improves retrieval quality. Always retrieve 2-3x more candidates than needed, then rerank.

### Cross-Encoder Reranking (Cohere)

```python
import cohere

async def cohere_rerank(
    query: str, documents: list[dict], top_k: int = 5
) -> list[dict]:
    co = cohere.Client(settings.COHERE_API_KEY)
    response = co.rerank(
        query=query,
        documents=[d["text"] for d in documents],
        top_n=top_k,
        model="rerank-english-v3.0",
    )
    return [
        {**documents[r.index], "rerank_score": r.relevance_score}
        for r in response.results
    ]
```

### Reciprocal Rank Fusion (No External API)

Merge results from multiple retrieval methods.

```python
def reciprocal_rank_fusion(
    result_lists: list[list[dict]], k: int = 60, top_k: int = 10
) -> list[dict]:
    """Fuse multiple ranked lists using RRF.
    
    Args:
        result_lists: List of ranked result lists. Each result must have 'id' key.
        k: RRF constant (default 60, higher = more weight to lower-ranked items).
        top_k: Number of results to return.
    """
    scores = {}
    items = {}
    for result_list in result_lists:
        for rank, item in enumerate(result_list):
            item_id = item.get("id") or item.get("doc_id")
            scores[item_id] = scores.get(item_id, 0) + 1.0 / (k + rank + 1)
            items[item_id] = item
    sorted_ids = sorted(scores, key=lambda x: scores[x], reverse=True)
    return [
        {**items[id_], "rrf_score": scores[id_]}
        for id_ in sorted_ids[:top_k]
    ]
```

### FlashRank (Local, Free Reranking)

```python
from flashrank import Ranker, RerankRequest

ranker = Ranker(model_name="ms-marco-MultiBERT-L-12")

def flashrank_rerank(query: str, documents: list[dict], top_k: int = 5) -> list[dict]:
    passages = [{"id": i, "text": d["text"]} for i, d in enumerate(documents)]
    request = RerankRequest(query=query, passages=passages)
    results = ranker.rerank(request)
    return [
        {**documents[r["id"]], "rerank_score": r["score"]}
        for r in results[:top_k]
    ]
```

### Reranking Decision Guide

| Method | Quality | Speed | Cost | Best For |
|---|---|---|---|---|
| Cohere Rerank v3 | Excellent | ~200ms | $1/1K queries | Production, budget available |
| FlashRank (local) | Good | ~50ms | Free | Self-hosted, latency-sensitive |
| LLM-based rerank | Best | ~2-5s | Expensive | Small candidate sets (<20) |
| RRF (no model) | Good | <1ms | Free | Merging multiple retrieval methods |

---

## 6. Hybrid Search (Dense + Sparse)

Combine vector (semantic) search with keyword (BM25/sparse) search for best results.

### Qdrant Hybrid Search

```python
from qdrant_client.models import SparseVector

# Create collection with both dense and sparse vectors
client.create_collection(
    collection_name="hybrid_search",
    vectors_config={
        "dense": VectorParams(size=1536, distance=Distance.COSINE),
    },
    sparse_vectors_config={
        "sparse": {},  # BM25 sparse vectors
    },
)

# Index with both dense and sparse vectors
async def index_hybrid(doc_id: str, text: str, metadata: dict):
    dense_vector = await embed([text])
    sparse_vector = compute_bm25_vector(text)  # Use splade or bm25 encoder
    
    client.upsert(
        collection_name="hybrid_search",
        points=[PointStruct(
            id=doc_id,
            vector={
                "dense": dense_vector[0],
                "sparse": SparseVector(
                    indices=sparse_vector.indices,
                    values=sparse_vector.values,
                ),
            },
            payload={"text": text, **metadata},
        )],
    )

# Search with both methods + RRF
async def hybrid_search(query: str, top_k: int = 10) -> list[dict]:
    dense_vector = await embed([query])
    sparse_vector = compute_bm25_vector(query)
    
    results = client.query_points(
        collection_name="hybrid_search",
        prefetch=[
            {"query": dense_vector[0], "using": "dense", "limit": top_k * 2},
            {"query": SparseVector(**sparse_vector), "using": "sparse", "limit": top_k * 2},
        ],
        query=FusionQuery(fusion="rrf"),
        limit=top_k,
    )
    return [{"id": r.id, "score": r.score, **r.payload} for r in results]
```

---

## 7. Context Window Management

Manage token budget to fit within model context limits.

```python
# core/context_manager.py
import tiktoken

MODEL_CONTEXT_LIMITS = {
    "gpt-4o": 128000,
    "gpt-4o-mini": 128000,
    "claude-3-5-sonnet-20241022": 200000,
    "claude-3-5-haiku-20241022": 200000,
    "gemini-1.5-pro": 2000000,
    "gemini-2.0-flash": 1000000,
}

class ContextManager:
    def __init__(self, model: str = "gpt-4o-mini"):
        self.model = model
        self.max_tokens = MODEL_CONTEXT_LIMITS.get(model, 128000)
        try:
            self.encoder = tiktoken.encoding_for_model(model)
        except KeyError:
            self.encoder = tiktoken.get_encoding("cl100k_base")

    def count_tokens(self, text: str) -> int:
        return len(self.encoder.encode(text))

    def build_context(
        self,
        system_prompt: str,
        user_query: str,
        retrieved_docs: list[dict],
        conversation_history: list[dict] | None = None,
        max_output_tokens: int = 1000,
    ) -> tuple[list[dict], list[dict]]:
        """Build messages that fit within context window.
        
        Returns: (messages, included_docs) — docs that made it into context.
        """
        # Reserve tokens
        reserved = max_output_tokens + 200  # output + overhead
        budget = self.max_tokens - reserved

        # System prompt (always included)
        system_tokens = self.count_tokens(system_prompt)
        budget -= system_tokens

        # User query (always included)
        query_tokens = self.count_tokens(user_query)
        budget -= query_tokens

        # Conversation history (include recent, drop old if needed)
        included_history = []
        if conversation_history:
            for msg in reversed(conversation_history):
                msg_tokens = self.count_tokens(msg["content"])
                if budget - msg_tokens > 0:
                    included_history.insert(0, msg)
                    budget -= msg_tokens
                else:
                    break

        # Retrieved docs (include as many as fit, highest relevance first)
        included_docs = []
        for doc in retrieved_docs:  # Already sorted by relevance
            doc_tokens = self.count_tokens(doc["text"])
            if budget - doc_tokens > 0:
                included_docs.append(doc)
                budget -= doc_tokens
            else:
                break  # Stop adding docs when budget exhausted

        # Build context string
        context_str = "\n\n---\n\n".join([
            f"[Source: {d.get('doc_id', 'unknown')}]\n{d['text']}"
            for d in included_docs
        ])

        messages = [
            {"role": "system", "content": system_prompt},
        ] + included_history + [
            {"role": "user", "content": f"Context:\n{context_str}\n\nQuestion: {user_query}"},
        ]

        return messages, included_docs
```

---

## 8. Evaluation Metrics

### Core RAG Metrics

| Metric | What It Measures | Target | Tool |
|---|---|---|---|
| **Faithfulness** | Is the answer grounded in retrieved context? | > 0.8 | RAGAS, DeepEval |
| **Answer Relevancy** | Does the answer actually address the question? | > 0.8 | RAGAS, DeepEval |
| **Context Recall** | Did we retrieve all relevant information? | > 0.7 | RAGAS |
| **Context Precision** | Are retrieved docs actually relevant? | > 0.7 | RAGAS |
| **Hallucination Rate** | Does the answer contain fabricated info? | < 0.1 | DeepEval |
| **Retrieval nDCG** | Are the most relevant docs ranked highest? | > 0.5 | Custom |
| **Latency (e2e)** | Total time from query to answer | < 5s | Custom |
| **Latency (retrieval)** | Vector search time | < 500ms | Custom |
| **Token Efficiency** | Tokens used vs answer quality | Optimize | Custom |

### Evaluation Pipeline

```python
# tests/eval_rag.py
from ragas import evaluate
from ragas.metrics import (
    faithfulness,
    answer_relevancy,
    context_recall,
    context_precision,
)
from datasets import Dataset

def build_eval_dataset(test_cases: list[dict]) -> Dataset:
    """Build RAGAS evaluation dataset.
    
    Each test case: {
        "question": str,
        "ground_truth": str,    # Expected answer
        "answer": str,          # RAG-generated answer
        "contexts": list[str],  # Retrieved context documents
    }
    """
    return Dataset.from_list(test_cases)

def run_evaluation(test_cases: list[dict]) -> dict:
    dataset = build_eval_dataset(test_cases)
    result = evaluate(
        dataset,
        metrics=[
            faithfulness,
            answer_relevancy,
            context_recall,
            context_precision,
        ],
    )
    return {
        "faithfulness": result["faithfulness"],
        "answer_relevancy": result["answer_relevancy"],
        "context_recall": result["context_recall"],
        "context_precision": result["context_precision"],
        "overall": (
            result["faithfulness"] + result["answer_relevancy"]
            + result["context_recall"] + result["context_precision"]
        ) / 4,
    }
```

---

## 9. Cold Start Handling

When the knowledge base is empty or sparse:

```python
class ColdStartHandler:
    """Handle RAG queries when knowledge base has insufficient data."""

    async def handle_query(
        self, query: str, retrieved_docs: list[dict], min_docs: int = 2,
        min_relevance: float = 0.4,
    ) -> dict:
        relevant_docs = [d for d in retrieved_docs if d.get("score", 0) >= min_relevance]

        if len(relevant_docs) < min_docs:
            # Cold start: not enough relevant context
            return {
                "answer": (
                    "I don't have enough information in my knowledge base to answer "
                    "this question confidently. Here's what I found:\n\n"
                    + "\n".join([d["text"][:200] for d in retrieved_docs[:3]])
                    + "\n\nWould you like me to search more broadly, or can you "
                    "provide additional context?"
                ),
                "confidence": "low",
                "sources": retrieved_docs[:3],
                "suggestion": "Add more documents to the knowledge base covering this topic.",
            }

        # Normal path: enough context available
        return None  # Proceed with normal RAG generation
```

---

## 10. Index Management and Refresh Strategies

### Incremental Indexing

```python
class IndexManager:
    """Manage vector index lifecycle: create, update, refresh, delete."""

    async def incremental_update(
        self, new_docs: list[dict], updated_docs: list[dict], deleted_ids: list[str],
    ):
        """Update index without full rebuild."""
        # 1. Delete removed documents
        if deleted_ids:
            self.qdrant.delete(
                collection_name=self.collection,
                points_selector=PointIdsList(points=deleted_ids),
            )

        # 2. Upsert new and updated documents
        all_docs = new_docs + updated_docs
        if all_docs:
            await self.index_documents(all_docs)

    async def full_reindex(self, documents: list[dict]):
        """Full reindex — recreate collection from scratch."""
        # 1. Create new collection
        temp_collection = f"{self.collection}_temp"
        create_collection(self.qdrant, temp_collection)

        # 2. Index all documents into temp
        await self.index_documents(documents, collection=temp_collection)

        # 3. Swap collections (atomic)
        self.qdrant.delete_collection(self.collection)
        self.qdrant.update_collection_aliases(
            change_aliases_operations=[
                {"create_alias": {"collection_name": temp_collection, "alias_name": self.collection}},
            ]
        )

    def get_index_stats(self) -> dict:
        """Get index health stats."""
        info = self.qdrant.get_collection(self.collection)
        return {
            "total_vectors": info.vectors_count,
            "indexed_vectors": info.indexed_vectors_count,
            "index_status": info.status,
            "disk_usage_mb": info.disk_data_size / (1024 * 1024),
        }
```

### Refresh Schedule

| Data Type | Refresh Strategy | Frequency |
|---|---|---|
| Static docs (manuals, policies) | Full reindex | Weekly |
| Semi-static (knowledge base, FAQs) | Incremental | Daily |
| Dynamic (tickets, conversations) | Real-time upsert | On creation |
| External sources (web scrapes) | Full reindex | Daily-weekly |

### Index Health Monitoring

```python
async def check_index_health(self) -> dict:
    stats = self.get_index_stats()
    issues = []

    if stats["indexed_vectors"] < stats["total_vectors"] * 0.95:
        issues.append("Index not fully built — search quality may be degraded")

    if stats["total_vectors"] == 0:
        issues.append("Empty index — no documents indexed")

    if stats["disk_usage_mb"] > 10000:
        issues.append("Index exceeds 10GB — consider sharding or pruning old data")

    return {
        "healthy": len(issues) == 0,
        "stats": stats,
        "issues": issues,
    }
```
