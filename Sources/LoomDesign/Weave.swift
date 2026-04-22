import SwiftUI

/// The **Weave** animation vocabulary.
///
/// Loom's signature motion is a *weave*: tiles don't all move at once, they
/// arrive in a wave, the way a loom shuttle crosses the warp left-to-right.
/// Every screen in the app speaks this vocabulary, so the feel stays
/// consistent — Shuffle is a weave, the indexing view shows your library
/// being woven, the landing background is an ambient weave of color.
///
/// The primitives live here and nowhere else. Views never hand-roll stagger
/// math; they call ``Weave.stagger(...)`` so the whole app retunes from a
/// single file.
public enum Weave {

    // MARK: — Stagger timing

    /// How long a full wave should take, end to end. A single tile at
    /// position 0 starts now; the tile at position 1 starts after this many
    /// seconds. 320ms feels alive but not sluggish.
    public static let totalSpan: Double = 0.32

    /// Extra per-tile jitter layered on top of position-based stagger, so a
    /// wall of 40 tiles doesn't look like a metronome. ±20ms by default.
    public static let jitter: Double = 0.02

    /// Compute a stagger delay from a tile's normalized position (0…1) along
    /// the wave direction. Jitter is deterministic on `index` so the delay
    /// stays stable across re-renders within a single wall.
    public static func stagger(
        normalizedPosition p: Double,
        index: Int,
        span: Double = totalSpan,
        jitter: Double = jitter
    ) -> Double {
        let clamped = max(0, min(1, p))
        // Gentle ease-out so early tiles fire a bit earlier than linear.
        let eased = 1 - pow(1 - clamped, 1.4)
        let jitterValue = deterministicJitter(seed: index, magnitude: jitter)
        return eased * span + jitterValue
    }

    /// The spring tiles use to settle into their new frame.
    public static func settleAnimation(delay d: Double = 0) -> Animation {
        .spring(response: 0.58, dampingFraction: 0.78, blendDuration: 0.22).delay(d)
    }

    /// The spring for an entering tile. Slightly faster so the arrival
    /// feels crisp rather than lazy.
    public static func enterAnimation(delay d: Double = 0) -> Animation {
        .spring(response: 0.48, dampingFraction: 0.82, blendDuration: 0.18).delay(d)
    }

    /// The exit curve. Eased (not spring) because exits don't need bounce —
    /// we want tiles to get out of the way cleanly, not sign off.
    public static func exitAnimation(delay d: Double = 0) -> Animation {
        .easeOut(duration: 0.22).delay(d)
    }

    // MARK: — Transitions

    /// Entrance: tile scales from 0.92 with opacity, honoring the wave.
    public static func insertTransition(delay d: Double = 0) -> AnyTransition {
        .asymmetric(
            insertion: AnyTransition
                .scale(scale: 0.92)
                .combined(with: .opacity)
                .animation(enterAnimation(delay: d)),
            removal: AnyTransition
                .scale(scale: 1.05)
                .combined(with: .opacity)
                .animation(exitAnimation())
        )
    }

    // MARK: — Ambient drift (landing / indexing backgrounds)

    /// Low-frequency, deterministic 0…1 oscillation keyed on `index`. Used
    /// by the landing tapestry to drift rectangles independently without a
    /// live RNG.
    public static func driftPhase(
        time: TimeInterval,
        index: Int,
        period: Double = 14
    ) -> Double {
        let phaseOffset = Double(index) * 0.37
        let raw = time / period + phaseOffset
        return (sin(raw * .pi * 2) + 1) * 0.5
    }

    /// Deterministic per-tile rotation jitter for the MiniWall entrance.
    /// Returns an angle in degrees (±15°) so each swatch tumbles in from
    /// a visible tilt that settles to flat — like photos being tossed
    /// onto a table.
    public static func tileJitterAngle(index: Int) -> Double {
        deterministicJitter(seed: index &+ 7919, magnitude: 15)
    }

    // MARK: — Helpers

    private static func deterministicJitter(seed: Int, magnitude: Double) -> Double {
        // Cheap hash → [-1, 1)
        var h = UInt64(bitPattern: Int64(seed)) &+ 0x9E3779B97F4A7C15
        h ^= h &>> 30
        h &*= 0xBF58476D1CE4E5B9
        h ^= h &>> 27
        let unit = Double(h & 0xFFFFFFFF) / Double(0xFFFFFFFF)   // 0…1
        return (unit * 2 - 1) * magnitude
    }
}
