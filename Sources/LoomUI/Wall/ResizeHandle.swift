import SwiftUI
import LoomCore
import LoomDesign

/// A small corner handle. Four of these sit at the four corners of a
/// hovered tile; each emits its own ``ResizeCorner`` so ``WallCanvas``
/// can apply the right anchor math (the opposite corner stays fixed while
/// the drag grows or shrinks the tile along the diagonal).
///
/// The handle never touches sizes directly — it pipes ``TileDragPhase``
/// events up; only the canvas knows the current render scale needed to
/// convert screen-space drag into wall-space size changes.
struct ResizeHandle: View {

    let corner: ResizeCorner
    let onResize: (ResizeCorner, TileDragPhase) -> Void

    @State private var dragging = false

    var body: some View {
        Circle()
            .fill(Palette.surface)
            .overlay(
                Circle().strokeBorder(Palette.brass.opacity(0.85), lineWidth: 1)
            )
            .frame(width: 12, height: 12)
            .shadow(color: LoomShadow.tone.opacity(0.18), radius: 2, x: 0, y: 1)
            .scaleEffect(dragging ? 1.4 : 1.0)
            .animation(LoomMotion.snap, value: dragging)
            // Expand the touch target without enlarging the visual so a
            // 12pt dot is still easy to grab on a small tile.
            .contentShape(Circle().inset(by: -6))
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if !dragging {
                            dragging = true
                            onResize(corner, .began)
                        }
                        onResize(corner, .changed(value.translation))
                    }
                    .onEnded { _ in
                        dragging = false
                        onResize(corner, .ended)
                    }
            )
    }
}
