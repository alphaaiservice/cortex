# Auto-Build Reference: Market Research & Product Branding

> **This file is referenced by `/auto-build` command.** Do NOT invoke this file directly.
> It contains Phase -1 (Market Research) and Phase -0.5 (Branding) instructions.
> These phases run before any code is written.

---

## PHASE -1: MARKET RESEARCH & COMPETITIVE INTELLIGENCE (MANDATORY)

Before writing a single line of code, conduct thorough market research to ensure the product is **world-class** and competitive. Use `WebSearch` and `WebFetch` tools to gather real-world intelligence.

### Research Steps (execute ALL):

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  MARKET RESEARCH CHECKLIST — Complete BEFORE coding                         │
│                                                                              │
│  1. COMPETITOR ANALYSIS                                                      │
│     WebSearch: "[product category] best tools 2025 2026"                    │
│     WebSearch: "[product category] alternatives comparison"                  │
│     WebSearch: "[product category] market leaders"                           │
│     → Identify top 5-10 competitors                                         │
│     → For each: note features, pricing, tech stack, UX approach             │
│     → WebFetch their landing pages to analyze value propositions            │
│     → WebFetch their pricing pages to study pricing models                  │
│     → Identify gaps/weaknesses in existing solutions                        │
│                                                                              │
│  2. MARKET SIZE & TRENDS                                                     │
│     WebSearch: "[product category] market size 2025 2026"                   │
│     WebSearch: "[product category] industry trends"                          │
│     WebSearch: "[product category] growth projections"                       │
│     → Total addressable market (TAM), serviceable (SAM)                     │
│     → Growing or declining? Key drivers?                                    │
│     → Regional focus (India/Global)                                          │
│                                                                              │
│  3. USER EXPECTATIONS & UX PATTERNS                                          │
│     WebSearch: "[product category] best UX practices"                       │
│     WebSearch: "[product category] user complaints problems"                │
│     WebSearch: "[product category] feature wishlist users want"             │
│     → What features do users expect as table-stakes?                        │
│     → What are common pain points with existing tools?                      │
│     → What UX patterns are industry standard?                               │
│     → What innovative features would differentiate our product?             │
│                                                                              │
│  4. PRICING & MONETIZATION RESEARCH                                          │
│     WebSearch: "[product category] pricing models comparison"               │
│     WebSearch: "[product category] SaaS pricing India"                      │
│     → How do competitors price? (freemium, per-seat, usage-based)          │
│     → What's the sweet spot for India market pricing?                       │
│     → Inform our subscription plan pricing + point allocation              │
│                                                                              │
│  5. TECHNICAL BEST PRACTICES                                                 │
│     WebSearch: "[product category] architecture best practices"             │
│     WebSearch: "[product category] API design patterns"                     │
│     WebSearch: "[product category] security requirements"                   │
│     WebSearch: "[product category] performance benchmarks"                  │
│     → What tech patterns do top products use?                               │
│     → Any regulatory/compliance requirements?                               │
│     → Performance expectations (latency, uptime, scale)                     │
│     → Security standards specific to this domain                            │
│                                                                              │
│  6. OPEN SOURCE & ECOSYSTEM                                                  │
│     WebSearch: "[product category] open source github"                      │
│     WebSearch: "[product category] python libraries"                        │
│     → Any open-source tools we can leverage or integrate?                   │
│     → Existing Python/JS libraries for domain-specific features?           │
│     → API integrations commonly expected (Slack, Zapier, etc.)             │
│                                                                              │
│  7. UI/UX & DESIGN RESEARCH                                                 │
│     WebSearch: "[product category] best UI design 2025 2026"               │
│     WebSearch: "[product category] dashboard design examples"               │
│     WebSearch: "best React UI library for [product category]"              │
│     WebSearch: "[product category] mobile app design best"                  │
│     WebFetch: Top 3 competitor websites → screenshot/analyze UI patterns   │
│     → Which UI component library do competitors use?                       │
│     → What design system/aesthetic is expected in this space?              │
│     → Dashboard layout patterns (sidebar, topbar, widgets)                 │
│     → Mobile experience expectations (responsive web vs native app)        │
│     → DECIDE: Best UI library for THIS specific product                    │
│     → DECIDE: React web only, or React Native mobile too?                  │
│                                                                              │
│  8. SEO & CONTENT STRATEGY                                                   │
│     WebSearch: "[product category] keywords search volume"                  │
│     WebSearch: "how to market [product category] SaaS"                      │
│     → Target keywords for landing page and content                          │
│     → Content marketing opportunities (blog, docs, guides)                 │
│     → Distribution channels (Product Hunt, Hacker News, etc.)              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Research Output: `MARKET_RESEARCH.md`

Create a comprehensive research document:

```markdown
# Market Research Report

## 1. Executive Summary
- Market opportunity in 2-3 sentences
- Key differentiators for our product
- Recommended positioning

## 2. Competitor Analysis
| Competitor | Website | Key Features | Pricing | Weaknesses | Our Advantage |
|-----------|---------|-------------|---------|------------|---------------|
| [name]    | [url]   | [features]  | [price] | [gaps]     | [our edge]    |

### Detailed Competitor Breakdown
[For each top 5 competitor: features, pricing, UX, tech stack, user reviews]

## 3. Market Size & Trends
- TAM: [total addressable market]
- SAM: [serviceable addressable market]
- Growth rate: [X% YoY]
- Key trends: [list 3-5 trends]
- Regional insights (India market specifics)

## 4. Target User Persona
- Primary user: [who, role, pain points]
- Secondary user: [who, role, needs]
- User expectations: [table-stakes features]
- Willingness to pay: [price sensitivity]

## 5. Feature Prioritization (Informed by Research)
### Must-Have (Day 1)
- [features every competitor has — table stakes]

### Differentiators (What makes us BETTER)
- [features competitors lack or do poorly]
- [innovative features based on user pain points]

### Nice-to-Have (Post-Launch)
- [features for future roadmap]

## 6. Pricing Strategy (Informed by Market)
- Competitor pricing range: [₹X to ₹Y]
- Recommended pricing:
  - Free Trial: [X days, Y points]
  - Basic: ₹[X]/mo — [target audience]
  - Pro: ₹[X]/mo — [target audience]
  - Enterprise: ₹[X]/mo — [target audience]
- Rationale: [why these prices based on research]

## 7. UI/UX Decisions (Research-Based)
- **Chosen UI Library**: [e.g., shadcn/ui + Radix] — rationale: [why]
- **App Type**: Web only / Web + Mobile (React Native)
- **Design Aesthetic**: [modern minimal / data-dense / consumer playful]
- **Key UI Patterns**: [sidebar nav / command palette / wizard flows]
- **Animation Strategy**: [Framer Motion for page transitions + micro-interactions]
- **Dark Mode**: Required (next-themes)
- **Competitor UI Analysis**: [what looks best, what feels clunky]

## 8. Technical Insights
- Common architecture patterns in this space
- Domain-specific libraries/APIs to integrate
- Security/compliance requirements
- Performance benchmarks to target

## 8. Go-to-Market Insights
- Distribution channels
- Content strategy keywords
- Community/ecosystem to engage

## 9. Risks & Mitigation
- [risk 1] → [mitigation]
- [risk 2] → [mitigation]

## 10. Decisions Made (Based on Research)
- [decision 1]: [rationale from research]
- [decision 2]: [rationale from research]
```

### Research Rules:
```
┌──────────────────────────────────────────────────────────────────────────┐
│  MARKET RESEARCH RULES                                                    │
│                                                                            │
│  ✅ Minimum 15-20 WebSearch queries before proceeding                     │
│  ✅ WebFetch at least 5 competitor websites/landing pages                 │
│  ✅ Study at least 3 competitor pricing pages                             │
│  ✅ Document ALL findings in MARKET_RESEARCH.md                          │
│  ✅ Use research to inform feature prioritization                         │
│  ✅ Use research to inform pricing strategy                               │
│  ✅ Use research to identify domain-specific libraries to use            │
│  ✅ Use research to determine table-stakes vs differentiator features    │
│  ✅ Save competitor analysis for reference during build                   │
│                                                                            │
│  ❌ NEVER skip market research — it's what makes the difference          │
│     between a hobby project and a world-class product                     │
│  ❌ NEVER assume you know the market — ALWAYS search and verify          │
│  ❌ NEVER copy competitor pricing blindly — adapt for India market        │
│  ❌ NEVER ignore user complaints about competitors — they're             │
│     our opportunity to differentiate                                       │
└──────────────────────────────────────────────────────────────────────────┘
```

**Commit:** `research: market research and competitive analysis`

### How Research Feeds Into the Build:
```
MARKET_RESEARCH.md → Informs →
  ├── Feature list & prioritization (Phase 0 master plan)
  ├── Data models (what entities are needed)
  ├── Point costs (informed by competitor pricing)
  ├── Subscription pricing (competitive positioning)
  ├── UI component library choice (shadcn vs MUI vs Ant Design — based on product type)
  ├── UI/UX design patterns (dashboard layout, nav, interactions)
  ├── React Native decision (web-only vs web+mobile — based on competitor mobile presence)
  ├── Animation & interaction patterns (what competitor UIs feel like)
  ├── Third-party integrations (ecosystem expectations)
  ├── SEO meta tags & landing page copy (Phase 9 frontend)
  └── DECISIONS.md (research-backed rationale)
```

---

## PHASE -0.5: PRODUCT BRANDING & DESIGN IDENTITY (MANDATORY)

> **Standalone command available:** This phase can also be run independently via `/gen-brand "ProductName — description"` or `/gen-brand ./PRD.md`. If `BRAND_GUIDE.md` and `public/logo.svg` already exist (from a prior `/gen-brand` run), READ them and SKIP this phase — use the existing brand identity.

After market research, establish the product's brand identity BEFORE writing any UI code. Consistent branding across every touchpoint is what separates a world-class product from a hobby project.

### Branding Research (WebSearch):
```
WebSearch: "[product category] SaaS branding examples"
WebSearch: "[product category] logo design inspiration"
WebSearch: "best SaaS color palettes 2025 2026"
WebSearch: "[product category] brand guidelines examples"
WebSearch: "SaaS landing page design inspiration"
```

### Brand Deliverables — Create `BRAND_GUIDE.md`:

```markdown
# Brand Guide: [Product Name]

## 1. Brand Identity
- **Product Name**: [name — memorable, easy to spell, .com available]
- **Tagline**: [one-line value proposition, max 8 words]
- **Brand Voice**: [professional/friendly/playful/authoritative — pick one]
- **Brand Personality**: [3-4 adjectives: e.g., modern, trustworthy, innovative, approachable]
- **Target Emotion**: [what users should FEEL — confident, empowered, delighted]

## 2. Logo & Mark
- **Logo Concept**: [describe logo — wordmark, icon+wordmark, lettermark, abstract]
- **Logo Prompt** (for AI generation or designer brief):
  "[Product Name] logo, [style: modern minimalist/bold geometric/elegant],
   [industry] SaaS product, [color] palette, clean lines, scalable,
   works on light and dark backgrounds"
- **Favicon**: Simplified icon version of logo (16x16, 32x32, SVG)
- **Social Avatar**: Square crop of logo for Twitter/LinkedIn/GitHub

## 3. Color System
### Primary Colors
| Name | Hex | Usage |
|------|-----|-------|
| Primary | #[hex] | CTAs, links, active states, brand accent |
| Primary Light | #[hex] | Hover states, light backgrounds |
| Primary Dark | #[hex] | Active/pressed states |

### Neutral Colors
| Name | Hex | Usage |
|------|-----|-------|
| Background | #FFFFFF | Page background (light mode) |
| Background Dark | #0F172A | Page background (dark mode) |
| Surface | #F8FAFC | Card/section backgrounds |
| Surface Dark | #1E293B | Card backgrounds (dark mode) |
| Text Primary | #0F172A | Main body text |
| Text Secondary | #64748B | Descriptions, labels |
| Border | #E2E8F0 | Dividers, input borders |

### Semantic Colors
| Name | Hex | Usage |
|------|-----|-------|
| Success | #22C55E | Positive actions, success states |
| Warning | #F59E0B | Warnings, pending states |
| Error | #EF4444 | Errors, destructive actions |
| Info | #3B82F6 | Informational notices |

### Gradients (for hero sections, CTAs)
- Primary gradient: `linear-gradient(135deg, [primary] 0%, [accent] 100%)`

## 4. Typography
- **Headings**: Inter / Plus Jakarta Sans / Cal Sans (modern SaaS standard)
- **Body**: Inter / system-ui (readable, clean)
- **Monospace**: JetBrains Mono / Fira Code (for code/data)
- **Scale**: 12px / 14px / 16px / 18px / 20px / 24px / 30px / 36px / 48px / 60px
- **Weights**: 400 (regular), 500 (medium), 600 (semibold), 700 (bold)

## 5. Design Tokens (Tailwind Config)
```javascript
// tailwind.config.ts — extend with brand tokens
const config = {
  theme: {
    extend: {
      colors: {
        brand: {
          50: '#[lightest]',
          100: '#[...]',
          500: '#[primary]',
          600: '#[primary dark]',
          900: '#[darkest]',
        },
      },
      fontFamily: {
        heading: ['Plus Jakarta Sans', 'Inter', 'system-ui'],
        body: ['Inter', 'system-ui'],
        mono: ['JetBrains Mono', 'monospace'],
      },
      borderRadius: {
        DEFAULT: '0.5rem',  // 8px — modern rounded look
      },
      boxShadow: {
        card: '0 1px 3px rgba(0,0,0,0.1), 0 1px 2px rgba(0,0,0,0.06)',
        elevated: '0 10px 25px rgba(0,0,0,0.1)',
      },
    },
  },
}
```

## 6. Component Styling Standards
- **Buttons**: Rounded (rounded-lg), clear primary/secondary/ghost variants
- **Cards**: Subtle shadow (shadow-card), rounded-xl, proper padding (p-6)
- **Inputs**: Border, rounded-lg, focus ring with brand color
- **Modals**: Centered, backdrop blur, slide-in animation
- **Navigation**: Clean sidebar (SaaS) or topbar, brand color accent on active

## 7. Brand Application
### Landing Page
- Hero section with gradient background + product screenshot
- Social proof (logos, testimonials, metrics)
- Feature grid with icons
- Pricing cards with brand colors
- CTA buttons in primary color

### Email Templates
- Header: Logo + brand colors
- Body: Clean, white background, brand typography
- Footer: Social links, unsubscribe, brand address
- CTA buttons: Match website primary color

### Documentation
- Consistent with website branding
- Code blocks with brand-consistent syntax highlighting

### Favicon & OG Images
- favicon.ico, apple-touch-icon.png (180x180)
- og-image.png (1200x630) — product name + tagline + screenshot
- twitter-card.png (1200x600)

## 8. Branding Files to Generate

**Claude writes SVG code directly** — geometric, modern logos. No external API needed. Follow the SVG generation rules from `commands/gen-brand.md Section 5`.

```
public/
├── logo.svg                 # Full logo (200x48) — icon + wordmark, light bg
├── logo-dark.svg            # Full logo (200x48) — same icon, white text, dark bg
├── logo-icon.svg            # Icon-only mark (48x48) — no text
├── favicon.svg              # Simplified icon (32x32) — browser tab
├── apple-touch-icon.svg     # Icon on brand-50 bg (180x180) — iOS home screen
├── og-image.svg             # Social card (1200x630) — gradient + logo + tagline
└── manifest.json            # PWA manifest with brand name, theme_color
```

**SVG Rules (mandatory):**
- Max 15 shape elements per file, under 5KB each
- `font-family="system-ui, -apple-system, Arial, sans-serif"` (web-safe only)
- Icon mark color = brand-500 (same in light and dark variants)
- Text fill: `#0F172A` (light bg) or `#F8FAFC` (dark bg)
- Include `role="img"` + `<title>` for accessibility
- No raster images, no external references, no JS — pure vector SVG
```

### Branding Rules:
```
┌──────────────────────────────────────────────────────────────────────────┐
│  PRODUCT BRANDING RULES — Consistent brand = Professional product       │
│                                                                          │
│  ✅ Create BRAND_GUIDE.md BEFORE any frontend code                      │
│  ✅ Define color system with light + dark mode variants                 │
│  ✅ Choose typography that matches brand personality                     │
│  ✅ Configure Tailwind with brand design tokens                         │
│  ✅ Brand colors on ALL touchpoints (web, email, docs, OG images)      │
│  ✅ Favicon and OG images generated with brand identity                 │
│  ✅ Email templates use brand header/footer/colors                      │
│  ✅ Error pages, 404, loading screens — all branded                     │
│  ✅ Consistent border-radius, shadows, spacing across ALL components   │
│  ✅ PWA manifest with brand name and theme_color                        │
│                                                                          │
│  ❌ NEVER use default Tailwind blue as primary (customize it)           │
│  ❌ NEVER mix brand inconsistencies (different blues in different pages)│
│  ❌ NEVER ship without favicon and OG images                            │
│  ❌ NEVER use unstyled default error pages (brand them)                 │
│  ❌ NEVER use different fonts across pages (stick to brand typography)  │
│  ❌ NEVER skip dark mode in brand system (it's mandatory)              │
│  ❌ NEVER send emails without brand header/footer                       │
└──────────────────────────────────────────────────────────────────────────┘
```

**Commit:** `brand: establish product branding and design identity`

---
