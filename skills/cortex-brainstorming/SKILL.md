---
name: cortex-brainstorming
description: "MUST USE before creating any new feature, product, service, or component — including any time a user says 'add', 'build', 'create', 'implement', 'make', 'design', or describes a new behavior. Explores intent, surfaces hidden constraints, and builds the FEATURE_PROFILE needed by /gen-prd, /init-project, /auto-build, /retrofit, and /ai-upgrade. Skipping this leads to scaffolding the wrong stack — e.g., installing Razorpay for a project that doesn't take payments, or building a mobile app the user didn't want."
license: "Proprietary — Alpha AI Service Pvt Ltd"
compatibility: "Designed for Claude Code with cortex plugin"
metadata:
  author: "Alpha AI Service Pvt Ltd"
  version: "1.0"
---

# Cortex Brainstorming — Explore Before You Build

The single biggest waste in autonomous SDLC is building the wrong thing well. Cortex's stack is "Core + Conditional" — every conditional component (Razorpay, Meilisearch, FCM, WebSocket, GenAI, Mobile, 2FA, RBAC, PWA, i18n) costs hours to scaffold and more hours to remove. **Brainstorm first, scaffold second.**

This skill is the explicit conversation that builds the **FEATURE_PROFILE** consumed by every downstream Cortex command. Skipping it means `/init-project` defaults badly, `/gen-prd` invents requirements, `/auto-build` scaffolds dead code, and `/retrofit` adds features no one asked for.

---

## When to use this skill

Always fire when the user:
- Describes a new product, feature, page, screen, agent, or workflow
- Says "I want to add X", "build me Y", "let's create Z"
- Asks for a PRD, sprint plan, or architecture for a new thing
- Requests an existing feature be enhanced ("make X smarter", "add AI to Y")
- Wants to modify a behavior in a non-obvious way

Skip ONLY when:
- A `PRD.md` already exists in the project AND the user is just running `/auto-build` against it (the PRD already captured intent)
- The task is a pure refactor of existing behavior (no new requirements)
- The task is a literal bug fix to existing code

---

## The Cortex Brainstorming Framework (5 questions)

Run these IN ORDER. Do not start writing PRDs, scaffolding directories, or generating code until all five have answers (the user can say "skip — I don't care" for any question, but you must ASK).

### Q1 — Who is this for? (audience)

- Internal tool (employees) vs public-facing SaaS vs enterprise B2B vs consumer mobile
- Geography (India-focused → Razorpay; global → research best gateway)
- Scale expectation (10 users vs 10K vs 10M — drives infra choices)
- Compliance footprint (DPDPA, GDPR, SOC2, HIPAA — drives audit/logging/RBAC)

### Q2 — What's the core action? (job-to-be-done)

- The ONE thing a user does in this product/feature
- What "success" looks like for them in 30 seconds
- The "demo flow" from landing page to value (or feature entry to value)

### Q3 — What does the FEATURE_PROFILE look like? (Cortex's tech profile)

Walk through every conditional component and get a YES/NO for each. **Default to NO** — only flip to YES with explicit reasoning.

| Component | Default | Flip to YES when |
|-----------|---------|------------------|
| MongoDB | NO | Product has flexible documents, audit logs, profiles, content with unknown schema |
| Redis | NO | Needs caching, rate limiting, JWT blacklist, real-time, OTP storage, or session tracking |
| Payments (Razorpay) | NO | Has paid plans, subscriptions, or top-up purchases |
| Google OAuth2 | NO | Public-facing app where social login reduces signup friction |
| Transactional Email | NO | Sends OTPs, welcome mails, password reset, billing receipts |
| File Upload (S3) | NO | Users upload files, images, documents, or media |
| Meilisearch | NO | Needs full-text search across user-generated content |
| Real-Time (WebSocket) | NO | Live updates, chat, collaborative editing, real-time dashboards |
| Push Notifications (FCM) | NO | Has a mobile app AND wants to push notify users |
| Mobile (React Native + Expo) | NO | Product needs an iOS/Android app, not just responsive web |
| GenAI (LiteLLM + RAG) | NO | LLM-powered features, chat, summarization, semantic search |
| 2FA | NO | Stores PII, payment data, or admin-level access |
| RBAC | NO | More than `user` + `admin` roles needed |
| Feature Flags | NO | Plans to do gradual rollouts or A/B tests |
| i18n | NO | Multi-language users (India SaaS → at least English + Hindi) |
| PWA | NO | Offline mode or "install to home screen" matters |
| Admin Panel | NO | Has paying customers or anything requiring back-office ops |

### Q4 — What are we NOT building? (anti-scope)

The most useful brainstorming output is often what's EXCLUDED. Force the user to name 3 things they're explicitly NOT doing in v1. This kills scope creep before `/gen-prd` even runs.

Examples:
- "NOT doing social/sharing features in v1"
- "NOT supporting non-INR currencies in v1"
- "NOT supporting iPad-specific UI in v1"
- "NOT exposing a public API in v1 — internal use only"

### Q5 — Which Cortex persona would own this? (delegation hint)

Pick from `/auto-build`'s persona roster (Arjun Tech Lead, Priya Services, Marcus API, Yuki Security, Daan Payments, Sofia Frontend Pages, Hiroshi LiteLLM Gateway, ...). This isn't just flavor — it nudges later phase delegation toward the right specialist and surfaces gaps (if no persona fits, the build needs a custom specialist via auto-recruit).

---

## Output of brainstorming

After the 5 questions, write a `BRAINSTORM.md` (or update an existing one) in the project root with:

```markdown
# Brainstorm — <product/feature name>

## Audience
- Type: [internal | public SaaS | B2B enterprise | consumer mobile]
- Geography: [...]
- Scale: [...]
- Compliance: [...]

## Core action
[The ONE thing a user does, in 1-2 sentences.]

## FEATURE_PROFILE
- MongoDB: [YES/NO — reason]
- Redis: [YES/NO — reason]
- Payments: [YES/NO — reason]
... [all 17 conditional components]

## Out of scope (v1)
1. [...]
2. [...]
3. [...]

## Persona ownership
- Primary: [persona name]
- Secondary: [persona name(s)]
```

This `BRAINSTORM.md` is the input contract for `/gen-prd`. Downstream commands read it before generating any plan.

---

## Anti-patterns (DO NOT DO)

- ❌ **Jumping straight to `/gen-prd`** without brainstorming when no PRD exists. The PRD will hallucinate requirements you never agreed to.
- ❌ **Flipping conditional components to YES "to be safe"**. Every YES adds hours of build time and code surface. Default NO.
- ❌ **Treating brainstorming as a single question**. The 5 questions are independent — answering "what is it?" doesn't answer "who is it for?"
- ❌ **Asking all 5 questions in one wall of text**. Ask one at a time, listen to the answer, ask the next.
- ❌ **Skipping Q4 (anti-scope)**. This is the highest-ROI question — it kills scope creep at the source.
- ❌ **Brainstorming AGAIN if BRAINSTORM.md already exists**. Read it instead. Only re-brainstorm if the user is making a major pivot.

---

## Integration with downstream Cortex commands

| Downstream command | What it reads from brainstorming |
|--------------------|----------------------------------|
| `/gen-prd` | Audience, core action, FEATURE_PROFILE, out-of-scope list |
| `/market-research` | Audience, core action (for competitor identification) |
| `/init-project` | FEATURE_PROFILE (which directories/deps to scaffold) |
| `/auto-build` | FEATURE_PROFILE (which phases to execute) + persona hint |
| `/retrofit` | FEATURE_PROFILE diff (what features the existing app is missing) |
| `/ai-upgrade` | Core action (where AI can amplify the JTBD) |
| `/estimate-cost` | Scale expectation (drives 100/1K/10K/100K projections) |
| `/sprint-plan` | Out-of-scope list (sprint backlog filter) |

The brainstorm is the single source of truth for product intent. Every later phase reads it.
