---
description: "Generate a brand-consistent pitch/demo deck from a PRD, market research, or a one-line idea. Authored as Marp/Slidev markdown, rendered to PDF/HTML (PPTX on request). Reuses /gen-brand, /market-research, /gen-mockup. Usage: /gen-pitch ./PRD.md [--mode=investor|hackathon|demo|sales] [--slides=12] [--format=pdf,html,pptx] [--tool=marp|slidev]"
---

# Pitch Deck Generator — PRD → Presentation

Turn a product into a presentable, brand-consistent deck. The `pitch-deck` skill auto-loads and defines the narrative arc + quality bar.

`$ARGUMENTS` = PRD path, idea text, or empty (infer from the current project).

---

## Section 0: Input & Context

### 0a. Parse input & flags
- File path → read as PRD. Free text → the pitch brief. Empty → scan the project (`PRD.md`, `README.md`, `MARKET_RESEARCH.md`, `BRAND_GUIDE.md`, `SPRINT_PLAN.md`/`FEATURE_ROADMAP.md`).
- Flags: `--mode=investor|hackathon|demo|sales` (default **investor**), `--slides=N` (default per mode), `--format=pdf,html,pptx` (default `pdf,html`), `--tool=marp|slidev` (default **marp**).

### 0b. Gather source artifacts (reuse, don't reinvent)
Collect whatever exists and cite it on the relevant slide:
- `BRAND_GUIDE.md` → logo, OKLCH colors, fonts (deck theme)
- `MARKET_RESEARCH.md` / `/market-research` output → market, competition, pricing
- `mockups/` (from `/gen-mockup`) → product screenshots
- `pitch/demo.mp4` (from `/gen-demo-video`) → embed/link in demo slide
- `SPRINT_PLAN.md` / `FEATURE_ROADMAP.md` → roadmap/traction
- `/estimate-cost` output → unit economics
If a source is missing, mark its slide content `[TBD]` — never fabricate.

### 0c. Pick the arc
Use the `pitch-deck` skill's arc for the chosen `--mode` (investor = full 10–12; hackathon = compressed 6: Problem→Solution→Demo→Tech→Impact→Ask). Confirm the slide outline to the user in one line before writing.

---

## Section 1: Author the deck (markdown-first)

### 1a. Theme
Generate `pitch/theme.css` from the brand tokens (OKLCH colors, display + body fonts, radius). If no BRAND_GUIDE, use a clean neutral theme and note it.

### 1b. Write `pitch/deck.md` (Marp or Slidev)
- Marp front-matter wires the theme; one `---` per slide.
- Each slide: a **claim headline** (not a label), ≤ ~20 words support, one visual (image/inline-SVG/chart).
- Add **speaker notes** under each slide (`<!-- notes -->`).
- One idea per slide; no bullet dump > 5 lines; data over adjectives.
- Title slide uses the logo SVG; product slides embed mockup screenshots; market slides use real numbers.

### 1c. Mode tuning
- **investor**: emphasize market size, business model, ask. Polished.
- **hackathon**: lead with the demo + tech/architecture + impact; fast, punchy.
- **demo**: product-walkthrough heavy; minimal market.
- **sales**: problem→ROI→proof→pricing→next step.

---

## Section 2: Render & Deliver

### 2a. Render
- Always render HTML. Render PDF by default. Render PPTX only if requested.
- Marp: `npx @marp-team/marp-cli deck.md --theme theme.css --pdf --html` (and `--pptx` if asked).
- Slidev: `npx slidev build` / `export`.
- If the renderer isn't installed, write the source + theme and give the exact `npx` command to render (don't fail the whole command over a missing CLI).

### 2b. Output
```
pitch/
├── deck.md          # source of truth (edit here)
├── theme.css        # brand-themed
├── deck.pdf         # deliverable
├── deck.html        # web version
└── README.md        # how to edit/re-render + which Cortex artifacts were used
```

### 2c. Report back
- The slide outline produced, the mode, and which source artifacts were pulled in (and which were `[TBD]`).
- The render command(s) run or to run.
- Suggested next step: `/gen-demo-video` for a moving demo, or refine specific slides.

---

## Guardrails
- NEVER fabricate metrics, traction, or team facts — use `[TBD]`.
- NEVER default-theme a product that has a BRAND_GUIDE.
- Keep `deck.md` the single source — re-rendering must be one command.
- One idea per slide; kill any slide that's a wall of text.
