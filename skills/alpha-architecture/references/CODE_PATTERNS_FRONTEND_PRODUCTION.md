# CODE_PATTERNS_FRONTEND_PRODUCTION.md — The Production-Ready Bar
# Part 4 of 4: Fonts & Color, Real Data, Visual Polish, Performance + A11y, Robustness
# Language: TypeScript/TSX | Framework: Next.js 15+ | UI: shadcn/ui + Tailwind 4+
# ═══════════════════════════════════════════════════════════════════
# See also: CODE_PATTERNS_FRONTEND_CORE.md (architecture)
#           CODE_PATTERNS_FRONTEND_PAGES.md (layouts + page templates)
#           CODE_PATTERNS_FRONTEND_UX.md (components + UX patterns)
#
# THIS FILE IS THE QUALITY CONTRACT. Every frontend Cortex writes — via
# /auto-build, /init-project --with-frontend, /retrofit, or /feature —
# MUST satisfy all five pillars below. These are NOT suggestions; a page
# that violates any §0–§4 rule is NOT production-ready and is not done.
#
# Reference implementation (the gold standard these rules are extracted from):
#   ai_song_generator (SwarAI) — client/src/index.css (OKLCH token system),
#   client/index.html (font loading), BRAND_GUIDE.md (the design contract).
#   SwarAI is Vite+React; Cortex's stack is Next.js, so the canonical CODE
#   below is the Next.js form of the same principles.


# ╔══════════════════════════════════════════════════════════════════╗
# ║  §0. FONTS & COLOR — NON-NEGOTIABLE                              ║
# ╚══════════════════════════════════════════════════════════════════╝
#
# A production frontend NEVER ships on browser-default system fonts or raw
# Tailwind palette colors. It ships on a deliberate typeface pairing and a
# full semantic design-token color system with light AND dark themes.
#
# HARD RULES:
#   ✅ Real typeface pairing: a DISPLAY font (headings/brand) + a UI/BODY
#      font, loaded via `next/font` (self-hosted, zero layout shift).
#   ✅ Full OKLCH semantic token system in globals.css — light + dark.
#   ✅ Components consume SEMANTIC TOKENS ONLY (bg-primary, text-foreground,
#      border-border, text-muted-foreground).
#   ✅ A committed BRAND_GUIDE.md is the design contract (run /gen-brand
#      first if one does not exist — never invent ad-hoc colors per page).
#   ✅ Branded loading / empty / error states — never an unstyled default.
#
#   ❌ NEVER rely on system-ui / default sans as the product font.
#   ❌ NEVER use raw Tailwind palette in components (bg-blue-500, text-gray-700).
#   ❌ NEVER hard-code hex/rgb in a component (hex lives only in BRAND_GUIDE,
#      SVG assets, and email templates — never in .tsx).
#   ❌ NEVER ship a single-theme app — light + dark are both required.
#   ❌ NEVER let fonts cause layout shift (use next/font, not a raw <link>).

## 0.1 — Font loading (canonical: next/font/google)

```ts
// app/fonts.ts — ONE place defines the typeface pairing.
import { Playfair_Display, Inter } from "next/font/google";

// DISPLAY — headings, hero, wordmark. Editorial / brand voice.
export const fontDisplay = Playfair_Display({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-display",
  weight: ["400", "500", "600", "700", "800"],
});

// BODY / UI — everything functional: paragraphs, buttons, labels, tables.
export const fontSans = Inter({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-sans",
  weight: ["300", "400", "500", "600", "700"],
});
```

```tsx
// app/layout.tsx — wire the variables onto <html>, then Tailwind/CSS uses them.
import { fontDisplay, fontSans } from "./fonts";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning
          className={`${fontDisplay.variable} ${fontSans.variable}`}>
      <body className="font-sans antialiased bg-background text-foreground">
        {children}
      </body>
    </html>
  );
}
```

> The display font and body font are PROJECT CHOICES from BRAND_GUIDE.md.
> Playfair Display + Inter is the SwarAI pairing and a safe default, but
> pick per brand: e.g. Sora/Geist for SaaS, Fraunces/Inter for editorial,
> Space Grotesk/Inter for technical. Multi-script products add Noto Sans
> for the relevant scripts (see SwarAI for the 13-language pattern).
> Rule of thumb: DISPLAY font for expression (titles, hero), BODY font for
> everything functional. Never set long body copy in the display font.

## 0.2 — Color token system (canonical: OKLCH, light + dark)

Build `globals.css` from semantic tokens. OKLCH is preferred (perceptually
uniform, easy to tune lightness for dark mode). This skeleton mirrors the
SwarAI `index.css` token block — replace the brand hues, keep the structure.

```css
/* app/globals.css */
@import "tailwindcss";

@custom-variant dark (&:is(.dark *));

@theme inline {
  --font-sans: var(--font-sans);
  --font-display: var(--font-display);
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-card: var(--card);
  --color-card-foreground: var(--card-foreground);
  --color-primary: var(--primary);
  --color-primary-foreground: var(--primary-foreground);
  --color-secondary: var(--secondary);
  --color-secondary-foreground: var(--secondary-foreground);
  --color-muted: var(--muted);
  --color-muted-foreground: var(--muted-foreground);
  --color-accent: var(--accent);
  --color-accent-foreground: var(--accent-foreground);
  --color-destructive: var(--destructive);
  --color-success: var(--success);
  --color-warning: var(--warning);
  --color-info: var(--info);
  --color-border: var(--border);
  --color-input: var(--input);
  --color-ring: var(--ring);
  --radius-lg: var(--radius);
  --radius-md: calc(var(--radius) - 2px);
  --radius-sm: calc(var(--radius) - 4px);
}

:root {
  --radius: 0.75rem;
  --background: oklch(0.985 0.006 80);   /* warm paper, NOT pure white */
  --foreground: oklch(0.2 0.02 270);
  --card: oklch(1 0 0);
  --card-foreground: oklch(0.2 0.02 270);
  --primary: oklch(0.6 0.18 48);         /* ← brand hue: tune per BRAND_GUIDE */
  --primary-foreground: oklch(0.99 0.005 80);
  --secondary: oklch(0.945 0.01 80);
  --secondary-foreground: oklch(0.25 0.02 270);
  --muted: oklch(0.955 0.008 80);
  --muted-foreground: oklch(0.47 0.02 270);
  --accent: oklch(0.94 0.015 285);
  --accent-foreground: oklch(0.25 0.02 270);
  --destructive: oklch(0.55 0.22 25);
  --success: oklch(0.5 0.16 155);
  --warning: oklch(0.55 0.15 75);
  --info: oklch(0.5 0.15 250);
  --border: oklch(0.89 0.012 80);
  --input: oklch(0.93 0.01 80);
  --ring: oklch(0.6 0.18 48);
}

.dark {
  --background: oklch(0.08 0.015 270);   /* deep ink, NOT pure black */
  --foreground: oklch(0.96 0.008 60);
  --card: oklch(0.13 0.02 270);
  --card-foreground: oklch(0.96 0.008 60);
  --primary: oklch(0.72 0.18 55);        /* brighter on dark surfaces */
  --primary-foreground: oklch(0.10 0.015 270);
  --secondary: oklch(0.16 0.025 270);
  --secondary-foreground: oklch(0.85 0.01 60);
  --muted: oklch(0.14 0.020 270);
  --muted-foreground: oklch(0.68 0.015 270);
  --accent: oklch(0.18 0.035 285);
  --accent-foreground: oklch(0.92 0.01 60);
  --destructive: oklch(0.55 0.22 25);
  --success: oklch(0.7 0.17 160);
  --warning: oklch(0.8 0.14 85);
  --info: oklch(0.7 0.13 240);
  --border: oklch(0.28 0.025 270);
  --input: oklch(0.17 0.022 270);
  --ring: oklch(0.72 0.18 55);
}

@layer base {
  * { @apply border-border outline-ring/50; }
  html { scroll-behavior: smooth; -webkit-font-smoothing: antialiased; }
  body { @apply bg-background text-foreground; min-height: 100vh; }
  h1, h2, h3, h4 { font-weight: 700; letter-spacing: -0.02em; line-height: 1.2; }
}
```

```tsx
// Usage in components — semantic tokens ONLY:
<button className="bg-primary text-primary-foreground hover:bg-primary/90 rounded-lg">Save</button>
<div className="bg-card text-card-foreground border border-border rounded-2xl">...</div>
<p className="text-muted-foreground">Secondary copy</p>
// ❌ NEVER: <button className="bg-blue-600 text-white">  /  style={{ color: "#D55000" }}
```

> Type scale (Major Third, 1.25): xs 12 · sm 14 · base 16 · lg 18 · xl 20 ·
> 2xl 24 · 3xl 30 · 4xl 36 · 5xl 48 · 6xl 60. Headings leading-tight +
> tracking-tight; body leading-normal.
> next-themes drives the `.dark` class — see CODE_PATTERNS_FRONTEND_UX.md.


# ╔══════════════════════════════════════════════════════════════════╗
# ║  §1. REAL DATA — NO MOCKS                                        ║
# ╚══════════════════════════════════════════════════════════════════╝
#
#   ✅ Every page fetches from the real API client (lib/api.ts) via
#      TanStack Query — no hardcoded arrays standing in for server data.
#   ✅ All FOUR states wired on every data view: loading (skeleton),
#      empty (illustration + CTA), error (friendly + retry), success.
#   ✅ Config from env: NEXT_PUBLIC_API_URL etc. — never a hardcoded URL.
#   ✅ Every button/link does something real — no dead/no-op handlers.
#
#   ❌ NEVER ship lorem ipsum, "John Doe", or placeholder arrays as content.
#   ❌ NEVER leave a "TODO: wire API" stub in a shipped page.
#   ❌ NEVER render a bare spinner where a content-shaped skeleton belongs.
#   ❌ NEVER leave a button that logs to console or does nothing.

```tsx
// Canonical data view — all four states, real query.
function SongsList() {
  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: ["songs"],
    queryFn: () => api.get("/songs").then(r => r.data),
  });

  if (isLoading) return <SongsListSkeleton />;            // content-shaped
  if (isError)   return <ErrorState onRetry={refetch} />; // friendly + retry (§4)
  if (!data?.length) return <EmptyState title="No songs yet"
                              description="Create your first track to see it here."
                              action={<CreateSongButton />} />;
  return <SongsGrid songs={data} />;
}
```


# ╔══════════════════════════════════════════════════════════════════╗
# ║  §2. POLISHED VISUAL DESIGN — NO GENERIC AI AESTHETIC            ║
# ╚══════════════════════════════════════════════════════════════════╝
#
#   ✅ For any non-trivial UI (landing, dashboard, hero, marketing,
#      distinctive components), INVOKE the `frontend-design` skill to drive
#      design quality — do not settle for raw shadcn defaults on key pages.
#   ✅ Apply BRAND_GUIDE component standards consistently:
#        - Primary CTA: gradient or solid brand fill, rounded, hover state.
#        - Cards: bg-card + border-border/50 + rounded-2xl + subtle shadow.
#        - Inputs: branded focus ring (--ring = brand hue).
#        - Badges/chips: brand-tinted (bg-primary/10 text-primary).
#   ✅ Intentional spacing rhythm, real visual hierarchy, brand gradients /
#      glass surfaces where the brand calls for them.
#
#   ❌ NEVER ship the default "centered card on gray, generic blue button"
#      look. Distinctive ≠ decorated; it means deliberate.
#   ❌ NEVER mix arbitrary radii — stick to the BRAND_GUIDE radius scale.

> When the page is visual (hero, landing, dashboard shell, signature
> component), load the `frontend-design` skill BEFORE writing it. Functional
> CRUD forms can follow the page templates in CODE_PATTERNS_FRONTEND_PAGES.md.


# ╔══════════════════════════════════════════════════════════════════╗
# ║  §3. PERFORMANCE + ACCESSIBILITY                                 ║
# ╚══════════════════════════════════════════════════════════════════╝
#
#   ✅ Images via next/image (sizing, lazy load, modern formats).
#   ✅ Fonts via next/font (§0) — zero layout shift, no render-blocking link.
#   ✅ Code-split heavy/below-the-fold pieces with next/dynamic.
#   ✅ Server Components by default; "use client" only where interactivity
#      requires it. Suspense boundaries around async UI.
#   ✅ WCAG 2.1 AA: semantic HTML, labelled controls, keyboard navigation,
#      visible focus rings, alt text, color contrast ≥ 4.5:1 (verified in
#      BOTH themes), respects prefers-reduced-motion.
#
#   ❌ NEVER ship <img> for content images (use next/image).
#   ❌ NEVER use a <div onClick> where a <button> belongs.
#   ❌ NEVER convey state by color alone (add icon/text).
#   ❌ NEVER cause cumulative layout shift (reserve space for media/skeletons).


# ╔══════════════════════════════════════════════════════════════════╗
# ║  §4. ROBUSTNESS — incl. USER-FRIENDLY ERRORS (HARD)             ║
# ╚══════════════════════════════════════════════════════════════════╝
#
# ERROR MESSAGING — ABSOLUTE RULES:
#   ✅ Every user-facing error is a plain-language, actionable message in the
#      BRAND VOICE (e.g. "We couldn't load your songs — please try again.").
#   ✅ Rendered in a branded surface: toast, inline <ErrorState>, or a route
#      error boundary fallback — never bare unstyled text.
#   ✅ ONE central mapper (lib/errors.ts → getErrorMessage) turns any error
#      into a friendly string. Every page/mutation uses it — no hand-rolled
#      error copy scattered across components.
#   ✅ Technical detail (status, exception, payload) goes to console + Sentry
#      ONLY. The user never sees it.
#
#   ❌ NEVER show an HTTP status code to the user (no "Error 404", "500",
#      "Request failed with status code 403").
#   ❌ NEVER show an exception name, message, or stack trace in the UI.
#   ❌ NEVER render the raw backend error body / API JSON to the user.
#   ❌ NEVER ship Next.js's default error/500 screen — always a branded fallback.
#
# OTHER ROBUSTNESS RULES:
#   ✅ error.tsx + loading.tsx in EVERY route group (branded fallbacks).
#   ✅ Root error boundary catches render crashes → branded "something went
#      wrong" + reset action.
#   ✅ API client: 401 → silent refresh → retry; transient (network/5xx) →
#      bounded retry/backoff; all mapped through getErrorMessage.
#   ✅ Forms: React Hook Form + Zod, inline field errors, submit disabled +
#      spinner while pending, success toast.
#   ✅ Every mutation has disabled + loading state (no double-submit).
#   ✅ Auth via HTTP-Only cookies only — never localStorage/sessionStorage,
#      never decode JWT on the client for route protection (middleware.ts).

```ts
// lib/errors.ts — the ONLY place that decides what the user reads.
import { isAxiosError } from "axios";

const FRIENDLY: Record<number, string> = {
  400: "Something about that request wasn't right. Please check and try again.",
  401: "Your session has expired. Please sign in again.",
  403: "You don't have access to this. If that seems wrong, contact support.",
  404: "We couldn't find what you were looking for.",
  409: "That conflicts with something that already exists.",
  422: "Some details need fixing before we can continue.",
  429: "You're going a little fast — please wait a moment and try again.",
};

export function getErrorMessage(error: unknown): string {
  if (isAxiosError(error)) {
    const status = error.response?.status;
    if (status && FRIENDLY[status]) return FRIENDLY[status];
    if (status && status >= 500) return "Something went wrong on our end. Please try again shortly.";
    if (error.code === "ERR_NETWORK") return "We can't reach the server. Check your connection and try again.";
  }
  // Log the real thing for engineers; show a safe line to the user.
  console.error("[unhandled error]", error);   // Sentry.captureException(error) in prod
  return "Something went wrong. Please try again.";
}
```

```tsx
// components/shared/error-state.tsx — branded inline error (NEVER raw text).
export function ErrorState({ error, onRetry }: { error?: unknown; onRetry?: () => void }) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 rounded-2xl border border-border bg-card p-10 text-center">
      <AlertTriangle className="h-8 w-8 text-destructive" />
      <p className="text-foreground">{getErrorMessage(error)}</p>
      {onRetry && <Button variant="outline" onClick={onRetry}>Try again</Button>}
    </div>
  );
}

// On a mutation:
onError: (err) => toast.error(getErrorMessage(err)),   // friendly, branded
```

```tsx
// app/error.tsx — route error boundary. Branded, never the default screen.
"use client";
export default function Error({ reset }: { error: Error; reset: () => void }) {
  return (
    <div className="flex min-h-[60vh] flex-col items-center justify-center gap-4">
      <h2 className="font-display text-2xl">Something went wrong</h2>
      <p className="text-muted-foreground">We hit a snag loading this page.</p>
      <Button onClick={reset}>Try again</Button>
    </div>
  );
}
```


# ╔══════════════════════════════════════════════════════════════════╗
# ║  PRODUCTION-READY SELF-REVIEW (run against your own output)     ║
# ╚══════════════════════════════════════════════════════════════════╝
#
# Before declaring any frontend work done, confirm EACH:
#   □ §0  Real font pairing via next/font (no system-ui default)?
#   □ §0  Full OKLCH token system, light + dark, in globals.css?
#   □ §0  Components use semantic tokens only (zero raw hex / bg-blue-500)?
#   □ §0  BRAND_GUIDE.md exists and was followed?
#   □ §1  Every data view on a real query with loading/empty/error/data?
#   □ §1  No lorem/placeholder/mock arrays, no dead buttons?
#   □ §2  Visual pages went through the frontend-design skill?
#   □ §3  next/image + next/font; WCAG 2.1 AA; no layout shift?
#   □ §4  All errors friendly + branded; NO HTTP codes / exceptions / stack
#         traces / raw payloads ever shown to the user?
#   □ §4  error.tsx + loading.tsx in every route group; forms validated;
#         mutations have loading/disabled states?
#
# If any box is unchecked, the frontend is NOT production-ready. Fix it.
