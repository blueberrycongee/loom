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

## Feel

- **Weave motion** — tiles arrive in a left-to-right wave when you shuffle, with deterministic ±20ms jitter so 40-tile walls aren't metronomic. Exits are ease-out; entries are spring; positions settle on the same wave. One vocabulary across every screen.
- **Pointer aura** — a soft brass glow follows the cursor; tiles within 240pt gain brightness, tiles further away lose a whisper of saturation, so your gaze literally focuses the wall.
- **Ambient tapestry** — the landing hero is 12 drifting rectangles of the brand palette, rotating within their own zones at 16–28s periods, no two in lockstep.
- **Live indexing** — while your library is being indexed, a mini-wall grows in real time as each photo's dominant color becomes a tile, arriving in the same wave.
- **Paper grain** — static pre-rendered noise overlay at 3% via `.softLight`, with a slow 8s opacity breathe; no per-frame redraw cost.
- **Haptics** — trackpad ticks only on the three moments that carry intent: shuffle, snap, confirm.

## Stack

- **UI** · SwiftUI + AppKit bridge where precision matters
- **Render** · CALayer for the wall, Metal-backed where dense
- **Local AI** · Vision (`VNGenerateImageFeaturePrintRequest`), Core Image (color), Core ML (mood embedding)
- **Index** · SQLite, per-folder, encrypted at rest
- **Ingest** · User folder (v1), PhotoKit (M7)

Full architectural spec: [VISION.md](./VISION.md).

## Getting started

> **Status:** all milestones complete (M0 – M7). Six style engines, color + mood clustering, pin-to-keep, favorites with byte-identical replay, PNG/PDF export, both folder and Photos-library indexers. Open in Xcode 15+ on macOS 14+.

```bash
git clone https://github.com/blueberrycongee/loom.git
cd loom
open Package.swift          # Xcode
# or
swift test                  # run the pure-compute test suite
```

Press **⌘O** to pick a folder. The first scan indexes every photo
(Vision feature-print + dominant Lab color + EXIF), then the wall
auto-composes. Press **Space** — or hit the brass button — to weave
a new wall from the same library.

## Milestones

- [x] **M0** · Vision, scaffold, atomic-commit workflow
- [x] **M1** · Folder → Vision → SQLite → grid browser
- [x] **M2** · Tapestry layout + Shuffle
- [x] **M3** · Collage · Editorial · Gallery · Minimal · Vintage
- [x] **M4** · Mood embedding (via Vision feature-print k-medoids)
- [x] **M5** · Pin-to-keep (tile locks) · favorites (save + reproduce)
- [x] **M6** · Export — PNG (3×) · PDF (vector-backed)
- [x] **M7** · PhotoKit source — full indexer + permission + incremental rescan

See [ARCHITECTURE.md](./ARCHITECTURE.md) for the module graph and the Shuffle
pipeline in detail.

## Keyboard

| Key             | Action                         |
|-----------------|--------------------------------|
| **Space**       | Shuffle                        |
| **⌘1 – ⌘6**    | Switch style                   |
| **⌘O**          | Open folder                    |
| **⌘S**          | Save current wall as favorite  |
| **⌘E**          | Export as PNG                  |
| **⌘⇧P**        | Export as PDF                  |
| **⌘⇧L**        | Clear all tile locks           |
| **Double-click tile** | Pin / unpin photo        |

## Principles

1. **Native first.** Performance and feel measured against Photos · Pages · Keynote.
2. **Aesthetic first.** Default state is great without tuning.
3. **Surprise first.** Automatic beats manual. Randomness lives inside aesthetic rules.
4. **Offline first.** No network. No uploads. No account.
5. **Privacy first.** Sandboxed, encrypted index, one-click wipe.

## License

MIT — see [LICENSE](./LICENSE).
