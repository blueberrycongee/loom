import CoreGraphics
import Foundation
import LoomCore

/// Exhibit — the signature Loom composition.
///
/// Feel: a hand-printed exhibit catalogue spread. Tiles are placed with
/// intent, not on a grid; a single anchor carries most of the weight, a
/// handful of supporting pieces drift around it, and accents float in the
/// negative space. Tiles don't fill the canvas — the breathing room is the
/// point.
///
/// Combined with the ``FeatheredEdge`` modifier at render time, the result
/// reads like photos ink-printed onto paper: soft edges, intentional
/// asymmetry, overlap where overlap tells a story.
///
/// Algorithm: templates define the composition's personality. Each
/// template is a list of "zones" — a normalised center, a target height
/// (as a fraction of canvas height), and a preferred aspect. At shuffle
/// time the engine picks a template deterministically on the seed, sorts
/// its zones by preferred aspect, sorts the shortlist's photos by actual
/// aspect, pairs them up greedily so no photo gets awkwardly letterboxed,
/// then jitters each zone's position by ±1.5% so two shuffles with the
/// same template never look identical.
public struct ExhibitEngine: LayoutEngine, Sendable {

    public let style: Style = .exhibit

    public init() {}

    public func compose(
        photos: [Photo],
        canvasSize: CGSize,
        rng: inout SeededRNG
    ) -> Wall {
        guard !photos.isEmpty, canvasSize.width > 0, canvasSize.height > 0 else {
            return Wall(style: .exhibit, axis: .color, seed: rng.state,
                        tiles: [], canvasSize: canvasSize)
        }

        // Templates swap orientation when the canvas is tall — the cascades
        // are designed for landscape; a portrait window gets the "breath"
        // templates rotated 90° in spirit.
        let pool = canvasSize.width >= canvasSize.height
            ? ExhibitTemplates.landscape
            : ExhibitTemplates.portrait
        let template = pool[Int(rng.next() % UInt64(pool.count))]

        // Pair zones with photos by aspect, greedily. Zones go biggest-first
        // (the anchor) so the visually heaviest tile gets picked first.
        let sortedZones = template.zones.sorted { $0.height > $1.height }
        let sortedPhotos = photos.sorted { p1, p2 in p1.aspect > p2.aspect }

        // Density-driven zone expansion.
        // At low density we use a subset of zones (fewer, larger tiles).
        // At high density we grow outward in layers: each layer uses fewer
        // zones (to avoid crowding), shrinks progressively, and drifts with
        // random angular offset so tiles spread rather than stack.
        let expandedZones: [ExhibitTemplates.Zone]
        if photos.count <= sortedZones.count {
            expandedZones = Array(sortedZones.prefix(photos.count))
        } else {
            var acc: [ExhibitTemplates.Zone] = []
            var layer = 0
            while acc.count < photos.count {
                let scale = max(0.28, pow(0.74, Double(layer)))
                // Fewer zones per layer as we go outward:
                // layer 0 → all, 1 → 6, 2 → 4, 3 → 3 …
                let take = max(2, sortedZones.count - layer * 2)
                let layerZones = Array(sortedZones.prefix(take))
                let baseAngle = rng.double(in: 0..<(2 * .pi))
                for (idx, zone) in layerZones.enumerated() {
                    if acc.count >= photos.count { break }
                    let angle = baseAngle + Double(idx) * (.pi / 3) + rng.double(in: -0.15..<0.15)
                    let dist = Double(layer) * 0.06 + rng.double(in: -0.015..<0.015)
                    let cx = max(0.08, min(0.92, zone.centerX + cos(angle) * dist))
                    let cy = max(0.08, min(0.92, zone.centerY + sin(angle) * dist))
                    acc.append(ExhibitTemplates.Zone(
                        centerX: cx,
                        centerY: cy,
                        height: zone.height * scale,
                        preferredAspect: zone.preferredAspect
                    ))
                }
                layer += 1
            }
            expandedZones = acc
        }

        // Build tiles paired with their zone height so we can z-sort
        // biggest-first. This keeps hero tiles in front and prevents small
        // accent tiles from visually obscuring the anchor.
        var tileDrafts: [(photo: Photo, zone: ExhibitTemplates.Zone)] = []
        var usedIDs = Set<PhotoID>()
        for zone in expandedZones {
            let idx = bestMatchIndex(for: zone, in: sortedPhotos, excluding: usedIDs)
            let photo = sortedPhotos[idx]
            usedIDs.insert(photo.id)
            tileDrafts.append((photo, zone))
        }

        // Sort by zone height descending so large tiles paint on top.
        tileDrafts.sort { $0.zone.height > $1.zone.height }

        var tiles: [Tile] = []
        for (i, draft) in tileDrafts.enumerated() {
            let zone = draft.zone
            let photo = draft.photo

            let tileH = canvasSize.height * zone.height
            let tileW = tileH * CGFloat(photo.aspect)

            let jitterX = rng.double(in: -0.015..<0.015) * canvasSize.width
            let jitterY = rng.double(in: -0.015..<0.015) * canvasSize.height
            let centerX = canvasSize.width  * zone.centerX + jitterX
            let centerY = canvasSize.height * zone.centerY + jitterY

            let rotation = max(-0.035, min(0.035, rng.gaussian() * 0.012))

            tiles.append(Tile(
                photoID: photo.id,
                frame: CGRect(
                    x: centerX - tileW / 2,
                    y: centerY - tileH / 2,
                    width: tileW,
                    height: tileH
                ),
                rotation: rotation,
                z: i
            ))
        }

        return Wall(
            style: .exhibit,
            axis: .color,
            seed: rng.state,
            tiles: tiles,
            canvasSize: canvasSize
        )
    }

    /// Pick the unused photo whose aspect is closest to the zone's
    /// preferred aspect. Prevents a tall zone from getting a landscape
    /// photo that would have to be letterboxed or cropped.
    private func bestMatchIndex(
        for zone: ExhibitTemplates.Zone,
        in photos: [Photo],
        excluding used: Set<PhotoID>
    ) -> Int {
        var best = 0
        var bestDelta = Double.infinity
        for (i, p) in photos.enumerated() {
            if used.contains(p.id) { continue }
            let delta = abs(p.aspect - zone.preferredAspect)
            if delta < bestDelta {
                bestDelta = delta
                best = i
            }
        }
        return best
    }
}

/// Composition templates — hand-written, not procedural. Each one is a
/// deliberate arrangement with its own personality. Per-shuffle jitter
/// gives variation; the set grows over time.
public enum ExhibitTemplates {

    public struct Zone: Sendable {
        public let centerX: Double        // 0…1 in canvas width
        public let centerY: Double        // 0…1 in canvas height
        public let height: Double         // tile height as fraction of canvas height
        public let preferredAspect: Double

        public init(centerX: Double, centerY: Double, height: Double, preferredAspect: Double) {
            self.centerX = centerX
            self.centerY = centerY
            self.height = height
            self.preferredAspect = preferredAspect
        }
    }

    public struct Template: Sendable {
        public let name: String
        public let zones: [Zone]
        public init(name: String, zones: [Zone]) {
            self.name = name
            self.zones = zones
        }
    }

    /// Composition 1 — cascade descending from upper-right toward a large
    /// anchor at lower-left. Mirrors the reference image's feel.
    public static let cascadeLeft = Template(name: "cascade-left", zones: [
        Zone(centerX: 0.22, centerY: 0.74, height: 0.34, preferredAspect: 1.45),   // anchor LL
        Zone(centerX: 0.60, centerY: 0.36, height: 0.28, preferredAspect: 1.00),   // hero-right
        Zone(centerX: 0.28, centerY: 0.28, height: 0.22, preferredAspect: 0.78),   // portrait mid-left
        Zone(centerX: 0.80, centerY: 0.60, height: 0.20, preferredAspect: 1.10),
        Zone(centerX: 0.54, centerY: 0.68, height: 0.16, preferredAspect: 1.30),
        Zone(centerX: 0.72, centerY: 0.82, height: 0.14, preferredAspect: 1.10),
        Zone(centerX: 0.54, centerY: 0.12, height: 0.08, preferredAspect: 1.70),   // small top
        Zone(centerX: 0.14, centerY: 0.50, height: 0.14, preferredAspect: 1.15)
    ])

    /// Composition 2 — mirror of cascadeLeft. Anchor lower-right, cascade
    /// from upper-left.
    public static let cascadeRight = Template(name: "cascade-right", zones:
        cascadeLeft.zones.map {
            Zone(centerX: 1.0 - $0.centerX,
                 centerY: $0.centerY,
                 height: $0.height,
                 preferredAspect: $0.preferredAspect)
        }
    )

    /// Composition 3 — central anchor, supports orbiting in the negative
    /// space. Calmer, symmetric, breathier.
    public static let breath = Template(name: "breath", zones: [
        Zone(centerX: 0.44, centerY: 0.52, height: 0.40, preferredAspect: 1.30),   // center anchor
        Zone(centerX: 0.16, centerY: 0.30, height: 0.18, preferredAspect: 0.85),
        Zone(centerX: 0.80, centerY: 0.30, height: 0.20, preferredAspect: 1.10),
        Zone(centerX: 0.76, centerY: 0.72, height: 0.14, preferredAspect: 1.00),
        Zone(centerX: 0.14, centerY: 0.68, height: 0.14, preferredAspect: 1.20),
        Zone(centerX: 0.62, centerY: 0.86, height: 0.10, preferredAspect: 1.50),
        Zone(centerX: 0.88, centerY: 0.54, height: 0.08, preferredAspect: 1.00)
    ])

    /// Composition 4 — two-anchor diptych with a constellation of small
    /// accents floating between them. Works well for ~9 photos.
    public static let diptych = Template(name: "diptych", zones: [
        Zone(centerX: 0.26, centerY: 0.40, height: 0.34, preferredAspect: 0.85),
        Zone(centerX: 0.72, centerY: 0.60, height: 0.34, preferredAspect: 1.25),
        Zone(centerX: 0.50, centerY: 0.20, height: 0.10, preferredAspect: 1.60),
        Zone(centerX: 0.50, centerY: 0.80, height: 0.10, preferredAspect: 1.40),
        Zone(centerX: 0.12, centerY: 0.78, height: 0.12, preferredAspect: 1.00),
        Zone(centerX: 0.88, centerY: 0.22, height: 0.12, preferredAspect: 1.00),
        Zone(centerX: 0.50, centerY: 0.50, height: 0.12, preferredAspect: 0.95),   // bridge accent
        Zone(centerX: 0.38, centerY: 0.88, height: 0.08, preferredAspect: 1.80)
    ])

    public static let landscape: [Template] = [cascadeLeft, cascadeRight, breath, diptych]

    /// Portrait canvases: rotate the cascades so the anchor drops to the
    /// bottom and supports rise above it. We reuse Breath as-is because
    /// it's axis-neutral.
    public static let portrait: [Template] = [
        Template(name: "cascade-vertical", zones: [
            Zone(centerX: 0.50, centerY: 0.82, height: 0.26, preferredAspect: 1.30),   // anchor bottom
            Zone(centerX: 0.30, centerY: 0.48, height: 0.20, preferredAspect: 0.85),
            Zone(centerX: 0.72, centerY: 0.36, height: 0.22, preferredAspect: 1.10),
            Zone(centerX: 0.24, centerY: 0.22, height: 0.12, preferredAspect: 1.40),
            Zone(centerX: 0.62, centerY: 0.14, height: 0.10, preferredAspect: 1.00),
            Zone(centerX: 0.80, centerY: 0.62, height: 0.10, preferredAspect: 1.00),
            Zone(centerX: 0.18, centerY: 0.66, height: 0.08, preferredAspect: 1.20)
        ]),
        breath
    ]
}
