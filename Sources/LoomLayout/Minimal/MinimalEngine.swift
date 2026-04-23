import CoreGraphics
import Foundation
import LoomCore

/// Minimal — three to five photos, maximally distinct, a lot of breathing room.
///
/// Feel: a curator's pick. No noise, no filler. Works well when the user has
/// a library of strong singles and wants the wall to say *look at these*.
///
/// Algorithm:
///   1. Take the first 3–5 photos from the input (Composer will have already
///      stratified them by luminance, which gives us the contrast we want).
///   2. Decide on an axis — horizontal (wider canvas) or vertical (taller).
///   3. Lay them down as equal-height rectangles along that axis, with a
///      generous gutter (10% of canvas short-dim).
///   4. Center the composition both ways — asymmetry breaks the minimal feel.
public struct MinimalEngine: LayoutEngine, Sendable {

    public let style: Style = .minimal

    public init() {}

    public func compose(
        photos: [Photo],
        canvasSize: CGSize,
        rng: inout SeededRNG
    ) -> Wall {
        let count = max(1, photos.count)
        guard count > 0, canvasSize.width > 0, canvasSize.height > 0 else {
            return Wall(style: .minimal, axis: .color, seed: rng.state,
                        tiles: [], canvasSize: canvasSize)
        }

        let picks = Array(photos.prefix(count))
        let horizontal = canvasSize.width >= canvasSize.height

        // Generous gutter: 10% of the short dimension.
        let gutter = CGFloat(min(canvasSize.width, canvasSize.height) * 0.08)

        // The composition occupies 70% of the long axis, 60% of the short.
        let longAxis  = horizontal ? canvasSize.width  : canvasSize.height
        let shortAxis = horizontal ? canvasSize.height : canvasSize.width
        let stripLong  = longAxis  * 0.76
        let stripShort = shortAxis * 0.60

        // Uniform height; widths by aspect.
        let cellShort = stripShort
        let totalGutter = CGFloat(count - 1) * gutter
        var rawWidths = picks.map { CGFloat($0.aspect) * cellShort }
        let rawSum = rawWidths.reduce(0, +)
        let available = stripLong - totalGutter
        let scale = available / rawSum
        rawWidths = rawWidths.map { $0 * scale }

        // Center within the canvas.
        let totalUsed = rawWidths.reduce(0, +) + totalGutter
        let startLong  = (longAxis  - totalUsed) / 2
        let startShort = (shortAxis - cellShort) / 2

        var tiles: [Tile] = []
        var cursor = startLong
        for (i, p) in picks.enumerated() {
            let w = rawWidths[i]
            let frame: CGRect
            if horizontal {
                frame = CGRect(x: cursor, y: startShort, width: w, height: cellShort)
            } else {
                frame = CGRect(x: startShort, y: cursor, width: cellShort, height: w)
            }
            tiles.append(Tile(photoID: p.id, frame: frame))
            cursor += w + gutter
        }

        return Wall(
            style: .minimal,
            axis: .color,
            seed: rng.state,
            tiles: tiles,
            canvasSize: canvasSize
        )
    }
}
