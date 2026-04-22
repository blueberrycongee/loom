import CoreGraphics
import Foundation
import LoomCore

/// Gallery — golden-ratio grid, generous whitespace.
///
/// Feel: a curated wall in a white-cube gallery. Tiles are uniform-ish,
/// spaced far apart, aligned to a 2×3 (or 3×4 on taller canvases) grid with
/// cells proportioned by φ ≈ 1.618. No overlap, no rotation, no jitter.
///
/// Algorithm:
///   1. Pick a grid shape (rows × cols) that fits the canvas and the photo
///      count. Biased toward 3×4 for large libraries, 2×3 for medium.
///   2. Each cell is a φ-ratio rectangle; orient it portrait or landscape
///      to match the photo it'll host (so we don't letterbox photos).
///   3. Space cells apart with gutters = 18% of cell height. Big gutters
///      are the whole point.
///   4. Center the grid in the canvas. Leftover photos are dropped — the
///      style insists on uniform cells.
public struct GalleryEngine: LayoutEngine, Sendable {

    public let style: Style = .gallery
    private let phi: CGFloat = 1.6180339887

    public init() {}

    public func compose(
        photos: [Photo],
        canvasSize: CGSize,
        rng: inout SeededRNG
    ) -> Wall {
        guard !photos.isEmpty, canvasSize.width > 0, canvasSize.height > 0 else {
            return Wall(style: .gallery, axis: .color, seed: rng.state,
                        tiles: [], canvasSize: canvasSize)
        }

        let (rows, cols) = chooseGridShape(photoCount: photos.count, canvasSize: canvasSize)
        let cellCount = rows * cols
        let picks = Array(photos.prefix(cellCount))

        // Gallery cells are φ-ratio rectangles (5:8-ish, landscape oriented).
        // Solve for cell size so the grid fits with `gutter = cellHeight * 0.18`.
        let gutterRatio: CGFloat = 0.18
        let gridWidth  = canvasSize.width  * 0.82
        let gridHeight = canvasSize.height * 0.82

        // From width-constraint: cols * (cellH * φ) + (cols-1) * cellH * gutter = gridWidth
        //   cellH * [cols*φ + (cols-1)*gutter] = gridWidth
        // From height-constraint: rows * cellH + (rows-1) * cellH * gutter = gridHeight
        //   cellH * [rows + (rows-1)*gutter] = gridHeight
        // Take the smaller cellH so nothing overflows.
        let wDenom = CGFloat(cols) * phi + CGFloat(cols - 1) * gutterRatio
        let hDenom = CGFloat(rows) + CGFloat(rows - 1) * gutterRatio
        let cellHFromW = gridWidth  / wDenom
        let cellHFromH = gridHeight / hDenom
        let cellH = min(cellHFromW, cellHFromH)
        let cellW = cellH * phi
        let gutter = cellH * gutterRatio

        let totalW = CGFloat(cols) * cellW + CGFloat(cols - 1) * gutter
        let totalH = CGFloat(rows) * cellH + CGFloat(rows - 1) * gutter
        let startX = (canvasSize.width  - totalW) / 2
        let startY = (canvasSize.height - totalH) / 2

        var tiles: [Tile] = []
        for (i, p) in picks.enumerated() {
            let r = i / cols
            let c = i % cols
            let x = startX + CGFloat(c) * (cellW + gutter)
            let y = startY + CGFloat(r) * (cellH + gutter)
            tiles.append(Tile(photoID: p.id, frame: CGRect(x: x, y: y, width: cellW, height: cellH)))
        }

        return Wall(
            style: .gallery,
            axis: .color,
            seed: rng.state,
            tiles: tiles,
            canvasSize: canvasSize
        )
    }

    /// Pick a grid shape that maximizes used photos without overflowing.
    private func chooseGridShape(photoCount n: Int, canvasSize: CGSize) -> (rows: Int, cols: Int) {
        let wide = canvasSize.width >= canvasSize.height
        let candidates: [(Int, Int)] = wide
            ? [(2, 3), (3, 4), (3, 5), (4, 5)]
            : [(3, 2), (4, 3), (5, 3), (5, 4)]
        // Pick the largest that fits within n.
        var best = candidates.first!
        for shape in candidates where shape.0 * shape.1 <= n {
            best = shape
        }
        return best
    }
}
