import SwiftUI
import LoomCore
import LoomDesign

/// Renders a ``Wall`` as positioned ``TileView``s with fluid cross-wall
/// animations.
///
/// Each tile is identified by ``photoID`` so SwiftUI can preserve views
/// across Shuffle: a photo present in both the old and new walls slides
/// from its old frame to its new one rather than fading out + in.
///
/// Layout coordinate system: the ``Wall`` is computed against a specific
/// canvas size. If the available size shrinks/grows (e.g. window resize),
/// we scale the whole wall uniformly to fit, preserving tile proportions.
/// A subsequent Shuffle recomposes for the new real size.
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

            ZStack(alignment: .topLeading) {
                ForEach(wall.tiles, id: \.photoID) { tile in
                    TileView(tile: tile, photo: photoByID[tile.photoID], style: wall.style)
                        .position(
                            x: (tile.frame.midX) * scale + offset.x,
                            y: (tile.frame.midY) * scale + offset.y
                        )
                        .frame(
                            width: tile.frame.width * scale,
                            height: tile.frame.height * scale
                        )
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal:   .scale(scale: 0.9).combined(with: .opacity)
                        ))
                }
            }
        }
    }

    private var photoByID: [PhotoID: Photo] {
        Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0) })
    }

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
