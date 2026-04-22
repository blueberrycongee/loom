import SwiftUI
import LoomDesign

/// The landing hero's ambient background — an abstract woven composition
/// of drifting colored rectangles that hints at what Loom makes without
/// needing a library to demo against.
///
/// The piece teaches the product metaphor in motion: rectangles of
/// brand-palette colors drift within zones, softly rotate, and occasionally
/// overlap with ``.softLight`` blending — so the image reads as a gentle
/// tapestry weaving itself.
///
/// Deterministic on `time` (via `Weave.driftPhase`) so there's no RNG state
/// — the motion is smooth and repeatable, and `accessibilityReduceMotion`
/// freezes it without jank.
public struct LoomTapestry: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    private static let threads: [Thread] = makeThreads()

    public var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? nil : 1.0 / 30.0)) { timeline in
            let t = reduceMotion
                ? 0.0
                : timeline.date.timeIntervalSinceReferenceDate
            Canvas(rendersAsynchronously: true) { ctx, size in
                for thread in Self.threads {
                    draw(thread, at: t, into: ctx, size: size)
                }
            }
            // Paper canvas: multiply darkens the threads into the cream,
            // reading like ink-on-paper. .plusLighter (dark-mode default)
            // would invert the intent.
            .blendMode(.multiply)
            .allowsHitTesting(false)
        }
    }

    private func draw(
        _ thread: Thread,
        at time: TimeInterval,
        into ctx: GraphicsContext,
        size: CGSize
    ) {
        let driftX = Weave.driftPhase(time: time, index: thread.index, period: thread.period)
        let driftY = Weave.driftPhase(time: time, index: thread.index + 17, period: thread.period * 1.27)
        let pulse  = Weave.driftPhase(time: time, index: thread.index + 31, period: 6.5)
        let swing  = Weave.driftPhase(time: time, index: thread.index + 53, period: 9.1)

        let zoneX = thread.zone.origin.x + (driftX - 0.5) * thread.zone.width  * 0.25
        let zoneY = thread.zone.origin.y + (driftY - 0.5) * thread.zone.height * 0.25

        let x = zoneX * size.width
        let y = zoneY * size.height
        let w = thread.size.width  * size.width  * thread.scale
        let h = thread.size.height * size.height * thread.scale

        let rotation = (swing - 0.5) * thread.rotationRange    // radians
        let opacity  = thread.baseOpacity * (0.86 + pulse * 0.28)

        let rect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
        let path = Path(
            roundedRect: rect,
            cornerRadius: min(w, h) * 0.06,
            style: .continuous
        )

        var layer = ctx
        layer.translateBy(x: x, y: y)
        layer.rotate(by: .radians(rotation))
        layer.opacity = opacity
        layer.fill(path, with: .color(thread.color))

        // Subtle inner line so the rect reads as a woven element, not a
        // flat fill. On paper we use a darker ink stroke rather than the
        // canvas color (which would be invisible against itself).
        var outline = layer
        outline.opacity = opacity * 0.35
        outline.stroke(
            path,
            with: .color(Palette.ink.opacity(0.35)),
            lineWidth: 0.5
        )
    }

    // MARK: — Threads

    private struct Thread {
        let index: Int
        let zone: CGRect          // all in unit-normalized coords
        let size: CGSize
        let scale: Double
        let period: Double
        let rotationRange: Double // radians
        let baseOpacity: Double
        let color: Color
    }

    private static func makeThreads() -> [Thread] {
        // Hand-composed zones so the motion has intention, not randomness.
        // The palette is restricted to the brand's warm neutrals + a few
        // supports so the whole background reads as one piece.
        // Paper-canvas palette: muted pigments that read as darker than
        // the cream background under .multiply blend. Pure white / very
        // light tints would vanish; we want something like ink washes in
        // the catalogue style.
        let palette: [Color] = [
            Palette.brass.opacity(0.36),                               // terracotta
            Palette.brassShade.opacity(0.40),                          // deep terracotta
            Color(red: 0.32, green: 0.36, blue: 0.46).opacity(0.30),   // soft indigo
            Color(red: 0.52, green: 0.30, blue: 0.34).opacity(0.26),   // muted rose
            Color(red: 0.24, green: 0.36, blue: 0.34).opacity(0.28),   // deep teal
            Color(red: 0.42, green: 0.38, blue: 0.30).opacity(0.24),   // olive umber
            Color(red: 0.60, green: 0.54, blue: 0.46).opacity(0.22),   // linen gray
            Color(red: 0.18, green: 0.20, blue: 0.24).opacity(0.20)    // warm charcoal
        ]

        // Layout: alternating warp (tall) + weft (wide) rectangles distributed
        // across the canvas at different scales. Periods vary so no two
        // rectangles move in lockstep.
        let raw: [(zone: CGRect, size: CGSize, scale: Double, period: Double, rotation: Double)] = [
            (CGRect(x: 0.12, y: 0.18, width: 0.20, height: 0.22), CGSize(width: 0.14, height: 0.36), 1.0, 18, 0.04),
            (CGRect(x: 0.28, y: 0.62, width: 0.22, height: 0.22), CGSize(width: 0.26, height: 0.10), 1.0, 22, 0.05),
            (CGRect(x: 0.55, y: 0.22, width: 0.22, height: 0.24), CGSize(width: 0.10, height: 0.30), 1.0, 16, 0.06),
            (CGRect(x: 0.72, y: 0.58, width: 0.20, height: 0.22), CGSize(width: 0.22, height: 0.12), 1.0, 24, 0.03),
            (CGRect(x: 0.42, y: 0.40, width: 0.20, height: 0.22), CGSize(width: 0.16, height: 0.22), 1.1, 20, 0.08),
            (CGRect(x: 0.08, y: 0.72, width: 0.20, height: 0.22), CGSize(width: 0.12, height: 0.18), 0.9, 19, 0.07),
            (CGRect(x: 0.82, y: 0.14, width: 0.16, height: 0.22), CGSize(width: 0.14, height: 0.14), 0.9, 17, 0.05),
            (CGRect(x: 0.18, y: 0.44, width: 0.20, height: 0.22), CGSize(width: 0.24, height: 0.08), 1.0, 26, 0.04),
            (CGRect(x: 0.62, y: 0.78, width: 0.22, height: 0.18), CGSize(width: 0.18, height: 0.10), 1.0, 23, 0.05),
            (CGRect(x: 0.36, y: 0.10, width: 0.20, height: 0.14), CGSize(width: 0.22, height: 0.09), 1.0, 21, 0.04),
            (CGRect(x: 0.04, y: 0.04, width: 0.14, height: 0.12), CGSize(width: 0.12, height: 0.08), 0.9, 28, 0.03),
            (CGRect(x: 0.86, y: 0.82, width: 0.12, height: 0.14), CGSize(width: 0.10, height: 0.12), 0.9, 25, 0.03)
        ]

        return raw.enumerated().map { (i, t) in
            Thread(
                index: i,
                zone: t.zone,
                size: t.size,
                scale: t.scale,
                period: t.period,
                rotationRange: t.rotation,
                baseOpacity: 1.0,
                color: palette[i % palette.count]
            )
        }
    }
}
