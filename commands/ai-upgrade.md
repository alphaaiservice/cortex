---
description: "Upgrade a specific feature with AI capabilities. Implementation counterpart to /suggest-ai-features. Usage: /ai-upgrade search or /ai-upgrade metrics or /ai-upgrade catalog"
---

# AI Upgrade — Add AI Capabilities to an Existing Feature

Upgrade this feature with AI: **$ARGUMENTS**

This is the implementation command. It takes an existing feature in the codebase and adds AI/ML capabilities to it. Works for ANY stack — Python/FastAPI, Node.js/NestJS, Java/Spring Boot, or any other.

**KEY PRINCIPLE: Enhance, do not replace. The existing feature must continue to work. AI adds a layer on top — if the AI service is down, the feature falls back to its original behavior.**

---

## Step 1: Identify the Target Feature

### 1.1: Find the Feature in Codebase

```bash
# Search for the feature by name across the codebase
grep -rn "$ARGUMENTS" . --include="*.py" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.java" --include="*.go" -l 2>/dev/null | head -20

# Search in directory names
find . -type d -iname "*$ARGUMENTS*" -not -path "*/node_modules/*" -not -path "*/.git/*"

# Search in route definitions
grep -rn "/$ARGUMENTS\|$ARGUMENTS" . --include="*route*" --include="*controller*" --include="*handler*" -l 2>/dev/null
```

### 1.2: Analyze Current Implementation

Read the feature's files across all layers:

```
CURRENT IMPLEMENTATION ANALYSIS
════════════════════════════════
Feature: [name]
Description: [what it does now]

Database:
  Tables: [list]
  Key queries: [types of queries — CRUD, search, aggregation]

Backend:
  Models: [files]
  Services: [files + key methods]
  Controllers: [files + endpoints]
  Current logic: [brief description of business logic]

Frontend:
  Pages: [files]
  Components: [files]
  Current UX: [how the user interacts with this feature]

Pain Points (inferred from code):
  1. [limitation of current implementation]
  2. [missing capability]
  3. [poor UX pattern]
```

---

## Step 2: Design the AI Enhancement

Based on the feature type, select the appropriate AI upgrade pattern:

### Search Features → Semantic Search
```
Enhancement: Semantic Search with Vector Embeddings
  Current: SQL LIKE / full-text search
  Upgrade: Embed content → vector DB → similarity search → re-rank

  Components:
    - Embedding pipeline (batch + real-time)
    - Vector storage (Qdrant / pgvector / Pinecone)
    - Hybrid search (keyword + semantic)
    - Result re-ranking with LLM
```

### CRUD / Data Entry → Smart Defaults + Auto-Categorization
```
Enhancement: AI-Assisted Data Entry
  Current: Manual form filling, manual categorization
  Upgrade: Predict field values, auto-categorize, suggest tags

  Components:
    - Classification endpoint (LLM or lightweight model)
    - Smart default prediction based on context
    - Auto-tagging pipeline
    - Confidence score display in UI
```

### Reports / Analytics → AI Narratives + Anomaly Detection
```
Enhancement: AI-Powered Insights
  Current: Static charts and tables
  Upgrade: Natural language summaries, trend explanations, anomaly alerts

  Components:
    - Narrative generation endpoint (LLM)
    - Anomaly detection (statistical or ML-based)
    - Natural language query interface
    - Insight caching layer
```

### Content / CMS → Auto-Tagging + Summarization + Moderation
```
Enhancement: AI Content Pipeline
  Current: Manual content management
  Upgrade: Auto-tag, summarize, moderate, generate SEO metadata

  Components:
    - Content analysis pipeline (on save/publish)
    - Summarization endpoint
    - Moderation scoring
    - SEO metadata generation
```

### Catalog / Products → Recommendations + NL Shopping
```
Enhancement: AI-Powered Discovery
  Current: Category browsing, basic filters
  Upgrade: "Find me X" natural language search, recommendations

  Components:
    - Product embedding pipeline
    - Recommendation engine (collaborative / content-based)
    - Natural language query parser
    - Personalization layer
```

### Metrics / Dashboard → Metric Discovery + Impact Analysis
```
Enhancement: AI Metric Intelligence
  Current: Display metrics, manual analysis
  Upgrade: Explain metrics, detect anomalies, predict trends

  Components:
    - Metric explanation endpoint
    - Anomaly detection pipeline
    - Trend forecasting
    - Impact analysis (what caused the change)
```

### Communication / Messaging → Smart Replies + Sentiment
```
Enhancement: AI-Assisted Communication
  Current: Manual messaging
  Upgrade: Smart reply suggestions, sentiment analysis, auto-prioritize

  Components:
    - Reply suggestion endpoint
    - Sentiment analysis pipeline
    - Priority scoring
    - Conversation summarization
```

---

## Step 3: Implement Backend

### 3.1: Create AI Service

Create a new service file for the AI enhancement. Follow the project's existing patterns.

**For Python/FastAPI:**

```python
# app/services/ai/{feature}_ai_service.py

from typing import Optional
import httpx
from app.core.config import settings

class {Feature}AIService:
    """AI enhancement for {feature} feature.
    
    Provides: [list of AI capabilities]
    Fallback: Returns None/empty when AI service unavailable
    """
    
    def __init__(self):
        self.model = settings.AI_MODEL or "gpt-4o-mini"
        self.api_key = settings.OPENAI_API_KEY  # or ANTHROPIC_API_KEY
        self._client: Optional[httpx.AsyncClient] = None
    
    async def _get_client(self) -> httpx.AsyncClient:
        if self._client is None:
            self._client = httpx.AsyncClient(timeout=30.0)
        return self._client
    
    async def enhance(self, data: dict) -> dict:
        """Main AI enhancement method with fallback."""
        try:
            result = await self._call_ai(data)
            return {"ai_enhanced": True, "result": result}
        except Exception:
            # Graceful fallback — feature works without AI
            return {"ai_enhanced": False, "result": None}
    
    async def _call_ai(self, data: dict) -> dict:
        """Call AI provider. Override for specific implementations."""
        raise NotImplementedError
```

**For Node.js/NestJS:**

```typescript
// src/modules/{feature}/services/{feature}-ai.service.ts

import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class {Feature}AIService {
  private readonly logger = new Logger({Feature}AIService.name);
  
  constructor(private config: ConfigService) {}
  
  async enhance(data: Record<string, any>): Promise<AIResult> {
    try {
      const result = await this.callAI(data);
      return { aiEnhanced: true, result };
    } catch (error) {
      this.logger.warn(`AI enhancement failed, falling back: ${error.message}`);
      return { aiEnhanced: false, result: null };
    }
  }
  
  private async callAI(data: Record<string, any>): Promise<any> {
    // Implementation specific to the enhancement type
  }
}
```

**For Java/Spring Boot:**

```java
// src/main/java/com/app/service/ai/{Feature}AIService.java

@Service
@Slf4j
public class {Feature}AIService {
    
    @Value("${ai.model:gpt-4o-mini}")
    private String model;
    
    public AIResult enhance(Map<String, Object> data) {
        try {
            var result = callAI(data);
            return new AIResult(true, result);
        } catch (Exception e) {
            log.warn("AI enhancement failed, falling back: {}", e.getMessage());
            return new AIResult(false, null);
        }
    }
}
```

### 3.2: Create AI Endpoint

Add a new endpoint to the existing feature's controller:

```
[METHOD] /api/{feature}/ai/{action}
  Purpose: [what the AI endpoint does]
  Input: [request body/params]
  Output: [response shape]
  Auth: [same as parent feature]
  Rate Limit: [stricter than normal — AI calls are expensive]
```

### 3.3: Add Cost Tracking

```python
# Track AI usage for cost monitoring
class AIUsageTracker:
    async def track(self, feature: str, model: str, tokens_in: int, tokens_out: int):
        cost = self._calculate_cost(model, tokens_in, tokens_out)
        await self._store_usage(feature, model, tokens_in, tokens_out, cost)
    
    def _calculate_cost(self, model: str, tokens_in: int, tokens_out: int) -> float:
        rates = {
            "gpt-4o-mini": {"input": 0.15 / 1_000_000, "output": 0.60 / 1_000_000},
            "gpt-4o": {"input": 2.50 / 1_000_000, "output": 10.00 / 1_000_000},
        }
        rate = rates.get(model, rates["gpt-4o-mini"])
        return tokens_in * rate["input"] + tokens_out * rate["output"]
```

### 3.4: Add Guardrails

Every AI endpoint MUST include:

```python
# 1. Rate limiting — stricter than normal endpoints
@rate_limit(requests=100, window=3600)  # 100 AI calls per hour per user

# 2. Cost cap — stop if daily spend exceeds threshold
if await usage_tracker.daily_cost(user_id) > settings.AI_DAILY_COST_CAP:
    raise HTTPException(429, "Daily AI usage limit reached")

# 3. Input validation — prevent prompt injection
sanitized_input = sanitize_for_llm(user_input)

# 4. Output validation — ensure AI response is safe
validated_output = validate_ai_response(raw_output, expected_schema)

# 5. Timeout — AI calls must not hang
async with asyncio.timeout(30):  # 30 second max
    result = await ai_service.enhance(data)

# 6. Fallback — feature works without AI
if not result.ai_enhanced:
    return original_feature_response(data)
```

---

## Step 4: Implement Frontend

### 4.1: Create AI Enhancement Component

Build a reusable component that wraps the AI capability:

```typescript
// components/ai/{Feature}AIPanel.tsx (React/Next.js example)

interface AIEnhancementProps {
  featureData: any;
  onApply: (aiResult: any) => void;
}

export function {Feature}AIPanel({ featureData, onApply }: AIEnhancementProps) {
  const [isLoading, setIsLoading] = useState(false);
  const [aiResult, setAiResult] = useState(null);
  const [error, setError] = useState(null);
  
  // AI enhancement is always optional — show a trigger button
  // Never auto-call AI without user action (costs money)
  
  return (
    <div className="ai-panel">
      <button onClick={handleEnhance} disabled={isLoading}>
        {isLoading ? 'Analyzing...' : 'AI Enhance'}
      </button>
      
      {aiResult && (
        <div className="ai-suggestions">
          {/* Display AI results with confidence scores */}
          {/* Always show "Apply" / "Dismiss" actions */}
        </div>
      )}
      
      {error && (
        <div className="ai-fallback">
          {/* Graceful fallback message — feature still works */}
          AI enhancement unavailable. You can continue manually.
        </div>
      )}
    </div>
  );
}
```

### 4.2: UX Patterns for AI Features

Select the appropriate UX pattern:

```
INLINE SUGGESTION — For search, auto-complete, smart defaults
  Pattern: Show AI results alongside normal results
  Trigger: Automatic (on type, on load)
  Example: "Did you mean..." or ghost text suggestions

SIDEBAR PANEL — For analysis, insights, explanations
  Pattern: Collapsible panel with AI insights
  Trigger: User clicks "AI Insights" button
  Example: Dashboard with "Explain this metric" sidebar

MODAL / DIALOG — For generation, complex actions
  Pattern: Modal with AI-generated content + edit ability
  Trigger: User clicks "Generate with AI" button
  Example: "Generate product description" modal

BADGE / INDICATOR — For classification, scoring, risk
  Pattern: Small badge or score next to items
  Trigger: Automatic (on data load)
  Example: Fraud risk score badge on transactions

TOAST / ALERT — For anomaly detection, breaking changes
  Pattern: Non-blocking notification
  Trigger: Automatic (when anomaly detected)
  Example: "Unusual spike in failed payments detected"
```

### 4.3: Loading and Error States

```
Required States:
  IDLE        — AI not yet invoked, show trigger button
  LOADING     — AI processing, show skeleton/spinner with estimate
  SUCCESS     — AI result available, show with confidence
  ERROR       — AI failed, show fallback (feature still works)
  RATE_LIMITED — User hit AI limit, show when limit resets
```

---

## Step 5: Implement Tests

### 5.1: Unit Tests for AI Service

```python
# tests/test_{feature}_ai_service.py

class Test{Feature}AIService:
    async def test_enhance_success(self):
        """AI enhancement returns valid result."""
        
    async def test_enhance_fallback_on_api_error(self):
        """Feature works when AI API is down."""
        
    async def test_enhance_respects_rate_limit(self):
        """Rate limiting prevents excessive AI calls."""
        
    async def test_enhance_respects_cost_cap(self):
        """Cost cap stops AI calls when budget exceeded."""
        
    async def test_enhance_sanitizes_input(self):
        """Prompt injection attempts are neutralized."""
        
    async def test_enhance_validates_output(self):
        """Malformed AI responses are caught and handled."""
        
    async def test_enhance_timeout(self):
        """Slow AI responses are terminated within timeout."""
```

### 5.2: Integration Tests

```python
# tests/integration/test_{feature}_ai_endpoint.py

class Test{Feature}AIEndpoint:
    async def test_endpoint_returns_ai_result(self):
        """Endpoint returns AI-enhanced response."""
        
    async def test_endpoint_requires_auth(self):
        """AI endpoint requires same auth as parent feature."""
        
    async def test_endpoint_rate_limited(self):
        """AI endpoint respects rate limits."""
```

---

## Step 6: Update Configuration

### 6.1: Environment Variables

Add to `.env` / `.env.example`:

```bash
# AI Enhancement Configuration
AI_PROVIDER=openai          # openai | anthropic | groq | local
AI_MODEL=gpt-4o-mini        # default model for this feature
AI_API_KEY=sk-...            # provider API key
AI_DAILY_COST_CAP=5.00      # max daily AI spend in USD
AI_RATE_LIMIT=100            # max AI calls per user per hour
AI_TIMEOUT=30                # max seconds for AI response
AI_FALLBACK_ENABLED=true     # enable graceful fallback
```

### 6.2: Feature Flag (Optional)

If the project has feature flags, wrap the AI enhancement:

```python
if feature_flags.is_enabled("ai_{feature}_enhancement", user_id):
    result = await ai_service.enhance(data)
else:
    result = original_response
```

---

## Step 7: Output Summary

After implementation, display:

```
╔══════════════════════════════════════════════════════════════╗
║  AI UPGRADE COMPLETE                                          ║
╠══════════════════════════════════════════════════════════════╣
║  Feature: [name]                                              ║
║  Enhancement: [type of AI added]                              ║
║                                                               ║
║  Files Created:                                               ║
║    Backend:  [list of new/modified files]                     ║
║    Frontend: [list of new/modified files]                     ║
║    Tests:    [list of new test files]                         ║
║    Config:   [list of config changes]                         ║
║                                                               ║
║  AI Model: [model name]                                       ║
║  Estimated Cost: $[X]/1000 requests                           ║
║  Rate Limit: [X] calls/hour/user                              ║
║  Fallback: Enabled (feature works without AI)                 ║
║                                                               ║
║  To test:                                                     ║
║    1. Set AI_API_KEY in .env                                  ║
║    2. Run: [test command]                                     ║
║    3. Start server and test the [feature] page                ║
║                                                               ║
║  Next: /estimate-cost "[feature] AI" for cost projection      ║
╚══════════════════════════════════════════════════════════════╝
```

---

## Critical Rules

1. **Never break the existing feature.** The AI enhancement is an addition. If `AI_API_KEY` is not set or the AI service is down, the feature MUST work exactly as before.

2. **Always add cost tracking.** Every AI call must be logged with token usage and calculated cost. This is non-negotiable — runaway AI costs can bankrupt a startup.

3. **Never auto-call AI on page load for expensive operations.** Require explicit user action (click a button) for any AI call that costs more than $0.001. Auto-calls are only acceptable for cheap operations like classification with GPT-4o-mini.

4. **Sanitize ALL user input before sending to LLM.** Prompt injection is a real attack vector. Strip HTML, limit length, and use system prompts to constrain behavior.

5. **Show confidence scores.** When AI classifies, suggests, or generates, always show the model's confidence so users can decide whether to trust the result.

6. **Match the project's existing patterns.** If the project uses dependency injection, use it. If it uses a specific folder structure, follow it. The AI service should feel native to the codebase.

7. **Include rate limiting AND cost caps.** Rate limiting protects against abuse. Cost caps protect against accidental overspend. Both are required.
