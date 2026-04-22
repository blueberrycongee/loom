import CoreGraphics
import Foundation
import LoomCore

/// Tapestry — Loom's default style.
///
/// Output: photos packed into justified horizontal rows, like the warp and
/// weft of a textile. Each row's target height varies slightly (within ±12%
/// of the canvas baseline) to break the uniformity that makes Masonry-style
/// grids feel robotic. Within each row, photos are reordered greedily so
/// adjacent tiles don't share an aspect bucket — we want portrait–landscape
/// alternation, not portrait–portrait–portrait–landscape.
///
/// Packing algorithm:
///   1. Derive a baseline row height from canvas height and the target row
///      count (`max(3, photos.count / ~4)`).
///   2. Walk the shortlist, accumulating into a row. Row finalises when
///      combined width (at current target height) exceeds canvas width.
///   3. Justify that row — scale every tile in it down so the row fits the
///      canvas width exactly; gutters stay fixed.
///   4. Stash the used actual height, advance y, repeat.
///   5. Trailing row: cap at baseline height instead of stretching, so a
///      short last row doesn't become artificially tall.
public struct TapestryEngine: LayoutEngine, Sendable {

    public let style: Style = .tapestry

    public let gutter: CGFloat
    public let baselineRatio: Double
    public let heightJitter: Double

    public init(
        gutter: CGFloat = 8,
        baselineRatio: Double = 0.26,
        heightJitter: Double = 0.12
    ) {
        self.gutter = gutter
        self.baselineRatio = baselineRatio
        self.heightJitter = heightJitter
    }

    public func compose(
        photos: [Photo],
        canvasSize: CGSize,
        rng: inout SeededRNG
    ) -> Wall {
        guard !photos.isEmpty, canvasSize.width > 0, canvasSize.height > 0 else {
            return Wall(
                style: .tapestry,
                axis: .color,
                seed: rng.state,
                tiles: [],
                canvasSize: canvasSize
            )
        }

        let ordered = variegate(photos, rng: &rng)
        let baseline = canvasSize.height * CGFloat(baselineRatio)

        var tiles: [Tile] = []
        var y: CGFloat = 0
        var row: [(Photo, CGFloat)] = []   // (photo, width at current target)
        var rowWidth: CGFloat = 0
        var targetHeight = jitter(baseline, rng: &rng)
        let wall = canvasSize.width

        func finalise(stretch: Bool) {
            guard !row.isEmpty else { return }
            let gutters = CGFloat(max(0, row.count - 1)) * gutter
            let tilesTotal = row.reduce(CGFloat(0)) { $0 + $1.1 }
            let scale: CGFloat
            if stretch {
                scale = (wall - gutters) / tilesTotal
            } else {
                // Trailing row; keep aspect at current target height, clamp to
                // canvas width if needed.
                scale = min(1.0, (wall - gutters) / tilesTotal)
            }

            var x: CGFloat = 0
            let rowHeight = (targetHeight * scale).rounded()
            for (p, w) in row {
                let tileW = (w * scale).rounded()
                let tileH = rowHeight
                tiles.append(Tile(
                    photoID: p.id,
                    frame: CGRect(x: x, y: y, width: tileW, height: tileH),
                    rotation: 0,
                    z: 0
                ))
                x += tileW + gutter
            }
            y += rowHeight + gutter
            row.removeAll(keepingCapacity: true)
            rowWidth = 0
            targetHeight = jitter(baseline, rng: &rng)
        }

        for p in ordered {
            let w = CGFloat(p.aspect) * targetHeight
            row.append((p, w))
            rowWidth += w + gutter
            // -gutter: we don't add a trailing gutter when measuring
            let widthWithoutTrailingGutter = rowWidth - gutter
            if widthWithoutTrailingGutter >= wall {
                finalise(stretch: true)
            }
        }
        finalise(stretch: false)

        return Wall(
            style: .tapestry,
            axis: .color,
            seed: rng.state,
            tiles: tiles,
            canvasSize: canvasSize
        )
    }

    // MARK: — Ordering: aspect-bucket alternation

    /// Greedy reordering: next photo is picked so its aspect bucket differs
    /// from the previous one. With 4+ buckets the constraint almost always
    /// has room; when it doesn't, we fall back to insertion order.
    private func variegate(_ photos: [Photo], rng: inout SeededRNG) -> [Photo] {
        guard photos.count > 2 else { return photos }

        // Shuffle first so the "same input" case doesn't look identical.
        var pool = photos
        for i in stride(from: pool.count - 1, to: 0, by: -1) {
            let j = Int(rng.next() % UInt64(i + 1))
            pool.swapAt(i, j)
        }

        var out: [Photo] = []
        out.reserveCapacity(pool.count)
        var lastBucket: Aspect.Bucket?
        while !pool.isEmpty {
            let pickIdx: Int
            if let last = lastBucket,
               let idx = pool.firstIndex(where: { Aspect.bucket(of: $0.aspect) != last }) {
                pickIdx = idx
            } else {
                pickIdx = 0
            }
            let p = pool.remove(at: pickIdx)
            out.append(p)
            lastBucket = Aspect.bucket(of: p.aspect)
        }
        return out
    }

    private func jitter(_ base: CGFloat, rng: inout SeededRNG) -> CGFloat {
        let delta = heightJitter
        let factor = 1.0 + rng.double(in: -delta..<delta)
        return base * CGFloat(factor)
    }
}
