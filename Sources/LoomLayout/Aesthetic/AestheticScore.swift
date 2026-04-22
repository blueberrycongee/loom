import CoreGraphics
import Foundation
import LoomCore

/// Aesthetic scoring for a candidate wall.
///
/// The composer runs the layout engine several times with different seeds,
/// scores each resulting wall, and keeps the best. Scorers are all pure
/// functions taking (wall, photos) and returning [0, 1].
///
/// Each dimension captures one failure mode Loom must avoid:
///
///   • ``ColorHarmonyScore`` — tile colors that clash. Photos clustered
///     well should score high; mixed palettes low.
///   • ``RhythmScore`` — monotonous aspect sequences. All-portrait walls
///     feel robotic; strict alternation feels equally robotic. We reward
///     moderate variety (measured by 3-tile sliding window diversity).
///   • ``ContrastScore`` — luminance spread. A uniformly bright or
///     uniformly dark wall is flat; moderate spread reads as "composition".
public enum AestheticScore {

    public struct Breakdown {
        public let harmony: Double
        public let rhythm: Double
        public let contrast: Double
        public let composite: Double
    }

    public static func score(wall: Wall, photos: [Photo]) -> Breakdown {
        let byID = Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0) })
        let tilePhotos: [Photo] = wall.tiles.compactMap { byID[$0.photoID] }

        let h = harmonyScore(tilePhotos)
        let r = rhythmScore(tilePhotos)
        let c = contrastScore(tilePhotos)

        // Composite: weighted average. Harmony dominates — the vision doc
        // lists "color balance" as the first aesthetic rule. Rhythm and
        // contrast get half weight each.
        let composite = (h * 2 + r + c) / 4
        return Breakdown(
            harmony: h, rhythm: r, contrast: c, composite: composite
        )
    }

    // MARK: — Color harmony

    /// Reward walls whose photos live in a single color family. We compute
    /// the mean Lab position, then average ΔE from mean. Low = unified; we
    /// map that through an exponential decay to [0, 1].
    static func harmonyScore(_ photos: [Photo]) -> Double {
        guard photos.count >= 2 else { return 1.0 }

        var meanL = 0.0, meanA = 0.0, meanB = 0.0
        for p in photos {
            meanL += p.dominantColor.l
            meanA += p.dominantColor.a
            meanB += p.dominantColor.b
        }
        let n = Double(photos.count)
        meanL /= n; meanA /= n; meanB /= n
        let mean = LabColor(l: meanL, a: meanA, b: meanB)

        var sumD = 0.0
        for p in photos { sumD += p.dominantColor.deltaE(mean) }
        let meanDelta = sumD / n

        // ΔE under ~12 reads as "same palette"; over ~35 reads as chaos.
        // Map meanDelta → [0, 1] with an exponential falloff centered on 12.
        let s = Foundation.exp(-Foundation.pow(max(0, meanDelta - 8) / 22.0, 2))
        return min(1.0, max(0.0, s))
    }

    // MARK: — Rhythm (aspect-bucket variety)

    static func rhythmScore(_ photos: [Photo]) -> Double {
        guard photos.count >= 3 else { return 1.0 }
        var diverseTriples = 0
        let total = photos.count - 2
        for i in 0..<total {
            let a = Aspect.bucket(of: photos[i].aspect)
            let b = Aspect.bucket(of: photos[i + 1].aspect)
            let c = Aspect.bucket(of: photos[i + 2].aspect)
            let set: Set<Aspect.Bucket> = [a, b, c]
            diverseTriples += set.count - 1    // 0 (all same), 1 (two different), 2 (all different)
        }
        // Max score = 2 per triple. Divide.
        return Double(diverseTriples) / Double(total * 2)
    }

    // MARK: — Contrast (L* spread)

    static func contrastScore(_ photos: [Photo]) -> Double {
        guard photos.count >= 2 else { return 0.5 }
        let ls = photos.map(\.dominantColor.l)
        let mean = ls.reduce(0, +) / Double(ls.count)
        let variance = ls.map { Foundation.pow($0 - mean, 2) }.reduce(0, +) / Double(ls.count)
        let stdev = variance.squareRoot()

        // Sweet spot in L* std-dev is 10–25 on a [0, 100] scale.
        //   < 5   → flat, score → 0
        //   10–25 → plateau at 1
        //   > 40  → noisy, decaying
        switch stdev {
        case ..<5:   return stdev / 5.0
        case 5..<10: return 0.5 + (stdev - 5) / 10.0
        case 10...25: return 1.0
        case 25...40: return max(0, 1.0 - (stdev - 25) / 15.0 * 0.5)
        default:      return max(0, 0.5 - (stdev - 40) / 60.0)
        }
    }
}
