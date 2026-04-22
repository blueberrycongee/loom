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
                    let spreadMid = spreadPosition(
                        original: CGPoint(x: tile.frame.midX, y: tile.frame.midY),
                        around: wallCenter,
                        by: spread
                    )

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
                    .position(
                        x: spreadMid.x * scale + offset.x,
                        y: spreadMid.y * scale + offset.y
                    )
                    .frame(
                        width: tile.frame.width * scale,
                        height: tile.frame.height * scale
                    )
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
