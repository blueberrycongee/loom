import Foundation

/// A seeded pseudo-random generator for the composer.
///
/// Two requirements, both unmet by `SystemRandomNumberGenerator`:
///
///   1. **Determinism.** A Wall stores its RNG seed so it can be reproduced
///      exactly — same photos + seed + style ⇒ same wall. Essential for
///      "favorite this layout" and for testability.
///   2. **Speed.** The composer makes thousands of small decisions per
///      shuffle; the system RNG's overhead shows up on older Macs.
///
/// Algorithm: SplitMix64. Tiny, fast, passes BigCrush, and a single 64-bit
/// state word fits in a register. Not cryptographic — don't use it where
/// that matters.
public struct SeededRNG: RandomNumberGenerator {
    public private(set) var state: UInt64

    public init(seed: UInt64) {
        // Guard against the degenerate seed=0 case by mixing in a constant.
        self.state = seed &+ 0x9E3779B97F4A7C15
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z &>> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z &>> 27)) &* 0x94D049BB133111EB
        return z ^ (z &>> 31)
    }

    // MARK: — Convenience

    /// Uniform Double in [0, 1).
    public mutating func unit() -> Double {
        Double(next() >> 11) * (1.0 / 9007199254740992.0)
    }

    /// Uniform Double in [lower, upper).
    public mutating func double(in range: Range<Double>) -> Double {
        range.lowerBound + unit() * (range.upperBound - range.lowerBound)
    }

    /// Gaussian sample, mean 0 std 1 — Marsaglia polar method. Used for
    /// *subtle* perturbations (tile rotation in Collage) where uniform looks
    /// unnatural.
    public mutating func gaussian() -> Double {
        var u: Double, v: Double, s: Double
        repeat {
            u = unit() * 2 - 1
            v = unit() * 2 - 1
            s = u * u + v * v
        } while s >= 1.0 || s == 0.0
        return u * (-2 * Foundation.log(s) / s).squareRoot()
    }

    /// Sample `k` distinct indices from `0..<n` without replacement.
    /// Reservoir-style so it's O(n) for all k.
    public mutating func sampleIndices(_ k: Int, from n: Int) -> [Int] {
        precondition(k >= 0 && n >= 0, "negative count")
        guard k > 0, n > 0 else { return [] }
        if k >= n { return Array(0..<n) }
        var reservoir = Array(0..<k)
        for i in k..<n {
            let j = Int(next() % UInt64(i + 1))
            if j < k { reservoir[j] = i }
        }
        return reservoir
    }
}

public extension SeededRNG {
    /// Derive a seed from a raw string — useful for deterministic shuffles
    /// keyed by wall title or a user-entered tag.
    init(seedString: String) {
        var h: UInt64 = 0xCBF29CE484222325
        for byte in seedString.utf8 {
            h ^= UInt64(byte)
            h &*= 0x00000100000001B3  // FNV-1a
        }
        self.init(seed: h)
    }
}
