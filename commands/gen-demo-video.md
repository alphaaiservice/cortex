---
description: "Generate a product demo / marketing video as versioned source — HyperFrames (HTML template → MP4, high quality) or Remotion (React) — with script → storyboard → TTS voiceover + captions → branded scenes → MP4. Reuses /gen-brand and /gen-mockup. Usage: /gen-demo-video ./PRD.md [--engine=hyperframes|remotion] [--length=60s] [--style=marketing|demo|explainer|launch] [--aspect=16:9|9:16] [--quality=draft|standard|high] [--voice=on|off]"
---

# Demo / Marketing Video Generator — Template or Code

Produce a branded, re-renderable product video. The `video-producer` skill auto-loads and defines the pipeline + quality bar. Two engines:
- **HyperFrames** (default) — open-source HTML-template → MP4 CLI; **best for high-quality branded templated video**. Proven in your **FrameCraft** product.
- **Remotion** — React/TypeScript; best for code-driven animation. Productizes the `voicemint/marketing-video` workflow.

`$ARGUMENTS` = PRD path, product/idea text, or empty (infer from the current project).

---

## Section 0: Input & Context

### 0a. Parse input & flags
- File path → PRD. Free text → brief. Empty → scan project (`PRD.md`, `README.md`, `BRAND_GUIDE.md`, `mockups/`).
- Flags: `--engine=hyperframes|remotion` (default **hyperframes**), `--length=` (default **60s**), `--style=marketing|demo|explainer|launch` (default **marketing**), `--aspect=16:9|9:16` (default **16:9**; 9:16 for social), `--quality=draft|standard|high` (HyperFrames; default **high**), `--fps=24|30|60` (default **30**), `--voice=on|off` (default **on**), `--music=on|off` (default **off**).

### 0b. Gather assets (reuse)
- `BRAND_GUIDE.md` → logo, OKLCH colors, fonts (`@remotion/google-fonts`).
- `mockups/` screenshots (from `/gen-mockup`) → product B-roll. If none and the video is a demo, suggest running `/gen-mockup` first or fall back to animated UI built in Remotion.
- Existing `voicemint/marketing-video` is the reference implementation for structure.

---

## Section 1: Script & Storyboard (FIRST)

### 1a. Write the script
Tight spoken script for the target length. Structure by style:
- **marketing**: hook (3s) → problem → solution → 2–3 key features → CTA.
- **demo**: intro → walk through the core flow screen-by-screen → outro/CTA.
- **explainer**: question → concept → how-it-works → payoff.
- **launch**: tease → reveal → what's new → availability/CTA.

### 1b. Storyboard → `src/data/script.ts`
Break into 5–9 scenes; for each: visual, on-screen text, duration (frames @ 30fps), voiceover line. This data file is the single edit point for copy/timing. Confirm the scene outline to the user in one line before scaffolding.

---

## Section 2: Scaffold the project (per `--engine`)

### 2a — HyperFrames (default)
Create a HyperFrames project under `video/` (per the `video-producer` skill output shape):
- `index.html` — the composition: one section per scene, animations via CSS/JS, **content-free** (reads everything from `window.__hyperframes.getVariables()`).
- `hyperframes.json` — manifest: dimensions (from `--aspect`: 1920×1080 or 1080×1920), `fps`, per-scene timings.
- `vars.json` — ALL copy, brand colors/fonts, asset paths, and timing. This is the single edit point.
- `assets/` — logo SVG, mockup screenshots, music, generated VO audio.
- `scripts/generate-vo.ts`, `README.md`.
Brand it from `BRAND_GUIDE.md` (colors/fonts/logo into `vars.json` + `<link>`/`@font-face` in `index.html`); logo intro + end-card scenes. Pin the CLI version in README (FrameCraft uses `0.5.3`) for deterministic renders.

### 2b — Remotion (`--engine=remotion`)
Create `video/` with `package.json` (remotion, @remotion/cli, @remotion/google-fonts, @remotion/media, TTS SDK), `remotion.config.ts`, `src/Root.tsx`, `src/scenes/*`, `src/components/` (`LowerThird`, `EndCard`, `CaptionTrack`, `Logo`), `src/data/script.ts`, `scripts/generate-vo.ts`, `public/`, `README.md`. Theme from BRAND_GUIDE; composition size from `--aspect` @ `--fps`; duration = sum of scene durations.

### 2c. Captions & Voiceover (both engines)
- Captions: render the per-scene line on screen AND emit a sidecar `captions.srt` (video must work muted).
- `--voice=on`: `scripts/generate-vo.ts` calls the GenAI TTS provider (`@google/genai` / ElevenLabs / OpenAI TTS) — **API key from `.env`, never hard-coded** (the `genai` skill applies). One audio file per scene under `assets/vo/` (HyperFrames) or `public/vo/` (Remotion); sequence under its scene; duck optional music beneath it.
- `--voice=off`: captions only, no audio generation.

---

## Section 3: Render & Deliver

### 3a. Render (per `--engine`)
- **HyperFrames**: `hyperframes render video/ -o video/out/demo.mp4 -q <quality> -f <fps> --variables-file video/vars.json`. Requires Node 20 + Google Chrome + FFmpeg + the `hyperframes` CLI (`npm install -g hyperframes`; set `PUPPETEER_EXECUTABLE_PATH` to the Chrome binary). For CI, mirror FrameCraft's `Dockerfile.composition`.
- **Remotion**: `npx remotion render src/index.ts <Composition> out/demo.mp4`.
- If the chosen engine's toolchain isn't installed, scaffold everything and print the exact install + render commands rather than failing the command.
- Vertical variant: re-render with the 9:16 dimensions when `--aspect=9:16`.

### 3b. Output
```
video/
├── (HyperFrames) index.html · hyperframes.json · vars.json   # ← edit vars.json, then re-render
│   (Remotion)    src/data/script.ts                          # ← edit here, then re-render
├── assets|public/vo/ · captions.srt
└── out/demo.mp4
```

### 3c. Report back
- Engine, scene outline, length, aspect, quality/fps, voice on/off, brand source.
- The render command run/to run and where the MP4 lands.
- Next step: embed `out/demo.mp4` into the demo slide via `/gen-pitch`.

---

## Guardrails
- NEVER hard-code TTS/API keys — use `.env` (`genai` skill).
- NEVER render without captions — videos must work muted.
- NEVER use stock/fake UI for product shots — use real mockups/screen captures.
- Keep the single source (`vars.json` for HyperFrames, `script.ts` for Remotion) authoritative so iteration is one edit + one re-render.
- Pin the engine version (e.g. HyperFrames `0.5.3`) so renders are reproducible across machines/CI.
