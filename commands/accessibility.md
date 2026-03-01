---
description: "Audit frontend for WCAG 2.1 AA compliance: check semantic HTML, ARIA labels, color contrast, keyboard navigation, screen reader support. Usage: /accessibility [page-or-component] [--fix] [--level=AA|AAA]"
---

# Accessibility Audit — WCAG 2.1 Compliance

You are a senior accessibility engineer performing a thorough WCAG 2.1 audit of this frontend codebase. You have deep expertise in assistive technologies, screen readers, keyboard navigation, and inclusive design patterns.

**Arguments**: $ARGUMENTS

Parse flags from arguments:
- `--fix` = Auto-fix common accessibility issues that can be safely remediated
- `--level=AA` = Audit against WCAG 2.1 AA criteria (default)
- `--level=AAA` = Audit against WCAG 2.1 AAA criteria (stricter)
- A specific page or component name = Scope the audit to that file or directory only
- No arguments = Scan the entire frontend codebase

---

## Step 0: Project Discovery and Scope

Before auditing, understand the frontend architecture and determine the scope.

```bash
echo "=== Project Root ==="
pwd

echo "=== Frontend Framework Detection ==="
cat package.json 2>/dev/null | grep -E "(next|react|vue|angular|svelte|astro)" | head -10

echo "=== App Directory (Next.js) ==="
find . -maxdepth 1 -type d \( -name "app" -o -name "src" -o -name "pages" \) 2>/dev/null

echo "=== Components Directory ==="
find . -maxdepth 3 -type d -name "components" 2>/dev/null

echo "=== Style Files ==="
find . -maxdepth 4 -type f \( -name "*.css" -o -name "*.scss" -o -name "*.module.css" -o -name "tailwind.config.*" \) -not -path "*/node_modules/*" -not -path "*/.next/*" 2>/dev/null

echo "=== Total Frontend Files ==="
find . -maxdepth 6 -type f \( -name "*.tsx" -o -name "*.jsx" -o -name "*.vue" -o -name "*.svelte" -o -name "*.html" \) -not -path "*/node_modules/*" -not -path "*/.next/*" 2>/dev/null | wc -l
```

Use the output to determine:
- Which framework is in use (Next.js, React, Vue, etc.)
- Where pages and components live
- Whether Tailwind CSS or traditional CSS is used
- Total number of files to audit

If `$ARGUMENTS` specifies a page or component, narrow the scope to only those files. Otherwise, audit the entire frontend.

Initialize an accessibility findings tracker. Track every finding as:
```
{
  severity: "CRITICAL|MAJOR|MINOR|INFO",
  wcag_criterion: "X.X.X",
  criterion_name: "...",
  category: "Perceivable|Operable|Understandable|Robust",
  file: "...",
  line: N,
  description: "...",
  code_snippet: "...",
  remediation: "..."
}
```

---

## Step 1: Scan Frontend Code

Use Glob and Grep to build an inventory of all interactive and content elements across the codebase.

### 1A: Find All Pages

```bash
# Next.js App Router pages
find . -path "*/app/**/page.tsx" -o -path "*/app/**/page.jsx" -o -path "*/app/**/page.js" 2>/dev/null | grep -v node_modules

# Next.js Pages Router
find . -path "*/pages/**/*.tsx" -o -path "*/pages/**/*.jsx" 2>/dev/null | grep -v node_modules

# Layout files (important for skip nav, lang attribute, meta)
find . -path "*/app/**/layout.tsx" -o -path "*/app/**/layout.jsx" 2>/dev/null | grep -v node_modules
```

### 1B: Find All Components

Use Glob to find all component files:
- `**/components/**/*.tsx`
- `**/components/**/*.jsx`
- `**/ui/**/*.tsx`

### 1C: Identify Interactive Elements

Use Grep to catalog all interactive elements across the codebase:

**Forms:**
```
Pattern: <form[\s>]
Pattern: <input[\s>]
Pattern: <select[\s>]
Pattern: <textarea[\s>]
Pattern: <button[\s>]
```

**Links and Navigation:**
```
Pattern: <a[\s>]
Pattern: <Link[\s>]
Pattern: <nav[\s>]
```

**Media:**
```
Pattern: <img[\s>]
Pattern: <video[\s>]
Pattern: <audio[\s>]
Pattern: <svg[\s>]
Pattern: <canvas[\s>]
Pattern: <iframe[\s>]
```

**Dynamic UI:**
```
Pattern: <dialog[\s>]
Pattern: <details[\s>]
Pattern: role="dialog"
Pattern: role="alert"
Pattern: role="tablist"
Pattern: role="menu"
Pattern: aria-modal
```

**Tables:**
```
Pattern: <table[\s>]
Pattern: <th[\s>]
Pattern: <td[\s>]
```

Record the count of each element type. This inventory determines which WCAG criteria are applicable.

### 1D: Find All Style Files

Use Glob to find:
- `**/*.css`
- `**/*.scss`
- `**/*.module.css`
- `**/tailwind.config.*`
- `**/globals.css`

---

## Step 2: WCAG 2.1 Checklist Audit

Use Agent tool (mode = "bypassPermissions") to run four parallel audit agents, one for each WCAG principle. Each agent uses Grep and Read to check the codebase against the specific success criteria.

### Agent 1: Perceivable (Guideline 1.x)

Audit all criteria under the Perceivable principle.

#### 1.1.1 Non-text Content (Level A)

Every `<img>` element MUST have an `alt` attribute. Decorative images must use `alt=""`.

**Check for missing alt attributes:**
```
Pattern: <img(?![^>]*alt=)[^>]*>
```

**Check for empty alt on non-decorative images (potential false negative):**
```
Pattern: <img[^>]*alt=""[^>]*>
```

Read 3-5 lines of context around each match to determine if the image is decorative (icon, background) or informative (content image, chart, photo). Decorative images with `alt=""` are correct. Informative images with `alt=""` are a violation.

**Check for SVG accessibility:**
```
Pattern: <svg(?![^>]*(role="img"|aria-label|aria-labelledby|aria-hidden))[^>]*>
```

SVGs used as images must have `role="img"` plus `aria-label` or `<title>`. Decorative SVGs must have `aria-hidden="true"`.

**Check for background images conveying information:**
```
Pattern: background-image:\s*url\(
Pattern: bg-\[url\(
```

If background images convey information, they need text alternatives.

**Severity:** CRITICAL if informative images lack alt text. MINOR if decorative images lack `alt=""`.

#### 1.2.1 Audio-only and Video-only (Level A)

**Check for media elements:**
```
Pattern: <video[\s>]
Pattern: <audio[\s>]
Pattern: <iframe[^>]*(?:youtube|vimeo|wistia|loom)
```

If media elements exist, verify:
- `<track kind="captions">` for video
- `<track kind="descriptions">` for audio descriptions
- Transcript links near media players

**Severity:** CRITICAL if video lacks captions. MAJOR if audio-only content lacks transcript.

#### 1.3.1 Info and Relationships (Level A)

**Check heading hierarchy:**
```bash
# Extract all headings from all pages/components
grep -rn "<h[1-6]" --include="*.tsx" --include="*.jsx" --include="*.html" . | grep -v node_modules
```

Verify:
- Each page has exactly one `<h1>`
- Headings follow sequential order (h1 > h2 > h3, no skipping h2 to jump to h3)
- Headings are not used purely for styling (should use CSS instead)

**Check for semantic HTML usage:**
```
Pattern: <div[^>]*onClick
Pattern: <span[^>]*onClick
```

Non-interactive elements with click handlers must have `role="button"`, `tabIndex={0}`, and keyboard event handlers (`onKeyDown`/`onKeyPress`).

**Check for proper list usage:**
```
Pattern: <ul[\s>]
Pattern: <ol[\s>]
Pattern: <li[\s>]
Pattern: <dl[\s>]
```

Navigation items, menus, and grouped content should use semantic list elements.

**Check for data table structure:**
```
Pattern: <table[\s>]
Pattern: <thead[\s>]
Pattern: <th[\s>]
Pattern: <caption[\s>]
```

Data tables must have `<thead>`, `<th>` with `scope` attributes, and `<caption>` elements.

**Severity:** MAJOR for broken heading hierarchy. CRITICAL for clickable divs/spans without ARIA roles.

#### 1.3.2 Meaningful Sequence (Level A)

Read the DOM order of key page layouts. Verify that the reading order in the HTML matches the visual presentation order. Common violations:
- CSS `order` property reordering elements
- `flex-direction: row-reverse` or `column-reverse`
- Absolute/fixed positioning creating a different visual order than DOM order

```
Pattern: order:\s*-?\d+
Pattern: flex-direction:\s*(?:row|column)-reverse
```

**Severity:** MAJOR if DOM order differs significantly from visual order.

#### 1.4.1 Use of Color (Level A)

Search for patterns where color is the sole indicator of meaning:

**Check for color-only error states:**
```
Pattern: (?:text|border|bg)-red(?!.*(?:icon|error|warning|alert|message|text))
Pattern: (?:text|border|bg)-green(?!.*(?:icon|check|success|text))
```

Read form components and verify that error states include text messages or icons, not just red borders or text color.

**Check for color-only status indicators:**
```
Pattern: (?:bg|text)-(?:red|green|yellow|orange)-\d+
```

Review status badges, tags, and indicators to ensure they include text labels or icons alongside color.

**Severity:** MAJOR if information is conveyed by color alone.

#### 1.4.3 Contrast Minimum (Level AA)

This requires checking color values. Extract all text color + background color combinations.

**Check for potentially low-contrast Tailwind classes:**
```
Pattern: text-gray-[234]00
Pattern: text-slate-[234]00
Pattern: text-zinc-[234]00
Pattern: text-neutral-[234]00
Pattern: text-stone-[234]00
```

Light gray text on white backgrounds commonly fails contrast. Check context to see background colors.

**Check for explicit color values:**
```
Pattern: color:\s*#[0-9a-fA-F]{3,8}
Pattern: color:\s*rgb
Pattern: color:\s*hsl
Pattern: background(?:-color)?:\s*#[0-9a-fA-F]{3,8}
```

For Level AA:
- Normal text (< 18pt or < 14pt bold): contrast ratio must be >= 4.5:1
- Large text (>= 18pt or >= 14pt bold): contrast ratio must be >= 3:1

For Level AAA (if --level=AAA):
- Normal text: >= 7:1
- Large text: >= 4.5:1

**Check for placeholder text contrast:**
```
Pattern: placeholder:text-
Pattern: ::placeholder
Pattern: placeholder-
```

Placeholder text often has insufficient contrast.

**Severity:** MAJOR for text that fails the minimum contrast ratio. MINOR for placeholder text contrast issues.

#### 1.4.4 Resize Text (Level AA)

**Check for fixed font sizes:**
```
Pattern: font-size:\s*\d+px
Pattern: line-height:\s*\d+px
```

Font sizes should use `rem` or `em` units, not `px`, so they scale with user preferences.

**Check Tailwind for responsive text:**
```
Pattern: text-\[[\d.]+px\]
```

Custom pixel-based Tailwind text sizes prevent proper scaling.

**Check for viewport-unit-only font sizes:**
```
Pattern: font-size:\s*[\d.]+vw(?![^;]*clamp)
```

Font sizes using only `vw` units without `clamp()` or minimum sizes can become unreadably small.

**Severity:** MINOR for fixed pixel font sizes (may scale via browser zoom). MAJOR if text is completely unscalable.

#### 1.4.11 Non-text Contrast (Level AA)

**Check for focus, border, and UI component colors:**
```
Pattern: border-gray-[12]00
Pattern: border-slate-[12]00
Pattern: outline-gray-[12]00
Pattern: ring-gray-[12]00
```

UI components (buttons, inputs, toggles) and their states (focus, hover, active) must have at least 3:1 contrast ratio against adjacent colors.

**Check for custom checkboxes/radios/toggles:**
```
Pattern: type="checkbox"
Pattern: type="radio"
Pattern: role="switch"
Pattern: role="slider"
```

Read the styling of these components to verify the active/inactive states are distinguishable at 3:1 contrast.

**Severity:** MAJOR for form controls that fail non-text contrast requirements.

---

### Agent 2: Operable (Guideline 2.x)

Audit all criteria under the Operable principle.

#### 2.1.1 Keyboard (Level A)

**Check for mouse-only event handlers:**
```
Pattern: onMouseDown(?![^}]*onKeyDown)
Pattern: onMouseUp(?![^}]*onKeyUp)
Pattern: onMouseEnter(?![^}]*onFocus)
Pattern: onMouseLeave(?![^}]*onBlur)
Pattern: onClick(?![^}]*onKeyDown|onKeyPress|onKeyUp)
```

Read context around each match. If the element is a native interactive element (`<button>`, `<a>`, `<input>`), `onClick` alone is acceptable because browsers handle keyboard events natively. If it is a `<div>`, `<span>`, or other non-interactive element, it MUST also have keyboard handlers.

**Check for non-interactive elements used as buttons:**
```
Pattern: <div[^>]*onClick
Pattern: <span[^>]*onClick
Pattern: <li[^>]*onClick
Pattern: <td[^>]*onClick
Pattern: <tr[^>]*onClick
```

Each of these MUST have:
- `role="button"` (or appropriate role)
- `tabIndex={0}` (or `tabIndex="0"`)
- `onKeyDown` or `onKeyPress` handler

**Severity:** CRITICAL for interactive elements not reachable by keyboard. MAJOR for click handlers on non-interactive elements without keyboard support.

#### 2.1.2 No Keyboard Trap (Level A)

**Check for modal/dialog implementations:**
```
Pattern: role="dialog"
Pattern: aria-modal="true"
Pattern: <dialog[\s>]
Pattern: (?:Modal|Dialog|Drawer|Sheet|Popover|Dropdown)
```

Read modal components and verify:
- Focus is trapped inside the modal when open (focus trap)
- Pressing `Escape` closes the modal
- Focus returns to the trigger element on close
- Tab order cycles within the modal

**Check for focus trap libraries:**
```
Pattern: focus-trap
Pattern: FocusTrap
Pattern: useFocusTrap
Pattern: createFocusTrap
```

If modals exist without focus trap management, that is a violation.

**Severity:** CRITICAL for keyboard traps (cannot escape a component). MAJOR for modals without proper focus management.

#### 2.4.1 Bypass Blocks (Level A)

**Check for skip navigation link:**
```
Pattern: skip.*(?:nav|content|main)
Pattern: (?:skip|jump).*(?:to|navigation|content)
Pattern: #main-content
Pattern: #content
Pattern: skipToContent
Pattern: SkipLink
Pattern: SkipNav
```

Read the root layout file to verify a skip navigation link exists as the first focusable element. It should:
- Be the first item in the tab order
- Be visible on focus (can be visually hidden until focused)
- Link to the main content area (`#main-content` or `<main>`)

**Check that main content has an ID target:**
```
Pattern: <main[^>]*id=
Pattern: id="main-content"
Pattern: id="content"
```

**Severity:** MAJOR if no skip navigation link exists. MINOR if it exists but is not the first focusable element.

#### 2.4.2 Page Titled (Level A)

**Check for page titles in Next.js:**
```
Pattern: <title>
Pattern: metadata.*title
Pattern: export\s+(?:const|function)\s+(?:metadata|generateMetadata)
Pattern: <Head>[\s\S]*<title>
```

Read each page file and verify:
- Every page has a unique, descriptive `<title>`
- Titles follow a consistent pattern (e.g., "Page Name | App Name")
- Dynamic pages have dynamic titles (not hardcoded generic titles)

**Severity:** MAJOR if pages lack titles. MINOR if titles are not descriptive.

#### 2.4.3 Focus Order (Level A)

**Check for positive tabIndex values (anti-pattern):**
```
Pattern: tabIndex=\{[1-9]
Pattern: tabindex="[1-9]
Pattern: tabIndex=[1-9]
```

Positive `tabIndex` values greater than 0 override natural tab order and create unpredictable navigation. Only `tabIndex={0}` (add to tab order) and `tabIndex={-1}` (programmatic focus only) are acceptable.

**Check for CSS that might affect visual order vs DOM order:**
```
Pattern: order:\s*-?\d+
Pattern: flex-direction:\s*(?:row|column)-reverse
Pattern: direction:\s*rtl
```

**Severity:** MAJOR for positive tabIndex values. MINOR for CSS reordering without DOM adjustment.

#### 2.4.4 Link Purpose (Level A)

**Check for non-descriptive link text:**
```
Pattern: >click here<
Pattern: >here<
Pattern: >read more<
Pattern: >learn more<
Pattern: >more<
Pattern: >link<
Pattern: >\s*<\/a
```

Links must have descriptive text that makes sense out of context. If generic text is necessary, it must be supplemented with `aria-label` or `aria-describedby`.

**Check for links with only an icon (no text):**
```
Pattern: <a[^>]*>[^<]*<(?:svg|img|i|span[^>]*class="[^"]*icon)[^<]*<\/a>
Pattern: <Link[^>]*>[^<]*<(?:svg|img|Icon)
```

Icon-only links MUST have `aria-label` describing the link purpose.

**Severity:** MAJOR for links with no accessible name. MINOR for generic "click here" / "read more" text.

#### 2.4.7 Focus Visible (Level AA)

**Check for focus outline removal:**
```
Pattern: outline:\s*(?:none|0)
Pattern: outline-none(?![^{]*ring)
Pattern: \*:focus\s*\{[^}]*outline:\s*(?:none|0)
Pattern: focus:outline-none(?![^"]*focus:ring)
```

If `outline: none` or `outline-none` is used, there MUST be a replacement focus indicator (e.g., `ring`, `border`, `box-shadow`, custom focus styles).

**Check for focus-visible utilities:**
```
Pattern: focus-visible:
Pattern: :focus-visible
Pattern: focus:ring
Pattern: focus:border
Pattern: focus:shadow
```

**Check global styles for focus reset:**
Read `globals.css`, `base.css`, or equivalent to see if focus styles are globally removed without replacement.

**Severity:** CRITICAL if focus indicators are removed with no replacement. MAJOR if custom focus styles are inconsistent across the app.

---

### Agent 3: Understandable (Guideline 3.x)

Audit all criteria under the Understandable principle.

#### 3.1.1 Language of Page (Level A)

**Check for lang attribute on html element:**
```
Pattern: <html[^>]*lang=
Pattern: <Html[^>]*lang=
```

Read the root layout file (`app/layout.tsx` or `pages/_document.tsx`) and verify:
- `<html>` has a `lang` attribute
- The language code is valid (e.g., `"en"`, `"es"`, `"fr"`, not empty)

**Severity:** CRITICAL if `<html>` has no `lang` attribute. It is the single most important accessibility attribute for screen readers.

#### 3.1.2 Language of Parts (Level AA)

**Check for multilingual content:**
```
Pattern: lang="(?!en)[a-z]{2}"
Pattern: hreflang=
```

If the app serves content in multiple languages, verify that content blocks in a different language than the page default have `lang` attributes on their container elements.

**Severity:** MINOR for missing lang on foreign-language content blocks.

#### 3.2.1 On Focus (Level A)

**Check for auto-submission or navigation on focus:**
```
Pattern: onFocus[^=]*=.*(?:submit|navigate|push|replace|redirect|window\.location)
Pattern: autoFocus.*(?:submit|fetch|navigate)
```

Focus events must not trigger unexpected context changes (form submissions, navigation, opening new windows).

**Severity:** MAJOR if focus triggers unexpected navigation or submissions.

#### 3.2.2 On Input (Level A)

**Check for auto-submission on input change:**
```
Pattern: onChange[^=]*=.*(?:submit|navigate|push|replace|redirect)
```

Changing the value of a form control (select, checkbox, radio) must not automatically trigger a context change unless the user has been advised.

**Severity:** MAJOR if select dropdowns or checkboxes trigger navigation without warning.

#### 3.3.1 Error Identification (Level A)

**Check for form validation error handling:**
```
Pattern: error[Mm]essage
Pattern: (?:error|invalid|validation).*(?:text|message|msg)
Pattern: aria-invalid
Pattern: aria-errormessage
Pattern: aria-describedby.*error
Pattern: role="alert"
```

Read form components and verify:
- Form errors are described in text (not just color)
- Error messages identify the field with the error
- `aria-invalid="true"` is set on invalid fields
- Error messages are associated via `aria-describedby` or `aria-errormessage`

**Severity:** MAJOR if form errors are not programmatically associated with their fields. MINOR if error text is present but not linked via ARIA.

#### 3.3.2 Labels or Instructions (Level A)

**Check for inputs without labels:**
```
Pattern: <input(?![^>]*(?:aria-label|aria-labelledby|id="[^"]*"))[^>]*>
Pattern: <select(?![^>]*(?:aria-label|aria-labelledby))[^>]*>
Pattern: <textarea(?![^>]*(?:aria-label|aria-labelledby))[^>]*>
```

**Check for label elements without htmlFor:**
```
Pattern: <label(?![^>]*(?:htmlFor|for))[^>]*>
Pattern: <Label(?![^>]*(?:htmlFor|for))[^>]*>
```

Every form input MUST have either:
- A visible `<label>` with matching `htmlFor`/`for` attribute
- An `aria-label` attribute
- An `aria-labelledby` pointing to a visible element

**Check for placeholder-only labels:**
```
Pattern: placeholder="[^"]*"(?![^>]*(?:aria-label|<label))
```

Placeholder text is NOT a substitute for a label. It disappears on input and is not reliably announced by screen readers.

**Severity:** CRITICAL for inputs without any accessible label. MAJOR for placeholder-only labels.

#### 3.3.3 Error Suggestion (Level AA)

Read form validation logic and verify that error messages provide constructive guidance:
- "Email is required" (not just "Error")
- "Password must be at least 8 characters" (not just "Invalid password")
- "Please enter a valid phone number (e.g., +1 555-123-4567)"

**Check for generic error messages:**
```
Pattern: "(?:Error|Invalid|Required)"(?!\s*[+,])
Pattern: "Something went wrong"
Pattern: "An error occurred"
```

**Severity:** MINOR if error messages exist but are not helpful. MAJOR if no error messages are displayed.

---

### Agent 4: Robust (Guideline 4.x)

Audit all criteria under the Robust principle.

#### 4.1.1 Parsing (Level A)

**Check for duplicate IDs:**
```bash
# Extract all id attributes and find duplicates
grep -roh 'id="[^"]*"' --include="*.tsx" --include="*.jsx" --include="*.html" . 2>/dev/null | grep -v node_modules | sort | uniq -d
```

Duplicate IDs break ARIA relationships and label associations.

**Check for valid HTML nesting:**
```
Pattern: <p[^>]*>[\s\S]*<(?:div|section|article|header|footer|nav|aside|main|h[1-6])
Pattern: <a[^>]*>[\s\S]*<a[\s>]
Pattern: <button[^>]*>[\s\S]*<button[\s>]
```

Interactive elements must not be nested inside each other (e.g., button inside a link).

**Severity:** MAJOR for duplicate IDs that break ARIA. MINOR for invalid nesting that may cause parser issues.

#### 4.1.2 Name, Role, Value (Level A)

**Check for custom interactive components without ARIA:**
```
Pattern: (?:Accordion|Tab|Tabs|TabPanel|Tooltip|Popover|Dropdown|Menu|MenuItem|TreeView|Carousel|Slider|ProgressBar|Rating)(?![^}]*(?:role=|aria-))
```

Custom widgets MUST expose:
- **Name**: via `aria-label`, `aria-labelledby`, or visible text content
- **Role**: via `role` attribute or native HTML element
- **Value**: via `aria-valuenow`, `aria-checked`, `aria-selected`, `aria-expanded`, etc.

**Check for toggle/accordion patterns:**
```
Pattern: aria-expanded
Pattern: aria-controls
Pattern: aria-selected
Pattern: aria-checked
Pattern: aria-pressed
```

Read expandable/collapsible components and verify `aria-expanded` toggles between `"true"` and `"false"`.

**Check for custom select/combobox:**
```
Pattern: role="combobox"
Pattern: role="listbox"
Pattern: role="option"
Pattern: aria-activedescendant
```

Custom dropdowns MUST implement the combobox or listbox pattern with proper ARIA attributes.

**Severity:** CRITICAL for custom interactive components with no ARIA. MAJOR for incomplete ARIA implementation.

#### 4.1.3 Status Messages (Level AA)

**Check for dynamic content announcements:**
```
Pattern: aria-live
Pattern: role="status"
Pattern: role="alert"
Pattern: role="log"
Pattern: role="timer"
Pattern: aria-atomic
```

Dynamic content updates (toast notifications, loading indicators, form submission results, live data) MUST be announced to screen readers via live regions.

**Check for toast/notification components:**
```
Pattern: (?:Toast|Notification|Snackbar|Alert|Banner|Flash)
Pattern: useToast
Pattern: toast\(
```

Read toast/notification implementations to verify they use `role="alert"` or `aria-live="assertive"` for important messages, and `role="status"` or `aria-live="polite"` for informational updates.

**Check for loading states:**
```
Pattern: (?:loading|isLoading|isPending|isFetching)
Pattern: <Spinner
Pattern: <Skeleton
Pattern: aria-busy
```

Loading states should set `aria-busy="true"` on the updating region and announce completion.

**Severity:** MAJOR for toast notifications not announced to screen readers. MINOR for loading states without aria-busy.

---

## Step 3: Code-Level Pattern Checks

Run these additional automated checks using Grep across the entire frontend codebase. These catch common accessibility anti-patterns that may not be covered by the WCAG criterion-by-criterion audit.

### 3A: Images Without Alt Text

```
Pattern: <img(?![^>]*alt)[^>]*\/?>
```

Exclude: `node_modules`, `.next`, `dist`, `build` directories.

For each match, read context to determine if the image is decorative or informative.

### 3B: Buttons Without Accessible Names

```
Pattern: <button[^>]*>\s*<(?:svg|img|i|span[^>]*icon)[^<]*\s*<\/button>
Pattern: <IconButton(?![^>]*aria-label)
Pattern: <Button(?![^>]*(?:aria-label|>[^<]+<))
```

Icon-only buttons MUST have `aria-label` describing the action.

### 3C: Inputs Without Labels

```
Pattern: <input(?![^>]*(?:type="(?:hidden|submit|button|reset)"))[^>]*(?<!aria-label[^>])(?<!aria-labelledby[^>])\/?>
```

Verify each input has an associated `<label>` (via `htmlFor`), `aria-label`, or `aria-labelledby`.

### 3D: Links Without Meaningful Text

```
Pattern: <a[^>]*>\s*<\/a>
Pattern: <a[^>]*>\s*<img[^>]*>\s*<\/a>
Pattern: <Link[^>]*>\s*<\/Link>
```

Empty links or links with only an image (and no alt text on the image or aria-label on the link) have no accessible name.

### 3E: Click Handlers on Non-Interactive Elements

```
Pattern: <div[^>]*onClick(?![^>]*(?:role=|tabIndex))
Pattern: <span[^>]*onClick(?![^>]*(?:role=|tabIndex))
Pattern: <li[^>]*onClick(?![^>]*(?:role=|tabIndex))
Pattern: <tr[^>]*onClick(?![^>]*(?:role=|tabIndex))
```

Non-interactive elements with click handlers MUST have `role`, `tabIndex`, and keyboard event handlers.

### 3F: Missing aria-live on Dynamic Content

```
Pattern: (?:setState|dispatch|mutate|refetch)\([^)]*\)(?![\s\S]{0,500}aria-live)
```

This is a heuristic check. Review dynamic content regions to ensure screen readers are notified of updates.

### 3G: Fixed Font Sizes

```
Pattern: font-size:\s*\d+px
Pattern: text-\[\d+px\]
```

Prefer `rem`, `em`, or Tailwind's built-in text size classes which use rem.

### 3H: Focus Style Removal Without Replacement

```
Pattern: outline:\s*(?:none|0)\s*;(?![^}]*(?:box-shadow|border|ring|outline-offset))
Pattern: outline-none(?![^"]*(?:ring|border|shadow))
```

Removing focus indicators without providing an alternative makes keyboard navigation impossible.

### 3I: Missing Heading Hierarchy

```bash
# Extract heading levels and check for gaps
grep -rn "<h[1-6]" --include="*.tsx" --include="*.jsx" . 2>/dev/null | grep -v node_modules | sort
```

Verify headings do not skip levels (e.g., h1 directly to h3 without h2).

### 3J: Autoplaying Media

```
Pattern: autoPlay
Pattern: autoplay
Pattern: <video[^>]*autoplay
Pattern: <audio[^>]*autoplay
```

Autoplaying media that lasts more than 3 seconds must have a pause/stop mechanism. Autoplaying media with audio must be muted by default.

### 3K: Touch Target Size (Level AA — WCAG 2.2 enhancement)

```
Pattern: (?:w|h|size)-(?:[0-5]|px|\[(?:[0-9]|1[0-9]|2[0-3])px\])
```

Interactive elements should have a minimum touch target size of 24x24 CSS pixels (44x44 for AAA). Check small icon buttons, close buttons, and compact UI elements.

### 3L: Motion and Animation Safety

```
Pattern: @keyframes
Pattern: animation:
Pattern: transition:
Pattern: animate-
Pattern: motion\.
Pattern: framer-motion
Pattern: useSpring
Pattern: useAnimation
```

Check that animations:
- Respect `prefers-reduced-motion` media query
- Do not flash more than 3 times per second
- Can be paused or disabled

```
Pattern: prefers-reduced-motion
Pattern: motion-reduce
Pattern: motionSafe
```

If animations exist but `prefers-reduced-motion` is not handled, that is a violation.

**Severity:** MAJOR if no `prefers-reduced-motion` support is present with significant animations.

---

## Step 4: Automated Testing Integration

Recommend and optionally set up automated accessibility testing tools.

### 4A: Check Existing a11y Tooling

```bash
# Check if a11y testing tools are already installed
cat package.json 2>/dev/null | grep -iE "(axe|a11y|accessibility|pa11y|lighthouse)"

# Check for ESLint a11y plugin
cat .eslintrc* eslint.config.* 2>/dev/null | grep -i "jsx-a11y"

# Check for Playwright/Cypress a11y tests
find . -maxdepth 4 -name "*.spec.ts" -o -name "*.test.ts" 2>/dev/null | xargs grep -l "axe\|a11y\|accessibility" 2>/dev/null
```

### 4B: Recommend Tool Setup

Based on what is missing, recommend installing:

**Static Analysis (ESLint):**
```bash
npm install --save-dev eslint-plugin-jsx-a11y
```

ESLint config addition:
```json
{
  "extends": ["plugin:jsx-a11y/recommended"]
}
```

**Runtime Testing (axe-core):**
```bash
npm install --save-dev @axe-core/react axe-core
```

Development-only setup for React:
```typescript
// In development entry point
if (process.env.NODE_ENV === 'development') {
  import('@axe-core/react').then((axe) => {
    axe.default(React, ReactDOM, 1000);
  });
}
```

**E2E Testing (Playwright + axe):**
```bash
npm install --save-dev @axe-core/playwright
```

Playwright test example:
```typescript
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test('homepage should have no a11y violations', async ({ page }) => {
  await page.goto('/');
  const results = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa'])
    .analyze();
  expect(results.violations).toEqual([]);
});
```

### 4C: Generate Test Scripts

If requested or if `--fix` is in arguments, create a basic accessibility test file:

```typescript
// tests/accessibility.spec.ts
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

const pages = [
  { name: 'Home', path: '/' },
  { name: 'Login', path: '/login' },
  { name: 'Dashboard', path: '/dashboard' },
  // Add discovered pages here
];

for (const { name, path } of pages) {
  test(`${name} page should have no WCAG 2.1 AA violations`, async ({ page }) => {
    await page.goto(path);
    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa'])
      .analyze();
    expect(results.violations).toEqual([]);
  });

  test(`${name} page should be keyboard navigable`, async ({ page }) => {
    await page.goto(path);
    const body = page.locator('body');
    await body.press('Tab');
    const focusedElement = await page.evaluate(() => {
      const el = document.activeElement;
      return el ? el.tagName : null;
    });
    expect(focusedElement).not.toBeNull();
    expect(focusedElement).not.toBe('BODY');
  });
}
```

---

## Step 5: Auto-Fix (only with --fix flag)

If `--fix` is in $ARGUMENTS, automatically remediate the following safe fixes. Only apply fixes that will not break functionality or change visual appearance.

### 5A: Add Missing alt="" to Decorative Images

For images that are clearly decorative (icons inside buttons with text, background decorations, spacer images):

Find pattern: `<img src="..." />`
Replace with: `<img src="..." alt="" />`

Only apply to images that are confirmed decorative based on context analysis.

### 5B: Add aria-label to Icon-Only Buttons

For buttons containing only an icon (SVG, icon component) with no text:

Find pattern: `<button onClick={...}><Icon /></button>`
Replace with: `<button onClick={...} aria-label="[descriptive action]"><Icon /></button>`

Infer the label from the icon name, handler name, or surrounding context.

### 5C: Add htmlFor to Labels

For `<label>` elements without `htmlFor` that are adjacent to an input with an `id`:

Find the label + input pair and add the matching `htmlFor` attribute.

### 5D: Add lang Attribute to HTML Element

If the root `<html>` element is missing a `lang` attribute:

Read the layout file and add `lang="en"` (or the appropriate language code if detectable from i18n config).

### 5E: Add Skip Navigation Link

If no skip navigation link exists, add one to the root layout:

```tsx
<a
  href="#main-content"
  className="sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 focus:z-50 focus:px-4 focus:py-2 focus:bg-white focus:text-black focus:rounded focus:shadow-lg"
>
  Skip to main content
</a>
```

And add `id="main-content"` to the `<main>` element.

### 5F: Fix Heading Hierarchy

If headings skip levels (e.g., h1 then h3), suggest corrections. Only auto-fix if the correction is unambiguous (single heading level gap).

### 5G: Add focus-visible Styles

If focus outlines are globally removed, add a focus-visible replacement in globals.css:

```css
/* Accessibility: Visible focus indicators */
*:focus-visible {
  outline: 2px solid #2563eb;
  outline-offset: 2px;
}
```

### 5H: Add prefers-reduced-motion

If animations exist without motion preference support, add to globals.css:

```css
/* Accessibility: Respect reduced motion preference */
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

### 5I: Install ESLint a11y Plugin

If `eslint-plugin-jsx-a11y` is not installed:

```bash
npm install --save-dev eslint-plugin-jsx-a11y
```

Add `"plugin:jsx-a11y/recommended"` to the ESLint extends array.

**Important:** For any auto-fix, create a summary of changes made:

```markdown
## Auto-Fix Summary
| Fix | File | Change | Status |
|-----|------|--------|--------|
| Added alt="" to decorative images | [files] | Added N alt attributes | Applied |
| Added aria-label to icon buttons | [files] | Added N aria-labels | Applied |
| Added lang="en" to html | layout.tsx | Added lang attribute | Applied |
| Added skip navigation link | layout.tsx | Added skip-to-content link | Applied |
| Added focus-visible styles | globals.css | Added focus outline | Applied |
| Added reduced-motion support | globals.css | Added media query | Applied |
| Installed eslint-plugin-jsx-a11y | package.json | Added dev dependency | Applied |
```

---

## Step 6: Generate Accessibility Report

After completing all audit steps, compile findings into a comprehensive report and save as `ACCESSIBILITY_AUDIT_REPORT.md` in the project root.

Count findings by severity:
- **CRITICAL**: Blocks entire user groups from accessing content (no keyboard access, no screen reader support, missing lang)
- **MAJOR**: Significant barriers that make tasks difficult (missing labels, broken heading hierarchy, no focus indicators)
- **MINOR**: Inconveniences that reduce usability but do not block access (generic link text, placeholder contrast, minor ARIA issues)
- **INFO**: Good practices observed or informational notes

Determine the compliance level:
- Any CRITICAL findings = **Non-Compliant**
- No CRITICAL but MAJOR findings = **Partially Compliant**
- No CRITICAL or MAJOR = **Largely Compliant**
- Only INFO findings = **Fully Compliant**

Calculate compliance score:
- Total applicable criteria (based on content types present)
- Passing criteria count
- Score = (Passing / Total) x 100

```markdown
# Accessibility Audit Report

**Date**: [today's date]
**Standard**: WCAG 2.1 [AA or AAA based on --level flag]
**Auditor**: Claude Accessibility Auditor (Cortex)
**Scope**: [All pages / Specific component from $ARGUMENTS]
**Pages Scanned**: [n]
**Components Scanned**: [n]
**Total Files Analyzed**: [n]
**Compliance Level**: [Non-Compliant / Partially Compliant / Largely Compliant / Fully Compliant]

---

## Compliance Score: [X]%

| WCAG Principle | Criteria Checked | Pass | Fail | N/A | Score |
|----------------|-----------------|------|------|-----|-------|
| 1. Perceivable | [n] | [n] | [n] | [n] | [x]% |
| 2. Operable | [n] | [n] | [n] | [n] | [x]% |
| 3. Understandable | [n] | [n] | [n] | [n] | [x]% |
| 4. Robust | [n] | [n] | [n] | [n] | [x]% |
| **TOTAL** | **[n]** | **[n]** | **[n]** | **[n]** | **[x]%** |

---

## Findings Summary

| Severity | Count | Description |
|----------|-------|-------------|
| CRITICAL | [n] | Blocks user groups entirely |
| MAJOR | [n] | Significant barriers |
| MINOR | [n] | Inconveniences |
| INFO | [n] | Good practices / notes |
| **TOTAL** | **[n]** | |

---

## Detailed Findings

### CRITICAL Issues (Blocks Users)

#### [C-001] [Title]
- **WCAG Criterion**: [X.X.X] [Criterion Name] (Level [A/AA/AAA])
- **Category**: [Perceivable/Operable/Understandable/Robust]
- **File**: [file path]
- **Line**: [line number]
- **Code**:
  ```tsx
  [offending code snippet]
  ```
- **Issue**: [detailed explanation of what is wrong and who is affected]
- **Impact**: [which users are blocked — screen reader users, keyboard users, low vision, etc.]
- **Remediation**:
  ```tsx
  [corrected code snippet]
  ```
- **Reference**: [WCAG understanding doc URL]

[Repeat for each CRITICAL finding]

---

### MAJOR Issues (Significant Barriers)

#### [M-001] [Title]
[Same format as CRITICAL]

[Repeat for each MAJOR finding]

---

### MINOR Issues (Inconveniences)

#### [MI-001] [Title]
[Same format as above]

[Repeat for each MINOR finding]

---

### INFO (Good Practices Observed)

#### [I-001] [Title]
- [Description of correct accessibility implementation observed]
- [Which WCAG criterion it satisfies]

---

## WCAG 2.1 [AA/AAA] Compliance Matrix

| Criterion | Level | Name | Status | Notes |
|-----------|-------|------|--------|-------|
| 1.1.1 | A | Non-text Content | [PASS/FAIL/N/A] | [summary] |
| 1.2.1 | A | Audio-only/Video-only | [PASS/FAIL/N/A] | [summary] |
| 1.2.2 | A | Captions (Prerecorded) | [PASS/FAIL/N/A] | [summary] |
| 1.2.3 | A | Audio Description | [PASS/FAIL/N/A] | [summary] |
| 1.3.1 | A | Info and Relationships | [PASS/FAIL/N/A] | [summary] |
| 1.3.2 | A | Meaningful Sequence | [PASS/FAIL/N/A] | [summary] |
| 1.3.3 | A | Sensory Characteristics | [PASS/FAIL/N/A] | [summary] |
| 1.4.1 | A | Use of Color | [PASS/FAIL/N/A] | [summary] |
| 1.4.2 | A | Audio Control | [PASS/FAIL/N/A] | [summary] |
| 1.4.3 | AA | Contrast (Minimum) | [PASS/FAIL/N/A] | [summary] |
| 1.4.4 | AA | Resize Text | [PASS/FAIL/N/A] | [summary] |
| 1.4.5 | AA | Images of Text | [PASS/FAIL/N/A] | [summary] |
| 1.4.10 | AA | Reflow | [PASS/FAIL/N/A] | [summary] |
| 1.4.11 | AA | Non-text Contrast | [PASS/FAIL/N/A] | [summary] |
| 1.4.12 | AA | Text Spacing | [PASS/FAIL/N/A] | [summary] |
| 1.4.13 | AA | Content on Hover/Focus | [PASS/FAIL/N/A] | [summary] |
| 2.1.1 | A | Keyboard | [PASS/FAIL/N/A] | [summary] |
| 2.1.2 | A | No Keyboard Trap | [PASS/FAIL/N/A] | [summary] |
| 2.1.4 | A | Character Key Shortcuts | [PASS/FAIL/N/A] | [summary] |
| 2.4.1 | A | Bypass Blocks | [PASS/FAIL/N/A] | [summary] |
| 2.4.2 | A | Page Titled | [PASS/FAIL/N/A] | [summary] |
| 2.4.3 | A | Focus Order | [PASS/FAIL/N/A] | [summary] |
| 2.4.4 | A | Link Purpose (In Context) | [PASS/FAIL/N/A] | [summary] |
| 2.4.5 | AA | Multiple Ways | [PASS/FAIL/N/A] | [summary] |
| 2.4.6 | AA | Headings and Labels | [PASS/FAIL/N/A] | [summary] |
| 2.4.7 | AA | Focus Visible | [PASS/FAIL/N/A] | [summary] |
| 2.5.1 | A | Pointer Gestures | [PASS/FAIL/N/A] | [summary] |
| 2.5.2 | A | Pointer Cancellation | [PASS/FAIL/N/A] | [summary] |
| 2.5.3 | A | Label in Name | [PASS/FAIL/N/A] | [summary] |
| 2.5.4 | A | Motion Actuation | [PASS/FAIL/N/A] | [summary] |
| 3.1.1 | A | Language of Page | [PASS/FAIL/N/A] | [summary] |
| 3.1.2 | AA | Language of Parts | [PASS/FAIL/N/A] | [summary] |
| 3.2.1 | A | On Focus | [PASS/FAIL/N/A] | [summary] |
| 3.2.2 | A | On Input | [PASS/FAIL/N/A] | [summary] |
| 3.2.3 | AA | Consistent Navigation | [PASS/FAIL/N/A] | [summary] |
| 3.2.4 | AA | Consistent Identification | [PASS/FAIL/N/A] | [summary] |
| 3.3.1 | A | Error Identification | [PASS/FAIL/N/A] | [summary] |
| 3.3.2 | A | Labels or Instructions | [PASS/FAIL/N/A] | [summary] |
| 3.3.3 | AA | Error Suggestion | [PASS/FAIL/N/A] | [summary] |
| 3.3.4 | AA | Error Prevention (Legal/Financial) | [PASS/FAIL/N/A] | [summary] |
| 4.1.1 | A | Parsing | [PASS/FAIL/N/A] | [summary] |
| 4.1.2 | A | Name, Role, Value | [PASS/FAIL/N/A] | [summary] |
| 4.1.3 | AA | Status Messages | [PASS/FAIL/N/A] | [summary] |

---

## Automated Testing Status

| Tool | Status | Configuration |
|------|--------|---------------|
| eslint-plugin-jsx-a11y | [Installed/Missing] | [details] |
| @axe-core/react | [Installed/Missing] | [details] |
| @axe-core/playwright | [Installed/Missing] | [details] |
| pa11y | [Installed/Missing] | [details] |

---

## Remediation Plan

### Immediate Actions (within 24 hours)
1. [Fix CRITICAL issues — list each with file and fix]
2. [Next critical fix]

### Short-Term (within 1 week)
1. [Fix MAJOR issues]
2. [Set up automated a11y testing]

### Medium-Term (within 1 month)
1. [Fix MINOR issues]
2. [Improve test coverage]
3. [Add a11y to CI/CD pipeline]

### Ongoing
1. [Include a11y in code review checklist]
2. [Regular screen reader testing]
3. [User testing with assistive technology users]

---

## Resources

- [WCAG 2.1 Quick Reference](https://www.w3.org/WAI/WCAG21/quickref/)
- [ARIA Authoring Practices Guide](https://www.w3.org/WAI/ARIA/apg/)
- [Deque axe-core Rules](https://dequeuniversity.com/rules/axe/)
- [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)
- [A11y Project Checklist](https://www.a11yproject.com/checklist/)
```

Save this report as `ACCESSIBILITY_AUDIT_REPORT.md` in the project root.

---

## Step 7: Output Summary

After generating the report, display a final summary:

```
+================================================================+
|                  ACCESSIBILITY AUDIT COMPLETE                    |
+================================================================+
| Standard: WCAG 2.1 [AA/AAA]                                    |
| Compliance Score: [X]%                                          |
| Compliance Level: [Non-Compliant/Partially/Largely/Fully]       |
|                                                                  |
| Findings:                                                        |
|   Critical: [N] (blocks user groups)                            |
|   Major:    [N] (significant barriers)                          |
|   Minor:    [N] (inconveniences)                                |
|   Info:     [N] (good practices)                                |
|                                                                  |
| Pages Scanned:      [N]                                         |
| Components Scanned: [N]                                         |
|                                                                  |
| Top 3 Actions Required:                                          |
|   1. [Most critical accessibility fix]                          |
|   2. [Second most critical fix]                                 |
|   3. [Third most critical fix]                                  |
|                                                                  |
| Report saved: ACCESSIBILITY_AUDIT_REPORT.md                      |
+================================================================+
```

If CRITICAL issues were found:

```
!! WARNING: CRITICAL accessibility barriers detected.
!! Users with disabilities CANNOT access parts of this application.
!! Fix all CRITICAL findings before deployment.
!! See ACCESSIBILITY_AUDIT_REPORT.md for details and code fixes.
```

If no CRITICAL or MAJOR issues:

```
Accessibility posture is good. The application is largely compliant
with WCAG 2.1 [AA/AAA]. Review MINOR findings for further improvement.
Consider scheduling user testing with assistive technology users.
```

If `--fix` was applied, also show:

```
Auto-Fix Applied:
  [N] files modified
  [N] issues auto-fixed
  [N] issues require manual review

See the Auto-Fix Summary section in the report for details.
Verify all changes visually and with a screen reader before committing.
```
