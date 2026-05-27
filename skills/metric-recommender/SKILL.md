---
name: metric-recommender
description: "Auto-invoked when user adds new features, sets up monitoring, asks about metrics, KPIs, observability, or 'what should I measure'. Provides metric recommendations per feature type (Auth, Payments, GenAI/RAG, Search, API, Frontend, Database, Mobile) with instrumentation code snippets for Python/FastAPI, Node.js/NestJS, Java/Spring Boot, and React/React Native."
license: "Proprietary — Alpha AI Service Pvt Ltd"
compatibility: "Designed for Claude Code with cortex plugin"
metadata:
  author: "Alpha AI Service Pvt Ltd"
  version: "1.0"
---

# Metric Recommender — What to Measure for Every Feature

This skill recommends the right metrics for any feature type and provides ready-to-use instrumentation code. It covers backend, frontend, mobile, AI/ML, and business metrics.

---

## Step 0: Detect Feature Type

Identify which feature areas exist in the project:

```
1. Scan the codebase:
   - Grep for auth code → Auth metrics needed
   - Grep for payment/billing code → Payment metrics needed
   - Grep for LLM/embedding/RAG code → GenAI metrics needed
   - Grep for search endpoints → Search metrics needed
   - Grep for API routes → API metrics needed
   - Grep for React/Next.js → Frontend metrics needed
   - Grep for database models → Database metrics needed
   - Grep for React Native/Expo → Mobile metrics needed

2. Check existing monitoring:
   - Is Prometheus configured? (prometheus_client import)
   - Is Sentry configured? (sentry_sdk import)
   - Is PostHog/Mixpanel configured? (analytics imports)
   - Is Grafana configured? (grafana dashboards)
```

---

## Metrics by Feature Type

### 1. Auth Metrics

| Metric | Type | Description | Alert Threshold |
|---|---|---|---|
| `auth_login_total` | Counter | Total login attempts (label: success/failure) | Failure rate > 20% |
| `auth_login_duration_seconds` | Histogram | Login request latency | p95 > 2s |
| `auth_session_active` | Gauge | Currently active sessions | Sudden drop > 50% |
| `auth_token_refresh_total` | Counter | Token refresh events | Failure rate > 5% |
| `auth_2fa_adoption_ratio` | Gauge | % of users with 2FA enabled | Below 30% |
| `auth_failed_attempts_per_user` | Counter | Failed login attempts per user | > 5 in 10 min (brute force) |
| `auth_password_reset_total` | Counter | Password reset requests | Spike > 3x normal |
| `auth_oauth_total` | Counter | OAuth login attempts (label: provider) | Failure rate > 10% |

#### Python/FastAPI Instrumentation

```python
# metrics/auth_metrics.py
from prometheus_client import Counter, Histogram, Gauge

auth_login_total = Counter(
    "auth_login_total",
    "Total login attempts",
    ["method", "status"],  # method: password|oauth|2fa, status: success|failure
)

auth_login_duration = Histogram(
    "auth_login_duration_seconds",
    "Login request latency",
    ["method"],
    buckets=[0.05, 0.1, 0.25, 0.5, 1.0, 2.0, 5.0],
)

auth_active_sessions = Gauge(
    "auth_sessions_active",
    "Currently active sessions",
)

# Usage in auth service:
async def login(self, credentials: LoginRequest) -> TokenResponse:
    with auth_login_duration.labels(method="password").time():
        try:
            result = await self._authenticate(credentials)
            auth_login_total.labels(method="password", status="success").inc()
            auth_active_sessions.inc()
            return result
        except AuthenticationError:
            auth_login_total.labels(method="password", status="failure").inc()
            raise
```

#### Node.js/NestJS Instrumentation

```typescript
// metrics/auth.metrics.ts
import { Injectable } from '@nestjs/common';
import { Counter, Histogram, Gauge, register } from 'prom-client';

@Injectable()
export class AuthMetrics {
  readonly loginTotal = new Counter({
    name: 'auth_login_total',
    help: 'Total login attempts',
    labelNames: ['method', 'status'],
  });

  readonly loginDuration = new Histogram({
    name: 'auth_login_duration_seconds',
    help: 'Login request latency',
    labelNames: ['method'],
    buckets: [0.05, 0.1, 0.25, 0.5, 1.0, 2.0, 5.0],
  });

  readonly activeSessions = new Gauge({
    name: 'auth_sessions_active',
    help: 'Currently active sessions',
  });
}
```

---

### 2. Payment Metrics

| Metric | Type | Description | Alert Threshold |
|---|---|---|---|
| `payment_transaction_total` | Counter | Total transactions (label: status, method) | Failure rate > 5% |
| `payment_amount_total` | Counter | Total revenue processed (in cents) | Sudden drop > 30% |
| `payment_mrr` | Gauge | Monthly Recurring Revenue | MoM decline > 10% |
| `payment_churn_rate` | Gauge | Monthly churn rate (cancelled / total) | > 5% |
| `payment_ltv_average` | Gauge | Average Customer Lifetime Value | Declining trend |
| `payment_arpu` | Gauge | Average Revenue Per User | Declining trend |
| `payment_failed_rate` | Gauge | Failed payment rate | > 3% |
| `payment_refund_total` | Counter | Total refunds processed | Spike > 3x normal |
| `payment_processing_duration` | Histogram | Payment processing latency | p95 > 5s |
| `payment_dispute_total` | Counter | Payment disputes/chargebacks | Any dispute |

```python
# metrics/payment_metrics.py
from prometheus_client import Counter, Histogram, Gauge

payment_transaction_total = Counter(
    "payment_transaction_total",
    "Total payment transactions",
    ["status", "method", "currency"],  # status: success|failed|pending
)

payment_amount_total = Counter(
    "payment_amount_cents_total",
    "Total revenue processed in cents",
    ["currency", "plan"],
)

payment_processing_duration = Histogram(
    "payment_processing_duration_seconds",
    "Payment processing latency",
    ["gateway", "method"],  # gateway: razorpay|stripe, method: card|upi|netbanking
    buckets=[0.5, 1.0, 2.0, 5.0, 10.0, 30.0],
)

payment_mrr = Gauge("payment_mrr_cents", "Monthly Recurring Revenue in cents")
payment_churn_rate = Gauge("payment_churn_rate", "Monthly churn rate")
payment_arpu = Gauge("payment_arpu_cents", "Average Revenue Per User in cents")

# Usage:
async def process_payment(self, payment: PaymentRequest) -> PaymentResult:
    with payment_processing_duration.labels(
        gateway="razorpay", method=payment.method
    ).time():
        try:
            result = await self.gateway.charge(payment)
            payment_transaction_total.labels(
                status="success", method=payment.method, currency=payment.currency
            ).inc()
            payment_amount_total.labels(
                currency=payment.currency, plan=payment.plan
            ).inc(payment.amount_cents)
            return result
        except PaymentError:
            payment_transaction_total.labels(
                status="failed", method=payment.method, currency=payment.currency
            ).inc()
            raise
```

---

### 3. GenAI / RAG Metrics

| Metric | Type | Description | Alert Threshold |
|---|---|---|---|
| `llm_request_total` | Counter | Total LLM API calls (label: model, status) | Error rate > 5% |
| `llm_latency_seconds` | Histogram | LLM response latency | p95 > 10s |
| `llm_tokens_total` | Counter | Total tokens used (label: model, direction) | Budget > 80% |
| `llm_cost_cents` | Counter | Cost in cents (label: model) | Daily budget exceeded |
| `rag_retrieval_latency` | Histogram | Vector search latency | p95 > 2s |
| `rag_context_tokens` | Histogram | Context tokens per query | > model limit |
| `rag_relevance_score` | Histogram | Retrieved doc relevance scores | Avg < 0.5 |
| `rag_faithfulness_score` | Gauge | RAGAS faithfulness score | < 0.7 |
| `rag_answer_relevancy` | Gauge | RAGAS answer relevancy | < 0.7 |
| `llm_cache_hit_rate` | Gauge | Semantic cache hit ratio | < 20% |
| `llm_hallucination_rate` | Gauge | Detected hallucination rate | > 10% |
| `llm_guardrail_blocked` | Counter | Requests blocked by guardrails | Spike > 5x |

```python
# metrics/genai_metrics.py
from prometheus_client import Counter, Histogram, Gauge

llm_request_total = Counter(
    "llm_request_total",
    "Total LLM API calls",
    ["model", "status", "operation"],  # operation: chat|embed|classify
)

llm_latency = Histogram(
    "llm_latency_seconds",
    "LLM response latency",
    ["model", "operation"],
    buckets=[0.5, 1.0, 2.0, 5.0, 10.0, 30.0, 60.0],
)

llm_tokens = Counter(
    "llm_tokens_total",
    "Total tokens used",
    ["model", "direction"],  # direction: input|output
)

llm_cost_cents = Counter(
    "llm_cost_cents_total",
    "LLM API cost in cents",
    ["model"],
)

rag_retrieval_latency = Histogram(
    "rag_retrieval_latency_seconds",
    "Vector search retrieval latency",
    buckets=[0.05, 0.1, 0.25, 0.5, 1.0, 2.0],
)

rag_relevance_score = Histogram(
    "rag_relevance_score",
    "Retrieved document relevance scores",
    buckets=[0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0],
)

llm_cache_hit_rate = Gauge("llm_cache_hit_rate", "Semantic cache hit ratio")

# Usage in LLM service:
async def generate(self, prompt: str, model: str = "gpt-4o-mini") -> str:
    with llm_latency.labels(model=model, operation="chat").time():
        try:
            response = await litellm.acompletion(model=model, messages=[...])
            llm_request_total.labels(model=model, status="success", operation="chat").inc()
            llm_tokens.labels(model=model, direction="input").inc(response.usage.prompt_tokens)
            llm_tokens.labels(model=model, direction="output").inc(response.usage.completion_tokens)
            cost = self._calculate_cost(model, response.usage)
            llm_cost_cents.labels(model=model).inc(int(cost * 100))
            return response.choices[0].message.content
        except Exception as e:
            llm_request_total.labels(model=model, status="error", operation="chat").inc()
            raise
```

---

### 4. Search Metrics

| Metric | Type | Description | Alert Threshold |
|---|---|---|---|
| `search_query_total` | Counter | Total search queries | - |
| `search_latency_seconds` | Histogram | Search response latency | p95 > 500ms |
| `search_zero_results_rate` | Gauge | % of queries with 0 results | > 15% |
| `search_click_through_rate` | Gauge | % of searches that lead to clicks | < 30% |
| `search_ndcg` | Gauge | Normalized Discounted Cumulative Gain | < 0.5 |
| `search_results_count` | Histogram | Number of results per query | Avg < 3 |

```python
# metrics/search_metrics.py
from prometheus_client import Counter, Histogram, Gauge

search_query_total = Counter(
    "search_query_total", "Total search queries", ["type"],  # type: keyword|semantic|hybrid
)
search_latency = Histogram(
    "search_latency_seconds", "Search latency",
    ["type"],
    buckets=[0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0],
)
search_zero_results = Counter("search_zero_results_total", "Queries with zero results")
search_results_count = Histogram(
    "search_results_count", "Results per query",
    buckets=[0, 1, 3, 5, 10, 20, 50, 100],
)
```

---

### 5. API Metrics

| Metric | Type | Description | Alert Threshold |
|---|---|---|---|
| `http_request_total` | Counter | Total HTTP requests (method, path, status) | Error rate > 5% |
| `http_request_duration_seconds` | Histogram | Request latency | p95 > 500ms |
| `http_request_size_bytes` | Histogram | Request payload size | > 10MB |
| `http_response_size_bytes` | Histogram | Response payload size | > 5MB |
| `http_rate_limit_hits` | Counter | Rate limit violations | Spike > 3x |
| `http_active_requests` | Gauge | Currently in-flight requests | > 80% capacity |

```python
# middleware/metrics_middleware.py
import time
from prometheus_client import Counter, Histogram, Gauge
from starlette.middleware.base import BaseHTTPMiddleware

http_request_total = Counter(
    "http_request_total", "Total HTTP requests",
    ["method", "path", "status"],
)
http_request_duration = Histogram(
    "http_request_duration_seconds", "Request latency",
    ["method", "path"],
    buckets=[0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0],
)
http_active_requests = Gauge("http_active_requests", "In-flight requests")

class MetricsMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        path = self._normalize_path(request.url.path)
        http_active_requests.inc()
        start = time.perf_counter()
        try:
            response = await call_next(request)
            duration = time.perf_counter() - start
            http_request_total.labels(
                method=request.method, path=path, status=response.status_code
            ).inc()
            http_request_duration.labels(
                method=request.method, path=path
            ).observe(duration)
            return response
        finally:
            http_active_requests.dec()

    def _normalize_path(self, path: str) -> str:
        """Normalize path to avoid high-cardinality labels."""
        import re
        # Replace UUIDs and numeric IDs with placeholders
        path = re.sub(r"/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", "/{uuid}", path)
        path = re.sub(r"/\d+", "/{id}", path)
        return path
```

---

### 6. Frontend Metrics (Core Web Vitals)

| Metric | Type | Description | Target |
|---|---|---|---|
| `web_lcp_seconds` | Histogram | Largest Contentful Paint | < 2.5s |
| `web_fid_ms` | Histogram | First Input Delay | < 100ms |
| `web_cls` | Histogram | Cumulative Layout Shift | < 0.1 |
| `web_inp_ms` | Histogram | Interaction to Next Paint | < 200ms |
| `web_ttfb_ms` | Histogram | Time to First Byte | < 800ms |
| `web_bounce_rate` | Gauge | Bounce rate per page | < 40% |
| `web_conversion_rate` | Gauge | Conversion rate per funnel | Declining |
| `web_js_error_total` | Counter | JavaScript errors | Any increase |

```typescript
// lib/web-vitals.ts
import { onLCP, onFID, onCLS, onINP, onTTFB } from 'web-vitals';

function sendMetric(metric: { name: string; value: number; id: string }) {
  // Send to your analytics endpoint
  navigator.sendBeacon('/api/metrics/web-vitals', JSON.stringify({
    name: metric.name,
    value: metric.value,
    page: window.location.pathname,
    timestamp: Date.now(),
  }));
}

// Initialize in app entry point
export function initWebVitals() {
  onLCP(sendMetric);
  onFID(sendMetric);
  onCLS(sendMetric);
  onINP(sendMetric);
  onTTFB(sendMetric);
}

// Error tracking
window.addEventListener('error', (event) => {
  navigator.sendBeacon('/api/metrics/js-error', JSON.stringify({
    message: event.message,
    filename: event.filename,
    lineno: event.lineno,
    colno: event.colno,
    page: window.location.pathname,
    timestamp: Date.now(),
  }));
});
```

---

### 7. Database Metrics

| Metric | Type | Description | Alert Threshold |
|---|---|---|---|
| `db_query_duration_seconds` | Histogram | Query execution time | p95 > 100ms |
| `db_connection_pool_active` | Gauge | Active connections | > 80% pool size |
| `db_connection_pool_idle` | Gauge | Idle connections | 0 (pool exhausted) |
| `db_slow_query_total` | Counter | Queries exceeding 100ms | > 10/min |
| `db_query_total` | Counter | Total queries (label: operation) | - |
| `db_cache_hit_rate` | Gauge | Query cache hit ratio | < 70% |
| `db_replication_lag_seconds` | Gauge | Replica lag (if applicable) | > 5s |
| `db_deadlock_total` | Counter | Deadlocks detected | Any |

```python
# metrics/db_metrics.py
from prometheus_client import Counter, Histogram, Gauge

db_query_duration = Histogram(
    "db_query_duration_seconds", "Query execution time",
    ["operation", "table"],
    buckets=[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0],
)
db_pool_active = Gauge("db_connection_pool_active", "Active DB connections")
db_pool_idle = Gauge("db_connection_pool_idle", "Idle DB connections")
db_slow_queries = Counter("db_slow_query_total", "Slow queries (>100ms)", ["table"])
db_deadlocks = Counter("db_deadlock_total", "Deadlocks detected")
```

---

### 8. Mobile App Metrics

| Metric | Type | Description | Target |
|---|---|---|---|
| `mobile_crash_rate` | Gauge | Crash rate (crashes / sessions) | < 1% |
| `mobile_anr_rate` | Gauge | ANR rate (Android Not Responding) | < 0.5% |
| `mobile_app_load_seconds` | Histogram | App cold start time | < 2s |
| `mobile_screen_load_seconds` | Histogram | Screen transition time | < 500ms |
| `mobile_retention_d1` | Gauge | Day 1 retention rate | > 40% |
| `mobile_retention_d7` | Gauge | Day 7 retention rate | > 20% |
| `mobile_retention_d30` | Gauge | Day 30 retention rate | > 10% |
| `mobile_api_latency` | Histogram | API call latency from device | p95 < 2s |
| `mobile_offline_sync_failures` | Counter | Failed offline sync attempts | > 5% |

```typescript
// lib/mobile-metrics.ts (React Native)
import analytics from '@react-native-firebase/analytics';

export const MobileMetrics = {
  async trackScreenLoad(screenName: string, durationMs: number) {
    await analytics().logEvent('screen_load', {
      screen: screenName,
      duration_ms: durationMs,
    });
  },

  async trackApiCall(endpoint: string, durationMs: number, status: number) {
    await analytics().logEvent('api_call', {
      endpoint,
      duration_ms: durationMs,
      status,
      success: status >= 200 && status < 300,
    });
  },

  async trackAppStart(coldStart: boolean, durationMs: number) {
    await analytics().logEvent('app_start', {
      cold_start: coldStart,
      duration_ms: durationMs,
    });
  },

  async trackError(error: string, context: string) {
    await analytics().logEvent('app_error', {
      error: error.substring(0, 100),
      context,
    });
  },
};
```

---

## Grafana Dashboard Recommendations

For each feature type, suggest Grafana dashboard panels:

### Auth Dashboard
- Login success/failure rate (time series)
- Active sessions (gauge)
- Failed login attempts heatmap (by hour)
- 2FA adoption trend

### Payment Dashboard
- MRR trend (time series)
- Transaction success rate (gauge)
- Revenue by plan (pie chart)
- Churn rate trend
- Failed payment reasons (bar chart)

### GenAI Dashboard
- LLM request rate and latency (time series)
- Token usage and cost (stacked area)
- Cache hit rate (gauge)
- RAG relevance scores (histogram)
- Cost per query trend

### API Dashboard
- Request rate and error rate (time series)
- Latency percentiles p50/p95/p99 (time series)
- Top endpoints by request count (table)
- Slowest endpoints (table)
- Active connections (gauge)

---

## Step 1: Output Metric Recommendations

Present recommendations for the specific project:

```
+================================================================+
|  METRIC RECOMMENDATIONS                                         |
+================================================================+
|                                                                 |
|  Features Detected: [Auth, Payments, GenAI, API, Frontend]      |
|                                                                 |
|  Recommended Metrics:                                           |
|  +-- Auth: [X] metrics (login rate, sessions, 2FA adoption)     |
|  +-- Payments: [X] metrics (MRR, churn, failure rate)           |
|  +-- GenAI: [X] metrics (latency, tokens, cost, relevance)      |
|  +-- API: [X] metrics (request rate, latency, error rate)       |
|  +-- Frontend: [X] metrics (LCP, FID, CLS, bounce rate)        |
|                                                                 |
|  Existing Monitoring: [Prometheus / Sentry / PostHog / None]    |
|                                                                 |
|  Next Steps:                                                    |
|  1. Add prometheus_client to requirements.txt                   |
|  2. Create metrics/ directory with metric definitions            |
|  3. Add MetricsMiddleware to FastAPI app                        |
|  4. Set up Grafana dashboards                                   |
|  5. Configure alert rules in Grafana/Alertmanager               |
+================================================================+
```
