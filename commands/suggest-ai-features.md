---
description: "Scan an existing codebase and recommend where AI/ML can add value. Generates AI_ENHANCEMENT_PLAN.md with prioritized opportunities. Usage: /suggest-ai-features [path-to-project]"
---

# Suggest AI Features — Intelligent Enhancement Discovery

Analyze project at: **$ARGUMENTS** (default: current directory)

Scan the existing codebase to discover where AI and machine learning capabilities can add measurable value. This command works for ANY stack — Python, Node.js, Java, Ruby, Go, or any other.

**KEY PRINCIPLE: Only suggest AI features that genuinely improve the user experience or operational efficiency. Never suggest AI for the sake of AI. Every recommendation must have a clear ROI justification.**

---

## Step 1: Analyze Project Structure

### 1.1: Detect Tech Stack

```bash
# Detect backend language/framework
ls package.json requirements.txt build.gradle pom.xml go.mod Gemfile Cargo.toml 2>/dev/null

# Detect frontend framework
grep -r "react\|vue\|angular\|svelte\|next\|nuxt" package.json 2>/dev/null

# Detect database
grep -ri "mysql\|postgres\|mongo\|sqlite\|redis\|supabase\|firebase\|dynamo" . --include="*.json" --include="*.yml" --include="*.yaml" --include="*.env*" --include="*.toml" -l 2>/dev/null | head -10

# Detect existing AI/ML usage
grep -ri "openai\|anthropic\|langchain\|huggingface\|transformers\|tensorflow\|pytorch\|sklearn\|litellm" . --include="*.py" --include="*.ts" --include="*.js" --include="*.java" -l 2>/dev/null
```

### 1.2: Identify Existing Features

Scan the codebase to build a feature inventory. Look for:

```
Feature Detection Patterns:
  Authentication    → auth/, login, register, JWT, session, OAuth
  User Management   → users/, profiles/, roles/, permissions/
  Search            → search/, query, filter, find, lookup
  CRUD Operations   → create, read, update, delete, list, get
  Reports/Analytics → reports/, analytics/, dashboard/, metrics/, charts/
  Payments          → payment/, billing/, invoice/, subscription/, stripe, razorpay
  Content/CMS       → content/, posts/, articles/, pages/, blog/, media/
  Messaging/Chat    → chat/, messages/, notifications/, inbox/
  File Management   → upload/, files/, documents/, storage/, media/
  Email             → email/, mail/, templates/, notifications/
  E-commerce        → products/, catalog/, cart/, orders/, inventory/
  Scheduling        → calendar/, events/, bookings/, appointments/
  Data Import/Export→ import/, export/, csv, excel, bulk/
  Workflows         → workflow/, pipeline/, approval/, state-machine/
  Forms/Surveys     → forms/, surveys/, questionnaire/, feedback/
```

Read route files, controllers, and service files to understand what each feature does.

### 1.3: Build Feature Inventory

Create a structured inventory:

```
FEATURE INVENTORY
═════════════════
Project: [name]
Stack: [backend] + [frontend] + [database]
Features Found: [count]

1. [Feature Name] — [brief description]
   Files: [key files]
   Data: [tables/collections involved]
   Complexity: Simple | Medium | Complex
```

---

## Step 2: Map AI Enhancement Opportunities

For EACH feature found, evaluate potential AI enhancements from this catalog:

### Search Features
| Current | AI Enhancement | Value |
|---------|---------------|-------|
| Keyword search (SQL LIKE) | Semantic search with embeddings | Users find results by meaning, not exact words |
| Filter-based search | Natural language queries ("show me cheap hotels near the beach") | 10x better UX |
| No search | Auto-complete + "Did you mean?" | Reduce zero-result searches |
| Basic sort/rank | AI-powered relevance ranking | Surface best results first |

### CRUD / Data Entry
| Current | AI Enhancement | Value |
|---------|---------------|-------|
| Manual form filling | Smart defaults based on context/history | 50% faster data entry |
| Manual categorization | Auto-categorization with classification models | Eliminate manual tagging |
| Manual data validation | AI-powered anomaly detection on input | Catch errors before save |
| Duplicate records | AI deduplication (fuzzy matching) | Cleaner data |
| Manual data enrichment | Auto-enrich from external sources | Richer records automatically |

### Reports & Analytics
| Current | AI Enhancement | Value |
|---------|---------------|-------|
| Static charts/tables | AI narrative summaries ("Revenue up 23% driven by...") | Instant insights |
| Manual trend analysis | Automated trend detection + alerts | Proactive monitoring |
| Fixed report templates | Natural language report builder ("show me Q4 sales by region") | Self-service analytics |
| Raw metric display | Metric explanation ("This is 15% above industry average") | Contextual understanding |
| Manual forecasting | ML-based forecasting (time series) | Predict future trends |

### Authentication & Security
| Current | AI Enhancement | Value |
|---------|---------------|-------|
| Password-only auth | Login risk scoring (new device, unusual time, geo) | Prevent account takeover |
| No fraud detection | Behavioral anomaly detection | Catch suspicious activity |
| Manual audit review | AI-powered audit log analysis | Auto-detect threats |
| Static rate limiting | Adaptive rate limiting based on behavior patterns | Smarter protection |

### Payments & Billing
| Current | AI Enhancement | Value |
|---------|---------------|-------|
| Manual refund review | Fraud detection scoring on transactions | Reduce chargebacks |
| Static pricing | Dynamic pricing based on demand/segments | Optimize revenue |
| No churn prediction | Churn prediction model on usage patterns | Retain customers |
| Manual dunning | Smart retry timing for failed payments | Recover more revenue |

### Content & CMS
| Current | AI Enhancement | Value |
|---------|---------------|-------|
| Manual tagging | Auto-tagging with NLP classification | Save hours of manual work |
| No moderation | AI content moderation (text + images) | Safer platform |
| No summarization | Auto-generate summaries/excerpts | Better content discovery |
| Manual SEO | AI-powered SEO suggestions | Higher search rankings |
| No translation | Auto-translation with LLMs | Reach global audience |

### Messaging & Notifications
| Current | AI Enhancement | Value |
|---------|---------------|-------|
| Manual replies | Smart reply suggestions | Faster response times |
| Blast notifications | Personalized notification timing + content | Higher engagement |
| No prioritization | AI inbox prioritization | Focus on what matters |
| Manual escalation | Auto-escalate based on sentiment analysis | Faster resolution |

### E-commerce & Catalog
| Current | AI Enhancement | Value |
|---------|---------------|-------|
| Manual product descriptions | AI-generated product descriptions | Scale catalog faster |
| Category browsing only | "Find me a gift for..." natural language shopping | Better discovery |
| No recommendations | Collaborative filtering / content-based recommendations | Higher AOV |
| Manual inventory | Demand forecasting for inventory planning | Reduce stockouts |
| Static product images | AI image enhancement / background removal | Better visuals |

### Data & Import/Export
| Current | AI Enhancement | Value |
|---------|---------------|-------|
| Manual data mapping | AI-powered column mapping for imports | Effortless data import |
| No data quality | Automated data quality scoring + cleaning | Trust your data |
| Manual extraction | Document extraction (OCR + LLM parsing) | Automate document processing |
| CSV/Excel only | Natural language data queries | Non-technical users get answers |

### Scheduling & Bookings
| Current | AI Enhancement | Value |
|---------|---------------|-------|
| Manual scheduling | Smart scheduling (find optimal slots) | Reduce scheduling friction |
| No-show problem | No-show prediction + overbooking optimization | Maximize utilization |
| Manual reminders | Personalized reminder timing | Reduce no-shows |

### Forms & Surveys
| Current | AI Enhancement | Value |
|---------|---------------|-------|
| Manual response review | AI sentiment analysis on responses | Instant feedback insights |
| Static forms | Adaptive forms (skip irrelevant questions) | Higher completion rates |
| Manual categorization | Auto-categorize open-ended responses | Structured insights |

---

## Step 3: Score and Prioritize Opportunities

For each identified opportunity, score on two axes:

### Impact Score (1-5)
- **5**: Revenue-generating or significant cost savings
- **4**: Major UX improvement or time savings
- **3**: Noticeable improvement for users
- **2**: Nice-to-have enhancement
- **1**: Marginal improvement

### Effort Score (1-5)
- **1**: Drop-in API call (1-2 days)
- **2**: New service + endpoint (3-5 days)
- **3**: New feature with UI (1-2 weeks)
- **4**: Significant architecture addition (2-4 weeks)
- **5**: Major system redesign (1+ months)

### ROI Priority = Impact / Effort
- **Priority 1 (Quick Wins)**: High impact, low effort (score > 2.0)
- **Priority 2 (Strategic)**: High impact, medium effort (score 1.0-2.0)
- **Priority 3 (Nice-to-Have)**: Medium impact, medium effort (score 0.5-1.0)
- **Priority 4 (Long-term)**: Any impact, high effort (score < 0.5)

---

## Step 4: Design Implementation Architecture

For each Priority 1 and Priority 2 opportunity, provide:

```
### [Enhancement Name]
**Feature**: [existing feature being enhanced]
**AI Type**: Classification | Generation | Search | Prediction | Extraction | Recommendation
**Approach**: [specific technique — embeddings, fine-tuning, prompt engineering, etc.]

**Backend Changes**:
- New service: [service name and responsibility]
- New endpoint: [HTTP method + path + purpose]
- Dependencies: [new packages/APIs needed]

**Frontend Changes**:
- New component: [component name and purpose]
- Modified page: [which page gets the AI feature]
- UX pattern: [inline suggestion | sidebar panel | modal | auto-complete | etc.]

**Data Requirements**:
- Training data: [what data is needed, where it comes from]
- Vector storage: [if embeddings needed — Qdrant, Pinecone, pgvector, etc.]
- Caching: [cache strategy for AI responses]

**Cost Estimate** (per 1000 requests):
- LLM API: $[amount] ([model] at [tokens/request])
- Embedding: $[amount] (if applicable)
- Infrastructure: $[amount] (vector DB, compute)

**Estimated Effort**: [X days]
```

---

## Step 5: Generate AI_ENHANCEMENT_PLAN.md

```markdown
# AI Enhancement Plan
**Generated**: [date]
**Project**: [name]
**Stack**: [detected stack]
**Features Analyzed**: [count]

## Executive Summary
[2-3 sentences: how many AI opportunities found, top 3 recommendations, estimated total ROI]

## Feature Inventory
| # | Feature | Current State | AI Opportunities |
|---|---------|--------------|-----------------|
| 1 | [feature] | [brief description] | [count] opportunities |

## AI Enhancement Opportunities

### Priority 1 — Quick Wins (High Impact, Low Effort)
| # | Enhancement | Feature | Impact | Effort | ROI Score | Est. Days |
|---|-------------|---------|--------|--------|-----------|-----------|
| 1 | [name] | [feature] | [1-5] | [1-5] | [ratio] | [days] |

### Priority 2 — Strategic Investments
| # | Enhancement | Feature | Impact | Effort | ROI Score | Est. Days |
|---|-------------|---------|--------|--------|-----------|-----------|

### Priority 3 — Nice-to-Have
| # | Enhancement | Feature | Impact | Effort | ROI Score | Est. Days |
|---|-------------|---------|--------|--------|-----------|-----------|

### Priority 4 — Long-term Vision
| # | Enhancement | Feature | Impact | Effort | ROI Score | Est. Days |
|---|-------------|---------|--------|--------|-----------|-----------|

## Detailed Implementation Plans

### [Enhancement 1 — highest priority]
[Full architecture from Step 4]

### [Enhancement 2]
[Full architecture from Step 4]

[... for all Priority 1 and Priority 2 items ...]

## Cost Projection
| Scale | Monthly AI API Cost | Infrastructure | Total |
|-------|-------------------|----------------|-------|
| MVP (100 users) | $[X] | $[X] | $[X] |
| Growth (10K users) | $[X] | $[X] | $[X] |
| Scale (100K users) | $[X] | $[X] | $[X] |

## Recommended Implementation Order
1. [First enhancement — why start here]
2. [Second enhancement — builds on first]
3. [Third enhancement]
[... ordered sequence with dependencies noted ...]

## Technology Recommendations
| Need | Recommended | Alternative | Why |
|------|------------|-------------|-----|
| LLM Provider | [e.g., OpenAI GPT-4o-mini] | [e.g., Claude Haiku] | [cost/quality tradeoff] |
| Embeddings | [e.g., text-embedding-3-small] | [e.g., Cohere embed] | [cost/quality] |
| Vector DB | [e.g., Qdrant] | [e.g., pgvector] | [scale/simplicity] |
| Orchestration | [e.g., LiteLLM] | [e.g., direct API] | [flexibility] |

## Next Steps
- Run `/ai-upgrade [feature]` to implement any enhancement
- Run `/estimate-cost "[enhancement]"` for detailed cost breakdown
- Review with team and prioritize based on business goals
```

---

## Step 6: Output Summary

```
╔══════════════════════════════════════════════════════════════╗
║  AI FEATURE ANALYSIS COMPLETE                                 ║
╠══════════════════════════════════════════════════════════════╣
║  Project: [name]                                              ║
║  Features Analyzed: [count]                                   ║
║  AI Opportunities Found: [total count]                        ║
║                                                               ║
║  Priority 1 (Quick Wins):     [n] enhancements               ║
║  Priority 2 (Strategic):      [n] enhancements               ║
║  Priority 3 (Nice-to-Have):   [n] enhancements               ║
║  Priority 4 (Long-term):      [n] enhancements               ║
║                                                               ║
║  Top 3 Recommendations:                                       ║
║  1. [highest ROI enhancement]                                 ║
║  2. [second highest]                                          ║
║  3. [third highest]                                           ║
║                                                               ║
║  Estimated Quick Win Effort: [X] days total                   ║
║  Estimated Monthly AI Cost (MVP): $[X]/month                  ║
║                                                               ║
║  Generated: AI_ENHANCEMENT_PLAN.md                            ║
║  Next: /ai-upgrade [feature] to implement                     ║
╚══════════════════════════════════════════════════════════════╝
```

---

## Critical Rules

1. **Only suggest AI where it genuinely helps.** If a feature works well without AI, say so. Not every CRUD needs ML.

2. **Be specific about implementation.** Vague suggestions like "add AI" are useless. Specify the model, the prompt pattern, the data flow.

3. **Always include cost estimates.** AI features have ongoing API costs. The team must know what they are committing to.

4. **Consider the existing stack.** If the project is a simple Node.js app, do not suggest a Kubernetes-deployed ML pipeline. Match complexity to the project.

5. **Prioritize prompt engineering over fine-tuning.** Most enhancements can be done with good prompts + GPT-4o-mini. Only suggest fine-tuning for high-volume, specialized tasks.

6. **Include guardrails.** Every AI feature suggestion must include: rate limiting, cost caps, fallback behavior (what happens when the AI API is down), and content safety.
