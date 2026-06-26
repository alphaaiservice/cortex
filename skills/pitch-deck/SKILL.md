---
name: pitch-deck
description: "Auto-invoked when the user wants a pitch deck, slide deck, investor/demo presentation, or hackathon slides — phrases like 'make a pitch deck', 'create slides', 'investor presentation', 'demo day deck', 'turn the PRD into a presentation'. Enforces Cortex's deck standards: the proven narrative arc, brand-consistent slides as version-controlled markdown (Marp/Slidev → HTML/PDF/PPTX), one idea per slide."
---

# Pitch Deck Standards

This skill governs how Cortex generates **presentations / pitch decks**. Decks are authored as **version-controlled markdown** (Marp or Slidev) and rendered to HTML/PDF/PPTX — never hand-built slide-by-slide in a GUI. Invoked by `/gen-pitch`; auto-fires on any "make slides / presentation / pitch" request.

---

## The narrative arc (default 10–12 slides)
A pitch deck is a STORY, not a feature list. Use this arc unless the user specifies another:
1. **Title** — product name, one-line positioning, logo (from `/gen-brand`)
2. **Problem** — the painful status quo, made concrete
3. **Solution** — your product in one sentence + the "aha"
4. **How it works** — 3-step or a simple diagram (reuse a mockup screenshot if available)
5. **Product** — key screens / demo (pull from `/gen-mockup` or `/gen-demo-video`)
6. **Market** — TAM/SAM/SOM (from `/market-research` if present)
7. **Competition** — positioning matrix (honest, not strawman)
8. **Business model** — how it makes money (Razorpay/subscriptions if relevant)
9. **Traction / roadmap** — milestones, what's built vs next
10. **Team** — who & why you
11. **Ask / CTA** — what you want (raise, signups, judges' vote)

For **hackathon** mode, compress to ~6: Problem → Solution → Demo → Tech/architecture → Impact → Ask.

## Hard rules
- ✅ **One idea per slide.** A headline that's a claim (not a label), ≤ ~20 words of support, one visual.
- ✅ **Brand-consistent**: pull colors/fonts/logo from `BRAND_GUIDE.md`; theme the Marp/Slidev deck with those tokens. Never default-theme a branded product.
- ✅ **Data over adjectives**: real numbers from `/market-research`, `/estimate-cost`, traction. No "revolutionary/world-class" filler.
- ✅ **Reuse Cortex artifacts**: title/logo ← `/gen-brand`; market/competition ← `/market-research`; product slides ← `/gen-mockup` screenshots; demo ← `/gen-demo-video`; roadmap ← `SPRINT_PLAN.md`/`FEATURE_ROADMAP.md`.
- ✅ **Speaker notes** per slide (Marp/Slidev `<!-- -->` notes) so it's presentable, not just pretty.
- ✅ **Multi-format export**: keep the source as `.md`; render HTML (always), PDF (default deliverable), and PPTX only when asked.
- ❌ NEVER produce a wall-of-text slide or bullet dumps > 5 lines.
- ❌ NEVER fabricate metrics/traction — mark unknowns as "[TBD]" rather than inventing.

## Tooling (markdown-first)
- **Marp** (`@marp-team/marp-cli`) — default; clean themes, easy PDF/PPTX, great for investor/standard decks.
- **Slidev** — when the user wants code highlighting, animations, or a dev-audience demo deck.
- **python-pptx** — only when a native editable `.pptx` is explicitly required.

## Output shape
```
pitch/
├── deck.md                 # the source (Marp or Slidev)
├── theme.css               # brand-themed (OKLCH tokens from BRAND_GUIDE)
├── deck.pdf                # rendered deliverable
├── deck.html               # rendered web version
└── README.md               # how to edit + re-render, source artifacts used
```

## How this skill works with others
- `gen-brand` — logo + color/type tokens the deck theme uses.
- `mockup` / `video-producer` — product & demo slides.
- `cost-estimator` / market-research command — market & unit-economics slides.
- `/gen-pitch` (command) — the user-facing trigger.
