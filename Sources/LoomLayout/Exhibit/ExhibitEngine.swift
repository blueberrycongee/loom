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

        // Density-driven zone count. At low density we drop zones so the
        // remaining tiles stay large; at high density we scale zones down
        // proportionally to fit more photos while keeping the template feel.
        let zoneCount = min(sortedZones.count, max(1, photos.count))
        let usedZones = Array(sortedZones.prefix(zoneCount))
        let densityScale = zoneCount < sortedZones.count
            ? 1.0
            : sqrt(Double(sortedZones.count) / Double(photos.count))

        var tiles: [Tile] = []
        for i in 0..<zoneCount {
            let zone = usedZones[i]
            let photo = sortedPhotos[bestMatchIndex(
                for: zone,
                in: sortedPhotos,
                excluding: Set(tiles.map { $0.photoID })
            )]

            let tileH = canvasSize.height * zone.height * CGFloat(densityScale)
            let tileW = tileH * CGFloat(photo.aspect)

            let jitterX = rng.double(in: -0.015..<0.015) * canvasSize.width
            let jitterY = rng.double(in: -0.015..<0.015) * canvasSize.height
            let centerX = canvasSize.width  * zone.centerX + jitterX
            let centerY = canvasSize.height * zone.centerY + jitterY

            // Mild rotation — paper tiles can't lie perfectly flat.
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
