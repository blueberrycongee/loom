import SwiftUI

/// A small shadow library. Light canvases are trickier than dark: pure-black
/// shadows on cream read as dirty. Loom uses warm near-black at low alpha so
/// the shadow registers as *paper lifted off paper*, not as a digital drop
/// shadow.
public enum LoomShadow {

    /// Warm near-black used across every shadow in the app. Avoids the
    /// "printed photo cutout" effect that pure black gives on cream.
    public static let tone = Color(red: 0.15, green: 0.11, blue: 0.08)

    /// For tiles on the canvas. Soft, warm, minimal offset — photos should
    /// look like they're resting on the paper, not floating above it.
    public struct Tile: ViewModifier {
        public func body(content: Content) -> some View {
            content
                .shadow(color: LoomShadow.tone.opacity(0.09), radius: 14, x: 0, y: 6)
                .shadow(color: LoomShadow.tone.opacity(0.05), radius: 2,  x: 0, y: 1)
        }
    }

    /// For elevated surfaces — popovers, the command palette, permission
    /// sheets.
    public struct Surface: ViewModifier {
        public func body(content: Content) -> some View {
            content
                .shadow(color: LoomShadow.tone.opacity(0.15), radius: 28, x: 0, y: 14)
                .shadow(color: LoomShadow.tone.opacity(0.08), radius: 3,  x: 0, y: 2)
        }
    }

    /// For the primary CTA — a subtle terracotta halo so the button feels
    /// warm.
    public struct Brass: ViewModifier {
        public func body(content: Content) -> some View {
            content
                .shadow(color: Palette.brass.opacity(0.22), radius: 14, x: 0, y: 0)
                .shadow(color: LoomShadow.tone.opacity(0.14), radius: 6, x: 0, y: 3)
        }
    }
}

public extension View {
    func tileShadow()    -> some View { modifier(LoomShadow.Tile()) }
    func surfaceShadow() -> some View { modifier(LoomShadow.Surface()) }
    func brassShadow()   -> some View { modifier(LoomShadow.Brass()) }
}
