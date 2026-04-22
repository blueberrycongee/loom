import SwiftUI

/// A small shadow library. Dark UIs are easy to make feel flat; the fix is
/// layered shadows that simulate ambient + key lighting. Loom's surfaces use
/// one of these three — never ad-hoc shadow values — so the lighting stays
/// consistent across the app.
public enum LoomShadow {

    /// For tiles on the canvas. Soft, one-directional, low contrast.
    public struct Tile: ViewModifier {
        public func body(content: Content) -> some View {
            content
                .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 8)
                .shadow(color: .black.opacity(0.16), radius: 2,  x: 0, y: 1)
        }
    }

    /// For elevated surfaces — popovers, the command palette.
    public struct Surface: ViewModifier {
        public func body(content: Content) -> some View {
            content
                .shadow(color: .black.opacity(0.45), radius: 32, x: 0, y: 16)
                .shadow(color: .black.opacity(0.22), radius: 4,  x: 0, y: 2)
        }
    }

    /// For the primary CTA — a subtle brass halo so the button feels warm.
    public struct Brass: ViewModifier {
        public func body(content: Content) -> some View {
            content
                .shadow(color: Palette.brass.opacity(0.28), radius: 16, x: 0, y: 0)
                .shadow(color: .black.opacity(0.35),        radius: 8,  x: 0, y: 4)
        }
    }
}

public extension View {
    func tileShadow()    -> some View { modifier(LoomShadow.Tile()) }
    func surfaceShadow() -> some View { modifier(LoomShadow.Surface()) }
    func brassShadow()   -> some View { modifier(LoomShadow.Brass()) }
}
