import CoreGraphics
import Foundation
import LoomCore

/// The common contract every layout engine (Tapestry, Editorial, Gallery,
/// Collage, Minimal, Vintage) satisfies.
///
/// Engines are **pure**: same input + same seed ⇒ same output. They don't
/// load images, don't touch disk, don't mutate shared state. This is what
/// lets the composer retry with a different seed when an aesthetic score
/// comes back too low.
public protocol LayoutEngine: Sendable {
    var style: Style { get }

    func compose(
        photos: [Photo],
        canvasSize: CGSize,
        rng: inout SeededRNG
    ) -> Wall
}

/// Registry mapping a style to its engine. Keeps `LoomCompose` from needing
/// to switch on `Style` in three different places.
public enum LayoutRegistry {
    public static func engine(for style: Style) -> LayoutEngine {
        switch style {
        case .tapestry:  return TapestryEngine()
        case .editorial: return TapestryEngine()   // TODO M3
        case .gallery:   return TapestryEngine()   // TODO M3
        case .collage:   return TapestryEngine()   // TODO M3
        case .minimal:   return MinimalEngine()
        case .vintage:   return TapestryEngine()   // TODO M3
        }
    }
}
