# Loom — Architecture

Loom is a SwiftPM package with **seven modules**. Each layer depends only on the ones beneath it; there are no cycles. This keeps the core pure and testable without a running app.

## Module graph

```
                    ┌──────────────┐
                    │     Loom     │   executable · @main · AppKit bridges
                    └──────┬───────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
  ┌─────▼─────┐     ┌──────▼──────┐   ┌───────▼──────┐
  │  LoomUI   │     │ LoomCompose │   │  LoomDesign  │   SwiftUI, tokens
  └─────┬─────┘     └──────┬──────┘   └──────┬───────┘
        │                  │                 │
        ├──────────────────┤                 │
        │                  │                 │
  ┌─────▼─────┐     ┌──────▼──────┐          │
  │ LoomIndex │     │ LoomLayout  │          │
  └─────┬─────┘     └──────┬──────┘          │
        │                  │                 │
        └────────┬─────────┴─────────────────┘
                 │
           ┌─────▼──────┐
           │  LoomCore  │   pure value types · RNG · no platform deps
           └────────────┘
```

- **LoomCore** — `Photo`, `Wall`, `Tile`, `Style`, `ClusterAxis`, `LabColor`, `FeaturePrint`, `SeededRNG`, `Aspect`, `AppModel`. Foundation only. No SwiftUI, no Vision, no Core Image. This is what the test suite exercises by default.
- **LoomDesign** — palette, typography, motion, haptics, grain overlay, radius & spacing tokens, shadow modifiers. SwiftUI.
- **LoomIndex** — folder scanner, SQLite store + migrations, EXIF / Vision feature-print / Core Image color extractors, thumbnail cache, indexer actor. Links `libsqlite3`.
- **LoomLayout** — the `LayoutEngine` protocol, `TapestryEngine`, the `AestheticScore` scorer trio.
- **LoomCompose** — the Shuffle orchestrator (`Composer.weave`) and the `ColorClusterer` (k-means++ in Lab).
- **LoomUI** — SwiftUI scenes and views. `RootScene` dispatches between `LandingView`, `IndexingView`, and `WallScene`. `WallCanvas` renders a `Wall`, `WallChrome` is the floating toolbar.
- **Loom** — the `@main` executable. Owns `LibraryCoordinator`, which bridges `NSOpenPanel` to the indexer and pushes state into `AppModel`.

## Shuffle pipeline

```
   User presses Space / ⌘N / Shuffle button
                  │
                  ▼
   NotificationCenter .loomShuffle
                  │
                  ▼
   WallScene.shuffleNow()
      ├── seed = now ⊕ style.hashValue
      ├── rng  = SeededRNG(seed)
      ├── canvasSize = effectiveCanvas(geo.size)
      └── wall = Composer.weave(…)
             │
             ▼
      Composer.weave
      ├── targetCount = canvas / baselineTile
      ├── clusters = ColorClusterer(k=6).cluster(photos)     // or uniform for non-color
      ├── picked   = clusters.weightedPick(by: size × cohesion)
      ├── shortlist = luminance-stratified sample from picked
      ├── for _ in 0..<candidates:
      │       subRNG = SeededRNG(rng.next())
      │       candidate = TapestryEngine.compose(shortlist, canvasSize, subRNG)
      │       score     = AestheticScore.score(candidate, shortlist).composite
      │       bestSoFar = max(bestSoFar, candidate)
      └── return bestSoFar
                  │
                  ▼
   withAnimation(.weave) { app.wall = wall }
   Haptics.shuffle()
                  │
                  ▼
   WallCanvas sees the new Wall, diffs tiles by photoID,
   matched tiles slide; new tiles scale-fade in; removed
   tiles scale-fade out.
```

## Index pipeline

```
   User picks folder (NSOpenPanel)
                  │
                  ▼
   LibraryBookmark.save(url)                 // security-scoped bookmark
                  │
                  ▼
   Indexer actor run()
      ├── FolderSource.discover(root)        // recursive walk, skip hidden/packages
      ├── for each url:
      │     ├── PhotoIdentity.id(url)          // SHA-256(path)[0..16]
      │     ├── if known && mtime ≤ indexed_at: skip
      │     ├── MetadataReader.read(url)       // EXIF via ImageIO, no full decode
      │     ├── ColorAnalyzer.analyze(url)     // thumbnail → CIAreaAverage → Lab + CCT
      │     ├── VisionFeatures.extract(url)    // VN feature-print, 768-dim L2-norm
      │     └── batch.append(photo)
      ├── every 64 photos: PhotoStore.upsert(batch)       // one transaction
      └── bake .grid thumbnails for the full library
                  │
                  ▼
   AsyncStream<IndexProgress> → AppModel.phase = .ready
                  │
                  ▼
   WallScene.onAppear → auto-shuffle
```

## Design system principles

Every view in LoomUI pulls its colors from `Palette`, type from `LoomType`, animations from `LoomMotion`, and shadows from `LoomShadow.*`. Nothing is hard-coded. Changing the app's feel — say, warming the brass by two ticks — is a one-line edit in `Palette.swift`.

## Randomness

`SeededRNG` is SplitMix64. Every `Wall` carries the top-level seed the Composer used to build it, so a favorited wall reproduces byte-for-byte. The composer derives sub-seeds for internal loops, so a single user-visible Shuffle explores the candidate space deterministically given its top seed.

## Motion vocabulary — `Weave`

One file (`LoomDesign/Weave.swift`) owns every per-tile timing in the app:

- `Weave.stagger(normalizedPosition:, index:)` — maps a tile's position along the wave direction to a delay, with deterministic ±20ms jitter keyed on `index` so the jitter is stable across re-renders within a wall.
- `Weave.settleAnimation` / `enterAnimation` / `exitAnimation` — the three springs / ease-outs that cover every tile event. Enters are crisper than settles; exits are non-springy ease-outs so leaving tiles don't bounce goodbye.
- `Weave.insertTransition(delay:)` — composed `AnyTransition` that respects the wave.
- `Weave.driftPhase(time:, index:, period:)` — low-frequency deterministic 0…1 oscillation used by the ambient landing tapestry and the noise-texture breathe.

Any screen that animates tiles routes through these primitives — retuning the whole app's feel is a single-file edit.

## Permissions — natural TCC flow

Loom never surfaces macOS's TCC prompt cold. The flow:

- Folder picker: the NSOpenPanel *is* the permission grant — no extra dialog, security-scoped bookmark persisted for next launch.
- Photos library: on tap, we read `PHPhotoLibrary.authorizationStatus`:
  - `.notDetermined` → show the in-app `PermissionSheet(.photosExplainer)` — three privacy bullets in the app's voice. Only if the user says Allow do we call `PHPhotoLibrary.requestAuthorization`. If they say Not Now, the system dialog is never triggered and they can return later.
  - `.denied` → `PermissionSheet(.photosDenied)` deep-links to System Settings via `x-apple.systempreferences:com.apple.preference.security?Privacy_Photos` rather than dead-ending on an Allow button that can't work.
  - `.restricted` → offers a folder-mode fallback for MDM / parental-controls machines.

The `PermissionPrompt` enum lives in `LoomCore` so the core stays AppKit-free; the sheet UI lives in `LoomUI`; the state transitions happen on `LibraryCoordinator`. Info.plist usage-description strings follow Apple HIG: benefit first, guarantee second — every TCC dialog arrives with context.
