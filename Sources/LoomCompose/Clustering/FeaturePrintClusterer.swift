import Foundation
import LoomCore

/// Groups photos by *visual / mood* similarity using high-dimensional
/// embeddings (CLIP when available, Vision feature-print as fallback).
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
///
/// **Adaptive k** — instead of a hardcoded cluster count, the clusterer
/// tries k from 2 to a data-driven ceiling and picks the k with the
/// highest average silhouette score. Users whose libraries are three
/// strongly-typed scenes get three clusters; users with twelve themes
/// get twelve. ``ClusterCount.fixed(_:)`` overrides for callers that
/// need a deterministic count.
public struct FeaturePrintClusterer {

    public struct Cluster: Identifiable, Sendable {
        public let id: Int
        public let medoid: PhotoID
        public let memberIDs: [PhotoID]
        public let cohesion: Double
    }

    /// How many clusters to produce.
    public enum ClusterCount: Sendable {
        /// Search k=2…kMax and pick the k that maximises the average
        /// silhouette score.
        case adaptive
        /// Use exactly this many clusters. Clamped to [1, n].
        case fixed(Int)
    }

    public let mode: ClusterCount

    public init(k: ClusterCount = .adaptive) {
        self.mode = k
    }

    // Convenience for callers that used the old `init(k: Int)` pattern.
    public init(k: Int) {
        self.mode = .fixed(max(1, k))
    }

    public func cluster(
        _ photos: [Photo],
        rng: inout SeededRNG,
        maxIterations: Int = 12
    ) -> [Cluster] {
        let candidates = extractCandidates(from: photos)
        guard !candidates.isEmpty else { return [] }
        if candidates.count <= 2 {
            return [singleCluster(candidates)]
        }

        switch mode {
        case .fixed(let k):
            let realK = min(max(1, k), candidates.count)
            return runKMedoids(candidates: candidates, k: realK,
                               maxIterations: maxIterations, rng: &rng)
        case .adaptive:
            return adaptiveCluster(candidates: candidates,
                                   maxIterations: maxIterations, rng: &rng)
        }
    }

    // MARK: — Embedding selection

    /// Pick the best available embedding for each photo. If ≥50% have
    /// CLIP embeddings, cluster in CLIP space for richer semantics;
    /// otherwise fall back to VNFeaturePrint.
    private func extractCandidates(
        from photos: [Photo]
    ) -> [(photo: Photo, embedding: FeaturePrint)] {
        let withClip = photos.compactMap { p -> (Photo, FeaturePrint)? in
            guard let clip = p.clipEmbedding, clip.dimension > 0 else { return nil }
            return (p, clip)
        }
        if withClip.count * 2 >= photos.count, !withClip.isEmpty {
            return withClip
        }
        return photos.compactMap { p -> (Photo, FeaturePrint)? in
            guard let fp = p.featurePrint, fp.dimension > 0 else { return nil }
            return (p, fp)
        }
    }

    // MARK: — Adaptive k

    private func adaptiveCluster(
        candidates: [(photo: Photo, embedding: FeaturePrint)],
        maxIterations: Int,
        rng: inout SeededRNG
    ) -> [Cluster] {
        let n = candidates.count
        let kMax = min(12, max(2, Int(Double(n).squareRoot())))

        // Precompute pairwise distance matrix for silhouette scoring.
        let dist = distanceMatrix(candidates)

        var bestK = 2
        var bestScore: Double = -.infinity
        var bestAssignment: [Int] = []
        var bestMedoids: [Int] = []

        for k in 2...kMax {
            let (assignment, medoids) = runPAM(
                dist: dist, n: n, k: k,
                maxIterations: maxIterations, rng: &rng
            )
            let score = silhouetteScore(dist: dist, assignment: assignment, k: k)
            if score > bestScore {
                bestScore = score
                bestK = k
                bestAssignment = assignment
                bestMedoids = medoids
            }
        }

        return emitClusters(candidates: candidates,
                            assignment: bestAssignment,
                            medoids: bestMedoids,
                            k: bestK, dist: dist)
    }

    // MARK: — k-medoids (PAM-lite)

    private func runKMedoids(
        candidates: [(photo: Photo, embedding: FeaturePrint)],
        k: Int,
        maxIterations: Int,
        rng: inout SeededRNG
    ) -> [Cluster] {
        if k == 1 { return [singleCluster(candidates)] }
        let dist = distanceMatrix(candidates)
        let (assignment, medoids) = runPAM(
            dist: dist, n: candidates.count, k: k,
            maxIterations: maxIterations, rng: &rng
        )
        return emitClusters(candidates: candidates,
                            assignment: assignment,
                            medoids: medoids, k: k, dist: dist)
    }

    /// Core PAM loop: k-means++ init → assign → swap medoids → repeat.
    /// Operates on a precomputed distance matrix for speed.
    private func runPAM(
        dist: [[Double]],
        n: Int,
        k: Int,
        maxIterations: Int,
        rng: inout SeededRNG
    ) -> (assignment: [Int], medoids: [Int]) {
        // k-means++ seeding
        var medoids: [Int] = []
        medoids.append(Int(rng.next() % UInt64(n)))
        while medoids.count < k {
            var weights = [Double](repeating: 0, count: n)
            var total: Double = 0
            for i in 0..<n {
                var best = Double.infinity
                for m in medoids {
                    if dist[i][m] < best { best = dist[i][m] }
                }
                let w = best * best
                weights[i] = w
                total += w
            }
            guard total > 0 else { break }
            var r = rng.unit() * total
            var chosen = n - 1
            for i in 0..<n {
                r -= weights[i]
                if r <= 0 { chosen = i; break }
            }
            if !medoids.contains(chosen) {
                medoids.append(chosen)
            } else {
                // Collision — pick next non-medoid
                for i in 0..<n where !medoids.contains(i) {
                    medoids.append(i)
                    break
                }
            }
        }

        var assignment = Array(repeating: 0, count: n)

        for _ in 0..<maxIterations {
            // Assignment
            var changed = false
            for i in 0..<n {
                var bestCluster = 0
                var bestD = Double.infinity
                for (ci, m) in medoids.enumerated() {
                    if dist[i][m] < bestD {
                        bestD = dist[i][m]
                        bestCluster = ci
                    }
                }
                if assignment[i] != bestCluster {
                    assignment[i] = bestCluster
                    changed = true
                }
            }
            if !changed { break }

            // Medoid update: per cluster, pick member minimising total
            // intra-cluster distance.
            var anySwap = false
            for ci in 0..<k {
                let members = (0..<n).filter { assignment[$0] == ci }
                guard members.count > 1 else { continue }
                var bestMember = medoids[ci]
                var bestCost = Double.infinity
                for candidate in members {
                    var cost = 0.0
                    for other in members where other != candidate {
                        cost += dist[candidate][other]
                    }
                    if cost < bestCost {
                        bestCost = cost
                        bestMember = candidate
                    }
                }
                if bestMember != medoids[ci] {
                    medoids[ci] = bestMember
                    anySwap = true
                }
            }
            if !anySwap { break }
        }

        return (assignment, medoids)
    }

    // MARK: — Silhouette score

    /// Average silhouette across all points: (b - a) / max(a, b).
    /// a = mean distance to same-cluster members.
    /// b = mean distance to members of the nearest *other* cluster.
    /// Higher (closer to 1) = better-separated clusters.
    private func silhouetteScore(
        dist: [[Double]],
        assignment: [Int],
        k: Int
    ) -> Double {
        let n = dist.count
        guard n > 1, k > 1 else { return 0 }

        // Group indices by cluster for fast intra/inter lookup.
        var groups: [[Int]] = Array(repeating: [], count: k)
        for (i, c) in assignment.enumerated() {
            groups[c].append(i)
        }

        var sum: Double = 0
        var count = 0
        for i in 0..<n {
            let ci = assignment[i]
            let myGroup = groups[ci]

            // a(i): mean intra-cluster distance
            let a: Double
            if myGroup.count <= 1 {
                a = 0
            } else {
                var s = 0.0
                for j in myGroup where j != i { s += dist[i][j] }
                a = s / Double(myGroup.count - 1)
            }

            // b(i): min over other clusters of mean distance to that cluster
            var b = Double.infinity
            for ck in 0..<k where ck != ci {
                let otherGroup = groups[ck]
                guard !otherGroup.isEmpty else { continue }
                var s = 0.0
                for j in otherGroup { s += dist[i][j] }
                let meanDist = s / Double(otherGroup.count)
                if meanDist < b { b = meanDist }
            }

            let denom = max(a, b)
            if denom > 0 {
                sum += (b - a) / denom
                count += 1
            }
        }
        return count > 0 ? sum / Double(count) : 0
    }

    // MARK: — Distance matrix

    /// O(n²) pairwise L2 distance. Each distance is computed once;
    /// dist[i][j] == dist[j][i]. For n=1000 this is ~500K distances ×
    /// 768 dims ≈ 400M FLOPs — well under a second on any Apple Silicon.
    private func distanceMatrix(
        _ candidates: [(photo: Photo, embedding: FeaturePrint)]
    ) -> [[Double]] {
        let n = candidates.count
        var m = Array(repeating: Array(repeating: 0.0, count: n), count: n)
        for i in 0..<n {
            for j in (i + 1)..<n {
                let d = candidates[i].embedding.distance(to: candidates[j].embedding)
                m[i][j] = d
                m[j][i] = d
            }
        }
        return m
    }

    // MARK: — Helpers

    private func singleCluster(
        _ candidates: [(photo: Photo, embedding: FeaturePrint)]
    ) -> Cluster {
        Cluster(
            id: 0,
            medoid: candidates[0].photo.id,
            memberIDs: candidates.map(\.photo.id),
            cohesion: 0
        )
    }

    private func emitClusters(
        candidates: [(photo: Photo, embedding: FeaturePrint)],
        assignment: [Int],
        medoids: [Int],
        k: Int,
        dist: [[Double]]
    ) -> [Cluster] {
        var buckets: [[Int]] = Array(repeating: [], count: k)
        for (i, c) in assignment.enumerated() { buckets[c].append(i) }

        return buckets.enumerated().compactMap { (idx, memberIdxs) -> Cluster? in
            guard !memberIdxs.isEmpty else { return nil }
            let medoidIdx = medoids[idx]
            let cohesion = memberIdxs
                .map { dist[$0][medoidIdx] }
                .reduce(0, +)
                / Double(memberIdxs.count)
            return Cluster(
                id: idx,
                medoid: candidates[medoidIdx].photo.id,
                memberIDs: memberIdxs.map { candidates[$0].photo.id },
                cohesion: cohesion
            )
        }
    }
}
