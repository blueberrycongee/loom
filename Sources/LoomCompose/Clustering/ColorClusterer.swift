import Foundation
import LoomCore

/// Groups photos into *color families* using k-means in CIE L*a*b*.
///
/// Why k-means here instead of HDBSCAN?
///   • Libraries of a few hundred photos don't need HDBSCAN's density
///     sophistication — the color space is inherently smooth.
///   • k-means gives a fixed, tunable number of groupings (one per "mood",
///     roughly), which is what the composer wants when picking a shortlist.
///   • Seeding from the RNG makes every Shuffle reach for a different
///     starting configuration, so the same library produces different walls.
///
/// We use **k-means++** for initialization: it avoids degenerate starts and
/// converges in 2–3× fewer iterations than uniform random seeding.
public struct ColorClusterer {

    public struct Cluster: Identifiable, Sendable {
        public let id: Int
        public let centroid: LabColor
        public let memberIDs: [PhotoID]
        /// Mean intra-cluster ΔE — lower means more unified.
        public let cohesion: Double
    }

    public let k: Int

    public init(k: Int = 6) {
        self.k = max(1, k)
    }

    public func cluster(
        _ photos: [Photo],
        rng: inout SeededRNG,
        maxIterations: Int = 25
    ) -> [Cluster] {
        guard !photos.isEmpty else { return [] }
        let realK = min(k, photos.count)
        if realK == 1 {
            return [Cluster(
                id: 0,
                centroid: photos.first!.dominantColor,
                memberIDs: photos.map(\.id),
                cohesion: 0
            )]
        }

        var centroids = kmeansPlusPlusInit(photos: photos, k: realK, rng: &rng)
        var assignment = Array(repeating: 0, count: photos.count)

        for _ in 0..<maxIterations {
            var changed = false
            for (i, p) in photos.enumerated() {
                let newLabel = nearestCentroid(color: p.dominantColor, in: centroids)
                if assignment[i] != newLabel {
                    assignment[i] = newLabel
                    changed = true
                }
            }
            // Recompute centroids.
            var sums = Array(repeating: (l: 0.0, a: 0.0, b: 0.0, n: 0), count: realK)
            for (i, p) in photos.enumerated() {
                let k = assignment[i]
                sums[k].l += p.dominantColor.l
                sums[k].a += p.dominantColor.a
                sums[k].b += p.dominantColor.b
                sums[k].n += 1
            }
            for i in 0..<realK {
                let s = sums[i]
                guard s.n > 0 else { continue }
                centroids[i] = LabColor(
                    l: s.l / Double(s.n),
                    a: s.a / Double(s.n),
                    b: s.b / Double(s.n)
                )
            }
            if !changed { break }
        }

        // Emit clusters.
        var buckets: [[Photo]] = Array(repeating: [], count: realK)
        for (i, p) in photos.enumerated() {
            buckets[assignment[i]].append(p)
        }

        return buckets.enumerated().compactMap { (idx, members) -> Cluster? in
            guard !members.isEmpty else { return nil }
            let centroid = centroids[idx]
            let cohesion = members.map { $0.dominantColor.deltaE(centroid) }.reduce(0, +)
                / Double(members.count)
            return Cluster(
                id: idx,
                centroid: centroid,
                memberIDs: members.map(\.id),
                cohesion: cohesion
            )
        }
    }

    // MARK: — Helpers

    private func kmeansPlusPlusInit(
        photos: [Photo],
        k: Int,
        rng: inout SeededRNG
    ) -> [LabColor] {
        var centroids: [LabColor] = []
        let firstIdx = Int(rng.next() % UInt64(photos.count))
        centroids.append(photos[firstIdx].dominantColor)

        while centroids.count < k {
            // Weighted random by squared distance to nearest existing centroid.
            var distances = [Double](repeating: 0, count: photos.count)
            var sum = 0.0
            for (i, p) in photos.enumerated() {
                let d = nearestDistance(color: p.dominantColor, in: centroids)
                let w = d * d
                distances[i] = w
                sum += w
            }
            if sum == 0 { break }
            var r = rng.unit() * sum
            var chosen = photos.count - 1
            for i in 0..<photos.count {
                r -= distances[i]
                if r <= 0 { chosen = i; break }
            }
            centroids.append(photos[chosen].dominantColor)
        }
        return centroids
    }

    private func nearestCentroid(color: LabColor, in centroids: [LabColor]) -> Int {
        var best = 0
        var bestD = Double.infinity
        for (i, c) in centroids.enumerated() {
            let d = color.deltaE(c)
            if d < bestD { bestD = d; best = i }
        }
        return best
    }

    private func nearestDistance(color: LabColor, in centroids: [LabColor]) -> Double {
        var bestD = Double.infinity
        for c in centroids {
            let d = color.deltaE(c)
            if d < bestD { bestD = d }
        }
        return bestD
    }
}
