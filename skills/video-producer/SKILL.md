---
name: video-producer
description: "Auto-invoked when the user wants a product demo video, marketing/promo video, explainer, launch video, or animated walkthrough — phrases like 'make a demo video', 'create a marketing video', 'product launch video', 'animate this flow', 'voiceover walkthrough'. Enforces Cortex's video standards: high-quality template render (HyperFrames HTML→MP4) or code render (Remotion/React), brand-consistent scenes, scripted narrative, TTS voiceover + captions, deterministic render."
---

# Demo / Marketing Video Standards

This skill governs how Cortex produces **product demo and marketing videos**. Videos are built **as versioned source** — an HTML template (HyperFrames) or React (Remotion) — rendered deterministically to MP4, never hand-edited in a timeline GUI. Invoked by `/gen-demo-video`; auto-fires on any "make a demo/marketing/explainer video" request.

Two proven engines, both used in your own stack:
- **HyperFrames** — open-source HTML-template → MP4 render CLI. **Recommended for high-quality, brand-templated videos.** Proven in production by **FrameCraft** (`templates/hyperframes/{slug}/`, `hyperframes_service.render(...)`, Dockerfile.composition).
- **Remotion** — React/TypeScript programmatic video. Best for code-driven animation and data-bound scenes. Productizes the `voicemint/marketing-video` pipeline (Remotion + @google/genai).

Pick per task; default to **HyperFrames** when the user asks for "high quality" or template-based video, **Remotion** when they want React/animation-as-code.

---

## The standard pipeline
1. **Script** — write a tight spoken script first (the video is the script + visuals, not the reverse). Hook in 3s; one message per scene; CTA at the end.
2. **Storyboard** — break the script into scenes (typically 5–9), each with: on-screen visual, on-screen text, duration, and the voiceover line.
3. **Voiceover** — generate TTS audio per scene (or one track). Caption every line (accessibility + sound-off viewing).
4. **Compose** — one scene per script beat, sequenced; brand-themed; transitions; B-roll = mockup screenshots / screen captures / animated UI. (HyperFrames: scenes are sections in `index.html`; Remotion: a component per scene.)
5. **Render** — engine CLI → MP4 (1080p default; 9:16 vertical variant on request for social).

## Hard rules (engine-agnostic)
- ✅ **Source-as-code** — the video is version-controlled source (HTML template or React), never a binary timeline project. No external editor required to re-render.
- ✅ **Brand-consistent** — colors/fonts/logo from `BRAND_GUIDE.md`; lower-thirds and end-card use brand tokens. (Remotion: `@remotion/google-fonts`; HyperFrames: brand fonts via `<link>` / `@font-face` in the template.)
- ✅ **Script-first & on-message** — every scene maps to one script beat. Hook → problem → solution → product/demo → CTA. Default length 30–90s (marketing) or up to ~2–3 min (full demo).
- ✅ **Captions always** — burned-in or sidecar `.srt`; videos must work muted.
- ✅ **Real product** — use actual mockup screenshots (`/gen-mockup`) or screen captures, not generic stock. Animate UI where it sells the feature.
- ✅ **Deterministic & re-renderable** — copy/timing/asset paths live in a data file (Remotion `data/script.ts`; HyperFrames `--variables-file` JSON) so a change is a one-line edit + re-render. Pin the engine version for reproducible output (FrameCraft pins HyperFrames `0.5.3`).
- ✅ **Audio**: TTS via the project's GenAI gateway (`@google/genai`, ElevenLabs, or OpenAI TTS) — keys via env, never hard-coded. Background music optional + ducked under voiceover.
- ❌ NEVER hard-code API keys in the project. ❌ NEVER ship a no-caption video. ❌ NEVER use lorem ipsum / fake UI in product shots.

## Engine A — HyperFrames (recommended for high-quality templated video)
Open-source HTML-template → MP4 renderer (Node 20 + Google Chrome via Puppeteer + FFmpeg). A **HyperFrames project** is a directory containing `index.html` + `hyperframes.json`.
- **Render**: `hyperframes render <project_dir> -o out.mp4 -q <quality> -f <fps>` — quality presets `draft | standard | high` (run `hyperframes render --help` to confirm), fps ∈ {24, 30, 60}.
- **Variables**: pass `--variables-file vars.json`; read inside the template via `window.__hyperframes.getVariables()`. Keep all copy/colors/asset paths/timings in `vars.json` so the template itself is content-free.
- **Install / config**: `npm install -g hyperframes`; binary resolved via `HYPERFRAMES_CLI` env or `$PATH`; `PUPPETEER_EXECUTABLE_PATH` for Chrome; `HYPERFRAMES_TELEMETRY_DISABLED=1`.
- **Reference implementation**: FrameCraft's `templates/hyperframes/{slug}/`, `hyperframes_service.render(...)`, and `ci/Dockerfile.composition` (Node 20 + Chrome stable + FFmpeg + pinned `hyperframes` CLI) — mirror its toolchain for CI renders.
- **Output shape**:
```
video/
├── index.html             # the composition: scene sections, animations (CSS/JS), reads window.__hyperframes.getVariables()
├── hyperframes.json       # project manifest (dimensions, fps, scene timings)
├── vars.json              # ← edit copy/colors/asset paths/timing here, then re-render
├── assets/                # logo, screenshots, music, generated VO audio
├── scripts/generate-vo.ts # TTS generation (env-keyed)
└── README.md              # render command, how to edit vars, formats, pinned CLI version
```

## Engine B — Remotion (recommended for code-driven animation / data-bound scenes)
React/TypeScript programmatic video; explicit timing (`useCurrentFrame`, `Sequence`).
- **Render**: `npx remotion render src/index.ts <Composition> out/demo.mp4`.
- **Output shape**:
```
video/
├── package.json           # remotion + @remotion/cli + @remotion/google-fonts + TTS sdk
├── remotion.config.ts
├── src/
│   ├── Root.tsx           # registers compositions
│   ├── scenes/            # one component per scene
│   ├── components/        # LowerThird, EndCard, CaptionTrack, Logo
│   └── data/script.ts     # script + storyboard (edit copy/timing here)
├── public/                # logo, screenshots, music, generated VO audio
├── scripts/generate-vo.ts # TTS generation (env-keyed)
└── README.md              # render commands, how to edit script, formats
```

## How this skill works with others
- `gen-brand` — logo, colors, fonts for lower-thirds/end-card/theme.
- `mockup` — product screenshots / animated screens used as B-roll.
- `genai` — the TTS/voiceover goes through the GenAI gateway with keys in env (no raw hard-coded keys).
- `pitch-deck` — the rendered MP4 embeds into the demo slide.
- `/gen-demo-video` (command) — the user-facing trigger.
