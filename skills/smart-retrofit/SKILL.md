---
name: smart-retrofit
description: "Auto-invoked when user asks to 'add AI to', 'upgrade', 'enhance', 'integrate AI', 'make smarter', or 'add intelligence to' any existing feature. Analyzes codebase architecture, identifies AI/ML enhancement opportunities per feature type (search, catalog, metrics, alerts, payments, auth, chat, forms, dashboards, notifications, content, reports), and generates implementation code for both backend (FastAPI/NestJS/Spring Boot) and frontend (React/Next.js)."
license: "Proprietary — Alpha AI Service Pvt Ltd"
compatibility: "Designed for Claude Code with cortex plugin"
metadata:
  author: "Alpha AI Service Pvt Ltd"
  version: "1.0"
---

# Smart Retrofit — AI-Enhance Any Existing Feature

This skill guides the process of intelligently adding AI/ML capabilities to existing application features. It works for ANY app — not just GenAI apps, but payments, analytics, data platforms, SaaS, e-commerce, and more.

---

## Step 0: Analyze the Existing Codebase

Before suggesting any AI enhancements, deeply understand what exists:

### 0a — Map the Architecture

```
1. Scan project structure:
   - Glob for all source files (*.py, *.ts, *.java, *.tsx)
   - Identify backend framework (FastAPI, NestJS, Spring Boot, Express, Django)
   - Identify frontend framework (React, Next.js, Vue, Angular)
   - Identify database(s) (MySQL, PostgreSQL, MongoDB, Redis)
   - Identify existing AI/ML code (LLM calls, embeddings, vector DBs)

2. Read key configuration files:
   - requirements.txt / package.json / build.gradle
   - docker-compose.yml
   - .env.example
   - Any existing AI/ML config (litellm config, vector DB setup)

3. Map feature areas:
   - Grep for route definitions → list all API endpoints
   - Grep for page/component definitions → list all frontend pages
   - Grep for model/schema definitions → list all data models
   - Grep for service files → list all business logic modules
```

### 0b — Identify Feature Types Present

For each feature area found, classify it:

| Feature Type | Detection Pattern |
|---|---|
| Search | `search`, `query`, `filter`, `find`, `lookup`, Meilisearch/Elasticsearch imports |
| Catalog/Directory | `catalog`, `directory`, `inventory`, `listing`, `registry`, metadata tables |
| Lineage/Dependencies | `lineage`, `dependency`, `graph`, `upstream`, `downstream`, parent-child relations |
| Metrics/KPIs | `metric`, `kpi`, `dashboard`, `analytics`, `measure`, aggregate queries |
| Alerts | `alert`, `notification`, `threshold`, `monitor`, `watch`, cron jobs |
| Reports | `report`, `export`, `pdf`, `csv`, `summary`, scheduled generation |
| Dashboards | `dashboard`, `chart`, `visualization`, `widget`, Recharts/Chart.js imports |
| Forms | `form`, `input`, `validation`, `submit`, Formik/react-hook-form imports |
| Auth | `auth`, `login`, `session`, `jwt`, `oauth`, `permission` |
| Payments | `payment`, `billing`, `subscription`, `invoice`, Stripe/Razorpay imports |
| Chat/Support | `chat`, `message`, `conversation`, `support`, `ticket` |
| Content | `content`, `article`, `post`, `blog`, `cms`, `media`, rich text editors |
| Notifications | `notification`, `email`, `sms`, `push`, `alert`, `digest` |

### 0c — Assess AI Readiness

For each feature area, check:
- Is there already AI/ML code? (enhance vs. add from scratch)
- Is there a vector DB? (ChromaDB, Qdrant, Pinecone, Weaviate)
- Is there an LLM gateway? (LiteLLM, direct OpenAI/Anthropic calls)
- What data is available for AI enhancement? (text, numbers, images, logs)
- What is the current user pain point? (slow search? manual classification? no insights?)

---

## Step 1: Generate Enhancement Map

For each feature type detected, recommend specific AI upgrades. Present as a prioritized table:

```
AI Enhancement Opportunities
=============================

Feature: [Feature Name]
Current State: [What it does now]
AI Enhancement: [What AI would add]
Effort: [Low/Medium/High]
Impact: [Low/Medium/High]
Priority: [P0/P1/P2/P3]
```

---

## Step 2: AI Enhancement Patterns by Feature Type

### 2.1 Search → Semantic Vector Search

**Current**: Keyword-based search (SQL LIKE, Meilisearch, Elasticsearch)
**Enhanced**: Semantic search that understands meaning, not just keywords

#### Python/FastAPI Implementation

```python
# services/semantic_search_service.py
from typing import Optional
import httpx
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct
import litellm

class SemanticSearchService:
    def __init__(self):
        self.qdrant = QdrantClient(url=settings.QDRANT_URL)
        self.collection_name = "search_index"
        self.embedding_model = "text-embedding-3-small"

    async def embed_text(self, text: str) -> list[float]:
        """Generate embedding vector for text."""
        response = await litellm.aembedding(
            model=self.embedding_model,
            input=[text],
        )
        return response.data[0]["embedding"]

    async def index_document(self, doc_id: str, text: str, metadata: dict):
        """Index a document for semantic search."""
        vector = await self.embed_text(text)
        self.qdrant.upsert(
            collection_name=self.collection_name,
            points=[PointStruct(
                id=doc_id,
                vector=vector,
                payload={"text": text, **metadata},
            )],
        )

    async def search(
        self, query: str, limit: int = 10, filters: Optional[dict] = None
    ) -> list[dict]:
        """Semantic search with optional metadata filters."""
        query_vector = await self.embed_text(query)
        results = self.qdrant.search(
            collection_name=self.collection_name,
            query_vector=query_vector,
            limit=limit,
            query_filter=self._build_filter(filters) if filters else None,
        )
        return [
            {"id": r.id, "score": r.score, **r.payload}
            for r in results
        ]

    async def hybrid_search(
        self, query: str, limit: int = 10, filters: Optional[dict] = None
    ) -> list[dict]:
        """Combine semantic search with keyword search for best results."""
        import asyncio
        semantic_results, keyword_results = await asyncio.gather(
            self.search(query, limit=limit * 2, filters=filters),
            self._keyword_search(query, limit=limit * 2, filters=filters),
        )
        # Reciprocal Rank Fusion
        return self._reciprocal_rank_fusion(semantic_results, keyword_results, limit)

    def _reciprocal_rank_fusion(
        self, list_a: list[dict], list_b: list[dict], limit: int, k: int = 60
    ) -> list[dict]:
        scores = {}
        for rank, item in enumerate(list_a):
            scores[item["id"]] = scores.get(item["id"], 0) + 1.0 / (k + rank + 1)
        for rank, item in enumerate(list_b):
            scores[item["id"]] = scores.get(item["id"], 0) + 1.0 / (k + rank + 1)
        all_items = {item["id"]: item for item in list_a + list_b}
        sorted_ids = sorted(scores, key=lambda x: scores[x], reverse=True)[:limit]
        return [all_items[id_] for id_ in sorted_ids if id_ in all_items]
```

#### Node.js/NestJS Implementation

```typescript
// services/semantic-search.service.ts
import { Injectable } from '@nestjs/common';
import { QdrantClient } from '@qdrant/js-client-rest';
import OpenAI from 'openai';

@Injectable()
export class SemanticSearchService {
  private qdrant: QdrantClient;
  private openai: OpenAI;
  private collectionName = 'search_index';

  constructor() {
    this.qdrant = new QdrantClient({ url: process.env.QDRANT_URL });
    this.openai = new OpenAI();
  }

  async embedText(text: string): Promise<number[]> {
    const response = await this.openai.embeddings.create({
      model: 'text-embedding-3-small',
      input: text,
    });
    return response.data[0].embedding;
  }

  async search(query: string, limit = 10, filters?: Record<string, any>) {
    const queryVector = await this.embedText(query);
    const results = await this.qdrant.search(this.collectionName, {
      vector: queryVector,
      limit,
      filter: filters ? this.buildFilter(filters) : undefined,
    });
    return results.map((r) => ({
      id: r.id,
      score: r.score,
      ...r.payload,
    }));
  }
}
```

#### React Frontend Component

```tsx
// components/SmartSearch.tsx
import { useState, useCallback } from 'react';
import { useDebouncedCallback } from 'use-debounce';
import { useQuery } from '@tanstack/react-query';
import { searchApi } from '@/lib/api';

export function SmartSearch({ onSelect }: { onSelect: (item: any) => void }) {
  const [query, setQuery] = useState('');
  const [debouncedQuery, setDebouncedQuery] = useState('');

  const debouncedSearch = useDebouncedCallback((value: string) => {
    setDebouncedQuery(value);
  }, 300);

  const { data: results, isLoading } = useQuery({
    queryKey: ['semantic-search', debouncedQuery],
    queryFn: () => searchApi.semanticSearch(debouncedQuery),
    enabled: debouncedQuery.length > 2,
  });

  return (
    <div className="relative">
      <input
        value={query}
        onChange={(e) => {
          setQuery(e.target.value);
          debouncedSearch(e.target.value);
        }}
        placeholder="Search by meaning, not just keywords..."
        className="w-full px-4 py-2 border rounded-lg"
      />
      {isLoading && <div className="absolute right-3 top-3"><Spinner /></div>}
      {results && results.length > 0 && (
        <ul className="absolute w-full mt-1 bg-white border rounded-lg shadow-lg max-h-60 overflow-auto z-50">
          {results.map((item: any) => (
            <li
              key={item.id}
              onClick={() => onSelect(item)}
              className="px-4 py-2 hover:bg-gray-100 cursor-pointer"
            >
              <div className="font-medium">{item.title || item.name}</div>
              <div className="text-sm text-gray-500">{item.description}</div>
              <div className="text-xs text-gray-400">Relevance: {(item.score * 100).toFixed(0)}%</div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
```

---

### 2.2 Catalog/Directory → Auto-Descriptions, PII Detection, Classification

**Current**: Manual metadata, static descriptions, no classification
**Enhanced**: AI-generated descriptions, automatic PII detection, smart classification

```python
# services/catalog_intelligence_service.py
import litellm
import json
from typing import Optional

class CatalogIntelligenceService:
    """AI-powered catalog enhancement for any entity type."""

    async def generate_description(
        self, entity_name: str, schema: dict, sample_data: list[dict]
    ) -> str:
        """Auto-generate a human-readable description for a catalog entity."""
        response = await litellm.acompletion(
            model="gpt-4o-mini",
            messages=[{
                "role": "system",
                "content": "You are a technical writer. Generate a concise, accurate description."
            }, {
                "role": "user",
                "content": (
                    f"Entity: {entity_name}\n"
                    f"Schema: {json.dumps(schema)}\n"
                    f"Sample data (3 rows): {json.dumps(sample_data[:3])}\n\n"
                    "Write a 1-2 sentence description of what this entity represents."
                )
            }],
            max_tokens=150,
        )
        return response.choices[0].message.content.strip()

    async def detect_pii(self, column_name: str, sample_values: list[str]) -> dict:
        """Detect if a column contains PII (Personally Identifiable Information)."""
        pii_patterns = {
            "email": r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}",
            "phone": r"(\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}",
            "ssn": r"\d{3}-\d{2}-\d{4}",
            "credit_card": r"\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}",
            "ip_address": r"\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}",
        }
        import re
        detections = {}
        for pii_type, pattern in pii_patterns.items():
            matches = sum(1 for v in sample_values if re.search(pattern, str(v)))
            if matches > len(sample_values) * 0.3:
                detections[pii_type] = {
                    "confidence": matches / len(sample_values),
                    "action": "MASK" if pii_type in ("ssn", "credit_card") else "FLAG",
                }
        return detections

    async def classify_entity(
        self, entity_name: str, columns: list[str], sample_data: list[dict]
    ) -> dict:
        """Classify a catalog entity into domain categories."""
        response = await litellm.acompletion(
            model="gpt-4o-mini",
            messages=[{
                "role": "user",
                "content": (
                    f"Classify this data entity.\n"
                    f"Name: {entity_name}\nColumns: {columns}\n"
                    f"Sample: {json.dumps(sample_data[:2])}\n\n"
                    "Return JSON: {\"domain\": \"...\", \"category\": \"...\", "
                    "\"sensitivity\": \"public|internal|confidential|restricted\", "
                    "\"tags\": [\"...\"]}"
                )
            }],
            response_format={"type": "json_object"},
            max_tokens=200,
        )
        return json.loads(response.choices[0].message.content)
```

---

### 2.3 Lineage/Dependencies → Impact Analysis, Change Propagation

**Current**: Static lineage visualization, manual dependency tracking
**Enhanced**: AI-powered impact analysis with automatic blast radius detection

```python
# services/impact_analysis_service.py
from typing import Optional
from dataclasses import dataclass

@dataclass
class ImpactNode:
    entity: str
    entity_type: str  # table, service, api, component
    impact_level: str  # critical, high, medium, low
    reason: str
    downstream: list["ImpactNode"]

class ImpactAnalysisService:
    """Analyze the blast radius of any change across the full stack."""

    async def analyze_change(
        self, changed_entity: str, change_type: str, lineage_graph: dict
    ) -> ImpactNode:
        """Trace impact of a change through the dependency graph."""
        visited = set()
        root = ImpactNode(
            entity=changed_entity,
            entity_type=self._detect_type(changed_entity),
            impact_level="critical",
            reason=f"Direct {change_type} change",
            downstream=[],
        )
        await self._traverse_downstream(root, lineage_graph, visited, depth=0)
        return root

    async def _traverse_downstream(
        self, node: ImpactNode, graph: dict, visited: set, depth: int
    ):
        if depth > 10 or node.entity in visited:
            return
        visited.add(node.entity)
        dependents = graph.get(node.entity, {}).get("downstream", [])
        for dep in dependents:
            impact = self._calculate_impact(dep, depth)
            child = ImpactNode(
                entity=dep["name"],
                entity_type=dep["type"],
                impact_level=impact,
                reason=f"Depends on {node.entity} via {dep.get('relation', 'reference')}",
                downstream=[],
            )
            node.downstream.append(child)
            await self._traverse_downstream(child, graph, visited, depth + 1)

    def _calculate_impact(self, dep: dict, depth: int) -> str:
        if depth == 0:
            return "critical"
        elif depth == 1:
            return "high" if dep.get("coupling") == "tight" else "medium"
        elif depth == 2:
            return "medium" if dep.get("coupling") == "tight" else "low"
        return "low"

    def generate_impact_report(self, root: ImpactNode) -> str:
        """Generate a human-readable impact report."""
        lines = ["# Impact Analysis Report\n"]
        self._render_node(root, lines, indent=0)
        return "\n".join(lines)

    def _render_node(self, node: ImpactNode, lines: list, indent: int):
        prefix = "  " * indent + ("" if indent == 0 else "+-- ")
        severity_icon = {
            "critical": "[CRITICAL]",
            "high": "[HIGH]",
            "medium": "[MEDIUM]",
            "low": "[LOW]",
        }
        lines.append(
            f"{prefix}{severity_icon[node.impact_level]} {node.entity} "
            f"({node.entity_type}) -- {node.reason}"
        )
        for child in node.downstream:
            self._render_node(child, lines, indent + 1)
```

---

### 2.4 Metrics/KPIs → AI Discovery, Anomaly Detection, Forecasting

**Current**: Manually defined metrics, static thresholds
**Enhanced**: AI discovers metrics from schema, detects anomalies, generates forecasts

```python
# services/metric_intelligence_service.py
import litellm
import json
import numpy as np
from datetime import datetime, timedelta

class MetricIntelligenceService:

    async def discover_metrics(self, schema: dict, domain: str) -> list[dict]:
        """AI discovers meaningful metrics from database schema."""
        response = await litellm.acompletion(
            model="gpt-4o-mini",
            messages=[{
                "role": "user",
                "content": (
                    f"Given this database schema for a {domain} application:\n"
                    f"{json.dumps(schema)}\n\n"
                    "Suggest 10 KPI metrics. For each, provide:\n"
                    "- name, description, SQL query, unit, aggregation_type, "
                    "suggested_threshold_low, suggested_threshold_high\n"
                    "Return as JSON array."
                )
            }],
            response_format={"type": "json_object"},
            max_tokens=1000,
        )
        return json.loads(response.choices[0].message.content).get("metrics", [])

    def detect_anomaly(
        self, values: list[float], timestamps: list[datetime],
        method: str = "zscore"
    ) -> list[dict]:
        """Detect anomalies in time-series metric data."""
        if method == "zscore":
            mean = np.mean(values)
            std = np.std(values)
            if std == 0:
                return []
            z_scores = [(v - mean) / std for v in values]
            anomalies = []
            for i, z in enumerate(z_scores):
                if abs(z) > 2.5:
                    anomalies.append({
                        "timestamp": timestamps[i].isoformat(),
                        "value": values[i],
                        "z_score": round(z, 2),
                        "severity": "critical" if abs(z) > 3.5 else "warning",
                        "direction": "spike" if z > 0 else "drop",
                    })
            return anomalies
        return []

    def simple_forecast(
        self, values: list[float], periods: int = 7
    ) -> list[float]:
        """Simple linear regression forecast for metrics."""
        n = len(values)
        if n < 3:
            return [values[-1]] * periods
        x = np.arange(n)
        coeffs = np.polyfit(x, values, deg=1)
        future_x = np.arange(n, n + periods)
        return [round(np.polyval(coeffs, fx), 2) for fx in future_x]
```

---

### 2.5 Alerts → AI-Recommended Thresholds, Auto Root-Cause Analysis

```python
# services/smart_alerts_service.py
import litellm
import json

class SmartAlertsService:

    async def recommend_thresholds(
        self, metric_name: str, historical_values: list[float]
    ) -> dict:
        """AI recommends alert thresholds based on historical data."""
        import numpy as np
        mean = np.mean(historical_values)
        std = np.std(historical_values)
        p95 = np.percentile(historical_values, 95)
        p5 = np.percentile(historical_values, 5)
        return {
            "metric": metric_name,
            "warning_high": round(mean + 2 * std, 2),
            "critical_high": round(mean + 3 * std, 2),
            "warning_low": round(mean - 2 * std, 2),
            "critical_low": round(mean - 3 * std, 2),
            "p95": round(p95, 2),
            "p5": round(p5, 2),
            "baseline_mean": round(mean, 2),
        }

    async def auto_root_cause(
        self, alert: dict, related_metrics: list[dict], recent_changes: list[dict]
    ) -> dict:
        """AI-powered root cause analysis for triggered alerts."""
        response = await litellm.acompletion(
            model="gpt-4o",
            messages=[{
                "role": "system",
                "content": "You are an SRE expert. Analyze the alert and find the root cause."
            }, {
                "role": "user",
                "content": (
                    f"Alert: {json.dumps(alert)}\n"
                    f"Related metrics (last 1h): {json.dumps(related_metrics)}\n"
                    f"Recent changes: {json.dumps(recent_changes)}\n\n"
                    "Provide root cause analysis as JSON with: "
                    "root_cause, confidence, evidence, suggested_fix, severity"
                )
            }],
            response_format={"type": "json_object"},
            max_tokens=500,
        )
        return json.loads(response.choices[0].message.content)
```

---

### 2.6 Reports → AI-Generated Narratives, Trend Explanation

```python
# services/report_intelligence_service.py
import litellm

class ReportIntelligenceService:

    async def generate_narrative(
        self, report_data: dict, report_type: str, period: str
    ) -> str:
        """Generate human-readable narrative for any report."""
        response = await litellm.acompletion(
            model="gpt-4o-mini",
            messages=[{
                "role": "system",
                "content": (
                    "You are a business analyst. Write a concise executive summary "
                    "for this report data. Use specific numbers. Highlight trends, "
                    "anomalies, and actionable insights. 3-5 paragraphs max."
                )
            }, {
                "role": "user",
                "content": (
                    f"Report type: {report_type}\nPeriod: {period}\n"
                    f"Data: {report_data}\n\n"
                    "Write the executive summary."
                )
            }],
            max_tokens=800,
        )
        return response.choices[0].message.content

    async def explain_trend(
        self, metric_name: str, values: list[float], context: str
    ) -> str:
        """AI explains why a metric is trending up/down."""
        trend = "increasing" if values[-1] > values[0] else "decreasing"
        change_pct = ((values[-1] - values[0]) / values[0] * 100) if values[0] != 0 else 0
        response = await litellm.acompletion(
            model="gpt-4o-mini",
            messages=[{
                "role": "user",
                "content": (
                    f"Metric '{metric_name}' is {trend} by {change_pct:.1f}%.\n"
                    f"Recent values: {values}\nContext: {context}\n\n"
                    "Explain the likely causes in 2-3 sentences."
                )
            }],
            max_tokens=200,
        )
        return response.choices[0].message.content
```

---

### 2.7 Dashboards → Natural Language Dashboard Builder

```typescript
// services/nl-dashboard.service.ts
// Natural language to dashboard configuration

interface DashboardWidget {
  type: 'line' | 'bar' | 'pie' | 'number' | 'table' | 'heatmap';
  title: string;
  dataSource: string;
  query: string;
  config: Record<string, any>;
}

interface DashboardLayout {
  title: string;
  widgets: DashboardWidget[];
  layout: { i: string; x: number; y: number; w: number; h: number }[];
}

export async function generateDashboardFromPrompt(
  prompt: string,
  availableMetrics: string[],
  availableTables: string[],
): Promise<DashboardLayout> {
  const response = await fetch('/api/ai/generate-dashboard', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      prompt,
      available_metrics: availableMetrics,
      available_tables: availableTables,
    }),
  });
  return response.json();
}
```

---

### 2.8 Forms → AI Validation, Auto-Fill, Smart Defaults

```typescript
// hooks/useSmartForm.ts
import { useCallback } from 'react';
import { useMutation } from '@tanstack/react-query';

export function useSmartForm(formSchema: Record<string, any>) {
  const autoFill = useMutation({
    mutationFn: async (partialData: Record<string, any>) => {
      const response = await fetch('/api/ai/form-autofill', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ schema: formSchema, partial_data: partialData }),
      });
      return response.json();
    },
  });

  const validateWithAI = useCallback(
    async (fieldName: string, value: any, context: Record<string, any>) => {
      const response = await fetch('/api/ai/form-validate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ field: fieldName, value, context }),
      });
      const result = await response.json();
      return result.valid ? null : result.suggestion;
    },
    [],
  );

  return { autoFill, validateWithAI };
}
```

---

### 2.9 Auth → Anomaly Login Detection, Risk Scoring

```python
# services/auth_intelligence_service.py
from datetime import datetime

class AuthIntelligenceService:

    async def score_login_risk(
        self, user_id: int, ip: str, user_agent: str, timestamp: datetime,
        login_history: list[dict],
    ) -> dict:
        """Score login risk based on behavioral patterns."""
        risk_score = 0.0
        reasons = []

        # Check IP reputation
        known_ips = {h["ip"] for h in login_history}
        if ip not in known_ips:
            risk_score += 0.3
            reasons.append("New IP address")

        # Check user agent
        known_agents = {h["user_agent"] for h in login_history}
        if user_agent not in known_agents:
            risk_score += 0.2
            reasons.append("New device/browser")

        # Check time pattern
        usual_hours = [h["timestamp"].hour for h in login_history]
        if usual_hours and timestamp.hour not in range(
            min(usual_hours) - 2, max(usual_hours) + 3
        ):
            risk_score += 0.2
            reasons.append("Unusual login time")

        # Check velocity (too many logins recently)
        recent = [
            h for h in login_history
            if (timestamp - h["timestamp"]).total_seconds() < 3600
        ]
        if len(recent) > 5:
            risk_score += 0.3
            reasons.append("High login velocity")

        risk_level = (
            "critical" if risk_score >= 0.7
            else "high" if risk_score >= 0.5
            else "medium" if risk_score >= 0.3
            else "low"
        )
        return {
            "score": round(min(risk_score, 1.0), 2),
            "level": risk_level,
            "reasons": reasons,
            "action": "BLOCK" if risk_level == "critical"
                      else "MFA" if risk_level in ("high", "medium")
                      else "ALLOW",
        }
```

---

### 2.10 Payments → Fraud Detection, Churn Prediction, Revenue Forecasting

```python
# services/payment_intelligence_service.py
import litellm
import json
import numpy as np

class PaymentIntelligenceService:

    async def detect_fraud_risk(self, transaction: dict, user_history: list[dict]) -> dict:
        """Score fraud risk for a payment transaction."""
        risk_score = 0.0
        signals = []

        avg_amount = np.mean([h["amount"] for h in user_history]) if user_history else 0
        if transaction["amount"] > avg_amount * 3 and avg_amount > 0:
            risk_score += 0.4
            signals.append(f"Amount {transaction['amount']} is 3x+ above average {avg_amount:.0f}")

        if transaction.get("country") and user_history:
            usual_countries = {h.get("country") for h in user_history}
            if transaction["country"] not in usual_countries:
                risk_score += 0.3
                signals.append(f"New country: {transaction['country']}")

        # Velocity check
        recent_txns = len([
            h for h in user_history
            if h.get("hours_ago", 999) < 1
        ])
        if recent_txns > 3:
            risk_score += 0.3
            signals.append(f"{recent_txns} transactions in last hour")

        return {
            "risk_score": round(min(risk_score, 1.0), 2),
            "risk_level": "high" if risk_score >= 0.6 else "medium" if risk_score >= 0.3 else "low",
            "signals": signals,
            "action": "REVIEW" if risk_score >= 0.6 else "ALLOW",
        }

    async def predict_churn(self, user_metrics: dict) -> dict:
        """Predict churn probability based on usage patterns."""
        response = await litellm.acompletion(
            model="gpt-4o-mini",
            messages=[{
                "role": "user",
                "content": (
                    f"User metrics: {json.dumps(user_metrics)}\n\n"
                    "Predict churn risk. Return JSON: "
                    "{\"churn_probability\": 0.0-1.0, \"risk_level\": \"low|medium|high\", "
                    "\"top_factors\": [\"...\"], \"retention_actions\": [\"...\"]}"
                )
            }],
            response_format={"type": "json_object"},
            max_tokens=300,
        )
        return json.loads(response.choices[0].message.content)
```

---

### 2.11 Chat/Support → RAG Knowledge Base, Intent Classification

```python
# services/support_intelligence_service.py
import litellm

class SupportIntelligenceService:

    async def classify_intent(self, message: str) -> dict:
        """Classify support message intent for routing."""
        response = await litellm.acompletion(
            model="gpt-4o-mini",
            messages=[{
                "role": "system",
                "content": (
                    "Classify the customer message intent. Categories: "
                    "billing, technical, account, feature_request, bug_report, "
                    "cancellation, general. Return JSON: "
                    "{\"intent\": \"...\", \"confidence\": 0.0-1.0, "
                    "\"urgency\": \"low|medium|high\", \"sentiment\": \"positive|neutral|negative\"}"
                )
            }, {
                "role": "user",
                "content": message,
            }],
            response_format={"type": "json_object"},
            max_tokens=100,
        )
        import json
        return json.loads(response.choices[0].message.content)

    async def generate_response(
        self, message: str, context_docs: list[str], conversation_history: list[dict]
    ) -> str:
        """Generate support response using RAG context."""
        context = "\n---\n".join(context_docs)
        messages = [{
            "role": "system",
            "content": (
                "You are a helpful support agent. Use the provided knowledge base "
                "context to answer accurately. If the answer is not in the context, "
                "say you will escalate to a human agent.\n\n"
                f"Knowledge base context:\n{context}"
            )
        }]
        messages.extend(conversation_history)
        messages.append({"role": "user", "content": message})
        response = await litellm.acompletion(
            model="gpt-4o-mini",
            messages=messages,
            max_tokens=500,
        )
        return response.choices[0].message.content
```

---

### 2.12 Content → AI Moderation, Auto-Tagging, Summarization

```python
# services/content_intelligence_service.py
import litellm
import json

class ContentIntelligenceService:

    async def moderate(self, content: str) -> dict:
        """AI content moderation — check for policy violations."""
        response = await litellm.acompletion(
            model="gpt-4o-mini",
            messages=[{
                "role": "system",
                "content": (
                    "Moderate this content. Check for: hate speech, harassment, "
                    "explicit content, spam, misinformation, self-harm. "
                    "Return JSON: {\"approved\": bool, \"violations\": [...], "
                    "\"severity\": \"none|low|medium|high\", \"reason\": \"...\"}"
                )
            }, {
                "role": "user",
                "content": content,
            }],
            response_format={"type": "json_object"},
            max_tokens=200,
        )
        return json.loads(response.choices[0].message.content)

    async def auto_tag(self, content: str, available_tags: list[str]) -> list[str]:
        """Auto-generate tags for content."""
        response = await litellm.acompletion(
            model="gpt-4o-mini",
            messages=[{
                "role": "user",
                "content": (
                    f"Content: {content[:2000]}\n\n"
                    f"Available tags: {available_tags}\n\n"
                    "Select the most relevant tags (max 5). "
                    "Return JSON: {\"tags\": [\"...\"]}"
                )
            }],
            response_format={"type": "json_object"},
            max_tokens=100,
        )
        return json.loads(response.choices[0].message.content).get("tags", [])

    async def summarize(self, content: str, max_length: int = 150) -> str:
        """Generate a concise summary of content."""
        response = await litellm.acompletion(
            model="gpt-4o-mini",
            messages=[{
                "role": "user",
                "content": f"Summarize in {max_length} words or less:\n\n{content}",
            }],
            max_tokens=max_length * 2,
        )
        return response.choices[0].message.content
```

---

### 2.13 Notifications → Smart Timing, Relevance Scoring, Channel Optimization

```python
# services/notification_intelligence_service.py
from datetime import datetime

class NotificationIntelligenceService:

    async def score_relevance(
        self, notification: dict, user_preferences: dict, user_activity: list[dict]
    ) -> dict:
        """Score notification relevance to decide send/skip/defer."""
        score = 0.5  # base relevance

        # Boost for matching user interests
        user_topics = set(user_preferences.get("interests", []))
        notif_topics = set(notification.get("tags", []))
        if user_topics & notif_topics:
            score += 0.3

        # Reduce for notification fatigue
        recent_notifs = len([
            a for a in user_activity
            if a["type"] == "notification" and a.get("hours_ago", 999) < 24
        ])
        if recent_notifs > 10:
            score -= 0.3

        # Boost for high-priority events
        if notification.get("priority") == "high":
            score += 0.2

        return {
            "score": round(max(0, min(1, score)), 2),
            "action": "send" if score >= 0.4 else "defer" if score >= 0.2 else "skip",
        }

    def optimal_send_time(self, user_activity: list[dict]) -> str:
        """Determine the best time to send a notification to a user."""
        if not user_activity:
            return "09:00"
        active_hours = [a["timestamp"].hour for a in user_activity if a.get("type") == "app_open"]
        if not active_hours:
            return "09:00"
        from collections import Counter
        most_common = Counter(active_hours).most_common(1)[0][0]
        return f"{most_common:02d}:00"

    def select_channel(
        self, notification: dict, user_preferences: dict
    ) -> str:
        """Select optimal delivery channel: push, email, in_app, sms."""
        priority = notification.get("priority", "normal")
        preferred = user_preferences.get("preferred_channel", "in_app")
        if priority == "critical":
            return "sms"
        elif priority == "high":
            return "push"
        elif preferred in ("email", "push", "in_app"):
            return preferred
        return "in_app"
```

---

## Step 3: Implementation Workflow

When the user asks to enhance a specific feature:

1. **Identify** the feature type from the list above
2. **Assess** current implementation (read the existing code)
3. **Select** the appropriate AI enhancement pattern
4. **Adapt** the pattern to match the project's stack and conventions
5. **Implement** backend service, API route, and frontend component
6. **Add** necessary dependencies (litellm, qdrant-client, numpy, etc.)
7. **Add** environment variables (.env.example)
8. **Write** tests for the new AI features
9. **Update** docker-compose if new services needed (Qdrant, Redis)

### Dependency Checklist

```
# Common dependencies for AI enhancements
litellm>=1.40.0          # Unified LLM gateway
qdrant-client>=1.9.0     # Vector search (if search enhancement)
numpy>=1.24.0            # Numerical operations (anomaly detection, forecasting)
scikit-learn>=1.3.0      # ML utilities (optional, for advanced patterns)
instructor>=1.0.0        # Structured LLM output (optional)
```

### Environment Variables

```env
# AI Enhancement Config
LITELLM_MODEL=gpt-4o-mini
LITELLM_FALLBACK_MODEL=claude-3-5-haiku-20241022
QDRANT_URL=http://localhost:6333
EMBEDDING_MODEL=text-embedding-3-small
AI_ENHANCEMENT_ENABLED=true
```

---

## Step 4: Output Summary

After implementing the enhancement, output:

```
+================================================================+
|  SMART RETROFIT COMPLETE                                        |
+================================================================+
|                                                                 |
|  Feature Enhanced: [feature name]                               |
|  Enhancement Type: [what AI capability was added]               |
|                                                                 |
|  New Files:                                                     |
|  +-- [file1] -- [purpose]                                       |
|  +-- [file2] -- [purpose]                                       |
|                                                                 |
|  Modified Files:                                                |
|  +-- [file1] -- [what changed]                                  |
|                                                                 |
|  New Dependencies: [list]                                       |
|  New Env Vars: [list]                                           |
|  New Services: [Qdrant/Redis/etc. if any]                       |
|                                                                 |
|  Before: [what the feature did before]                          |
|  After:  [what the feature does now with AI]                    |
+================================================================+
```
