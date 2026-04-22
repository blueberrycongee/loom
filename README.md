<div align="center">

# Loom

**Your photos, woven into walls.**  
*A macOS-native composer that turns any folder or Photos library into an aesthetic wall — automatically, privately, and never the same way twice.*

[![macOS](https://img.shields.io/badge/macOS-14+-333333?logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift)](./Package.swift)
[![License](https://img.shields.io/badge/License-MIT-9B6A2F)](./LICENSE)
[![Downloads](https://img.shields.io/badge/Download-Loom.app-9B6A2F)](./dist/Loom-macos-arm64.zip)

</div>

---

## What it does

Loom is not a photo browser. It is a **composer**.

Point it at a folder — or your entire Apple Photos library — and press **Shuffle**. Loom picks a set, arranges a wall, and the result is good on the first try. Press again: a different wall, equally good. No dragging, no presets, no cloud uploads, no subscription.

Every wall is generated on-device using local computer vision and a constraint-based aesthetic engine. The randomness is intentional; the beauty is guaranteed.

<div align="center">

`folder / Photos library → index → cluster → compose → wall`

</div>

---

## Why Loom

| | |
|:---|:---|
| **🎨 Aesthetic-first** | Default output is print-ready. No sliders to tune. |
| **🔒 Privacy-first** | All AI runs locally. No network, no account, no telemetry. |
| **⚡ Native-first** | SwiftUI + AppKit + Metal. Built like a first-party Mac app. |
| **🎲 Surprise-first** | Automatic beats manual. Randomness lives inside design rules. |

---

## Seven styles, one click

Loom ships with seven distinct layout engines. Switch instantly — the same photo set becomes a completely different object.

| Style | Feel | Shortcut |
|:---|:---|:---|
| **Exhibit** | Handcrafted composition with breathing room. *Default.* | `⌘1` |
| **Tapestry** | Justified rows, uniform row height. Woven like textile. | `⌘2` |
| **Editorial** | One hero image, supporting satellites. Magazine spread. | `⌘3` |
| **Gallery** | Golden-ratio grid, generous whitespace. | `⌘4` |
| **Collage** | Overlap, rotation, torn edges. Handmade energy. | `⌘5` |
| **Minimal** | 3–5 photos, high contrast. Quiet and decisive. | `⌘6` |
| **Vintage** | Polaroid frames, mild skew. Nostalgic warmth. | `⌘7` |

---

## How it composes

1. **Index** — Scans your library once (Vision feature-print + dominant Lab color + EXIF). Stores an encrypted SQLite index per library.
2. **Cluster** — Groups photos by the axis you choose: **Color**, **Mood** (semantic embedding), **Scene**, **People**, or **Time**.
3. **Compose** — Generates candidate layouts, scores each with a multi-factor aesthetic function (color harmony, edge alignment, aspect ratio balance), and returns the best.
4. **Weave** — Tiles enter in a left-to-right spring wave with deterministic micro-jitter. Every animation in the app shares one motion vocabulary.

---

## Features

- **Shuffle** — Press `Space` or the brass button. A new wall from the same library, instantly.
- **Pin to keep** — Double-click a tile to lock it. Shuffle again; locked photos stay, the rest reorganize around them.
- **Favorites** — Save a wall layout by name. Re-apply it later, or to a different library. Reproduces byte-identically thanks to deterministic seeds.
- **Export** — PNG at 3× retina resolution, vector-backed PDF, or one-click Snapshot to Desktop.
- **Two sources** — User folders (via NSOpenPanel) or Apple Photos Library (via PhotoKit) with incremental rescan.
- **HandSense** *(optional)* — Control the wall with hand gestures: open palm to spread, fist to gather, shake to shuffle. Camera video is processed in memory and never recorded.
- **Bilingual UI** — English and 简体中文, switchable live without restart.

---

## Get Loom

### Download (prebuilt)

Grab the latest build from [`dist/Loom-macos-arm64.zip`](./dist/Loom-macos-arm64.zip), unzip, and drag `Loom.app` to `/Applications`.

> Requires macOS 14+ (Sonoma) on Apple Silicon.

### Build from source

```bash
git clone https://github.com/blueberrycongee/loom.git
cd loom
open Package.swift   # Xcode 15+
# or
swift test           # run the pure-compute test suite
```

---

## Quick start

1. Open Loom.
2. Press `⌘O` to choose a photo folder, or select **Use Photos Library**.
3. Wait for the first index scan (progress shown as a live growing mini-wall).
4. Press `Space` — your first wall appears.
5. Keep pressing `Space`. Try `⌘1`–`⌘7` for different styles.

---

## Keyboard & gestures

| Key | Action |
|:---|:---|
| `Space` | Shuffle — generate a new wall |
| `⌘1` – `⌘7` | Switch style |
| `⌘O` | Pick library folder |
| `⌘S` | Save current wall as Favorite |
| `⌘E` | Export as PNG… |
| `⌘⇧P` | Export as PDF… |
| `⌘⇧S` | Snapshot wall to Desktop |
| `⌘⇧L` | Clear all tile locks |
| `Double-click tile` | Pin / unpin photo |
| `⌘,` | Settings (density, language, privacy, gestures) |

---

## Privacy

- **100% offline.** Vision, Core Image, and Core ML run on your Mac. Nothing uploads.
- **Encrypted index.** SQLite database is per-library and encrypted at rest.
- **Sandboxed.** One-click wipe in Settings → Privacy.
- **No camera cold-prompt.** HandSense only activates if you explicitly enable it; video frames are analyzed in memory and never persisted.

---

## Architecture

Loom is a SwiftPM package with seven layered modules and zero circular dependencies. The core (`LoomCore`) is pure Foundation — testable without a running app.

```
Loom (executable)
├── LoomUI      — SwiftUI scenes & views
├── LoomCompose — Shuffle orchestrator & clustering
├── LoomDesign  — Palette, motion, haptics, tokens
├── LoomLayout  — Layout engines & aesthetic scoring
├── LoomIndex   — SQLite store, Vision extractors, thumbnails
└── LoomCore    — Pure value types, RNG, models
```

For the full module graph, shuffle pipeline, and design-system principles, see [ARCHITECTURE.md](./ARCHITECTURE.md).

---

## Roadmap

- [x] Vision indexing & SQLite cache
- [x] Tapestry layout + Shuffle
- [x] Multi-style engines (Exhibit, Tapestry, Editorial, Gallery, Collage, Minimal, Vintage)
- [x] Mood / color / scene / people / time clustering
- [x] Pin-to-keep + Favorites with deterministic replay
- [x] PNG / PDF / Snapshot export
- [x] PhotoKit source + incremental rescan
- [x] HandSense gesture control
- [x] Bilingual UI (EN / 简体中文)

---

## License

MIT — see [LICENSE](./LICENSE).

---

<div align="center">

**[⬇ Download Loom.app](./dist/Loom-macos-arm64.zip)** · [Architecture](./ARCHITECTURE.md) · [Vision](./VISION.md)

</div>
