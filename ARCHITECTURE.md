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
