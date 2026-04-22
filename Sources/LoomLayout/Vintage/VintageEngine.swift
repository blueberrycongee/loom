import CoreGraphics
import Foundation
import LoomCore

/// Vintage — polaroid frames on a corkboard.
///
/// Feel: a snapshot scrapbook. Each tile has a thick white bottom margin
/// (the "polaroid signature space"), mild rotation ±3°, and laid out in
/// rows so the composition still reads as intentional. Unlike Collage, the
/// tiles don't overlap — each has its personal space. Unlike Tapestry,
/// each tile is square-cropped inside its frame and rotated slightly.
///
/// The white frame itself is handled at render-time by `TileView`, reading
/// `Tile.style` via the parent `Wall.style`. The engine's job is placement.
public struct VintageEngine: LayoutEngine, Sendable {

    public let style: Style = .vintage

    public init() {}

    public func compose(
        photos: [Photo],
        canvasSize: CGSize,
        rng: inout SeededRNG
    ) -> Wall {
        guard !photos.isEmpty, canvasSize.width > 0, canvasSize.height > 0 else {
            return Wall(style: .vintage, axis: .color, seed: rng.state,
                        tiles: [], canvasSize: canvasSize)
        }

        // Polaroid tiles are roughly square with a tall bottom margin.
        // We model them as 1:1.22 (the real polaroid ratio) rectangles.
        let polaroidAspect: CGFloat = 1.0 / 1.22

        // Target a grid with moderate density.
        let targetSide = canvasSize.height * 0.28
        let cols = max(2, Int((canvasSize.width / targetSide).rounded()))
        let rowCount = Int(ceil(Double(photos.count) / Double(cols)))
        let count = min(photos.count, cols * max(2, rowCount))
        let picks = Array(photos.prefix(count))

        let gutter: CGFloat = targetSide * 0.08
        let rows = Int(ceil(Double(picks.count) / Double(cols)))
        let tileH = targetSide
        let tileW = tileH * polaroidAspect

        let totalW = CGFloat(cols) * tileW + CGFloat(cols - 1) * gutter
        let totalH = CGFloat(rows) * tileH + CGFloat(rows - 1) * gutter
        let startX = (canvasSize.width  - totalW) / 2
        let startY = (canvasSize.height - totalH) / 2

        var tiles: [Tile] = []
        for (i, p) in picks.enumerated() {
            let r = i / cols
            let c = i % cols
            let x = startX + CGFloat(c) * (tileW + gutter)
            let y = startY + CGFloat(r) * (tileH + gutter)

            // Mild Gaussian rotation ±3°, clamped.
            let rot = max(-0.08, min(0.08, rng.gaussian() * 0.025))
            // Tiny random nudge so the grid doesn't feel machine-aligned.
            let jx = CGFloat(rng.double(in: -6..<6))
            let jy = CGFloat(rng.double(in: -6..<6))

            tiles.append(Tile(
                photoID: p.id,
                frame: CGRect(x: x + jx, y: y + jy, width: tileW, height: tileH),
                rotation: rot,
                z: i
            ))
        }

        return Wall(
            style: .vintage,
            axis: .color,
            seed: rng.state,
            tiles: tiles,
            canvasSize: canvasSize
        )
    }
}
