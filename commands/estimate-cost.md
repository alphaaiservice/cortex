---
description: "Estimate infrastructure and API costs for features at different scales. Usage: /estimate-cost \"add RAG search with GPT-4\" or /estimate-cost (analyzes current project)"
---

# Estimate Cost — Infrastructure & API Cost Projection

Estimate costs for: **$ARGUMENTS** (default: analyze current project)

Calculate realistic infrastructure, API, and operational costs for features at three scales: Startup (100 users), Growth (10K users), and Scale (100K users). Works for ANY stack.

**KEY PRINCIPLE: Use real pricing data, not guesses. Every estimate should reference actual provider pricing tiers. Always show the cheapest viable option alongside the recommended option.**

---

## Step 1: Identify Features to Cost

### If $ARGUMENTS describes a specific feature:
Parse the feature description and identify all infrastructure components needed.

### If $ARGUMENTS is empty (analyze current project):
Scan the codebase to detect all infrastructure dependencies:

```bash
# Detect cloud services
grep -ri "aws\|gcp\|azure\|vercel\|netlify\|railway\|render\|fly\.io\|supabase\|firebase\|heroku" . --include="*.json" --include="*.yml" --include="*.yaml" --include="*.toml" --include="*.env*" --include="*.tf" -l 2>/dev/null

# Detect databases
grep -ri "mysql\|postgres\|mongodb\|redis\|sqlite\|dynamodb\|firestore\|supabase" . --include="*.py" --include="*.ts" --include="*.js" --include="*.java" --include="*.json" --include="*.yml" -l 2>/dev/null

# Detect APIs and services
grep -ri "openai\|anthropic\|stripe\|razorpay\|twilio\|sendgrid\|mailgun\|algolia\|pinecone\|qdrant\|weaviate\|elasticsearch\|sentry\|posthog\|datadog\|newrelic" . --include="*.py" --include="*.ts" --include="*.js" --include="*.java" --include="*.json" --include="*.env*" -l 2>/dev/null

# Detect storage
grep -ri "s3\|minio\|cloudinary\|uploadthing\|cloudflare\|r2\|gcs\|blob" . --include="*.py" --include="*.ts" --include="*.js" --include="*.java" --include="*.json" -l 2>/dev/null
```

Build a component list:

```
INFRASTRUCTURE COMPONENTS DETECTED
═══════════════════════════════════
1. [Component] — [provider] — [purpose in the app]
2. [Component] — [provider] — [purpose in the app]
...
```

---

## Step 2: Calculate Per-Component Costs

For each component, calculate costs at three scales using current pricing (as of 2025-2026):

### Compute Costs

| Provider | Tier | Monthly Cost | Specs | Best For |
|----------|------|-------------|-------|----------|
| **Vercel** | Hobby | $0 | 100GB bandwidth, serverless | Frontend + simple API |
| **Vercel** | Pro | $20/member | 1TB bandwidth, edge | Production frontend |
| **Railway** | Starter | $5 + usage | 8GB RAM, $0.000231/min | Small backend |
| **Railway** | Pro | $20 + usage | 32GB RAM | Production backend |
| **Render** | Free | $0 | 512MB RAM, spins down | Dev/testing |
| **Render** | Starter | $7/service | 512MB RAM, always on | Small production |
| **Render** | Standard | $25/service | 2GB RAM | Production |
| **Fly.io** | Free | $0 | 3 shared VMs | Hobby projects |
| **Fly.io** | Launch | $0 + usage | Pay per VM-second | Flexible scaling |
| **AWS EC2** | t3.micro | ~$8.50/mo | 1 vCPU, 1GB RAM | Minimum viable |
| **AWS EC2** | t3.small | ~$17/mo | 2 vCPU, 2GB RAM | Small production |
| **AWS EC2** | t3.medium | ~$34/mo | 2 vCPU, 4GB RAM | Medium production |
| **GCP Cloud Run** | Free tier | $0 | 2M requests/mo | Serverless backend |
| **GCP Cloud Run** | Pay-as-go | ~$0.00002400/vCPU-sec | Auto-scaling | Variable traffic |

### Database Costs

| Provider | Tier | Monthly Cost | Specs | Best For |
|----------|------|-------------|-------|----------|
| **Supabase** | Free | $0 | 500MB, 2 projects | Prototyping |
| **Supabase** | Pro | $25 | 8GB, unlimited projects | Production |
| **Supabase** | Team | $599 | SOC2, priority support | Enterprise |
| **PlanetScale** | Hobby | $0 | 1 DB, 1B row reads/mo | Small MySQL |
| **PlanetScale** | Scaler | $29 | 2 DBs, 100B row reads | Production MySQL |
| **Neon (Postgres)** | Free | $0 | 0.5GB storage | Prototyping |
| **Neon** | Launch | $19 | 10GB storage | Production |
| **MongoDB Atlas** | Free | $0 | 512MB | Prototyping |
| **MongoDB Atlas** | Dedicated | $57+ | 10GB, dedicated cluster | Production |
| **AWS RDS MySQL** | db.t3.micro | ~$15/mo | 1 vCPU, 1GB RAM | Minimum |
| **AWS RDS** | db.t3.small | ~$30/mo | 2 vCPU, 2GB RAM | Small production |
| **Redis (Upstash)** | Free | $0 | 10K commands/day | Dev caching |
| **Redis (Upstash)** | Pay-as-go | $0.2/100K commands | Serverless | Production caching |
| **Redis Cloud** | Free | $0 | 30MB | Prototyping |
| **Redis Cloud** | Fixed | $5+ | 250MB+ | Production |

### LLM / AI API Costs

| Provider | Model | Input Cost | Output Cost | Best For |
|----------|-------|-----------|-------------|----------|
| **OpenAI** | GPT-4o | $2.50/1M tokens | $10.00/1M tokens | Complex reasoning |
| **OpenAI** | GPT-4o-mini | $0.15/1M tokens | $0.60/1M tokens | Most tasks (best value) |
| **OpenAI** | text-embedding-3-small | $0.02/1M tokens | — | Embeddings (cheap) |
| **OpenAI** | text-embedding-3-large | $0.13/1M tokens | — | Embeddings (quality) |
| **Anthropic** | Claude Sonnet 4 | $3.00/1M tokens | $15.00/1M tokens | Complex analysis |
| **Anthropic** | Claude Haiku 3.5 | $0.80/1M tokens | $4.00/1M tokens | Fast + cheap |
| **Google** | Gemini 2.0 Flash | $0.10/1M tokens | $0.40/1M tokens | Budget option |
| **Groq** | Llama 3.3 70B | $0.59/1M tokens | $0.79/1M tokens | Fast inference |
| **Local (Ollama)** | Llama 3.2 | $0 (compute only) | $0 | Privacy / offline |

### Vector Database Costs

| Provider | Tier | Monthly Cost | Specs | Best For |
|----------|------|-------------|-------|----------|
| **Qdrant Cloud** | Free | $0 | 1GB RAM, 1M vectors | Prototyping |
| **Qdrant Cloud** | Starter | $25 | 4GB RAM | Production |
| **Pinecone** | Starter | $0 | 2GB storage, 100K vectors | Prototyping |
| **Pinecone** | Standard | $70+ | Unlimited | Production |
| **pgvector** | (included in PG) | $0 extra | Extension | Simple vector search |
| **Weaviate Cloud** | Sandbox | $0 | 14-day trial | Testing |
| **Weaviate Cloud** | Standard | $25+ | Production | Production |
| **ChromaDB** | Self-hosted | $0 + compute | Open source | Budget option |

### Storage Costs

| Provider | Tier | Monthly Cost | Specs |
|----------|------|-------------|-------|
| **AWS S3** | Standard | $0.023/GB | First 50TB |
| **Cloudflare R2** | Free | $0 | 10GB + 10M requests |
| **Cloudflare R2** | Pay-as-go | $0.015/GB | No egress fees |
| **Supabase Storage** | Free | $0 | 1GB |
| **Supabase Storage** | Pro | included in $25 plan | 100GB |
| **Uploadthing** | Free | $0 | 2GB |
| **Uploadthing** | Pro | $10 | 100GB |

### Email / Messaging Costs

| Provider | Tier | Monthly Cost | Specs |
|----------|------|-------------|-------|
| **Resend** | Free | $0 | 100 emails/day |
| **Resend** | Pro | $20 | 50K emails/mo |
| **SendGrid** | Free | $0 | 100 emails/day |
| **SendGrid** | Essentials | $19.95 | 50K emails/mo |
| **Twilio SMS** | Pay-as-go | $0.0079/SMS | US pricing |
| **FCM Push** | Free | $0 | Unlimited |

### Payment Processing Costs

| Provider | Per Transaction | Monthly Fee | Best For |
|----------|----------------|-------------|----------|
| **Stripe** | 2.9% + $0.30 | $0 | International |
| **Razorpay** | 2% | $0 | India market |
| **Paddle** | 5% + $0.50 | $0 | SaaS (handles tax) |

### Monitoring / Observability

| Provider | Tier | Monthly Cost | Specs |
|----------|------|-------------|-------|
| **Sentry** | Developer | $0 | 5K errors/mo |
| **Sentry** | Team | $26 | 50K errors/mo |
| **PostHog** | Free | $0 | 1M events/mo |
| **PostHog** | Pay-as-go | $0.00045/event | After 1M |
| **Datadog** | Free | $0 | 5 hosts |
| **BetterStack** | Free | $0 | Basic uptime |

---

## Step 3: Build Cost Scenarios

Calculate total costs at three scales:

### Scale Assumptions

```
STARTUP (100 DAU / 1K MAU)
  API requests/day:    ~5,000
  DB storage:          < 1GB
  File storage:        < 10GB
  LLM calls/day:       ~500 (if AI features)
  Emails/month:        ~1,000

GROWTH (10K DAU / 50K MAU)
  API requests/day:    ~500,000
  DB storage:          5-50GB
  File storage:        100GB-1TB
  LLM calls/day:       ~50,000 (if AI features)
  Emails/month:        ~50,000

SCALE (100K DAU / 500K MAU)
  API requests/day:    ~5,000,000
  DB storage:          50-500GB
  File storage:        1-10TB
  LLM calls/day:       ~500,000 (if AI features)
  Emails/month:        ~500,000
```

For each scale, select the appropriate tier for each component and calculate total.

---

## Step 4: Compare Alternatives

For each major cost category, show at least 2 options:

```
COMPUTE ALTERNATIVES
════════════════════
Option A: Vercel (Frontend) + Railway (Backend)
  Startup: $25/mo | Growth: $70/mo | Scale: $300/mo
  Pros: Simple deployment, auto-scaling, great DX
  Cons: Vendor lock-in, costs rise fast at scale

Option B: AWS (EC2 + CloudFront)
  Startup: $30/mo | Growth: $120/mo | Scale: $500/mo
  Pros: Full control, mature ecosystem
  Cons: Complex setup, requires DevOps knowledge

Option C: Fly.io (Full Stack)
  Startup: $10/mo | Growth: $50/mo | Scale: $200/mo
  Pros: Cheapest, edge deployment, Docker-native
  Cons: Smaller ecosystem, fewer managed services
```

---

## Step 5: Generate COST_ESTIMATE.md

```markdown
# Cost Estimate Report
**Generated**: [date]
**Project**: [name]
**Scope**: [specific feature or full project]

## Infrastructure Components
| # | Component | Provider | Purpose | Tier |
|---|-----------|----------|---------|------|
| 1 | [compute] | [provider] | [purpose] | [tier at each scale] |
| 2 | [database] | [provider] | [purpose] | [tier at each scale] |
| ... |

## Cost Summary by Scale

### Startup (100 DAU / 1K MAU)
| Component | Provider | Tier | Monthly Cost |
|-----------|----------|------|-------------|
| Compute | [provider] | [tier] | $[X] |
| Database | [provider] | [tier] | $[X] |
| Storage | [provider] | [tier] | $[X] |
| AI/LLM APIs | [provider] | [model] | $[X] |
| Email | [provider] | [tier] | $[X] |
| Monitoring | [provider] | [tier] | $[X] |
| **Total** | | | **$[X]/month** |
| **Annual** | | | **$[X]/year** |

### Growth (10K DAU / 50K MAU)
[Same table format]

### Scale (100K DAU / 500K MAU)
[Same table format]

## Cost Comparison Chart
```
Monthly Cost by Scale:
                Startup    Growth     Scale
Compute         $[X]       $[X]       $[X]
Database        $[X]       $[X]       $[X]
AI/LLM          $[X]       $[X]       $[X]
Storage         $[X]       $[X]       $[X]
Other           $[X]       $[X]       $[X]
─────────────────────────────────────────────
TOTAL           $[X]       $[X]       $[X]
Per User/Month  $[X]       $[X]       $[X]
```

## Alternative Architectures
### Option A: [Name] (Recommended)
[Cost breakdown + pros/cons]

### Option B: [Name] (Budget)
[Cost breakdown + pros/cons]

### Option C: [Name] (Premium)
[Cost breakdown + pros/cons]

## Cost Optimization Tips
1. [Specific tip for this project — e.g., "Use GPT-4o-mini instead of GPT-4o for classification tasks to save 94%"]
2. [Another tip]
3. [Another tip]

## Hidden Costs to Watch
| Cost | Trigger | Estimated Impact |
|------|---------|-----------------|
| Data transfer egress | High API traffic | $[X]/TB |
| LLM token overrun | Verbose prompts | [X]x expected cost |
| Database connections | Connection pooling missing | Extra $[X]/mo for larger tier |
| SSL certificates | Custom domains | $0 (Let's Encrypt) or $[X] |
| Domain names | Per domain/year | $12-50/year |

## Revenue Break-Even Analysis
| Scale | Monthly Cost | Required Revenue | Break-Even Price/User |
|-------|-------------|-----------------|----------------------|
| Startup | $[X] | $[X] | $[X]/user/month |
| Growth | $[X] | $[X] | $[X]/user/month |
| Scale | $[X] | $[X] | $[X]/user/month |

## Next Steps
- Run `/deploy staging` to set up infrastructure
- Run `/monitoring setup` to add cost monitoring
- Review with team and select architecture option
```

---

## Step 6: Output Summary

```
╔══════════════════════════════════════════════════════════════╗
║  COST ESTIMATE COMPLETE                                       ║
╠══════════════════════════════════════════════════════════════╣
║  Scope: [feature or full project]                             ║
║  Components: [count]                                          ║
║                                                               ║
║  Monthly Cost Estimates:                                      ║
║    Startup (100 users):   $[X]/month                          ║
║    Growth (10K users):    $[X]/month                          ║
║    Scale (100K users):    $[X]/month                          ║
║                                                               ║
║  Biggest Cost Driver: [component name]                        ║
║  Best Savings Opportunity: [specific optimization]            ║
║                                                               ║
║  Generated: COST_ESTIMATE.md                                  ║
╚══════════════════════════════════════════════════════════════╝
```

---

## Critical Rules

1. **Use real pricing, not guesses.** Reference actual provider pricing pages. Prices change — note the date of your estimates.

2. **Include ALL costs, not just the obvious ones.** Data transfer, SSL, domains, monitoring, error tracking, CI/CD minutes — these add up.

3. **Show per-user cost.** This is the most useful metric for business decisions. Total cost means nothing without user context.

4. **Always show the free/cheap option.** Many projects can start on free tiers. Do not assume everyone needs production-grade infrastructure from day one.

5. **Factor in AI costs carefully.** LLM APIs are the most variable cost. Always calculate based on realistic token counts, not minimum estimates. Include a 2x buffer for prompt engineering iterations.

6. **Note pricing date.** Cloud and API pricing changes frequently. Always state that estimates are based on pricing as of the generation date.
