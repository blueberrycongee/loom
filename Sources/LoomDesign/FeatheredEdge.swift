import SwiftUI

/// A view modifier that softens a view's edges into the canvas — the
/// "watercolor bleed" that turns a photo tile from a rectangular cutout
/// into something that feels printed onto the paper.
///
/// Implementation: mask the view with a padded `Rectangle` that's been
/// blurred. The padded rectangle's interior stays solid (fully opaque);
/// the padding region smears to transparent under the blur, producing a
/// smooth falloff at every edge. No per-frame work — it's a single mask
/// view's static render, cached by the SwiftUI layer tree.
///
/// Feather amount is expressed as a fraction of the view's shorter side,
/// so a portrait tile gets a feather scaled to its width and a landscape
/// tile gets one scaled to its height — the bleed reads the same
/// regardless of orientation.
///
/// Use it sparingly: ``featheredEdge()`` on photo tiles and drift
/// rectangles that are meant to melt into the canvas; don't feather
/// controls / buttons, whose edges are the whole point.
public struct FeatheredEdge: ViewModifier {

    /// 0…1 — the inset (as a fraction of min(w,h)) that the mask's solid
    /// interior leaves; the bleed happens inside that inset through blur.
    /// 0.12–0.18 is the sweet spot.
    public let feather: Double

    public init(feather: Double = 0.14) {
        self.feather = max(0.02, min(0.35, feather))
    }

    public func body(content: Content) -> some View {
        content.mask(
            GeometryReader { geo in
                let shortSide = min(geo.size.width, geo.size.height)
                let inset = shortSide * feather
                Rectangle()
                    .fill(Color.black)
                    .padding(inset)
                    .blur(radius: inset * 0.85)
            }
        )
    }
}

public extension View {
    /// See ``FeatheredEdge``.
    func featheredEdge(_ feather: Double = 0.14) -> some View {
        modifier(FeatheredEdge(feather: feather))
    }
}
