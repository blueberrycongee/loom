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
///
/// Photos are rendered as-is — no cursor aura, no proximity brightness
/// shift, no saturation grading. The photo is the product; the chrome
/// disappears.
public struct WallCanvas: View {

    @Environment(AppModel.self) private var app
    let photos: [Photo]

    /// Live direct-manipulation override, kept as local @State so we
    /// don't rebuild the entire Wall struct on every drag tick. On
    /// drag-end the final frame is committed back into ``app.wall``
    /// (preserving ``wall.id`` so downstream staggered-wave animations
    /// don't re-trigger) and the override clears.
    @State private var dragOverride: DragOverride?

    private enum DragKind: Equatable {
        case resize(ResizeCorner)
        case move
    }

    private struct DragOverride: Equatable {
        let photoID: PhotoID
        let kind: DragKind
        let initialFrame: CGRect
        var currentFrame: CGRect
    }

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

            // Spread factor derived from the live hand-openness signal.
            // 0.5 openness = 1.0 factor (no change from composer).
            // Fist pulls tiles toward the canvas center by up to 45%;
            // open hand pushes them out by up to 35% — bounded so
            // tiles never vanish into the middle or fly off the wall.
            let spread = HandSenseTuning.spreadFactor(for: app.wallOpenness)
            let wallCenter = CGPoint(
                x: wall.canvasSize.width / 2,
                y: wall.canvasSize.height / 2
            )

            ZStack(alignment: .topLeading) {
                ForEach(wall.tiles, id: \.photoID) { tile in
                    let delay = staggerDelay(for: tile, wall: wall)
                    let isInteracting = dragOverride?.photoID == tile.photoID
                    // Effective frame: the drag-override's live rect while
                    // a drag is in flight, otherwise the committed tile.frame.
                    let effectiveFrame = isInteracting
                        ? dragOverride!.currentFrame
                        : tile.frame
                    let spreadMid = spreadPosition(
                        original: CGPoint(x: effectiveFrame.midX, y: effectiveFrame.midY),
                        around: wallCenter,
                        by: spread
                    )

                    // Build a display-tile whose frame tracks the live
                    // drag override so TileView's internal .frame() —
                    // which sizes the photo, clip shape, and overlays —
                    // updates in real time during a resize/move drag.
                    // Without this, TileView uses the committed tile.frame
                    // and the image stays frozen at the original size.
                    let displayTile: Tile = {
                        var t = tile
                        t.frame = effectiveFrame
                        return t
                    }()

                    TileView(
                        tile: displayTile,
                        photo: photoByID[tile.photoID],
                        style: wall.style,
                        isLocked: app.lockedPhotoIDs.contains(tile.photoID),
                        isInteracting: isInteracting,
                        onToggleLock: {
                            withLoomAnimation(LoomMotion.snap) {
                                app.toggleLock(tile.photoID)
                            }
                            Haptics.snap()
                        },
                        onResize: { corner, phase in
                            handleResize(tile: tile, corner: corner, phase: phase, scale: scale)
                        },
                        onMove: { phase in
                            handleMove(tile: tile, phase: phase, scale: scale)
                        }
                    )
                    .position(
                        x: spreadMid.x * scale + offset.x,
                        y: spreadMid.y * scale + offset.y
                    )
                    .frame(
                        width: effectiveFrame.width * scale,
                        height: effectiveFrame.height * scale
                    )
                    // Raise the actively-dragged tile above its neighbors
                    // so its shadow halo doesn't get clipped behind them.
                    .zIndex(isInteracting ? 1 : 0)
                    .transition(Weave.insertTransition(delay: delay))
                    .animation(Weave.settleAnimation(delay: delay), value: wall.id)
                    // Subtle spring just for the openness-driven glide so
                    // hand motion reads as a physical pull rather than an
                    // abrupt reposition. Separate from the shuffle
                    // animation (value: wall.id) so they don't fight.
                    .animation(.spring(response: 0.45, dampingFraction: 0.78), value: app.wallOpenness)
                }
            }
        }
    }

    // MARK: — Direct manipulation

    private func handleResize(
        tile: Tile,
        corner: ResizeCorner,
        phase: TileDragPhase,
        scale: CGFloat
    ) {
        switch phase {
        case .began:
            dragOverride = DragOverride(
                photoID: tile.photoID,
                kind: .resize(corner),
                initialFrame: tile.frame,
                currentFrame: tile.frame
            )
        case .changed(let translationScreen):
            guard var override = dragOverride,
                  override.photoID == tile.photoID,
                  case .resize(let activeCorner) = override.kind,
                  activeCorner == corner,
                  scale > 0 else { return }
            override.currentFrame = resizedFrame(
                from: override.initialFrame,
                corner: corner,
                translationScreen: translationScreen,
                scale: scale
            )
            dragOverride = override
        case .ended:
            guard let override = dragOverride,
                  override.photoID == tile.photoID else { return }
            commit(photoID: override.photoID, to: override.currentFrame)
            dragOverride = nil
        }
    }

    private func handleMove(tile: Tile, phase: TileDragPhase, scale: CGFloat) {
        switch phase {
        case .began:
            dragOverride = DragOverride(
                photoID: tile.photoID,
                kind: .move,
                initialFrame: tile.frame,
                currentFrame: tile.frame
            )
        case .changed(let translationScreen):
            guard var override = dragOverride,
                  override.photoID == tile.photoID,
                  case .move = override.kind,
                  scale > 0 else { return }
            let dx = translationScreen.width  / scale
            let dy = translationScreen.height / scale
            override.currentFrame = clampedToCanvas(
                override.initialFrame.offsetBy(dx: dx, dy: dy),
                canvas: app.wall.canvasSize
            )
            dragOverride = override
        case .ended:
            guard let override = dragOverride,
                  override.photoID == tile.photoID,
                  case .move = override.kind else { return }
            commit(photoID: override.photoID, to: override.currentFrame)
            dragOverride = nil
        }
    }

    /// Compute the resized frame for a corner-drag. The *opposite* corner
    /// stays fixed (that's the anchor); the dragged corner moves along
    /// its outward diagonal. Aspect is locked to the original so photos
    /// never stretch. A minimum of 40pt and 85% of the canvas provides
    /// a sane range.
    private func resizedFrame(
        from initial: CGRect,
        corner: ResizeCorner,
        translationScreen: CGSize,
        scale: CGFloat
    ) -> CGRect {
        let dxCanvas = translationScreen.width  / scale
        let dyCanvas = translationScreen.height / scale
        // Project drag onto the corner's outward direction: positive =
        // grow, negative = shrink. A pure horizontal or vertical drag
        // still produces a signed magnitude because the outward vector
        // has both components.
        let out = corner.outward
        let outwardDelta = dxCanvas * out.width + dyCanvas * out.height

        let aspect = initial.width / max(initial.height, 1)
        let minW: CGFloat = 40
        let maxW = max(minW + 1, app.wall.canvasSize.width * 0.85)
        let rawW = initial.width + outwardDelta
        let newW = min(maxW, max(minW, rawW))
        let newH = newW / aspect

        // Anchor point: the corner diagonally opposite the handle stays
        // fixed in canvas space. New origin is derived from that anchor.
        let anchor: CGPoint
        switch corner {
        case .topLeft:     anchor = CGPoint(x: initial.maxX, y: initial.maxY)
        case .topRight:    anchor = CGPoint(x: initial.minX, y: initial.maxY)
        case .bottomLeft:  anchor = CGPoint(x: initial.maxX, y: initial.minY)
        case .bottomRight: anchor = CGPoint(x: initial.minX, y: initial.minY)
        }
        let newOrigin: CGPoint
        switch corner {
        case .topLeft:     newOrigin = CGPoint(x: anchor.x - newW, y: anchor.y - newH)
        case .topRight:    newOrigin = CGPoint(x: anchor.x,         y: anchor.y - newH)
        case .bottomLeft:  newOrigin = CGPoint(x: anchor.x - newW, y: anchor.y)
        case .bottomRight: newOrigin = CGPoint(x: anchor.x,         y: anchor.y)
        }
        return CGRect(origin: newOrigin, size: CGSize(width: newW, height: newH))
    }

    /// Keep the tile's center within the canvas so a move can't strand
    /// a tile off-screen. The tile can still extend beyond the canvas
    /// edge — that matches the wall's existing bleed feel — but the
    /// center stays reachable.
    private func clampedToCanvas(_ rect: CGRect, canvas: CGSize) -> CGRect {
        guard canvas.width > 0, canvas.height > 0 else { return rect }
        let cx = min(canvas.width,  max(0, rect.midX))
        let cy = min(canvas.height, max(0, rect.midY))
        return CGRect(
            x: cx - rect.width  / 2,
            y: cy - rect.height / 2,
            width: rect.width,
            height: rect.height
        )
    }

    /// Replace one tile's frame in ``app.wall`` with the new rect,
    /// preserving the wall's identity so downstream
    /// `.animation(_:, value: wall.id)` watchers don't re-fire.
    private func commit(photoID: PhotoID, to newFrame: CGRect) {
        var tiles = app.wall.tiles
        guard let idx = tiles.firstIndex(where: { $0.photoID == photoID }) else { return }
        tiles[idx].frame = newFrame
        app.wall = Wall(
            id: app.wall.id,
            style: app.wall.style,
            axis: app.wall.axis,
            seed: app.wall.seed,
            tiles: tiles,
            canvasSize: app.wall.canvasSize,
            composedAt: app.wall.composedAt
        )
    }

    /// Scale `original` around `center` by `factor`. `factor` = 1 is
    /// no-op; < 1 pulls closer to center; > 1 pushes away.
    private func spreadPosition(
        original: CGPoint,
        around center: CGPoint,
        by factor: Double
    ) -> CGPoint {
        CGPoint(
            x: center.x + (original.x - center.x) * factor,
            y: center.y + (original.y - center.y) * factor
        )
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
        return Weave.stagger(
            normalizedPosition: normalized,
            index: tile.photoID.rawValue.hashValue
        )
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
