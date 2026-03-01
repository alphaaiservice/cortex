---
description: "Generate complete brand identity with SVG logos, color system, typography, and design tokens. Claude writes SVG code directly — no API key needed. Usage: /gen-brand 'ProductName — description' or /gen-brand ./PRD.md"
---

# Brand Identity Generator — SVG Logos & Complete Design System

Generate a complete brand identity package for: **$ARGUMENTS**

This command creates:
- **BRAND_GUIDE.md** — comprehensive brand guidelines document
- **7 SVG/JSON files** — logos, favicon, icons, OG image, PWA manifest
- **Design tokens** — Tailwind-ready color system, typography, spacing
- All generated directly by Claude — **no external API keys needed**

---

## Section 0: Input Parsing & Context Detection

Parse `$ARGUMENTS` to determine the product name, description, and domain.

### 0a. Detect Input Type

```
IF $ARGUMENTS is empty:
  → Ask: "What product should I create branding for? Provide a name and description, or a path to a PRD file."
  → STOP and wait for user input.

IF $ARGUMENTS ends with .md or starts with ./ or / (file path):
  → Read the file
  → Extract product name from the first H1 heading or "Product Name" field
  → Extract description from the first paragraph or "Description" field
  → Extract target audience, features list, and industry/category
  → SET INPUT_TYPE = "prd"

IF $ARGUMENTS is a quoted string or plain text:
  → Parse format: "ProductName — description" or "ProductName: description" or just "ProductName"
  → If no separator found, use the full text as product name
  → SET INPUT_TYPE = "brief"
```

### 0b. Extract Brand Inputs

```
Extract and store:
  PRODUCT_NAME    = [extracted product name — capitalize properly]
  PRODUCT_DESC    = [one-line description — what the product does]
  PRODUCT_DOMAIN  = [detected domain: fintech/healthtech/edtech/ecommerce/productivity/devtools/social/ai/security/analytics/marketing/hr/logistics/legal/gaming/media/travel/food/realestate/general]
  TARGET_AUDIENCE = [who uses this product — extracted from PRD or inferred from description]
  KEY_FEATURES    = [top 3-5 features — extracted from PRD or inferred]
  BRAND_MOOD      = [inferred mood: professional/playful/bold/elegant/minimal/warm/techy/corporate]
```

### 0c. Validate Inputs

```
IF PRODUCT_NAME is empty or unclear:
  → Ask: "What is the product name?"
  → STOP and wait for user input.

IF PRODUCT_DESC is empty and INPUT_TYPE = "brief":
  → Infer a description from the product name
  → Log: "Inferred description: [desc]. Proceeding with branding."
```

---

## Section 1: Brand Research (WebSearch)

Research branding trends and competitor examples to inform design decisions. This research shapes the color, typography, and logo style choices.

### 1a. Industry & Competitor Research

```
WebSearch: "[PRODUCT_DOMAIN] SaaS branding examples 2025 2026"
WebSearch: "[PRODUCT_DOMAIN] best logo design modern minimalist"
WebSearch: "best SaaS color palettes [PRODUCT_DOMAIN] 2025 2026"
WebSearch: "[PRODUCT_DOMAIN] brand guidelines examples"
WebSearch: "SaaS landing page design trends 2025 2026"
```

### 1b. Color Trend Research

```
WebSearch: "modern SaaS color trends [PRODUCT_DOMAIN]"
WebSearch: "brand color psychology [BRAND_MOOD] technology"
```

### 1c. Typography Research

```
WebSearch: "best Google Fonts for SaaS [PRODUCT_DOMAIN] 2025 2026"
WebSearch: "font pairing [BRAND_MOOD] technology products"
```

### 1d. Analyze Research Results

From the research, extract:
```
COMPETITOR_COLORS   = [list of 3-5 primary colors used by competitors]
COMPETITOR_FONTS    = [list of fonts commonly used in the domain]
DESIGN_TRENDS       = [3-5 key design trends in the domain]
COLOR_PSYCHOLOGY    = [what colors evoke the right emotion for BRAND_MOOD]
DIFFERENTIATION     = [how to visually stand apart from competitors]
```

### 1e. Research Summary

Log a brief research summary:
```
┌─────────────────────────────────────────────────────────┐
│  Brand Research Summary                                  │
│                                                          │
│  Domain: [PRODUCT_DOMAIN]                               │
│  Competitors analyzed: [count]                          │
│  Common colors: [list]                                  │
│  Common fonts: [list]                                   │
│  Key trends: [list]                                     │
│  Our differentiation: [strategy]                        │
└─────────────────────────────────────────────────────────┘
```

---

## Section 2: Brand Identity Definition

Define the core brand personality and voice before any visual design.

### 2a. Brand Personality

Based on PRODUCT_DOMAIN, TARGET_AUDIENCE, and research results, define:

```
BRAND_PERSONALITY = {
  voice:          [professional | friendly | playful | authoritative | warm | bold]
  personality:    [3-4 adjectives — e.g., modern, trustworthy, innovative, approachable]
  target_emotion: [what users should FEEL — confident, empowered, delighted, secure, inspired]
  tone:           [casual | semiformal | formal]
  energy:         [calm | balanced | energetic | intense]
}
```

### 2b. Brand Tagline

Create a tagline that:
- Is **max 8 words**
- Communicates the core value proposition
- Is memorable and easy to say aloud
- Avoids jargon unless targeting developers

```
TAGLINE = "[generated tagline — max 8 words]"
```

### 2c. Brand Story (one paragraph)

Write a 2-3 sentence brand story:
- What problem does the product solve?
- Who benefits from it?
- Why is this approach unique?

```
BRAND_STORY = "[2-3 sentence brand story]"
```

### 2d. Brand Archetypes

Select the primary brand archetype:
```
ARCHETYPE = [one of: Creator | Explorer | Sage | Hero | Magician | Rebel | Lover | Caregiver | Everyman | Jester | Ruler | Innocent]
```

Map archetype to design direction:
```
Creator    → creative, innovative colors (purple, orange)
Explorer   → adventurous, nature tones (green, teal)
Sage       → trust, knowledge (blue, navy)
Hero       → bold, powerful (red, dark blue)
Magician   → transformative (purple, gold)
Rebel      → disruptive, edgy (black, red, neon)
Lover      → connection, warmth (pink, warm red)
Caregiver  → nurturing, safe (green, soft blue)
Everyman   → approachable, honest (blue, green)
Jester     → fun, playful (orange, yellow, bright)
Ruler      → premium, authoritative (gold, navy, black)
Innocent   → simple, pure (white, light blue, pastel)
```

---

## Section 3: Color System Generation

Generate a complete, production-ready color system using HSL-based rules for mathematical consistency.

### 3a. Primary Color Selection

Based on brand archetype, domain, mood, and competitor differentiation:

```
1. Choose a PRIMARY HUE (0-360 on HSL wheel):
   - Must DIFFER from dominant competitor colors by at least 30 degrees
   - Must match the brand archetype's color direction
   - Must work well in both light and dark modes

2. Set PRIMARY COLOR at the 500 level:
   PRIMARY_HSL = hsl(H, S%, L%)
   - H = chosen hue (0-360)
   - S = 70-85% (vibrant but not neon)
   - L = 45-55% (visible on white bg, passes WCAG contrast)
```

### 3b. Generate 10-Shade Palette (50-900)

From the primary HSL, generate 10 shades using consistent HSL rules:

```
SHADE GENERATION RULES (HSL math):
┌────────┬───────────────────────────────────────────────────────┐
│ Shade  │ HSL Rule                                              │
├────────┼───────────────────────────────────────────────────────┤
│ 50     │ hsl(H, S-10%, 97%)     — barely-there tint           │
│ 100    │ hsl(H, S-5%,  93%)     — very light background       │
│ 200    │ hsl(H, S%,    85%)     — light accent                │
│ 300    │ hsl(H, S%,    73%)     — medium-light                │
│ 400    │ hsl(H, S%,    62%)     — approaching primary         │
│ 500    │ hsl(H, S%,    L%)      — PRIMARY (the chosen color)  │
│ 600    │ hsl(H, S+5%,  L-8%)   — hover/active state          │
│ 700    │ hsl(H, S+5%,  L-18%)  — dark accent                 │
│ 800    │ hsl(H, S+3%,  L-28%)  — very dark                   │
│ 900    │ hsl(H, S+3%,  L-35%)  — near-black with hue         │
└────────┴───────────────────────────────────────────────────────┘

Convert each HSL value to HEX for the final palette.
```

### 3c. Neutral Colors

Generate a neutral palette that's slightly tinted with the primary hue for brand cohesion:

```
NEUTRAL GENERATION (tinted neutrals):
- Take primary hue H
- Set saturation to 5-15% (barely visible tint)
- Generate shades:

  neutral-50:  hsl(H, 10%, 98%)   — lightest background
  neutral-100: hsl(H, 10%, 96%)   — subtle background
  neutral-200: hsl(H, 8%,  91%)   — borders, dividers
  neutral-300: hsl(H, 8%,  83%)   — disabled states
  neutral-400: hsl(H, 6%,  64%)   — placeholder text
  neutral-500: hsl(H, 5%,  46%)   — secondary text
  neutral-600: hsl(H, 5%,  33%)   — body text (dark mode secondary)
  neutral-700: hsl(H, 6%,  23%)   — headings on light bg
  neutral-800: hsl(H, 8%,  15%)   — near-black text
  neutral-900: hsl(H, 10%, 9%)    — darkest text / dark mode bg
```

### 3d. Semantic Colors

Define semantic colors that harmonize with the primary palette:

```
SEMANTIC COLORS:
  success:  hsl(142, 71%, 45%)  → #22C55E  — green for positive
  warning:  hsl(38, 92%, 50%)   → #F59E0B  — amber for caution
  error:    hsl(0, 84%, 60%)    → #EF4444  — red for errors
  info:     hsl(217, 91%, 60%)  → #3B82F6  — blue for information

  Each semantic color also gets a light variant (for backgrounds):
  success-light: hsl(142, 76%, 95%)
  warning-light: hsl(48, 96%, 95%)
  error-light:   hsl(0, 93%, 95%)
  info-light:    hsl(214, 95%, 95%)
```

### 3e. Dark Mode Colors

Define dark mode palette overrides:

```
DARK MODE MAPPING:
  background:    neutral-900       — page background
  surface:       neutral-800       — cards, panels
  surface-hover: neutral-700       — hover states
  border:        neutral-700       — dividers
  text-primary:  neutral-50        — main text
  text-secondary: neutral-400      — secondary text
  primary:       brand-400         — slightly lighter for dark bg contrast
  primary-hover: brand-300         — hover on dark bg
```

### 3f. Gradient Definitions

```
GRADIENTS:
  primary:    linear-gradient(135deg, brand-500 0%, brand-600 100%)
  hero:       linear-gradient(135deg, brand-500 0%, [complementary] 100%)
  subtle:     linear-gradient(180deg, brand-50 0%, white 100%)
  dark-hero:  linear-gradient(135deg, brand-900 0%, neutral-900 100%)
  shimmer:    linear-gradient(90deg, transparent 0%, brand-100 50%, transparent 100%)
```

### 3g. Color Output Table

Create a complete color reference table with all hex values:

```markdown
| Token         | Light Mode | Dark Mode  | Usage                    |
|---------------|-----------|------------|--------------------------|
| brand-50      | #______   | —          | Subtle tinted background |
| brand-100     | #______   | —          | Light accent bg          |
| brand-200     | #______   | —          | Borders, tags            |
| brand-300     | #______   | #______(dm-primary-hover) | Light text accent |
| brand-400     | #______   | #______(dm-primary)       | Icons on dark    |
| brand-500     | #______   | —          | PRIMARY — CTAs, links    |
| brand-600     | #______   | —          | Hover/active state       |
| brand-700     | #______   | —          | Dark accent              |
| brand-800     | #______   | —          | Very dark accent         |
| brand-900     | #______   | —          | Near-black with hue      |
| neutral-50    | #______   | (text)     | Lightest bg              |
| neutral-100   | #______   | —          | Subtle bg                |
| neutral-200   | #______   | —          | Borders                  |
| neutral-300   | #______   | —          | Disabled                 |
| neutral-400   | #______   | (secondary text) | Placeholder      |
| neutral-500   | #______   | —          | Muted text               |
| neutral-600   | #______   | —          | Body text                |
| neutral-700   | #______   | (border)   | Headings                 |
| neutral-800   | #______   | (surface)  | Dark text                |
| neutral-900   | #______   | (bg)       | Darkest                  |
```

---

## Section 4: Typography System

Select and configure fonts that match the brand personality.

### 4a. Font Selection

Based on BRAND_MOOD and domain research:

```
FONT SELECTION MATRIX:
┌───────────────┬──────────────────────────────────────────────────────┐
│ Brand Mood    │ Recommended Font Pairings (Heading / Body)           │
├───────────────┼──────────────────────────────────────────────────────┤
│ Professional  │ Inter / Inter  OR  Plus Jakarta Sans / Inter         │
│ Playful       │ Nunito / Open Sans  OR  Poppins / Inter             │
│ Bold          │ Sora / Inter  OR  Space Grotesk / DM Sans           │
│ Elegant       │ Playfair Display / Lora  OR  DM Serif / Inter       │
│ Minimal       │ Inter / Inter  OR  Outfit / Inter                    │
│ Warm          │ Plus Jakarta Sans / Nunito  OR  Rubik / Open Sans   │
│ Techy         │ Space Grotesk / JetBrains Mono  OR  Geist / Inter   │
│ Corporate     │ IBM Plex Sans / IBM Plex Sans  OR  Noto Sans / Inter│
└───────────────┴──────────────────────────────────────────────────────┘

MONOSPACE (always one of):
  JetBrains Mono | Fira Code | Source Code Pro | IBM Plex Mono | Geist Mono
```

Choose fonts:
```
FONT_HEADING  = [chosen heading font]
FONT_BODY     = [chosen body font]
FONT_MONO     = [chosen monospace font]
```

### 4b. Type Scale

Define a consistent type scale (using the Major Third ratio — 1.25):

```
TYPE SCALE:
  xs:   0.75rem  (12px)  — fine print, labels
  sm:   0.875rem (14px)  — secondary text, metadata
  base: 1rem     (16px)  — body text (default)
  lg:   1.125rem (18px)  — lead paragraphs
  xl:   1.25rem  (20px)  — small headings
  2xl:  1.5rem   (24px)  — section headings (h4)
  3xl:  1.875rem (30px)  — page subheadings (h3)
  4xl:  2.25rem  (36px)  — page headings (h2)
  5xl:  3rem     (48px)  — hero headings (h1)
  6xl:  3.75rem  (60px)  — landing hero (display)
```

### 4c. Font Weights

```
FONT WEIGHTS:
  regular:  400  — body text
  medium:   500  — emphasis, labels, nav items
  semibold: 600  — subheadings, buttons, bold UI
  bold:     700  — headings, hero text, strong emphasis
```

### 4d. Line Heights

```
LINE HEIGHTS:
  tight:   1.25  — headings (h1-h3)
  snug:    1.375 — subheadings (h4-h6)
  normal:  1.5   — body text
  relaxed: 1.625 — long-form reading
  loose:   2     — small text / labels
```

### 4e. Google Fonts URL

Generate the Google Fonts import URL:

```
GOOGLE_FONTS_URL = "https://fonts.googleapis.com/css2?family=[FONT_HEADING]:wght@400;500;600;700&family=[FONT_BODY]:wght@400;500;600&family=[FONT_MONO]:wght@400;500&display=swap"
```

### 4f. Letter Spacing

```
LETTER SPACING:
  tighter: -0.05em  — large display headings (5xl, 6xl)
  tight:   -0.025em — headings (3xl, 4xl)
  normal:  0em      — body text
  wide:    0.025em  — buttons, all-caps labels
  wider:   0.05em   — overline text, badges
  widest:  0.1em    — eyebrow text
```

---

## Section 5: SVG Logo Generation (CORE)

**Claude writes SVG code directly.** No external tools, no API keys. Generate geometric, modern SVG logos.

### 5a. SVG Generation Rules (MANDATORY)

Every SVG file MUST follow these rules:

```
SVG RULES — ALL logos MUST comply:
┌──────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│  1. MAX 15 path/shape elements per logo — keep it clean and geometric   │
│  2. MAX 5KB file size per SVG — no bloat                                │
│  3. Font: font-family="system-ui, -apple-system, Arial, sans-serif"    │
│     → Web-safe system fonts ONLY (no @import, no custom fonts in SVG)  │
│  4. Icon mark color = brand-500 (same in light and dark variants)       │
│  5. Text color (light bg): #0F172A (neutral-900)                        │
│  6. Text color (dark bg):  #F8FAFC (neutral-50)                         │
│  7. Accessibility: role="img" + <title>PRODUCT_NAME Logo</title>       │
│  8. No raster images (<image> tags) — pure vector only                  │
│  9. No external references (no xlink:href to external files)            │
│  10. No JavaScript or CSS animations in SVG                             │
│  11. Use viewBox (not width/height in px) for scalability               │
│  12. Optimize: no unnecessary whitespace, no editor metadata            │
│  13. All colors as hex (#RRGGBB), never rgb() or named colors          │
│  14. Text elements: use font-weight and letter-spacing attributes       │
│  15. Icon geometry: use basic shapes (rect, circle, path) not complex   │
│      Bezier curves — geometric/modern aesthetic                         │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

### 5b. Icon Concept Selection

Choose an icon concept based on the product domain. The icon should be:
- **Geometric** — made of simple shapes (circles, rectangles, triangles, lines)
- **Meaningful** — visually connected to what the product does
- **Scalable** — recognizable at 16x16 and 512x512
- **Unique** — not a generic clipart shape

```
ICON CONCEPT MATRIX — Select by PRODUCT_DOMAIN:
┌────────────────┬──────────────────────────────────────────────────────────┐
│ Domain         │ Icon Concepts (pick the most fitting)                    │
├────────────────┼──────────────────────────────────────────────────────────┤
│ fintech        │ chart-up arrow, stacked coins, shield+dollar, graph bar │
│ healthtech     │ heart+pulse, cross+circle, shield+heart, leaf+heart     │
│ edtech         │ open book, graduation cap, lightbulb, brain circuit     │
│ ecommerce      │ shopping bag, cart, storefront, price tag               │
│ productivity   │ checkmark+box, kanban board, lightning bolt, target     │
│ devtools       │ terminal bracket, code slash, git branch, hexagon      │
│ social         │ speech bubbles, connected dots, people silhouette       │
│ ai             │ neural nodes, brain circuit, sparkle star, infinity     │
│ security       │ shield, lock, fingerprint, key                          │
│ analytics      │ bar chart, pie segments, trend line, dashboard grid     │
│ marketing      │ megaphone, target, rocket, chart+arrow                  │
│ hr             │ people+gear, handshake, org chart, badge                │
│ logistics      │ truck, route pins, box+arrow, map marker                │
│ legal          │ scales, gavel, document+seal, pillar                    │
│ gaming         │ controller, diamond, trophy, joystick                   │
│ media          │ play button, camera, film reel, audio wave              │
│ travel         │ compass, airplane, globe, map pin                       │
│ food           │ fork+knife, chef hat, leaf, plate                       │
│ realestate     │ house, key+door, building, location pin                 │
│ general        │ abstract geometric (hexagon, overlapping circles, etc.) │
└────────────────┴──────────────────────────────────────────────────────────┘

SELECTED_ICON_CONCEPT = [chosen concept]
```

Design the icon as a combination of 2-3 geometric shapes. Think about:
- What shape tells the product's story at a glance?
- Does it work as a silhouette (single color)?
- Is it recognizable at favicon size (16x16)?

### 5c. File 1 — `public/logo.svg` (Full Logo — Light Background)

**ViewBox:** `0 0 200 48`
**Contains:** Icon mark (left) + wordmark text (right)
**Use:** Header navigation, landing page, light backgrounds

```
Write the SVG to: public/logo.svg

Structure:
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 48" role="img" aria-labelledby="logo-title">
  <title id="logo-title">[PRODUCT_NAME]</title>

  <!-- Icon Mark (left side, ~40x40 centered in 48px height) -->
  <g transform="translate(4, 4)">
    [2-4 geometric shapes using brand-500 as fill]
    [Keep shapes simple: rect, circle, polygon, simple path]
    [Total shapes MUST be under 15 elements]
  </g>

  <!-- Wordmark (right side) -->
  <text x="56" y="31"
    font-family="system-ui, -apple-system, Arial, sans-serif"
    font-size="22"
    font-weight="700"
    letter-spacing="-0.02em"
    fill="#0F172A">[PRODUCT_NAME]</text>
</svg>

RULES for logo.svg:
- Icon group starts at x=4, y=4 (4px padding from viewBox edge)
- Icon fits in 40x40 area
- Text starts at x=56 (40px icon + 16px gap)
- Text baseline at y=31 (vertically centered for 48px height)
- Text fill = #0F172A (dark text for light backgrounds)
- Icon fill = brand-500 hex color
- Total file MUST be under 5KB
```

### 5d. File 2 — `public/logo-dark.svg` (Full Logo — Dark Background)

**ViewBox:** `0 0 200 48`
**Contains:** Same icon mark + white wordmark text
**Use:** Dark mode header, dark hero sections, dark backgrounds

```
Write the SVG to: public/logo-dark.svg

IDENTICAL to logo.svg EXCEPT:
- Wordmark text fill = "#F8FAFC" (white/near-white for dark backgrounds)
- Icon mark color stays the SAME (brand-500) — do NOT change the icon color
- Everything else (viewBox, positions, shapes, font) remains identical

This ensures the icon is always recognizable regardless of background,
while the text adapts for readability.
```

### 5e. File 3 — `public/logo-icon.svg` (Icon Only — No Text)

**ViewBox:** `0 0 48 48`
**Contains:** Icon mark only (no text)
**Use:** Small spaces, mobile nav, app icon base, social avatar

```
Write the SVG to: public/logo-icon.svg

Structure:
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" role="img" aria-labelledby="icon-title">
  <title id="icon-title">[PRODUCT_NAME] Icon</title>

  <!-- Icon Mark (centered in 48x48) -->
  <g transform="translate(4, 4)">
    [SAME geometric shapes as in logo.svg icon group]
    [Fills: brand-500 hex color]
  </g>
</svg>

RULES for logo-icon.svg:
- Exact same icon shapes as logo.svg, just without the wordmark
- Centered in 48x48 viewBox with 4px padding on each side
- Same colors as logo.svg icon
- Must be recognizable at small sizes (16px rendering)
```

### 5f. File 4 — `public/favicon.svg` (Browser Tab Icon)

**ViewBox:** `0 0 32 32`
**Contains:** Simplified icon mark — fewer details for tiny rendering
**Use:** Browser tab, bookmark bar

```
Write the SVG to: public/favicon.svg

Structure:
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" role="img" aria-labelledby="favicon-title">
  <title id="favicon-title">[PRODUCT_NAME]</title>

  <!-- Simplified Icon (centered, minimal detail) -->
  [Simplified version of the icon mark]
  [Use 1-2 shapes maximum — must be clear at 16x16 pixels]
  [Fill: brand-500 hex color]
</svg>

RULES for favicon.svg:
- SIMPLIFIED version of logo-icon.svg
- Remove small details that disappear at 16x16
- Use brand-500 as primary fill
- Keep to 1-2 shapes maximum
- No text, no fine lines (they become invisible at small sizes)
- Consider adding a subtle background shape (rounded rect) if the
  icon alone doesn't read well at tiny sizes
```

### 5g. File 5 — `public/apple-touch-icon.svg` (iOS Home Screen)

**ViewBox:** `0 0 180 180`
**Contains:** Icon mark centered on brand-50 background
**Use:** iOS home screen when user adds site to home screen

```
Write the SVG to: public/apple-touch-icon.svg

Structure:
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 180 180" role="img" aria-labelledby="apple-icon-title">
  <title id="apple-icon-title">[PRODUCT_NAME]</title>

  <!-- Background (brand-50 — subtle tinted background) -->
  <rect width="180" height="180" rx="40" fill="[brand-50 hex]"/>

  <!-- Icon Mark (centered, scaled to ~100x100) -->
  <g transform="translate(40, 40) scale(2.5)">
    [SAME icon shapes as logo-icon.svg, scaled up]
    [Fill: brand-500 hex color]
  </g>
</svg>

RULES for apple-touch-icon.svg:
- 180x180 viewBox (standard Apple touch icon size)
- Background: rounded rect with brand-50 fill, rx=40 for iOS-like rounding
- Icon centered with generous padding (~40px on each side)
- Scale the 40x40 icon to fit ~100x100 area in the center
- The scale transform should be calculated: 100/40 = 2.5
- Brand-500 icon on brand-50 background = subtle, professional look
```

### 5h. File 6 — `public/og-image.svg` (Social Media Card)

**ViewBox:** `0 0 1200 630`
**Contains:** Gradient background + centered logo + tagline
**Use:** Link previews on Twitter, LinkedIn, Facebook, Slack

```
Write the SVG to: public/og-image.svg

Structure:
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 630" role="img" aria-labelledby="og-title">
  <title id="og-title">[PRODUCT_NAME] — [TAGLINE]</title>

  <defs>
    <linearGradient id="og-bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="[brand-900 hex]"/>
      <stop offset="100%" stop-color="[brand-700 hex]"/>
    </linearGradient>
  </defs>

  <!-- Background Gradient -->
  <rect width="1200" height="630" fill="url(#og-bg)"/>

  <!-- Optional: Subtle pattern or decorative shapes -->
  <!-- A few low-opacity geometric shapes for visual interest -->
  <circle cx="1100" cy="100" r="200" fill="[brand-500 hex]" opacity="0.1"/>
  <circle cx="100" cy="530" r="150" fill="[brand-500 hex]" opacity="0.08"/>

  <!-- Icon Mark (centered, larger) -->
  <g transform="translate(540, 180) scale(3)">
    [Icon shapes from logo-icon.svg, scaled 3x]
    [Fill: #F8FAFC (white on dark gradient)]
  </g>

  <!-- Product Name -->
  <text x="600" y="380"
    text-anchor="middle"
    font-family="system-ui, -apple-system, Arial, sans-serif"
    font-size="56"
    font-weight="700"
    letter-spacing="-0.02em"
    fill="#F8FAFC">[PRODUCT_NAME]</text>

  <!-- Tagline -->
  <text x="600" y="430"
    text-anchor="middle"
    font-family="system-ui, -apple-system, Arial, sans-serif"
    font-size="24"
    font-weight="400"
    fill="[brand-200 hex]"
    opacity="0.9">[TAGLINE]</text>

  <!-- Website URL (optional) -->
  <text x="600" y="560"
    text-anchor="middle"
    font-family="system-ui, -apple-system, Arial, sans-serif"
    font-size="16"
    font-weight="500"
    fill="[brand-300 hex]"
    opacity="0.7">[product-website.com]</text>
</svg>

RULES for og-image.svg:
- 1200x630 viewBox (standard Open Graph dimensions)
- Dark gradient background (brand-900 to brand-700) — looks premium
- Icon mark in white (#F8FAFC), scaled up and centered
- Product name in white, large font (56px), centered
- Tagline below name in brand-200, slightly smaller (24px)
- Optional decorative circles with very low opacity (0.08-0.1)
- Keep element count under 15 total
- Total file must be under 5KB
```

### 5i. File 7 — `public/manifest.json` (PWA Manifest)

```
Write the JSON to: public/manifest.json

{
  "name": "[PRODUCT_NAME]",
  "short_name": "[PRODUCT_NAME — shortened if > 12 chars]",
  "description": "[PRODUCT_DESC]",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#FFFFFF",
  "theme_color": "[brand-500 hex]",
  "orientation": "portrait-primary",
  "icons": [
    {
      "src": "/logo-icon.svg",
      "sizes": "any",
      "type": "image/svg+xml",
      "purpose": "any"
    },
    {
      "src": "/apple-touch-icon.svg",
      "sizes": "180x180",
      "type": "image/svg+xml",
      "purpose": "any maskable"
    },
    {
      "src": "/favicon.svg",
      "sizes": "32x32",
      "type": "image/svg+xml"
    }
  ],
  "categories": ["[PRODUCT_DOMAIN]", "productivity"],
  "lang": "en",
  "dir": "ltr"
}

RULES for manifest.json:
- name: full product name
- short_name: 12 chars max (truncate if needed)
- theme_color: brand-500 hex (browser chrome color)
- background_color: #FFFFFF (splash screen bg)
- Reference SVG icons (they scale to any size)
- Include maskable purpose for android adaptive icons
```

### 5j. SVG Quality Checklist

After generating all 7 files, verify each:

```
SVG QUALITY CHECKLIST — verify ALL boxes:
┌──────────────────────────────────────────────────────────────────────────┐
│  □ logo.svg        — viewBox="0 0 200 48", icon+text, dark text        │
│  □ logo-dark.svg   — viewBox="0 0 200 48", icon+text, white text       │
│  □ logo-icon.svg   — viewBox="0 0 48 48", icon only, no text           │
│  □ favicon.svg     — viewBox="0 0 32 32", simplified icon              │
│  □ apple-touch-icon.svg — viewBox="0 0 180 180", icon on brand-50 bg   │
│  □ og-image.svg    — viewBox="0 0 1200 630", gradient+logo+tagline     │
│  □ manifest.json   — valid JSON, theme_color=brand-500                 │
│                                                                          │
│  For EACH SVG verify:                                                   │
│  □ Has role="img" attribute                                             │
│  □ Has <title> element with descriptive text                            │
│  □ Uses system-ui font-family (no custom fonts)                         │
│  □ All colors are hex format (#RRGGBB)                                  │
│  □ Under 15 shape elements                                              │
│  □ Under 5KB file size                                                  │
│  □ No <image>, no external references, no JavaScript                   │
│  □ Valid SVG syntax (proper closing tags)                               │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Section 6: Design Tokens (Tailwind Config)

Generate a Tailwind CSS configuration that encodes all brand decisions as reusable design tokens.

### 6a. Tailwind Color Tokens

```typescript
// Include in BRAND_GUIDE.md — copy to tailwind.config.ts
const config = {
  theme: {
    extend: {
      colors: {
        brand: {
          50:  '[brand-50 hex]',
          100: '[brand-100 hex]',
          200: '[brand-200 hex]',
          300: '[brand-300 hex]',
          400: '[brand-400 hex]',
          500: '[brand-500 hex]',   // PRIMARY
          600: '[brand-600 hex]',
          700: '[brand-700 hex]',
          800: '[brand-800 hex]',
          900: '[brand-900 hex]',
        },
        neutral: {
          50:  '[neutral-50 hex]',
          100: '[neutral-100 hex]',
          200: '[neutral-200 hex]',
          300: '[neutral-300 hex]',
          400: '[neutral-400 hex]',
          500: '[neutral-500 hex]',
          600: '[neutral-600 hex]',
          700: '[neutral-700 hex]',
          800: '[neutral-800 hex]',
          900: '[neutral-900 hex]',
        },
        success: '[success hex]',
        warning: '[warning hex]',
        error:   '[error hex]',
        info:    '[info hex]',
      },
    },
  },
}
```

### 6b. Typography Tokens

```typescript
// Continue in tailwind.config.ts extend
fontFamily: {
  heading: ['[FONT_HEADING]', 'system-ui', '-apple-system', 'sans-serif'],
  body:    ['[FONT_BODY]', 'system-ui', '-apple-system', 'sans-serif'],
  mono:    ['[FONT_MONO]', 'ui-monospace', 'monospace'],
},
fontSize: {
  xs:   ['0.75rem',  { lineHeight: '1rem' }],
  sm:   ['0.875rem', { lineHeight: '1.25rem' }],
  base: ['1rem',     { lineHeight: '1.5rem' }],
  lg:   ['1.125rem', { lineHeight: '1.75rem' }],
  xl:   ['1.25rem',  { lineHeight: '1.75rem' }],
  '2xl': ['1.5rem',  { lineHeight: '2rem' }],
  '3xl': ['1.875rem', { lineHeight: '2.25rem' }],
  '4xl': ['2.25rem', { lineHeight: '2.5rem' }],
  '5xl': ['3rem',    { lineHeight: '1.25' }],
  '6xl': ['3.75rem', { lineHeight: '1.2' }],
},
```

### 6c. Spacing & Layout Tokens

```typescript
// Continue in tailwind.config.ts extend
borderRadius: {
  DEFAULT: '0.5rem',    // 8px — modern rounded look
  sm:      '0.375rem',  // 6px — subtle rounding
  md:      '0.5rem',    // 8px — default
  lg:      '0.75rem',   // 12px — cards, modals
  xl:      '1rem',      // 16px — large cards, hero sections
  '2xl':   '1.5rem',    // 24px — pills, feature cards
  full:    '9999px',    // fully rounded (avatars, badges)
},
boxShadow: {
  'card':     '0 1px 3px rgba(0,0,0,0.1), 0 1px 2px rgba(0,0,0,0.06)',
  'elevated': '0 4px 6px rgba(0,0,0,0.07), 0 2px 4px rgba(0,0,0,0.06)',
  'modal':    '0 20px 60px rgba(0,0,0,0.15), 0 4px 16px rgba(0,0,0,0.1)',
  'glow':     '0 0 20px rgba([brand-500-rgb], 0.3)',
},
```

### 6d. Animation Tokens

```typescript
// Continue in tailwind.config.ts extend
keyframes: {
  'fade-in': {
    '0%':   { opacity: '0', transform: 'translateY(10px)' },
    '100%': { opacity: '1', transform: 'translateY(0)' },
  },
  'slide-in': {
    '0%':   { transform: 'translateX(-100%)' },
    '100%': { transform: 'translateX(0)' },
  },
  'scale-in': {
    '0%':   { opacity: '0', transform: 'scale(0.95)' },
    '100%': { opacity: '1', transform: 'scale(1)' },
  },
},
animation: {
  'fade-in':  'fade-in 0.3s ease-out',
  'slide-in': 'slide-in 0.3s ease-out',
  'scale-in': 'scale-in 0.2s ease-out',
},
```

---

## Section 7: Component Styling Patterns

Define consistent styling patterns for common UI components using brand tokens.

### 7a. Button Styles

```
BUTTON VARIANTS (Tailwind classes):

Primary:    bg-brand-500 hover:bg-brand-600 text-white font-semibold
            rounded-lg px-6 py-2.5 transition-colors duration-200
            focus:ring-2 focus:ring-brand-500 focus:ring-offset-2

Secondary:  bg-brand-50 hover:bg-brand-100 text-brand-700 font-semibold
            rounded-lg px-6 py-2.5 border border-brand-200
            transition-colors duration-200

Ghost:      bg-transparent hover:bg-neutral-100 text-neutral-700 font-medium
            rounded-lg px-6 py-2.5 transition-colors duration-200

Danger:     bg-error hover:bg-red-600 text-white font-semibold
            rounded-lg px-6 py-2.5 transition-colors duration-200

Sizes:
  sm: text-sm px-4 py-1.5 rounded-md
  md: text-base px-6 py-2.5 rounded-lg  (default)
  lg: text-lg px-8 py-3 rounded-lg
```

### 7b. Card Styles

```
CARD VARIANTS:

Default:    bg-white dark:bg-neutral-800 rounded-xl shadow-card
            border border-neutral-200 dark:border-neutral-700 p-6

Elevated:   bg-white dark:bg-neutral-800 rounded-xl shadow-elevated p-6

Interactive: bg-white dark:bg-neutral-800 rounded-xl shadow-card
             border border-neutral-200 dark:border-neutral-700 p-6
             hover:shadow-elevated hover:border-brand-200
             transition-all duration-200 cursor-pointer

Featured:   bg-brand-50 dark:bg-brand-900/20 rounded-xl
             border border-brand-200 dark:border-brand-800 p-6
```

### 7c. Input Styles

```
INPUT STYLES:

Default:    w-full px-4 py-2.5 rounded-lg border border-neutral-300
            dark:border-neutral-600 bg-white dark:bg-neutral-800
            text-neutral-900 dark:text-neutral-100
            placeholder:text-neutral-400
            focus:border-brand-500 focus:ring-2 focus:ring-brand-500/20
            transition-colors duration-200

Error:      ... + border-error focus:border-error focus:ring-error/20

Disabled:   ... + bg-neutral-100 dark:bg-neutral-700 opacity-60 cursor-not-allowed
```

### 7d. Navigation Styles

```
NAV PATTERNS:

Sidebar (SaaS):
  - Width: w-64 (256px)
  - Background: bg-white dark:bg-neutral-900
  - Active item: bg-brand-50 dark:bg-brand-900/20 text-brand-600 font-medium
  - Inactive item: text-neutral-600 hover:bg-neutral-50 dark:hover:bg-neutral-800
  - Border: border-r border-neutral-200 dark:border-neutral-800

Topbar:
  - Height: h-16 (64px)
  - Background: bg-white/80 dark:bg-neutral-900/80 backdrop-blur-lg
  - Sticky: sticky top-0 z-50
  - Border: border-b border-neutral-200 dark:border-neutral-800
```

### 7e. Modal Styles

```
MODAL STYLES:

Backdrop:   fixed inset-0 bg-black/50 backdrop-blur-sm z-50
Content:    bg-white dark:bg-neutral-800 rounded-2xl shadow-modal
            max-w-md w-full mx-4 p-6 animate-scale-in
Header:     text-xl font-semibold text-neutral-900 dark:text-neutral-50
Close:      absolute top-4 right-4 text-neutral-400 hover:text-neutral-600
```

---

## Section 8: Brand Application Guidelines

Define how the brand should be applied across different touchpoints.

### 8a. Landing Page Branding

```
LANDING PAGE RULES:
- Hero: Use hero gradient background (brand-500 → complementary)
- Headlines: font-heading, font-bold, text-5xl/6xl, tracking-tight
- Body: font-body, text-base/lg, text-neutral-600 dark:text-neutral-400
- CTAs: Primary button style (brand-500 bg)
- Social proof: Grayscale logos with hover:grayscale-0
- Feature icons: brand-500 fill, brand-50 background circle
- Pricing cards: Highlight recommended plan with brand-500 border
- Footer: bg-neutral-900, text-neutral-400, brand-400 for links
```

### 8b. Email Template Branding

```
EMAIL BRANDING RULES:
- Header: Brand logo (inline SVG or hosted image)
- Background: #FFFFFF body, #F8FAFC wrapper
- CTA buttons: brand-500 background, white text, rounded
- Footer: Brand address, social links, unsubscribe
- Font: system-ui fallback (email-safe fonts only)
- Links: brand-600 color, underlined
- Do NOT use custom fonts in email (they don't render)
```

### 8c. Documentation Branding

```
DOCUMENTATION RULES:
- Consistent with main product branding
- Code blocks: neutral-900 bg, brand-themed syntax highlighting
- Links: brand-600 color
- Headings: font-heading, brand-700 or neutral-900
- Sidebar: brand-50 active background
- Search: brand-500 focus ring
```

### 8d. Error Pages Branding

```
ERROR PAGE RULES (404, 500, maintenance):
- Use brand illustration or icon (not generic)
- Background: gradient or brand-50
- Heading: brand-700 or neutral-900, friendly tone
- CTA: "Go home" button with primary style
- NEVER show unstyled default error pages
- Include brand logo in header
```

### 8e. Loading States

```
LOADING STATE RULES:
- Spinner/skeleton: brand-200 to brand-100 pulse animation
- Progress bar: brand-500 fill, brand-100 background
- Skeleton: neutral-200 with shimmer animation
- Full page loader: centered brand icon with pulse
```

---

## Section 9: PWA Configuration

Configure Progressive Web App settings using brand identity.

### 9a. HTML Head Tags

Include in BRAND_GUIDE.md for the frontend team:

```html
<!-- Brand Meta Tags — add to app/layout.tsx or index.html -->
<meta name="theme-color" content="[brand-500 hex]" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="[brand-900 hex]" media="(prefers-color-scheme: dark)">
<meta name="msapplication-TileColor" content="[brand-500 hex]">
<meta name="apple-mobile-web-app-status-bar-style" content="default">
<meta name="apple-mobile-web-app-title" content="[PRODUCT_NAME]">

<!-- Favicon & Icons -->
<link rel="icon" type="image/svg+xml" href="/favicon.svg">
<link rel="apple-touch-icon" href="/apple-touch-icon.svg">
<link rel="manifest" href="/manifest.json">

<!-- Open Graph -->
<meta property="og:title" content="[PRODUCT_NAME] — [TAGLINE]">
<meta property="og:description" content="[PRODUCT_DESC]">
<meta property="og:image" content="/og-image.svg">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:type" content="website">

<!-- Twitter Card -->
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="[PRODUCT_NAME] — [TAGLINE]">
<meta name="twitter:description" content="[PRODUCT_DESC]">
<meta name="twitter:image" content="/og-image.svg">

<!-- Google Fonts -->
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="[GOOGLE_FONTS_URL]" rel="stylesheet">
```

### 9b. Next.js Metadata Configuration

```typescript
// Include in BRAND_GUIDE.md — for app/layout.tsx
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: {
    default: '[PRODUCT_NAME] — [TAGLINE]',
    template: '%s | [PRODUCT_NAME]',
  },
  description: '[PRODUCT_DESC]',
  icons: {
    icon: '/favicon.svg',
    apple: '/apple-touch-icon.svg',
  },
  manifest: '/manifest.json',
  openGraph: {
    title: '[PRODUCT_NAME] — [TAGLINE]',
    description: '[PRODUCT_DESC]',
    images: [{ url: '/og-image.svg', width: 1200, height: 630 }],
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: '[PRODUCT_NAME] — [TAGLINE]',
    description: '[PRODUCT_DESC]',
    images: ['/og-image.svg'],
  },
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: '[brand-500 hex]' },
    { media: '(prefers-color-scheme: dark)', color: '[brand-900 hex]' },
  ],
}
```

---

## Section 10: Assemble BRAND_GUIDE.md

Write the complete brand guide document that consolidates all decisions from Sections 1-9.

### 10a. Brand Guide Template

```
Write to: BRAND_GUIDE.md

Use the following 8-section structure (matches auto-build Phase -0.5 template):
```

```markdown
# Brand Guide: [PRODUCT_NAME]

> Generated by `/gen-brand` — Cortex
> Date: [YYYY-MM-DD]

---

## 1. Brand Identity

- **Product Name**: [PRODUCT_NAME]
- **Tagline**: [TAGLINE]
- **Description**: [PRODUCT_DESC]
- **Brand Voice**: [voice from Section 2a]
- **Brand Personality**: [personality adjectives from Section 2a]
- **Target Emotion**: [target_emotion from Section 2a]
- **Brand Archetype**: [ARCHETYPE from Section 2d]
- **Brand Story**: [BRAND_STORY from Section 2c]

---

## 2. Logo & Mark

- **Logo Concept**: [SELECTED_ICON_CONCEPT from Section 5b]
- **Logo Style**: Geometric, modern, minimal — Claude-generated SVG
- **Icon Description**: [describe the icon shapes and what they represent]

### Logo Files

| File | Size | Purpose |
|------|------|---------|
| `public/logo.svg` | 200x48 | Full logo for light backgrounds |
| `public/logo-dark.svg` | 200x48 | Full logo for dark backgrounds |
| `public/logo-icon.svg` | 48x48 | Icon-only mark |
| `public/favicon.svg` | 32x32 | Browser tab icon |
| `public/apple-touch-icon.svg` | 180x180 | iOS home screen |
| `public/og-image.svg` | 1200x630 | Social media card |

### Logo Usage Rules

- Minimum clear space: 1x icon height on all sides
- Minimum size: 24px height for full logo, 16px for icon
- Never distort, rotate, or add effects to the logo
- Always use provided SVG files (never screenshot or rasterize)
- On light backgrounds: use `logo.svg`
- On dark backgrounds: use `logo-dark.svg`
- In small spaces: use `logo-icon.svg` or `favicon.svg`

---

## 3. Color System

### Primary Palette (brand)

[INSERT color table from Section 3g with all 10 brand shades]

### Neutral Palette

[INSERT neutral color table with all 10 neutral shades]

### Semantic Colors

| Name    | Hex       | Light Bg Variant | Usage |
|---------|-----------|-----------------|-------|
| Success | [hex]     | [light hex]     | Positive actions, confirmations |
| Warning | [hex]     | [light hex]     | Warnings, pending states |
| Error   | [hex]     | [light hex]     | Errors, destructive actions |
| Info    | [hex]     | [light hex]     | Informational notices |

### Gradients

| Name     | Value | Usage |
|----------|-------|-------|
| Primary  | [gradient] | Buttons, hero sections |
| Hero     | [gradient] | Landing page hero |
| Subtle   | [gradient] | Section backgrounds |
| Dark     | [gradient] | Dark mode hero sections |

### Dark Mode Mapping

[INSERT dark mode mapping from Section 3e]

---

## 4. Typography

### Font Stack

| Role     | Font          | Fallback            | Weight |
|----------|---------------|---------------------|--------|
| Heading  | [FONT_HEADING] | system-ui, sans-serif | 600-700 |
| Body     | [FONT_BODY]    | system-ui, sans-serif | 400-500 |
| Mono     | [FONT_MONO]    | ui-monospace, monospace | 400-500 |

### Google Fonts URL

```
[GOOGLE_FONTS_URL]
```

### Type Scale

[INSERT type scale from Section 4b]

### Font Weights

[INSERT font weights from Section 4c]

### Line Heights

[INSERT line heights from Section 4d]

---

## 5. Design Tokens (Tailwind Config)

```typescript
// tailwind.config.ts — extend with these brand tokens
[INSERT complete Tailwind config from Section 6a-6d]
```

---

## 6. Component Styling Standards

### Buttons
[INSERT button styles from Section 7a]

### Cards
[INSERT card styles from Section 7b]

### Inputs
[INSERT input styles from Section 7c]

### Navigation
[INSERT nav styles from Section 7d]

### Modals
[INSERT modal styles from Section 7e]

---

## 7. Brand Application

### Landing Page
[INSERT landing page rules from Section 8a]

### Email Templates
[INSERT email rules from Section 8b]

### Documentation
[INSERT docs rules from Section 8c]

### Error Pages
[INSERT error page rules from Section 8d]

### Loading States
[INSERT loading state rules from Section 8e]

---

## 8. Branding Files Generated

```
public/
├── logo.svg              # Full logo (icon + wordmark) — light bg
├── logo-dark.svg         # Full logo — dark bg
├── logo-icon.svg         # Icon-only mark
├── favicon.svg           # Browser tab icon (32x32)
├── apple-touch-icon.svg  # iOS home screen (180x180)
├── og-image.svg          # Social media card (1200x630)
└── manifest.json         # PWA manifest with brand colors
```

### HTML Head Tags
[INSERT head tags from Section 9a]

### Next.js Metadata
[INSERT Next.js metadata from Section 9b]
```

### 10b. Assembly Rules

```
ASSEMBLY RULES:
- Replace ALL [placeholders] with actual values from earlier sections
- Include actual hex color codes (not placeholder #______)
- Include actual font names (not [FONT_HEADING])
- Include actual Tailwind classes (not references to sections)
- The BRAND_GUIDE.md should be a COMPLETE, self-contained reference
- A developer should be able to implement the brand from this file ALONE
- No section should say "see Section X" — inline everything
```

---

## Section 11: Branding Consistency Rules

### 11a. Do's

```
BRANDING DO'S:
┌──────────────────────────────────────────────────────────────────────────┐
│  ✅ Create BRAND_GUIDE.md BEFORE any frontend code                      │
│  ✅ Use brand-500 as the primary action color everywhere                │
│  ✅ Define color system with BOTH light + dark mode variants            │
│  ✅ Choose typography that matches brand personality                     │
│  ✅ Configure Tailwind with brand design tokens                         │
│  ✅ Apply brand colors on ALL touchpoints (web, email, docs, OG)       │
│  ✅ Generate favicon and OG images with brand identity                  │
│  ✅ Email templates use brand header/footer/colors                      │
│  ✅ Error pages, 404, loading screens — all branded                     │
│  ✅ Consistent border-radius, shadows, spacing across ALL components   │
│  ✅ PWA manifest with brand name and theme_color                        │
│  ✅ Use logo.svg on light bg, logo-dark.svg on dark bg                 │
│  ✅ Test brand colors for WCAG AA contrast compliance                   │
│  ✅ Keep SVG logos under 5KB each                                       │
│  ✅ Use system fonts in SVG (no custom font dependencies)              │
└──────────────────────────────────────────────────────────────────────────┘
```

### 11b. Don'ts

```
BRANDING DON'TS:
┌──────────────────────────────────────────────────────────────────────────┐
│  ❌ NEVER use default Tailwind blue as primary (customize it)           │
│  ❌ NEVER mix brand inconsistencies (different shades across pages)    │
│  ❌ NEVER ship without favicon and OG images                            │
│  ❌ NEVER use unstyled default error pages (brand them)                 │
│  ❌ NEVER use different fonts across pages (stick to brand typography)  │
│  ❌ NEVER skip dark mode in brand system (it's mandatory)              │
│  ❌ NEVER send emails without brand header/footer                       │
│  ❌ NEVER use logo on backgrounds that clash with icon color           │
│  ❌ NEVER scale logo non-proportionally (always maintain aspect ratio) │
│  ❌ NEVER add effects (drop shadow, glow, outline) to the logo        │
│  ❌ NEVER embed raster images in SVG logos                              │
│  ❌ NEVER use rgb() or named colors in SVG — hex only                  │
│  ❌ NEVER put custom fonts inside SVG files                             │
│  ❌ NEVER exceed 15 shape elements per SVG logo                        │
│  ❌ NEVER skip <title> accessibility in SVG files                      │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Section 12: Verification & Output Summary

### 12a. File Existence Check

After generating all files, verify they exist:

```bash
# Verify all brand files were created
ls -la BRAND_GUIDE.md public/logo.svg public/logo-dark.svg public/logo-icon.svg \
       public/favicon.svg public/apple-touch-icon.svg public/og-image.svg public/manifest.json
```

### 12b. SVG Validation

For each SVG file, verify:
```bash
# Check file sizes (should all be under 5KB)
wc -c public/logo.svg public/logo-dark.svg public/logo-icon.svg \
      public/favicon.svg public/apple-touch-icon.svg public/og-image.svg

# Check for required attributes
grep -l 'role="img"' public/*.svg
grep -l '<title>' public/*.svg
```

### 12c. Output Summary

Display the final summary to the user:

```
┌──────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│  ✅ BRAND IDENTITY GENERATED SUCCESSFULLY                               │
│                                                                          │
│  Product:  [PRODUCT_NAME]                                               │
│  Tagline:  [TAGLINE]                                                    │
│  Primary:  [brand-500 hex] ████ [color block]                          │
│  Font:     [FONT_HEADING] / [FONT_BODY]                                │
│  Style:    [BRAND_MOOD] / [ARCHETYPE]                                  │
│                                                                          │
│  Files Created:                                                          │
│  ├── BRAND_GUIDE.md              ← Complete brand reference             │
│  ├── public/logo.svg             ← Full logo (light bg)                │
│  ├── public/logo-dark.svg        ← Full logo (dark bg)                 │
│  ├── public/logo-icon.svg        ← Icon-only mark                     │
│  ├── public/favicon.svg          ← Browser tab icon                    │
│  ├── public/apple-touch-icon.svg ← iOS home screen                    │
│  ├── public/og-image.svg         ← Social media card                  │
│  └── public/manifest.json        ← PWA manifest                       │
│                                                                          │
│  Next Steps:                                                            │
│  1. Review BRAND_GUIDE.md and adjust colors/fonts if needed            │
│  2. Copy Tailwind config from Section 5 to tailwind.config.ts          │
│  3. Add HTML head tags from Section 8 to app/layout.tsx                │
│  4. Preview SVG files in browser to verify appearance                   │
│                                                                          │
│  Tip: Run /auto-build to build the full product with this branding     │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

### 12d. Error Recovery

If any file fails to generate:
```
1. Check if public/ directory exists — create it if missing: mkdir -p public
2. Retry the specific file that failed
3. If SVG syntax is invalid, simplify the icon (use fewer shapes)
4. If file is over 5KB, reduce decorative elements in og-image.svg
5. Verify all hex colors are valid 6-character codes
```

---

## Integration with Auto-Build

This command generates the same brand deliverables as Phase -0.5 of `/auto-build`. The two are interchangeable:

```
INTEGRATION RULES:
- If BRAND_GUIDE.md already exists (from /gen-brand), /auto-build Phase -0.5
  should READ it and SKIP regenerating — use what's already there
- If running /gen-brand AFTER /auto-build created a BRAND_GUIDE.md,
  /gen-brand will OVERWRITE it with a more comprehensive version
- The SVG logo files generated here are the SAME files referenced in
  auto-build Phase 9 (Frontend) and Phase 13 (Documentation)
```

### Spawning Brand Designer Agent

For parallel execution during auto-build, spawn the brand-designer agent:

```
Task: "Generate complete brand identity for [PRODUCT_NAME]. Product description: [PRODUCT_DESC].
       Domain: [PRODUCT_DOMAIN]. Follow the gen-brand command instructions."
Agent: brand-designer
```

The brand-designer agent knows all the rules from this command and can execute independently.
