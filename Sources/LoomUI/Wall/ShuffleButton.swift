import SwiftUI
import LoomDesign

/// The hero action of the app.
///
/// Look: capsule, brass fill with subtle inner highlight, "SHUFFLE" in
/// rounded small-caps, a keyboard hint on the trailing edge. Feels physical
/// — the brass halo brightens on hover, the whole thing depresses by 2pt on
/// press, and a micro-haptic fires on the hand before the animation starts.
public struct ShuffleButton: View {

    public let action: () -> Void
    @State private var hovered = false
    @State private var pressed = false

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: fire) {
            HStack(spacing: LoomSpacing.sm) {
                ShuttleIcon()
                    .frame(width: 18, height: 18)

                Text("Shuffle")
                    .font(LoomType.heading)
                    .tracking(0.4)

                Spacer(minLength: LoomSpacing.md)

                ShortcutChip(key: "⎵")
            }
            .foregroundStyle(Palette.canvas)
            .padding(.horizontal, LoomSpacing.lg)
            .padding(.vertical, LoomSpacing.md)
            .frame(minWidth: 220)
            .background(
                Capsule().fill(Palette.brassFill)
            )
            .overlay(
                Capsule().strokeBorder(
                    Palette.brassLift.opacity(hovered ? 0.95 : 0.6),
                    lineWidth: hovered ? 0.8 : 0.5
                )
            )
            .scaleEffect(pressed ? 0.97 : (hovered ? 1.03 : 1.0))
        }
        .buttonStyle(.plain)
        .brassShadow()
        .onHover { hovered = $0 }
        .animation(LoomMotion.hover, value: hovered)
        .animation(LoomMotion.snap,  value: pressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }

    private func fire() {
        Haptics.shuffle()
        action()
    }
}

private struct ShuttleIcon: View {
    var body: some View {
        // A stylised loom shuttle: an ellipse with a vertical thread through it.
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let rect = CGRect(x: 0, y: h * 0.3, width: w, height: h * 0.4)
            ctx.fill(Path(ellipseIn: rect), with: .color(Palette.canvas))
            ctx.stroke(
                Path { p in
                    p.move(to: .init(x: w * 0.5, y: 0))
                    p.addLine(to: .init(x: w * 0.5, y: h))
                },
                with: .color(Palette.canvas.opacity(0.8)),
                lineWidth: 1
            )
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
                Capsule().strokeBorder(Palette.canvas.opacity(0.2), lineWidth: 0.5)
            )
    }
}
