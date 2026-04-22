import SwiftUI
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// A static, pre-rendered noise overlay.
///
/// The previous ``Grain`` view regenerated noise inside a `Canvas` at 30fps.
/// That was visible-warmth but invisible perf drag: every frame paid for a
/// pixel-loop the viewer couldn't distinguish from a static texture.
///
/// This replacement bakes a single 256×256 noise `CGImage` once (lazily, on
/// first use), wraps it in a SwiftUI `Image` with `.resizingMode(.tile)`,
/// and blends with `.softLight`. Zero per-frame cost; identical feel.
///
/// A subtle "breathe" on opacity is the only animated part — 8 seconds of
/// ±10% variance so the warmth reads as alive without burning CPU.
public struct NoiseTexture: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let baseOpacity: Double

    public init(baseOpacity: Double = 0.035) {
        self.baseOpacity = max(0, min(0.12, baseOpacity))
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 10.0, paused: reduceMotion)) { timeline in
            let phase = reduceMotion
                ? 0.0
                : Weave.driftPhase(
                    time: timeline.date.timeIntervalSinceReferenceDate,
                    index: 0,
                    period: 8
                )
            let o = baseOpacity * (0.88 + phase * 0.24)
            noiseImage
                .opacity(o)
                .blendMode(.softLight)
                .allowsHitTesting(false)
        }
    }

    private var noiseImage: Image {
        Image(nsImage: NoiseTextureCache.shared.image)
            .resizable(resizingMode: .tile)
    }
}

/// Global noise cache. One 256×256 NSImage for the life of the process.
private final class NoiseTextureCache: @unchecked Sendable {
    static let shared = NoiseTextureCache()

    let image: NSImage

    private init() {
        self.image = Self.render()
    }

    private static func render() -> NSImage {
        let size = NSSize(width: 256, height: 256)
        // Render via Core Image's deterministic random generator so every
        // install gets the same texture (helps with pixel-comparison tests).
        let context = CIContext()
        let random = CIFilter.randomGenerator()
        let color  = CIFilter.colorMatrix()
        let clamp  = CIFilter.colorClamp()

        color.inputImage = random.outputImage
        // Drop saturation; push output through a gentle contrast so the
        // texture reads as paper grain, not a TV-static test pattern.
        color.rVector = CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0)
        color.gVector = CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0)
        color.bVector = CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0)
        color.biasVector = CIVector(x: 0.05, y: 0.05, z: 0.05, w: 0)

        clamp.inputImage = color.outputImage
        clamp.minComponents = CIVector(x: 0.35, y: 0.35, z: 0.35, w: 1)
        clamp.maxComponents = CIVector(x: 0.78, y: 0.78, z: 0.78, w: 1)

        let extent = CGRect(origin: .zero, size: CGSize(width: size.width, height: size.height))
        guard
            let out = clamp.outputImage,
            let cg = context.createCGImage(out, from: extent)
        else {
            return NSImage(size: size)
        }
        return NSImage(cgImage: cg, size: size)
    }
}
