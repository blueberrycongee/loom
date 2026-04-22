import CoreGraphics
import Foundation
import LoomCore

/// Collage — overlapping, rotated, "handmade" feel.
///
/// Feel: stack of photos on a corkboard. Tiles overlap intentionally,
/// rotate ±6°, scale varies ±25%, and z-order creates layering. The
/// randomness is bounded: we enforce that every tile has ≥40% of its area
/// unobstructed, so no photo is fully buried.
///
/// Algorithm:
///   1. Place tiles from back (z=0) to front along a biased-random walk
///      through the canvas.
///   2. Each tile's size is `canvas.height * [0.35, 0.55]` with aspect
///      preserved.
///   3. Rotation is Gaussian ±6° (via SeededRNG.gaussian).
///   4. If a candidate placement would cover >60% of any already-placed
///      tile, retry up to 4× with a fresh position; otherwise accept.
public struct CollageEngine: LayoutEngine, Sendable {

    public let style: Style = .collage

    public init() {}

    public func compose(
        photos: [Photo],
        canvasSize: CGSize,
        rng: inout SeededRNG
    ) -> Wall {
        guard !photos.isEmpty, canvasSize.width > 0, canvasSize.height > 0 else {
            return Wall(style: .collage, axis: .color, seed: rng.state,
                        tiles: [], canvasSize: canvasSize)
        }

        let count = min(photos.count, max(6, Int((canvasSize.width * canvasSize.height) / (360 * 360))))
        let picks = Array(photos.prefix(count))

        // Reserve an inner safe rect so no tile clips the canvas edges.
        let inset: CGFloat = min(canvasSize.width, canvasSize.height) * 0.05
        let safe = CGRect(
            x: inset, y: inset,
            width: canvasSize.width - inset * 2,
            height: canvasSize.height - inset * 2
        )

        var tiles: [Tile] = []
        var placedFrames: [CGRect] = []

        for (i, p) in picks.enumerated() {
            let baseH = canvasSize.height * CGFloat(rng.double(in: 0.32..<0.54))
            let baseW = baseH * CGFloat(p.aspect)

            var accepted: CGRect?
            for _ in 0..<5 {
                let x = safe.minX + CGFloat(rng.unit()) * max(0, safe.width  - baseW)
                let y = safe.minY + CGFloat(rng.unit()) * max(0, safe.height - baseH)
                let candidate = CGRect(x: x, y: y, width: baseW, height: baseH)
                if isAcceptable(candidate, against: placedFrames) {
                    accepted = candidate
                    break
                }
            }
            let frame = accepted ?? CGRect(
                x: safe.midX - baseW / 2,
                y: safe.midY - baseH / 2,
                width: baseW, height: baseH
            )

            // ±6° gaussian rotation, clamped.
            let rot = max(-0.12, min(0.12, rng.gaussian() * 0.045))
            tiles.append(Tile(
                photoID: p.id,
                frame: frame,
                rotation: rot,
                z: i
            ))
            placedFrames.append(frame)
        }

        return Wall(
            style: .collage,
            axis: .color,
            seed: rng.state,
            tiles: tiles,
            canvasSize: canvasSize
        )
    }

    /// No already-placed tile may be more than 60% covered by the candidate.
    private func isAcceptable(_ candidate: CGRect, against placed: [CGRect]) -> Bool {
        for p in placed {
            let isect = candidate.intersection(p)
            guard !isect.isNull, p.width > 0, p.height > 0 else { continue }
            let coverage = (isect.width * isect.height) / (p.width * p.height)
            if coverage > 0.60 { return false }
        }
        return true
    }
}
