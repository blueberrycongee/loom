<div align="center">

# Loom

**macOS-native photo-wall app. Local AI weaves your photos into a wall with aesthetic rhythm.**

*Every click is a new composition you've never seen before — constrained by design rules, surprised by randomness.*

</div>

---

## What it does

Open Loom, point it at a folder of photos, press **Shuffle**. Loom picks a set, arranges a wall, and the result is good on the first try. Press again: a different wall, equally good. No dragging. No presets. No cloud.

## Why it exists

Photo libraries are big and boring to look at. Existing grids show everything with equal weight; slideshows are too linear; collage apps are too manual. Loom is a **composer**, not a browser — it treats a wall as an aesthetic object and uses local AI to make each one land.

## Core loop

```
folder  →  index (Vision · Core Image)  →  cluster (color · mood)  →  layout (Tapestry)  →  Wall
                                                                            ↑
                                                                         Shuffle
```

Everything runs locally. Nothing uploads.

## Styles

| Style      | Feel                                           |
|------------|------------------------------------------------|
| Tapestry   | Justified rows, uniform row-height. *Default.* |
| Editorial  | One dominant image, supporting satellites.     |
| Gallery    | Golden-ratio grid, generous whitespace.        |
| Collage    | Overlap, rotation, torn edges.                 |
| Minimal    | 3–5 photos, high contrast.                     |
| Vintage    | Polaroid frames, mild skew.                    |

## Stack

- **UI** · SwiftUI + AppKit bridge where precision matters
- **Render** · CALayer for the wall, Metal-backed where dense
- **Local AI** · Vision (`VNGenerateImageFeaturePrintRequest`), Core Image (color), Core ML (mood embedding)
- **Index** · SQLite, per-folder, encrypted at rest
- **Ingest** · User folder (v1), PhotoKit (M7)

Full architectural spec: [VISION.md](./VISION.md).

## Getting started

> **Status:** M1/M2 scaffold. Open in Xcode 15+ on macOS 14+. See [milestones](#milestones).

```bash
git clone https://github.com/blueberrycongee/loom.git
cd loom
open Package.swift   # Xcode
```

## Milestones

- [x] **M0** · Vision, scaffold, atomic-commit workflow
- [ ] **M1** · Folder → Vision → SQLite → grid browser
- [ ] **M2** · Tapestry layout + Shuffle
- [ ] **M3** · Collage · Editorial · Gallery · Minimal · Vintage
- [ ] **M4** · Mood embedding
- [ ] **M5** · Edit · lock · favorites
- [ ] **M6** · Export · PDF · print
- [ ] **M7** · PhotoKit source

## Principles

1. **Native first.** Performance and feel measured against Photos · Pages · Keynote.
2. **Aesthetic first.** Default state is great without tuning.
3. **Surprise first.** Automatic beats manual. Randomness lives inside aesthetic rules.
4. **Offline first.** No network. No uploads. No account.
5. **Privacy first.** Sandboxed, encrypted index, one-click wipe.

## License

MIT — see [LICENSE](./LICENSE).
