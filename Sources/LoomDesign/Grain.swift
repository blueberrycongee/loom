import SwiftUI

/// A very subtle animated grain overlay. Photographs on perfectly flat black
/// feel synthetic; a whisper of grain reintroduces the idea that we're
/// looking at an image, not a slab of glass. Kept at ≤ 4% alpha so it never
/// competes with the content.
///
/// Implementation: a `TimelineView` redraws a cheap noise pattern every
/// 1/30s, using `Canvas` to draw a tiled noise texture. On reduced-motion
/// accessibility, the grain is static.
public struct Grain: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let intensity: Double
    private let tileSize: CGFloat

    public init(intensity: Double = 0.035, tileSize: CGFloat = 128) {
        self.intensity = max(0, min(0.15, intensity))
        self.tileSize = tileSize
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            Canvas(rendersAsynchronously: true) { ctx, size in
                let seed = reduceMotion ? 0 : UInt64(timeline.date.timeIntervalSinceReferenceDate * 30)
                var rng = SplitMix64(seed: seed &* 0x9E3779B97F4A7C15)
                ctx.opacity = intensity
                let step = tileSize
                var y: CGFloat = 0
                while y < size.height {
                    var x: CGFloat = 0
                    while x < size.width {
                        let v = Double(rng.next() & 0xFFFF) / Double(0xFFFF)
                        let gray = 0.5 + (v - 0.5) * 0.9
                        ctx.fill(
                            Path(CGRect(x: x, y: y, width: step, height: step)),
                            with: .color(.init(red: gray, green: gray, blue: gray))
                        )
                        x += step
                    }
                    y += step
                }
            }
            .blendMode(.softLight)
            .allowsHitTesting(false)
        }
    }
}

// MARK: — Tiny deterministic RNG used only for the grain so we don't pay the
// cost of SystemRandomNumberGenerator on every tick.

private struct SplitMix64 {
    var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z &>> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z &>> 27)) &* 0x94D049BB133111EB
        return z ^ (z &>> 31)
    }
}
