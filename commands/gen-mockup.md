---
description: "Generate clickable UI screen mockups/wireframes from a PRD or a one-line description. Claude writes self-contained HTML/Tailwind (or real Next.js) directly — no design tool or API key. Brand-consistent via BRAND_GUIDE.md. Usage: /gen-mockup 'dashboard for a finance app' [--fidelity=low|mid|high] [--screens=dashboard,detail,settings] [--mobile]"
---

# UI Mockup Generator — Screens Before You Build

Generate viewable, brand-consistent screen mockups that sit between `/gen-prd` and `/auto-build`. The `mockup` skill auto-loads with this command and defines the quality bar.

`$ARGUMENTS` = product/screen description, or a path to a PRD/`PRD.md`.

---

## Section 0: Input Parsing & Context Detection

### 0a. Parse input
- If `$ARGUMENTS` is a file path → read it as the PRD; extract the screen list, primary entities, and user roles.
- If it's free text → treat it as the product/screen brief.
- Flags:
  - `--fidelity=low|mid|high` (default **mid**)
  - `--screens=a,b,c` (explicit screen list; otherwise infer from the PRD/brief)
  - `--mobile` (use a ~390px phone frame instead of desktop)
  - `--next` (emit real Next.js + shadcn components under `mockups-next/` instead of standalone HTML — for direct promotion)

### 0b. Detect brand source (CRITICAL — reuse, don't invent)
Search the project for, in order:
1. `BRAND_GUIDE.md` (from `/gen-brand`)
2. `globals.css` / `app/globals.css` with OKLCH `--` tokens
3. `tailwind.config.*` theme extension
If found → extract fonts, OKLCH color tokens (light + dark), radius, spacing; **use them verbatim**.
If none found and fidelity is mid/high → tell the user "no brand found — running with a sensible neutral default; run `/gen-brand` first for on-brand mockups" and proceed with a tasteful default token set.

### 0c. Decide the screen list
From PRD/brief infer the screens to mock. Map each to one of the 6 Cortex page templates (see `frontend` skill / `CODE_PATTERNS_FRONTEND_PAGES.md`): **List · Detail · Form · Settings · Dashboard · Auth**. Confirm the list back to the user in one line before generating.

---

## Section 1: Generation

### 1a. Per-screen rules (enforced by the `mockup` skill)
- Self-contained: each screen is ONE `.html` file, openable with no build step. Use Tailwind via CDN (`<script src="https://cdn.tailwindcss.com">`) for mid/high-fi; plain CSS grayscale for low-fi.
- Inject the brand tokens into a `<style>` block as CSS variables; components consume the tokens (never raw hex in markup).
- Load the brand fonts via `<link>` (Google Fonts) at mid/high-fi.
- Realistic content — plausible names, numbers, dates, states. Never lorem ipsum.
- Show the meaningful states for that screen type (empty / loading skeleton / populated) where it adds signal.
- Semantic HTML + visible focus states + AA contrast (the `accessibility` skill applies even here).
- High-fi screens carry a small fixed "MOCKUP — not production" ribbon.

### 1b. Fidelity specifics
- **low**: grayscale, dashed boxes, labels, no imagery, no brand color. Layout/structure only.
- **mid** (default): brand colors + type + shadcn-style components, placeholder-plausible data, light theme (note dark is available).
- **high**: pixel-close, light **and** dark theme toggle, clickable nav between screens, micro-interactions via CSS transitions, real-looking charts (inline SVG) for dashboards.

### 1c. Mobile (`--mobile`)
Wrap each screen in a ~390×844 phone frame; bottom tab bar / native-style headers; respect safe areas. Mirrors the React Native screens you build (see the `mobile` skill if present).

### 1d. `--next` mode
Instead of HTML, emit real `app/(preview)/<screen>/page.tsx` + components using shadcn/ui + Tailwind + the project's tokens, following the `frontend` skill exactly so the mockup IS promotable code. Include a short note that these are preview routes to be wired to real data.

---

## Section 2: Assembly & Output

### 2a. Write files
```
mockups/                      (or mockups-next/ for --next)
├── index.html                # gallery: a card per screen (title, fidelity, thumbnail/preview link)
├── 01-<screen>.html
├── 02-<screen>.html
└── README.md
```
- `index.html` is a simple responsive gallery linking every screen; at high-fi, link screens to each other so the flow is clickable end-to-end.

### 2b. README.md must contain
- Screen list + the page template each maps to
- Fidelity level and brand source used (file path, or "neutral default")
- How to view (just open `index.html`)
- **Promotion path**: which command turns this into real code — `/auto-build ./PRD.md`, `/init-project <name> --with-frontend`, or `/feature "<screen>"` — and a note that `--next` output drops straight into the App Router.

### 2c. Report back to the user
- The list of screens generated, fidelity, and the brand source.
- One-line "open `mockups/index.html` to view."
- The recommended next step (promotion path).

---

## Guardrails
- NEVER call real APIs, embed secrets, or implement real auth in a mockup.
- NEVER invent brand colors when a BRAND_GUIDE exists — reuse it.
- Keep each HTML file standalone and dependency-free except CDN Tailwind + Google Fonts.
- If the user wants the mockup in Figma rather than code, defer to the Figma skills (`figma-generate-design`) instead.
