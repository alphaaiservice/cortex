---
name: cost-estimator
description: "Auto-invoked when user asks about costs, pricing, budgets, 'how much will this cost', infrastructure estimates, API token costs, hosting costs, or compares pricing between services. Estimates infrastructure, API, service, and development costs at different user scales (100/1K/10K/100K users). Compares alternatives like Stripe vs Razorpay, GPT-4 vs Claude, AWS vs GCP, Qdrant vs Pinecone."
license: "Proprietary — Alpha AI Service Pvt Ltd"
compatibility: "Designed for Claude Code with cortex plugin"
metadata:
  author: "Alpha AI Service Pvt Ltd"
  version: "1.0"
---

# Cost Estimator — Full-Stack Cost Analysis

This skill estimates costs for any software project across infrastructure, APIs, services, and development effort. It provides breakdowns at different user scales and compares alternative providers.

---

## Step 0: Analyze Project Requirements

Before estimating costs, understand the project:

```
1. Detect the tech stack:
   - Backend framework and language
   - Database(s) used
   - Frontend framework
   - Mobile app (if any)
   - AI/ML components (LLM, embeddings, vector DB)
   - Third-party services (payment gateway, email, SMS, push)

2. Estimate usage patterns:
   - Expected user count (or ask the user)
   - Requests per user per day
   - Data storage growth rate
   - AI query volume (if applicable)

3. Identify cost-driving components:
   - Compute-heavy services
   - Storage-intensive features
   - API-call-heavy integrations
   - Real-time features (WebSocket, SSE)
```

---

## Step 1: Infrastructure Cost Estimation

### 1.1 Compute Costs

| Provider | Instance | vCPU | RAM | Monthly Cost | Best For |
|---|---|---|---|---|---|
| **Hostinger VPS** | KVM 2 | 2 | 8 GB | $12 | Small startups, MVPs |
| **Hostinger VPS** | KVM 4 | 4 | 16 GB | $16 | Growing apps |
| **AWS EC2** | t3.micro | 2 | 1 GB | $8.50 | Dev/staging |
| **AWS EC2** | t3.medium | 2 | 4 GB | $30 | Small production |
| **AWS EC2** | m5.large | 2 | 8 GB | $70 | Medium production |
| **AWS EC2** | m5.xlarge | 4 | 16 GB | $140 | Large production |
| **GCP** | e2-medium | 2 | 4 GB | $25 | Small production |
| **GCP** | e2-standard-4 | 4 | 16 GB | $100 | Medium production |
| **DigitalOcean** | Basic 2GB | 1 | 2 GB | $12 | MVPs |
| **DigitalOcean** | Basic 8GB | 4 | 8 GB | $48 | Medium apps |
| **Railway** | Pro | Shared | 8 GB | $20 + usage | Quick deploys |
| **Render** | Standard | 1 | 2 GB | $25 | Simple apps |

### 1.2 Database Costs

| Service | Tier | Storage | Monthly Cost | Best For |
|---|---|---|---|---|
| **Self-hosted MySQL** | On VPS | Included | $0 (VPS cost) | Cost-sensitive |
| **PlanetScale** | Scaler | 25 GB | $29 | Serverless MySQL |
| **PlanetScale** | Scaler Pro | 100 GB | $99 | Growing MySQL |
| **AWS RDS MySQL** | db.t3.micro | 20 GB | $15 | Dev/staging |
| **AWS RDS MySQL** | db.t3.medium | 100 GB | $55 | Small production |
| **AWS RDS MySQL** | db.r5.large | 500 GB | $180 | Large production |
| **MongoDB Atlas** | M0 Free | 512 MB | $0 | Dev/prototyping |
| **MongoDB Atlas** | M10 | 10 GB | $57 | Small production |
| **MongoDB Atlas** | M30 | 40 GB | $210 | Medium production |
| **Supabase** | Free | 500 MB | $0 | MVPs |
| **Supabase** | Pro | 8 GB | $25 | Small apps |

### 1.3 Redis/Cache Costs

| Service | Tier | Memory | Monthly Cost |
|---|---|---|---|
| **Self-hosted Redis** | On VPS | Shared | $0 (VPS cost) |
| **Upstash Redis** | Free | 256 MB | $0 |
| **Upstash Redis** | Pay-as-you-go | 1 GB | ~$10 |
| **AWS ElastiCache** | cache.t3.micro | 0.5 GB | $12 |
| **AWS ElastiCache** | cache.t3.medium | 3 GB | $48 |
| **Redis Cloud** | Fixed 250MB | 250 MB | $7 |
| **Redis Cloud** | Fixed 1GB | 1 GB | $30 |

### 1.4 Storage Costs

| Service | Free Tier | Per GB/month | Best For |
|---|---|---|---|
| **AWS S3** | 5 GB (12 months) | $0.023 | General file storage |
| **Cloudflare R2** | 10 GB | $0.015 (no egress fees) | High-read workloads |
| **MinIO** (self-hosted) | Unlimited | $0 (VPS cost) | Cost-sensitive |
| **GCP Cloud Storage** | 5 GB | $0.020 | GCP ecosystem |
| **DigitalOcean Spaces** | 250 GB | $5/mo flat | Simple storage |

### 1.5 CDN & DNS Costs

| Service | Free Tier | Paid | Best For |
|---|---|---|---|
| **Cloudflare** | Unlimited bandwidth | $20/mo (Pro) | Everyone |
| **AWS CloudFront** | 1 TB/month (12 months) | $0.085/GB | AWS ecosystem |
| **Vercel** | 100 GB | $20/mo (Pro) | Next.js apps |

---

## Step 2: API & Service Cost Estimation

### 2.1 LLM API Costs (per 1M tokens, as of 2024-2025)

| Model | Input (per 1M) | Output (per 1M) | Best For |
|---|---|---|---|
| **GPT-4o** | $2.50 | $10.00 | Complex reasoning |
| **GPT-4o-mini** | $0.15 | $0.60 | Cost-efficient general use |
| **Claude 3.5 Sonnet** | $3.00 | $15.00 | Coding, analysis |
| **Claude 3.5 Haiku** | $0.25 | $1.25 | Fast, cheap tasks |
| **Gemini 1.5 Pro** | $1.25 | $5.00 | Long context |
| **Gemini 1.5 Flash** | $0.075 | $0.30 | Cheapest option |
| **Gemini 2.0 Flash** | $0.10 | $0.40 | Latest cheap option |
| **Llama 3.1 70B** (Groq) | $0.59 | $0.79 | Open-source, fast |
| **Llama 3.1 8B** (Groq) | $0.05 | $0.08 | Ultra-cheap |

#### Cost Per Query Estimates

| Use Case | Avg Tokens (in+out) | Cost per Query (GPT-4o-mini) | Cost per Query (GPT-4o) |
|---|---|---|---|
| Chat response | 500 + 300 | $0.000255 | $0.00425 |
| RAG query | 2000 + 500 | $0.000600 | $0.01000 |
| Document summary | 3000 + 500 | $0.000750 | $0.01250 |
| Code generation | 1000 + 1000 | $0.000750 | $0.01250 |
| Classification | 200 + 50 | $0.000060 | $0.00100 |

#### Monthly Cost at Scale (Chat/RAG app)

| Users | Queries/user/day | Monthly Queries | GPT-4o-mini | GPT-4o | Claude Haiku |
|---|---|---|---|---|---|
| 100 | 5 | 15,000 | $4 | $64 | $5 |
| 1,000 | 5 | 150,000 | $38 | $638 | $47 |
| 10,000 | 5 | 1,500,000 | $375 | $6,375 | $469 |
| 100,000 | 5 | 15,000,000 | $3,750 | $63,750 | $4,688 |

### 2.2 Embedding API Costs

| Model | Per 1M Tokens | Dimensions | Best For |
|---|---|---|---|
| **text-embedding-3-small** | $0.02 | 1536 | Cost-efficient |
| **text-embedding-3-large** | $0.13 | 3072 | High accuracy |
| **Cohere embed-v3** | $0.10 | 1024 | Multilingual |
| **Voyage AI** | $0.06 | 1024 | Code/technical |

### 2.3 Vector Database Costs

| Service | Free Tier | Starter | Production | Best For |
|---|---|---|---|---|
| **Qdrant** (self-hosted) | Unlimited | $0 (VPS) | $0 (VPS) | Cost control |
| **Qdrant Cloud** | 1 GB | $25/mo | $100+/mo | Managed |
| **Pinecone** | 2 GB | $70/mo | $200+/mo | Enterprise |
| **ChromaDB** (self-hosted) | Unlimited | $0 (VPS) | $0 (VPS) | Simple RAG |
| **Weaviate Cloud** | 1 GB | $25/mo | $100+/mo | Multi-modal |

### 2.4 Search Engine Costs

| Service | Free Tier | Paid | Best For |
|---|---|---|---|
| **Meilisearch** (self-hosted) | Unlimited | $0 (VPS cost) | Cost-sensitive |
| **Meilisearch Cloud** | 100K docs | $30/mo | Managed search |
| **Algolia** | 10K records | $1/1K records | Large scale |
| **Typesense** (self-hosted) | Unlimited | $0 (VPS cost) | Open-source |

### 2.5 Payment Gateway Fees

| Gateway | Transaction Fee | Monthly Fee | Best For |
|---|---|---|---|
| **Razorpay** (India) | 2% per transaction | Free | Indian market |
| **Razorpay** (International) | 3% per transaction | Free | Indian apps, global |
| **Stripe** (US/EU) | 2.9% + $0.30 per txn | Free | Global market |
| **Stripe** (India) | 2% per transaction | Free | Indian apps |
| **PayPal** | 2.9% + $0.30 per txn | Free | B2C global |

#### Monthly Payment Processing Costs

| MRR | Transactions/mo | Razorpay (2%) | Stripe (2.9% + $0.30) |
|---|---|---|---|
| $1,000 | 100 | $20 | $59 |
| $10,000 | 500 | $200 | $440 |
| $100,000 | 2,000 | $2,000 | $3,500 |
| $1,000,000 | 10,000 | $20,000 | $32,000 |

### 2.6 Communication Costs

| Service | Free Tier | Per Unit Cost | Best For |
|---|---|---|---|
| **SendGrid** (Email) | 100/day | $0.001/email (beyond free) | Transactional email |
| **AWS SES** (Email) | 3K/mo (EC2) | $0.0001/email | High volume email |
| **Twilio SMS** (India) | None | $0.04/SMS | SMS notifications |
| **Twilio SMS** (US) | None | $0.0079/SMS | US market |
| **Firebase FCM** (Push) | Unlimited | Free | Push notifications |
| **OneSignal** (Push) | 10K subscribers | Free (basic) | Simple push |

---

## Step 3: Development Effort Estimation

### 3.1 Feature Development Time (Rough Estimates)

| Feature | Junior Dev | Senior Dev | Notes |
|---|---|---|---|
| Auth (JWT + OAuth) | 3-5 days | 1-2 days | Using established patterns |
| CRUD Module | 2-3 days | 0.5-1 day | Per entity |
| Payment Integration | 5-7 days | 2-3 days | Razorpay/Stripe |
| RAG Pipeline | 7-10 days | 3-5 days | Embed + store + retrieve |
| AI Chat (SSE) | 5-7 days | 2-3 days | With streaming |
| Search (Meilisearch) | 3-5 days | 1-2 days | Full-text search |
| Dashboard Page | 3-5 days | 1-2 days | With charts |
| Admin Panel | 7-10 days | 3-5 days | Full CRUD admin |
| Mobile App Shell | 5-7 days | 2-3 days | Expo + navigation + auth |
| CI/CD Pipeline | 2-3 days | 0.5-1 day | GitHub Actions |
| Docker + K8s Setup | 3-5 days | 1-2 days | Full containerization |
| E2E Tests (10 flows) | 5-7 days | 2-3 days | Playwright |
| WebSocket Real-time | 3-5 days | 1-2 days | Notifications |
| File Upload (S3) | 2-3 days | 0.5-1 day | Presigned URLs |
| Email System | 2-3 days | 1 day | Templates + queue |
| Feature Flags | 2-3 days | 1 day | MySQL + Redis |

---

## Step 4: Total Cost Projection

### Cost Estimation Template

Present costs in this format:

```markdown
# Cost Estimate: [Project Name]

## Monthly Infrastructure Costs

### At 100 Users (MVP)
| Component | Service | Spec | Monthly Cost |
|-----------|---------|------|-------------|
| Compute | Hostinger VPS | 2 vCPU, 8GB RAM | $12 |
| Database | Self-hosted MySQL | On VPS | $0 |
| Cache | Self-hosted Redis | On VPS | $0 |
| Storage | Cloudflare R2 | ~5 GB | $0 |
| CDN | Cloudflare Free | Unlimited | $0 |
| Vector DB | Self-hosted Qdrant | On VPS | $0 |
| Search | Self-hosted Meilisearch | On VPS | $0 |
| LLM API | GPT-4o-mini | ~15K queries | $4 |
| Email | SendGrid Free | 100/day | $0 |
| Push | Firebase FCM | Free | $0 |
| Domain | - | .com | $1 |
| **TOTAL** | | | **$17/month** |

### At 1,000 Users (Growth)
| Component | Service | Spec | Monthly Cost |
|-----------|---------|------|-------------|
| Compute | Hostinger VPS | 4 vCPU, 16GB RAM | $16 |
| Database | Self-hosted MySQL | On VPS | $0 |
| Cache | Self-hosted Redis | On VPS | $0 |
| Storage | Cloudflare R2 | ~50 GB | $1 |
| CDN | Cloudflare Free | Unlimited | $0 |
| Vector DB | Self-hosted Qdrant | On VPS | $0 |
| Search | Self-hosted Meilisearch | On VPS | $0 |
| LLM API | GPT-4o-mini | ~150K queries | $38 |
| Email | AWS SES | ~30K emails | $3 |
| Push | Firebase FCM | Free | $0 |
| Payment fees | Razorpay | 2% on ~$10K MRR | $200 |
| **TOTAL** | | | **$258/month** |

### At 10,000 Users (Scale)
| Component | Service | Spec | Monthly Cost |
|-----------|---------|------|-------------|
| Compute | AWS (2x m5.large) | 4 vCPU, 16GB each | $140 |
| Database | AWS RDS MySQL | db.r5.large, 500GB | $180 |
| Cache | AWS ElastiCache | 3 GB | $48 |
| Storage | Cloudflare R2 | ~500 GB | $8 |
| CDN | Cloudflare Pro | Enhanced | $20 |
| Vector DB | Qdrant Cloud | 10 GB | $50 |
| Search | Meilisearch Cloud | 1M docs | $60 |
| LLM API | GPT-4o-mini | ~1.5M queries | $375 |
| Email | AWS SES | ~300K emails | $30 |
| Push | Firebase FCM | Free | $0 |
| Monitoring | Sentry + PostHog | Basic plans | $50 |
| Payment fees | Razorpay | 2% on ~$100K MRR | $2,000 |
| **TOTAL** | | | **$2,961/month** |

### At 100,000 Users (Enterprise)
| Component | Service | Spec | Monthly Cost |
|-----------|---------|------|-------------|
| Compute | AWS (K8s cluster) | Auto-scaling | $800 |
| Database | AWS RDS MySQL | Multi-AZ, 2TB | $600 |
| Read Replica | AWS RDS | For reads | $300 |
| Cache | AWS ElastiCache | 16 GB cluster | $200 |
| Storage | Cloudflare R2 | ~5 TB | $75 |
| CDN | Cloudflare Business | Enhanced | $200 |
| Vector DB | Qdrant Cloud | 50 GB | $200 |
| Search | Meilisearch Cloud | 10M docs | $200 |
| LLM API | GPT-4o-mini + Haiku | ~15M queries | $4,000 |
| Email | AWS SES | ~3M emails | $300 |
| Push | Firebase FCM | Free | $0 |
| Monitoring | Sentry + PostHog + Grafana | Pro plans | $200 |
| Payment fees | Razorpay | 2% on ~$1M MRR | $20,000 |
| **TOTAL** | | | **$27,075/month** |
```

---

## Step 5: Cost Optimization Recommendations

Always include cost optimization tips:

### General Optimizations
- Use self-hosted services on VPS for small scale (MySQL, Redis, Qdrant, Meilisearch)
- Move to managed services only when operational burden exceeds cost
- Use Cloudflare R2 instead of S3 to eliminate egress costs
- Use GPT-4o-mini or Claude Haiku for most AI tasks (10-20x cheaper than GPT-4o)
- Implement semantic caching to reduce LLM API calls by 30-50%
- Use tiered model routing: cheap model first, expensive model only when needed

### LLM Cost Optimizations
- Cache frequent queries with Redis semantic cache
- Use smaller models for classification/extraction tasks
- Batch embeddings (process 100+ at once, not one-by-one)
- Implement token budgets per user/plan
- Use structured output to reduce output tokens
- Compress prompts: remove redundant instructions

### Infrastructure Optimizations
- Use spot/preemptible instances for batch processing (70% savings)
- Right-size instances (monitor actual CPU/RAM usage)
- Use auto-scaling to match demand
- Schedule non-critical workloads during off-peak hours
- Use reserved instances for stable baseline load (30-50% savings)

---

## Step 6: Provider Comparison

When alternatives exist, present a comparison:

```markdown
## Comparison: [Service A] vs [Service B] vs [Service C]

| Criteria | Service A | Service B | Service C |
|----------|-----------|-----------|-----------|
| Monthly cost (1K users) | $X | $Y | $Z |
| Monthly cost (10K users) | $X | $Y | $Z |
| Free tier | Yes/No | Yes/No | Yes/No |
| Setup complexity | Low/Med/High | Low/Med/High | Low/Med/High |
| Scalability | Good/Great | Good/Great | Good/Great |
| India pricing | Yes/No | Yes/No | Yes/No |
| Self-hosted option | Yes/No | Yes/No | Yes/No |

**Recommendation**: [Service X] because [specific reason based on project needs]
```

---

## Step 7: Output Summary

```
+================================================================+
|  COST ESTIMATE COMPLETE                                         |
+================================================================+
|                                                                 |
|  Project: [name]                                                |
|  Stack: [backend] + [frontend] + [database]                     |
|                                                                 |
|  Monthly Costs by Scale:                                        |
|  +-- 100 users (MVP):      $XX/month                           |
|  +-- 1,000 users (Growth): $XXX/month                          |
|  +-- 10,000 users (Scale): $X,XXX/month                        |
|  +-- 100,000 users (Ent):  $XX,XXX/month                       |
|                                                                 |
|  Top Cost Drivers:                                              |
|  1. [biggest cost item]                                         |
|  2. [second biggest]                                            |
|  3. [third biggest]                                             |
|                                                                 |
|  Optimization Potential: [X]% savings with [recommendations]    |
+================================================================+
```
