import CoreGraphics
import Foundation
import LoomCore
import LoomLayout

/// The Shuffle orchestrator. Turns a library + style + seed into the best
/// wall we can produce in a few hundred milliseconds.
///
/// Pipeline:
///
///   1. **Size** — decide how many tiles to aim for, from canvas area and a
///      tile-area baseline (smaller windows get fewer tiles, not tiny ones).
///   2. **Cluster** — group all photos on the active axis. For `color`, this
///      is ``ColorClusterer`` in Lab. Other axes fall back to one big bucket
///      until M4 lands mood embeddings.
///   3. **Pick a cluster** — weighted by size × cohesion. Large + unified =
///      high weight. Small clusters are still possible; they give the rare
///      all-blue wall that surprises the user.
///   4. **Sample a shortlist** — `k` distinct photos, biased to span the
///      cluster's L* range so the wall has luminance variety.
///   5. **Generate candidates** — run the engine N times with sub-seeds.
///   6. **Score + pick** — `AestheticScore.composite` wins.
public struct Composer {

    public let candidates: Int
    public let baselineTileArea: CGFloat

    public init(candidates: Int = 4, baselineTileArea: CGFloat = 220 * 220) {
        self.candidates = max(1, candidates)
        self.baselineTileArea = baselineTileArea
    }

    public func weave(
        photos: [Photo],
        style: Style,
        axis: ClusterAxis,
        canvasSize: CGSize,
        rng: inout SeededRNG
    ) -> Wall {
        guard !photos.isEmpty, canvasSize.width > 2, canvasSize.height > 2 else {
            return Wall(style: style, axis: axis, seed: rng.state, tiles: [],
                        canvasSize: canvasSize)
        }

        let engine = LayoutRegistry.engine(for: style)
        let targetCount = targetTileCount(canvasSize: canvasSize, libraryCount: photos.count)

        // Step 2+3: cluster + pick. For non-color axes we punt to 'all photos'
        // until M4 brings in embeddings.
        let shortlist: [Photo]
        switch axis {
        case .color:
            shortlist = sampleFromClusters(photos: photos, count: targetCount, rng: &rng)
        case .mood, .scene, .people, .time:
            shortlist = sampleUniform(photos: photos, count: targetCount, rng: &rng)
        }

        // Step 4+5+6: generate candidates with sub-seeds, score, pick best.
        var best: Wall?
        var bestScore: Double = -.infinity
        for _ in 0..<candidates {
            var subrng = SeededRNG(seed: rng.next())
            let wall = engine.compose(
                photos: shortlist,
                canvasSize: canvasSize,
                rng: &subrng
            )
            let score = AestheticScore.score(wall: wall, photos: shortlist).composite
            if score > bestScore {
                bestScore = score
                best = wall
            }
        }

        // Re-stamp axis and seed for the caller's records — Composer's seed,
        // not the engine's sub-seed.
        let finalWall = best ?? Wall(
            style: style, axis: axis, seed: rng.state, tiles: [],
            canvasSize: canvasSize
        )
        return Wall(
            id: finalWall.id,
            style: style,
            axis: axis,
            seed: rng.state,
            tiles: finalWall.tiles,
            canvasSize: finalWall.canvasSize,
            composedAt: Date()
        )
    }

    // MARK: — Sizing

    private func targetTileCount(canvasSize: CGSize, libraryCount: Int) -> Int {
        let area = canvasSize.width * canvasSize.height
        let raw = Int((area / baselineTileArea).rounded())
        return max(6, min(libraryCount, min(64, raw)))
    }

    // MARK: — Sampling strategies

    private func sampleUniform(
        photos: [Photo], count: Int, rng: inout SeededRNG
    ) -> [Photo] {
        let idx = rng.sampleIndices(count, from: photos.count)
        return idx.map { photos[$0] }
    }

    /// Cluster + weighted pick + in-cluster luminance-spread sample.
    private func sampleFromClusters(
        photos: [Photo], count: Int, rng: inout SeededRNG
    ) -> [Photo] {
        let clusters = ColorClusterer(k: 6).cluster(photos, rng: &rng)
        guard !clusters.isEmpty else {
            return sampleUniform(photos: photos, count: count, rng: &rng)
        }

        // Weighted pick. Favor larger, more-cohesive clusters. Cohesion is
        // "mean ΔE from centroid" — *lower* is better, so invert.
        let byID = Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0) })
        let weights: [Double] = clusters.map { c in
            let size = Double(c.memberIDs.count)
            let cohesion = 1.0 / (1.0 + c.cohesion)
            return size * cohesion
        }
        let total = weights.reduce(0, +)
        guard total > 0 else {
            return sampleUniform(photos: photos, count: count, rng: &rng)
        }
        var r = rng.unit() * total
        var picked = clusters[0]
        for (i, c) in clusters.enumerated() {
            r -= weights[i]
            if r <= 0 { picked = c; break }
        }

        let members = picked.memberIDs.compactMap { byID[$0] }
        guard !members.isEmpty else {
            return sampleUniform(photos: photos, count: count, rng: &rng)
        }

        // Luminance-stratified sample: sort by L*, divide into `count` bins,
        // pick one photo per bin. Gives the wall guaranteed L* spread so
        // contrast scores stay decent.
        let sorted = members.sorted { $0.dominantColor.l < $1.dominantColor.l }
        if sorted.count <= count { return sorted }
        var out: [Photo] = []
        out.reserveCapacity(count)
        for i in 0..<count {
            let lower = Int(Double(i)     * Double(sorted.count) / Double(count))
            let upper = Int(Double(i + 1) * Double(sorted.count) / Double(count))
            let bin = sorted[lower..<max(upper, lower + 1)]
            let pick = Int(rng.next() % UInt64(bin.count))
            out.append(bin[bin.startIndex + pick])
        }
        return out
    }
}
