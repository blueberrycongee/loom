import Foundation
import LoomCore

/// Groups photos by *visual / mood* similarity using Vision's feature-print.
///
/// Vision's `VNFeaturePrintObservation` is a 768-dim L2-normalised embedding
/// optimised for general-purpose visual similarity. It's not a semantic
/// (CLIP-style) model, so it won't group "happy photos" vs "sad photos"
/// by concept — but it does group by composition, palette-plus-texture,
/// lighting, and scene type, which covers most of what users mean when they
/// say a photo "feels a certain way".
///
/// Algorithm: **k-medoids** (Partitioning Around Medoids / PAM-lite).
///
/// Why k-medoids over k-means?
///   • Averaging two L2-normalised vectors gives a non-normalised vector;
///     re-normalising biases the centroid and makes distances noisy.
///   • k-medoids picks existing photos as cluster centers — cheaper to
///     interpret and no averaging math needed.
///   • Convergence is slower than k-means but the ≤ 1000-photo libraries
///     we target here make that moot.
public struct FeaturePrintClusterer {

    public struct Cluster: Identifiable, Sendable {
        public let id: Int
        public let medoid: PhotoID
        public let memberIDs: [PhotoID]
        public let cohesion: Double
    }

    public let k: Int

    public init(k: Int = 6) {
        self.k = max(1, k)
    }

    public func cluster(
        _ photos: [Photo],
        rng: inout SeededRNG,
        maxIterations: Int = 12
    ) -> [Cluster] {
        // Only consider photos that have a feature-print.
        let candidates = photos.compactMap { p -> (Photo, FeaturePrint)? in
            guard let fp = p.featurePrint, fp.dimension > 0 else { return nil }
            return (p, fp)
        }
        guard !candidates.isEmpty else { return [] }
        let realK = min(k, candidates.count)
        if realK == 1 {
            return [Cluster(
                id: 0,
                medoid: candidates[0].0.id,
                memberIDs: candidates.map { $0.0.id },
                cohesion: 0
            )]
        }

        // Init: k-means++-style picking, weighted by squared distance to
        // already-picked medoids.
        var medoidIdxs: [Int] = []
        medoidIdxs.append(Int(rng.next() % UInt64(candidates.count)))
        while medoidIdxs.count < realK {
            var dists = [Double](repeating: 0, count: candidates.count)
            var sum: Double = 0
            for (i, (_, fp)) in candidates.enumerated() {
                var best = Double.infinity
                for m in medoidIdxs {
                    let d = fp.distance(to: candidates[m].1)
                    if d < best { best = d }
                }
                let w = best * best
                dists[i] = w
                sum += w
            }
            guard sum > 0 else { break }
            var r = rng.unit() * sum
            var chosen = candidates.count - 1
            for i in 0..<candidates.count {
                r -= dists[i]
                if r <= 0 { chosen = i; break }
            }
            medoidIdxs.append(chosen)
        }

        var assignment = Array(repeating: 0, count: candidates.count)

        for _ in 0..<maxIterations {
            // Assign every point to its nearest medoid.
            var changed = false
            for i in 0..<candidates.count {
                var best = 0
                var bestD = Double.infinity
                for (k, m) in medoidIdxs.enumerated() {
                    let d = candidates[i].1.distance(to: candidates[m].1)
                    if d < bestD { bestD = d; best = k }
                }
                if assignment[i] != best {
                    assignment[i] = best
                    changed = true
                }
            }
            if !changed { break }

            // For each cluster, promote the member that minimises the
            // sum of distances to every other member (new medoid).
            for k in 0..<realK {
                let members = candidates.indices.filter { assignment[$0] == k }
                guard members.count > 1 else { continue }
                var bestMember = members[0]
                var bestCost = Double.infinity
                for candidate in members {
                    var cost = 0.0
                    for other in members where other != candidate {
                        cost += candidates[candidate].1.distance(to: candidates[other].1)
                    }
                    if cost < bestCost { bestCost = cost; bestMember = candidate }
                }
                medoidIdxs[k] = bestMember
            }
        }

        // Emit clusters.
        var buckets: [[Int]] = Array(repeating: [], count: realK)
        for (i, k) in assignment.enumerated() { buckets[k].append(i) }

        return buckets.enumerated().compactMap { (idx, memberIdxs) -> Cluster? in
            guard !memberIdxs.isEmpty else { return nil }
            let medoid = candidates[medoidIdxs[idx]]
            let cohesion = memberIdxs
                .map { candidates[$0].1.distance(to: medoid.1) }
                .reduce(0, +)
                / Double(memberIdxs.count)
            return Cluster(
                id: idx,
                medoid: medoid.0.id,
                memberIDs: memberIdxs.map { candidates[$0].0.id },
                cohesion: cohesion
            )
        }
    }
}
