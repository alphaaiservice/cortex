---
name: mockup
description: "Auto-invoked when the user wants to mock up, wireframe, prototype, or visualize a UI screen/page/flow BEFORE building the real thing — phrases like 'mock up the dashboard', 'wireframe the onboarding', 'show me what X looks like', 'design a screen', 'clickable prototype'. Enforces Cortex's mockup standards: brand-consistent (reuse BRAND_GUIDE tokens), fidelity-appropriate, self-contained, and a clean path to promote the mockup into real frontend code."
---

# UI Mockup Standards

This skill governs how Cortex generates **screen mockups / wireframes / clickable prototypes** — the artifact that sits between `/gen-prd` and `/auto-build`. It is invoked by the `/gen-mockup` command and auto-fires whenever the user asks to visualize a UI before building it. Claude writes mockups **directly as code** (no design-tool API key needed) — same philosophy as `/gen-brand`.

---

## Fidelity ladder — pick the right one
- **Low-fi (wireframe)** — grayscale, boxes + labels, no brand color/imagery. For early structure/layout debate. Output: single self-contained HTML file.
- **Mid-fi** — brand colors + typography + real component shapes (shadcn-like), placeholder-but-plausible copy. The default.
- **High-fi (prototype)** — pixel-close to production, real OKLCH tokens, dark+light, clickable navigation between screens. For stakeholder sign-off or pre-build review.

Ask / infer the fidelity. When unsure, default to **mid-fi**.

## Hard rules
- ✅ **Brand-consistent**: if a `BRAND_GUIDE.md` / `globals.css` token set exists, REUSE its OKLCH tokens, fonts, and radius — never invent ad-hoc colors. If none exists, suggest running `/gen-brand` first (mid/high-fi only).
- ✅ **Self-contained & instantly viewable**: a mockup must open in a browser with zero build step. Default output = one HTML file per screen (Tailwind via CDN for mid/high-fi) under `mockups/`. Multiple screens get an `index.html` gallery linking them.
- ✅ **Realistic content**: plausible names/numbers/states — never `lorem ipsum`. Show the real empty, loading, and populated states where they matter.
- ✅ **Responsive**: mockup the stated viewport (desktop default); for mobile screens use a phone-frame width (~390px).
- ✅ **Honest about being a mockup**: a small "MOCKUP — not production" ribbon on high-fi screens so it's never mistaken for shipped UI.
- ✅ **Promotion path**: every mockup ends with a note on how to promote it to real code — `/auto-build`, `/init-project --with-frontend`, or `/feature` — and the mockup obeys the `frontend` skill's structure so translation is 1:1.
- ❌ NEVER hard-code secrets, call real APIs, or wire real auth in a mockup.
- ❌ NEVER ship a high-fi mockup on system fonts or raw Tailwind palette — it must preview the real production bar (see `frontend` skill).

## Output shape
```
mockups/
├── index.html              # gallery: thumbnails + links to every screen
├── 01-dashboard.html
├── 02-detail.html
└── README.md               # screen list, fidelity, brand source, promotion steps
```

## How this skill works with others
- `frontend` — the production bar mockups should preview (fonts, OKLCH tokens, friendly errors); high-fi mockups are dry-runs of it.
- `gen-brand` / BRAND_GUIDE.md — the color/type source of truth a mockup must honor.
- `accessibility` — even mockups use semantic structure + contrast so a11y isn't bolted on later.
- `/gen-mockup` (command) — the user-facing trigger; `/auto-build` & `/feature` — where a signed-off mockup becomes real code.
- External alternative: the Figma skills (`figma-generate-design`) when the user wants the mockup *in Figma* instead of as code.
