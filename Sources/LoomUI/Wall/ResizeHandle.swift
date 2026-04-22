import SwiftUI
import LoomCore
import LoomDesign

/// A small diagonal-chevron drag handle that sits in the bottom-right
/// corner of a hovered tile. Drag it to resize the tile with aspect
/// locked. The handle never emits size values directly — it pipes
/// ``ResizePhase`` events up to ``WallCanvas``, which does the
/// screen-to-canvas conversion because only it knows the current
/// render scale.
struct ResizeHandle: View {

    let onResize: (ResizePhase) -> Void

    @State private var dragging = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Palette.surface.opacity(0.92))
                .background(.ultraThinMaterial, in: Circle())
            Circle()
                .strokeBorder(Palette.hairline, lineWidth: 1)
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Palette.brass)
        }
        .frame(width: 22, height: 22)
        .shadow(color: LoomShadow.tone.opacity(0.12), radius: 3, x: 0, y: 1)
        .scaleEffect(dragging ? 1.15 : 1.0)
        .animation(LoomMotion.snap, value: dragging)
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    if !dragging {
                        dragging = true
                        onResize(.began)
                    }
                    onResize(.changed(value.translation))
                }
                .onEnded { _ in
                    dragging = false
                    onResize(.ended)
                }
        )
    }
}
