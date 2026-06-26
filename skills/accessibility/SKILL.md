---
name: accessibility
description: "Auto-invoked when writing or modifying ANY user-facing UI — Next.js/React components, forms, modals, navigation, React Native screens. Enforces WCAG 2.1 AA at authoring time: semantic HTML, ARIA, color contrast, keyboard navigation, focus management, screen-reader support. Fires alongside the frontend skill so a11y is built in, not audited after."
---

# Accessibility Standards (WCAG 2.1 AA)

This skill enforces WCAG 2.1 **AA** on every UI surface as it is written — not as a later audit. The `/accessibility` command audits and fixes after the fact; this skill prevents the violations in the first place. It fires together with the `frontend` skill on all UI work.

---

## Hard Rules

### 1. Semantic HTML first
- ✅ Use real elements: `<button>`, `<a href>`, `<nav>`, `<main>`, `<header>`, `<ul>/<li>`, `<label>` — not `<div onClick>`.
- ✅ One `<h1>` per page; heading levels never skip (h1 → h2 → h3).
- ❌ NEVER make a `<div>` clickable without `role`, `tabindex`, and key handlers — just use `<button>`.

### 2. ARIA — only when semantics can't
- ✅ ARIA supplements, never replaces, semantic HTML.
- ✅ Icon-only controls get `aria-label`; live regions for async updates (`aria-live`); modals get `role="dialog"` + `aria-modal`.
- ❌ NEVER add redundant ARIA (`role="button"` on a `<button>`) or invalid ARIA references.

### 3. Color & contrast
- ✅ Text contrast ≥ **4.5:1** (normal), ≥ **3:1** (large text / UI components & focus indicators).
- ✅ Verify contrast for BOTH light and dark themes (ties into the OKLCH token system in `frontend`).
- ❌ NEVER convey meaning by color alone — pair with text, icon, or pattern.

### 4. Keyboard navigation
- ✅ Every interactive element is reachable and operable by keyboard; logical tab order.
- ✅ Visible focus indicator on every focusable element (never `outline: none` without a replacement).
- ✅ Modals/menus trap focus while open and restore focus to the trigger on close; `Esc` closes.
- ❌ NEVER create keyboard traps or mouse-only interactions.

### 5. Forms
- ✅ Every input has a programmatically associated `<label>` (`htmlFor`/`id`).
- ✅ Errors are announced (`aria-describedby` + `aria-invalid`) and described in text, not color alone.
- ✅ Required fields marked semantically (`required` / `aria-required`), not just visually.

### 6. Media & motion
- ✅ Meaningful images have `alt`; decorative images get `alt=""`. Icons have accessible names.
- ✅ Respect `prefers-reduced-motion`; no content that flashes > 3×/sec.
- ✅ Video/audio: captions and transcripts where applicable.

### 7. Screen-reader support
- ✅ Page has a descriptive `<title>` and a "skip to content" link.
- ✅ Dynamic route changes move focus / announce; loading + empty + error states are announced, not silent.

---

## Verify
- Keyboard-only pass: tab through the whole flow, operate everything, confirm focus is always visible.
- Automated: axe-core / Lighthouse a11y in CI; the `/accessibility` command for a full WCAG report.
- Manual: at least one screen-reader smoke test (VoiceOver / NVDA) for primary flows.

## How this skill works with others
- `frontend` — a11y is pillar 4 of the production bar; these two fire together on UI code.
- `security` — focus management overlaps with safe modal/dialog handling.
- `/accessibility` command — the deep audit + `--fix` pass; this skill keeps day-to-day edits compliant.
