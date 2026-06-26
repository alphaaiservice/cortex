---
name: frontend
description: "Auto-invoked when writing ANY frontend code — Next.js/React pages or components, Tailwind/shadcn UI, React Native/Expo screens, or Chrome extensions (.tsx/.jsx/.css/UI work). Enforces Alpha AI's frontend production bar: deliberate typography (next/font), OKLCH semantic design tokens (light + dark), real data wiring, visual polish, perf/a11y, and friendly errors (NEVER raw HTTP codes or stack traces in the UI)."
---

# Frontend Production Standards

This skill enforces Alpha AI's **frontend production bar** on every UI surface — web (Next.js 15+), mobile (React Native + Expo), and Chrome extensions. It is the frontend counterpart to the backend layer rules in `alpha-architecture`. A page that violates any rule below is **not production-ready and is not done**.

The detailed patterns and gold-standard code live in `alpha-architecture/references/` — load them on demand (progressive disclosure):

- **`CODE_PATTERNS_FRONTEND_CORE.md`** — dir structure, App Router, routes, providers, middleware, page state
- **`CODE_PATTERNS_FRONTEND_PAGES.md`** — dashboard layout + 6 page templates (List / Detail / Form / Settings / Dashboard / Auth)
- **`CODE_PATTERNS_FRONTEND_UX.md`** — components, responsive, skeletons, SEO, animations, dark mode, Cmd+K
- **`CODE_PATTERNS_FRONTEND_PRODUCTION.md`** — ⭐ THE QUALITY CONTRACT (the 5 pillars below)
- **`CODE_PATTERNS_CHROME_EXTENSION.md`** — MV3, service worker, content scripts, messaging, storage

---

## The 5 Non-Negotiable Pillars

### 1. Fonts & Color — NON-NEGOTIABLE
- ✅ Real typeface pairing: a DISPLAY font (headings/brand) + a UI/BODY font, loaded via `next/font` (self-hosted, zero layout shift).
- ✅ Full **OKLCH semantic token system** in `globals.css` — light **AND** dark themes.
- ✅ Components consume **semantic tokens only** (`bg-primary`, `text-foreground`, `border-border`, `text-muted-foreground`).
- ✅ A committed `BRAND_GUIDE.md` is the design contract — run `/gen-brand` first if none exists.
- ❌ NEVER ship on `system-ui` / default sans as the product font.
- ❌ NEVER use raw Tailwind palette in components (`bg-blue-500`, `text-gray-700`).
- ❌ NEVER hard-code hex/rgb in a `.tsx` (hex lives only in BRAND_GUIDE, SVG assets, email templates).
- ❌ NEVER ship a single-theme app — light + dark are both required.

### 2. Real Data — no fake UI
- ✅ Every screen wires to a real API / typed client (TanStack Query or server components) — no hard-coded arrays standing in for data.
- ✅ Branded loading (skeletons), empty, and error states for every async surface.
- ❌ NEVER leave `lorem ipsum`, placeholder counts, or mock arrays in a shipped page.

### 3. Visual Polish
- ✅ Consistent spacing scale, deliberate hierarchy, hover/focus/active states on every interactive element.
- ✅ Motion is purposeful (Framer Motion / CSS transitions), respects `prefers-reduced-motion`.
- ✅ Responsive at every breakpoint (mobile-first); no horizontal scroll, no overlap.

### 4. Performance & Accessibility
- ✅ `next/image` for images, `next/font` for fonts, code-split heavy routes, lazy-load below the fold.
- ✅ Core Web Vitals budget respected (LCP, CLS, INP). No layout shift.
- ✅ Accessibility is mandatory — see the `accessibility` skill (semantic HTML, ARIA, contrast, keyboard nav, focus management). This skill and `accessibility` fire together on UI work.

### 5. Friendly Errors — NEVER leak the backend
- ✅ User-facing errors are human sentences with a next action ("We couldn't save your changes — try again").
- ❌ NEVER render raw HTTP status codes (`404`, `500`), exception messages, or stack traces in the UI.
- ✅ Map errors at the data layer to friendly messages; log the technical detail to Sentry, not the screen.

---

## Stack (enforced)
- **Web**: Next.js 15+ App Router · TypeScript · Tailwind 4+ · shadcn/ui · TanStack Query · next-intl (i18n)
- **Mobile**: React Native 0.83+ · Expo SDK 55+ · NativeWind (New Architecture) · i18next
- **Auth on the client**: JWT lives in **HTTP-Only cookies only** — NEVER read/write tokens in `localStorage`/`sessionStorage` (see `security` + `alpha-architecture`).

## How this skill works with others
- `alpha-architecture` — owns the tech-stack catalog and backend layer rules; this skill is its frontend enforcement arm.
- `accessibility` — fires alongside this skill on all UI code; a11y is pillar 4 here and the deep checklist there.
- `security` — client token storage + CSP/XSS rules.
- `performance` — bundle/render budgets shared with pillar 4.

When in doubt, open `CODE_PATTERNS_FRONTEND_PRODUCTION.md` and check the page against all five pillars before calling it done.
