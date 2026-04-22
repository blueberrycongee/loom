import SwiftUI
import LoomDesign

/// The hero action of the app.
///
/// Capsule with a terracotta gradient fill, "Shuffle" label, and an
/// optional keyboard hint. Feels physical: the halo brightens on hover,
/// the whole thing depresses on press, a micro-haptic fires before the
/// animation, and a brief brass glow pulse confirms the action landed.
public struct ShuffleButton: View {

    public let action: () -> Void
    public let showShortcut: Bool
    @State private var hovered = false
    @State private var pressed = false
    @State private var glowing = false

    public init(showShortcut: Bool = true, action: @escaping () -> Void) {
        self.showShortcut = showShortcut
        self.action = action
    }

    public var body: some View {
        Button(action: fire) {
            HStack(spacing: LoomSpacing.sm) {
                Image(systemName: "shuffle")
                    .font(.system(size: 12, weight: .bold))

                Text("Shuffle")
                    .font(LoomType.heading)
                    .tracking(0.3)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                if showShortcut {
                    ShortcutChip(key: "⎵")
                        .padding(.leading, LoomSpacing.xxs)
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }
            }
            .foregroundStyle(Palette.canvas)
            .padding(.horizontal, LoomSpacing.md)
            .padding(.vertical, LoomSpacing.sm)
            .background(
                Capsule().fill(Palette.brassFill)
            )
            .overlay(
                Capsule().fill(
                    Palette.brassLift.opacity(glowing ? 0.4 : 0)
                )
            )
            .overlay(
                Capsule().strokeBorder(
                    Palette.brassLift.opacity(hovered ? 0.9 : 0.5),
                    lineWidth: hovered ? 0.8 : 0.5
                )
            )
            .scaleEffect(pressed ? 0.95 : (hovered ? 1.03 : 1.0))
        }
        .buttonStyle(.plain)
        .shadow(
            color: Palette.brass.opacity(glowing ? 0.35 : 0.18),
            radius: glowing ? 20 : 10,
            x: 0, y: 0
        )
        .shadow(
            color: LoomShadow.tone.opacity(0.12),
            radius: 4, x: 0, y: 2
        )
        .onHover { hovered = $0 }
        .animation(LoomMotion.hover, value: hovered)
        .animation(LoomMotion.snap,  value: pressed)
        .animation(glowing ? LoomMotion.snap : LoomMotion.breathe, value: glowing)
        .animation(LoomMotion.hover, value: showShortcut)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded   { _ in pressed = false }
        )
    }

    private func fire() {
        Haptics.shuffle()
        glowing = true
        action()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            glowing = false
        }
    }
}

private struct ShortcutChip: View {
    let key: String
    var body: some View {
        Text(key)
            .font(LoomType.monoSm)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(Palette.canvas.opacity(0.14))
            )
            .overlay(
                Capsule().strokeBorder(Palette.canvas.opacity(0.18), lineWidth: 0.5)
            )
    }
}
