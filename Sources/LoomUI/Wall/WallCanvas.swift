import SwiftUI
import LoomCore
import LoomDesign

/// Renders a ``Wall`` with the signature Weave motion: tiles arrive in a
/// left-to-right wave rather than all at once.
///
/// Tile identity is ``photoID``, so a photo present in both the old and new
/// wall is preserved; its frame animates to the new position. New tiles
/// enter with a staggered scale-fade-in; removed tiles leave with a
/// staggered scale-fade-out. Remaining tiles' position changes inherit the
/// same stagger delay so *everything* feels like one coherent wave.
public struct WallCanvas: View {

    @Environment(AppModel.self) private var app
    let photos: [Photo]

    @State private var cursor: CGPoint?

    public init(photos: [Photo]) {
        self.photos = photos
    }

    public var body: some View {
        GeometryReader { geo in
            let wall = app.wall
            let scale = computeScale(wallCanvas: wall.canvasSize, available: geo.size)
            let offset = centeringOffset(
                wallSize: wall.canvasSize,
                available: geo.size,
                scale: scale
            )
            let cursorInWall = cursorProjectedIntoWall(
                cursor: cursor, offset: offset, scale: scale
            )

            ZStack(alignment: .topLeading) {
                ForEach(wall.tiles, id: \.photoID) { tile in
                    let delay = staggerDelay(for: tile, wall: wall)
                    let proximity = tileProximity(tile: tile, cursor: cursorInWall)

                    TileView(
                        tile: tile,
                        photo: photoByID[tile.photoID],
                        style: wall.style,
                        isLocked: app.lockedPhotoIDs.contains(tile.photoID),
                        onToggleLock: {
                            withLoomAnimation(LoomMotion.snap) {
                                app.toggleLock(tile.photoID)
                            }
                            Haptics.snap()
                        }
                    )
                    .brightness(proximity * 0.05)
                    .saturation(1.0 - (1.0 - proximity) * 0.12)
                    .position(
                        x: tile.frame.midX * scale + offset.x,
                        y: tile.frame.midY * scale + offset.y
                    )
                    .frame(
                        width: tile.frame.width * scale,
                        height: tile.frame.height * scale
                    )
                    .transition(Weave.insertTransition(delay: delay))
                    .animation(Weave.settleAnimation(delay: delay), value: wall.id)
                    .animation(LoomMotion.hover, value: proximity)
                }
            }
            .overlay {
                CursorAura(cursor: cursor)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let p): cursor = p
                case .ended:         cursor = nil
                }
            }
        }
    }

    private var photoByID: [PhotoID: Photo] {
        Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0) })
    }

    // MARK: — Stagger

    private func staggerDelay(for tile: Tile, wall: Wall) -> Double {
        let w = max(1, wall.canvasSize.width)
        // Wave direction: left-to-right along x. A small y-contribution
        // curves the wave so it doesn't read as a dead metronome.
        let xp = Double(tile.frame.midX / w)
        let yp = Double(tile.frame.midY / max(1, wall.canvasSize.height))
        let normalized = xp * 0.85 + yp * 0.15
        // Deterministic index from photo-ID string hash so jitter is stable
        // per identity, not per-render.
        return Weave.stagger(
            normalizedPosition: normalized,
            index: tile.photoID.rawValue.hashValue
        )
    }

    // MARK: — Pointer aura

    private func cursorProjectedIntoWall(
        cursor: CGPoint?, offset: CGPoint, scale: CGFloat
    ) -> CGPoint? {
        guard let c = cursor, scale > 0 else { return nil }
        return CGPoint(
            x: (c.x - offset.x) / scale,
            y: (c.y - offset.y) / scale
        )
    }

    private func tileProximity(tile: Tile, cursor: CGPoint?) -> Double {
        guard let c = cursor else { return 0.45 }  // ambient wash when idle
        let dx = Double(tile.frame.midX - c.x)
        let dy = Double(tile.frame.midY - c.y)
        let dist = (dx * dx + dy * dy).squareRoot()
        // 240pt halo — anything closer gets a glow; anything farther is base.
        let halo = 240.0
        let near = max(0, 1 - dist / halo)
        // Ease-in so the fall-off feels "warm", not linear.
        return near * near
    }

    // MARK: — Geometry

    private func computeScale(wallCanvas: CGSize, available: CGSize) -> CGFloat {
        guard wallCanvas.width > 0, wallCanvas.height > 0 else { return 1 }
        let sx = available.width  / wallCanvas.width
        let sy = available.height / wallCanvas.height
        return min(sx, sy)
    }

    private func centeringOffset(
        wallSize: CGSize,
        available: CGSize,
        scale: CGFloat
    ) -> CGPoint {
        CGPoint(
            x: (available.width  - wallSize.width  * scale) / 2,
            y: (available.height - wallSize.height * scale) / 2
        )
    }
}

// MARK: — Cursor aura

/// A very soft warm glow that follows the pointer. Sits above the tiles
/// with `.plusLighter` blend at low alpha, so it lifts whatever's under it
/// without adding hard edges. Fades in smoothly when the cursor enters
/// the wall, out when it leaves.
private struct CursorAura: View {
    let cursor: CGPoint?

    var body: some View {
        GeometryReader { _ in
            if let c = cursor {
                RadialGradient(
                    stops: [
                        .init(color: Palette.brassLift.opacity(0.14), location: 0.0),
                        .init(color: Palette.brass.opacity(0.06),     location: 0.35),
                        .init(color: .clear,                          location: 1.0)
                    ],
                    center: UnitPoint(x: 0.5, y: 0.5),
                    startRadius: 0,
                    endRadius: 260
                )
                .frame(width: 520, height: 520)
                .position(c)
                .blendMode(.plusLighter)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.18), value: cursor == nil)
    }
}
