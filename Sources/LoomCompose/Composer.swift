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
        lockedPhotoIDs: Set<PhotoID> = [],
        rng: inout SeededRNG
    ) -> Wall {
        guard !photos.isEmpty, canvasSize.width > 2, canvasSize.height > 2 else {
            return Wall(style: style, axis: axis, seed: rng.state, tiles: [],
                        canvasSize: canvasSize)
        }

        let engine = LayoutRegistry.engine(for: style)
        let targetCount = targetTileCount(canvasSize: canvasSize, libraryCount: photos.count)

        // Step 1: lift locked photos out of the pool so they are guaranteed
        // to appear in the shortlist. The clusterer operates on the
        // remainder; locks go in first.
        let lockedPhotos = photos.filter { lockedPhotoIDs.contains($0.id) }
        let freePool     = photos.filter { !lockedPhotoIDs.contains($0.id) }
        let freeTarget   = max(0, targetCount - lockedPhotos.count)

        // Step 2+3: cluster + pick on the active axis (against the free pool).
        let freeShortlist: [Photo]
        switch axis {
        case .color:
            freeShortlist = sampleFromColorClusters(photos: freePool, count: freeTarget, rng: &rng)
        case .mood:
            freeShortlist = sampleFromFeaturePrintClusters(photos: freePool, count: freeTarget, rng: &rng)
        case .scene, .people, .time:
            freeShortlist = sampleUniform(photos: freePool, count: freeTarget, rng: &rng)
        }

        // Merge: locked first so the engine biases them to earlier tiles
        // (Editorial's hero selection, Tapestry's first rows) — the visible
        // promise of "your pins stay".
        let shortlist = lockedPhotos + freeShortlist

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

    /// Color-cluster + weighted pick + luminance-stratified in-cluster sample.
    private func sampleFromColorClusters(
        photos: [Photo], count: Int, rng: inout SeededRNG
    ) -> [Photo] {
        let clusters = ColorClusterer(k: 6).cluster(photos, rng: &rng)
        guard !clusters.isEmpty else {
            return sampleUniform(photos: photos, count: count, rng: &rng)
        }
        let byID = Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0) })

        // Weighted pick: larger, more-cohesive clusters win. Cohesion is
        // "mean ΔE from centroid" — lower is better, so invert.
        let weights: [Double] = clusters.map { c in
            Double(c.memberIDs.count) * (1.0 / (1.0 + c.cohesion))
        }
        guard let picked = weightedPick(clusters, weights: weights, rng: &rng) else {
            return sampleUniform(photos: photos, count: count, rng: &rng)
        }
        let members = picked.memberIDs.compactMap { byID[$0] }
        return luminanceStratifiedSample(members, count: count, rng: &rng)
    }

    /// Feature-print cluster + weighted pick + in-cluster diversity sample.
    private func sampleFromFeaturePrintClusters(
        photos: [Photo], count: Int, rng: inout SeededRNG
    ) -> [Photo] {
        let clusters = FeaturePrintClusterer(k: 6).cluster(photos, rng: &rng)
        guard !clusters.isEmpty else {
            // No feature-prints yet — fall through to color clustering so
            // the user still gets a cohesive wall, just not a mood one.
            return sampleFromColorClusters(photos: photos, count: count, rng: &rng)
        }
        let byID = Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0) })

        let weights: [Double] = clusters.map { c in
            Double(c.memberIDs.count) * (1.0 / (1.0 + c.cohesion))
        }
        guard let picked = weightedPick(clusters, weights: weights, rng: &rng) else {
            return sampleUniform(photos: photos, count: count, rng: &rng)
        }
        let members = picked.memberIDs.compactMap { byID[$0] }
        // Still stratify by luminance — photos in the same mood cluster can
        // share palette but we want the wall itself to carry light/dark
        // contrast for rhythm.
        return luminanceStratifiedSample(members, count: count, rng: &rng)
    }

    // MARK: — Shared sampling helpers

    private func weightedPick<T>(_ items: [T], weights: [Double], rng: inout SeededRNG) -> T? {
        let total = weights.reduce(0, +)
        guard total > 0, !items.isEmpty else { return nil }
        var r = rng.unit() * total
        for (i, w) in weights.enumerated() {
            r -= w
            if r <= 0 { return items[i] }
        }
        return items.last
    }

    /// Sort by L*, divide into `count` equal bins, pick one photo per bin.
    /// Guarantees the wall has light-to-dark spread, feeding the contrast
    /// scorer with useful variance.
    private func luminanceStratifiedSample(
        _ members: [Photo], count: Int, rng: inout SeededRNG
    ) -> [Photo] {
        guard !members.isEmpty else { return [] }
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
