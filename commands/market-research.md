---
description: "Conduct deep market research before building a product. Analyzes competitors, market trends, user pain points, pricing models, and technical landscape. Usage: /market-research 'product idea or category'"
---

# Market Research & Competitive Intelligence

Research topic: **$ARGUMENTS**

Conduct comprehensive market research to ensure the product is **world-class**. Use `WebSearch` and `WebFetch` extensively. Minimum **20 search queries** and **5 website fetches** before writing the report.

---

## Step 1: Competitor Discovery & Analysis

Execute these searches:
```
WebSearch: "[topic] best tools 2025 2026"
WebSearch: "[topic] top competitors"
WebSearch: "[topic] alternatives comparison review"
WebSearch: "[topic] vs [topic] comparison"
WebSearch: "[topic] market leaders enterprise"
WebSearch: "[topic] for startups small business"
WebSearch: "[topic] open source github"
```

For each of the **top 5-10 competitors**:
```
WebFetch: [competitor landing page] → extract value proposition, features, positioning
WebFetch: [competitor pricing page] → extract pricing tiers, feature gates, free plan limits
WebFetch: [competitor docs/changelog] → identify tech stack, API capabilities, recent updates
```

Document:
- **Company name & URL**
- **Founded, funding, team size** (if findable)
- **Core features** (list top 10)
- **Pricing model** (freemium / per-seat / usage-based / flat rate)
- **Pricing tiers** (free, starter, pro, enterprise — exact prices)
- **Tech stack** (if identifiable from job postings, docs, or headers)
- **Unique selling points** (what they emphasize in marketing)
- **Weaknesses** (from user reviews, complaints, missing features)
- **User reviews/ratings** (G2, Capterra, Product Hunt, Reddit)

---

## Step 2: Market Size & Trends

Execute these searches:
```
WebSearch: "[topic] market size 2025 2026"
WebSearch: "[topic] industry report"
WebSearch: "[topic] growth rate forecast"
WebSearch: "[topic] trends predictions"
WebSearch: "[topic] India market opportunity"
WebSearch: "[topic] SaaS landscape"
```

Document:
- **Total Addressable Market (TAM)**: Global market size
- **Serviceable Addressable Market (SAM)**: India / target region
- **Growth Rate**: YoY growth percentage
- **Key Trends**: 3-5 industry trends shaping the market
- **Emerging Technologies**: AI/ML adoption, automation trends
- **Regulatory Environment**: Any compliance requirements (GDPR, data localization, etc.)

---

## Step 3: User Pain Points & Feature Wishlist

Execute these searches:
```
WebSearch: "[topic] user complaints problems"
WebSearch: "[topic] reddit what users hate"
WebSearch: "[topic] feature requests wishlist"
WebSearch: "[topic] switching reasons why users leave"
WebSearch: "[topic] best features users love"
WebSearch: "why [competitor] is bad reviews"
```

Document:
- **Top 10 user pain points** with existing tools
- **Most requested features** that competitors don't have
- **Reasons users switch** between competing products
- **Features users love** (table stakes — must have these)
- **Underserved segments** (user groups competitors ignore)

---

## Step 4: UX & Design Patterns

Execute these searches:
```
WebSearch: "[topic] UX best practices"
WebSearch: "[topic] dashboard design patterns"
WebSearch: "[topic] onboarding flow best practices"
WebSearch: "[topic] mobile responsive design"
```

Document:
- **Standard UX patterns** in this product category
- **Navigation structure** (sidebar, tabs, breadcrumbs)
- **Dashboard layouts** competitors use
- **Onboarding flows** (wizard, progressive, tutorial)
- **Mobile experience** expectations

---

## Step 5: Pricing & Monetization Intelligence

Execute these searches:
```
WebSearch: "[topic] pricing comparison 2025 2026"
WebSearch: "[topic] SaaS pricing strategy"
WebSearch: "[topic] pricing India market"
WebSearch: "[topic] freemium vs premium conversion rates"
WebSearch: "how to price [topic] SaaS"
```

Document:
- **Pricing range**: Cheapest to most expensive competitor
- **Most common pricing model**: per-seat, usage-based, flat-rate
- **Free tier**: What do free plans include?
- **Conversion triggers**: What makes users upgrade?
- **India pricing**: Adjusted for purchasing power parity
- **Recommended pricing** for our product (Basic/Pro/Enterprise in INR)
- **Credit point allocation** recommendation based on market

---

## Step 6: Technical Landscape

Execute these searches:
```
WebSearch: "[topic] architecture best practices"
WebSearch: "[topic] API design standards"
WebSearch: "[topic] python libraries tools"
WebSearch: "[topic] integrations ecosystem"
WebSearch: "[topic] security compliance requirements"
WebSearch: "[topic] performance benchmarks"
```

Document:
- **Domain-specific Python libraries** to integrate
- **Third-party APIs** commonly expected (Slack, Zapier, webhooks, etc.)
- **Security requirements** specific to this domain
- **Performance expectations** (latency, concurrent users, data volume)
- **Compliance** (SOC 2, HIPAA, PCI-DSS, data localization)
- **Infrastructure patterns** (real-time, batch processing, event-driven)

---

## Step 7: UI/UX & Design Research

Execute these searches:
```
WebSearch: "[topic] best UI design 2025 2026"
WebSearch: "[topic] dashboard design examples"
WebSearch: "best React UI component library for [topic]"
WebSearch: "[topic] mobile app design inspiration"
WebSearch: "[topic] dark mode design patterns"
```

For **top 3 competitors**:
```
WebFetch: [competitor app/landing page] → analyze UI patterns, layout, colors, navigation
```

Document:
- **Competitor UI analysis** (what looks professional, what feels clunky)
- **Recommended UI library** (shadcn/ui, Ant Design, MUI, Chakra, Mantine — and WHY)
- **App type decision** (web-only or web + React Native mobile)
- **Design aesthetic** (modern minimal, data-dense, consumer playful, enterprise serious)
- **Key UI patterns** (sidebar nav, command palette, dashboard widgets, wizard flows)
- **Animation needs** (page transitions, hover effects, loading states)
- **Dark mode** (competitor support, user expectations)
- **Mobile expectations** (responsive web sufficient, or native app needed)

---

## Step 8: Branding & Visual Identity Research

Execute these searches:
```
WebSearch: "[topic] SaaS branding examples"
WebSearch: "[topic] logo design inspiration"
WebSearch: "best SaaS color palettes 2025 2026"
WebSearch: "[topic] brand guidelines examples"
WebSearch: "SaaS typography best practices"
```

For **top 3 competitors**:
```
WebFetch: [competitor website] → analyze brand colors, typography, logo style, overall feel
```

Document:
- **Competitor brand analysis** (colors, fonts, logo styles, brand voice)
- **Recommended color palette** (primary, secondary, neutral, semantic colors)
- **Recommended typography** (heading + body fonts)
- **Brand personality** (modern/classic, playful/serious, bold/subtle)
- **Logo style recommendation** (wordmark, icon+wordmark, lettermark)
- **Visual differentiation** (how to look different from competitors)

---

## Step 9: Go-to-Market Intelligence

Execute these searches:
```
WebSearch: "[topic] product hunt launch"
WebSearch: "how to market [topic] SaaS"
WebSearch: "[topic] content marketing strategy"
WebSearch: "[topic] customer acquisition channels"
WebSearch: "[topic] SEO keywords"
```

Document:
- **Launch channels**: Product Hunt, Hacker News, Reddit, Twitter/X
- **Content strategy**: Blog topics, SEO keywords, educational content
- **Community**: Relevant forums, Discord servers, subreddits
- **Partnership opportunities**: Complementary products, integrations marketplace
- **Influencers**: Key voices in this space to engage

---

## Output: `MARKET_RESEARCH.md`

Compile ALL findings into a comprehensive report:

```markdown
# Market Research Report: [Product Idea]
Generated: [date]

## Executive Summary
[3-5 sentences: market opportunity, competitive landscape, recommended positioning, key differentiators]

## 1. Competitor Analysis

### Competitor Matrix
| # | Competitor | URL | Users/Revenue | Pricing | Key Strength | Key Weakness |
|---|-----------|-----|--------------|---------|-------------|-------------|
| 1 | [name]    | [url] | [estimate] | [model] | [strength]  | [weakness]  |
| 2 | ...       | ...   | ...        | ...     | ...         | ...         |

### Detailed Competitor Profiles
[For each top 5 competitor: 1-2 paragraphs with features, pricing details, user sentiment]

### Competitor Feature Matrix
| Feature | Comp 1 | Comp 2 | Comp 3 | Comp 4 | Comp 5 | Our Product |
|---------|--------|--------|--------|--------|--------|------------|
| [feat]  | ✅/❌  | ✅/❌  | ✅/❌  | ✅/❌  | ✅/❌  | ✅ (better) |

## 2. Market Size & Trends
- **TAM**: $[X]B globally
- **SAM**: $[X]M in India/target
- **Growth**: [X]% YoY
- **Key Trends**: [numbered list]

## 3. User Pain Points & Opportunities
| Pain Point | Frequency | Opportunity for Us |
|-----------|-----------|-------------------|
| [problem] | High/Med/Low | [our solution] |

## 4. Feature Prioritization (Research-Informed)

### Must-Have (Table Stakes — Day 1)
- [features ALL competitors have → we need these to compete]

### Differentiators (Competitive Edge)
- [features competitors lack OR do poorly → THIS is our value]

### Future Roadmap (Post-Launch)
- [advanced features for growth phase]

## 5. Pricing Strategy
- Competitor range: ₹[X] to ₹[Y]/month
- **Recommended Tiers**:
  - Free Trial: [X] days, [Y] points
  - Basic: ₹[X]/mo — [audience]
  - Pro: ₹[Y]/mo — [audience]
  - Enterprise: ₹[Z]/mo — [audience]
- Rationale: [why based on research]

## 6. UI/UX Recommendations
- **Chosen UI Library**: [e.g., shadcn/ui + Radix — REASON: best for SaaS dashboards]
- **App Type**: [Web only / Web + React Native mobile — REASON]
- **Design Aesthetic**: [modern minimal / data-dense / consumer — based on competitor analysis]
- **Key UI Patterns**: [sidebar + topbar / command palette / wizard / cards]
- **Animation**: Framer Motion for [specific interactions]
- **Dark Mode**: Required (all top competitors support it)
- **Competitor UI Strengths**: [what competitor X does well visually]
- **Competitor UI Weaknesses**: [what looks/feels bad — our opportunity]

## 7. Technical Recommendations
- Libraries: [domain-specific packages]
- Integrations: [APIs to support]
- Compliance: [requirements]
- Performance targets: [benchmarks]

## 8. Go-to-Market Strategy
- Launch channels: [list]
- SEO keywords: [list]
- Content strategy: [topics]
- Community: [where target users hang out]

## 9. Risks & Mitigation
| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|-----------|
| [risk] | High/Med/Low | High/Med/Low | [strategy] |

## 10. Key Decisions & Recommendations
1. [Decision]: [Rationale based on research]
2. [Decision]: [Rationale based on research]
3. [Decision]: [Rationale based on research]

## 11. Sources
[List all URLs searched and fetched with brief descriptions]
```

---

## After Research

Suggest next steps:
1. **If user wants a PRD**: `/gen-prd "[product idea]"` — the PRD will reference this research
2. **If user wants to build**: `/auto-build` — the builder will use this research in Phase -1
3. **If user wants more depth**: Run `/market-research "[specific sub-topic]"` for deeper analysis

Print: "Market research saved to `MARKET_RESEARCH.md`. Use `/gen-prd` to generate a research-informed PRD, or `/auto-build` to start building."
