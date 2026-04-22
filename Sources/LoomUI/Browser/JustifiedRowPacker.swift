import CoreGraphics
import LoomCore

/// A small, pure justified-row packer for the grid browser.
///
/// Not to be confused with the Tapestry engine (M2): that one scores walls
/// against aesthetic objectives, while this one is just "fill rows with
/// photos at a target height, stretching each row to the full width". The
/// browser wants uniform row heights; Tapestry will want more.
///
/// Algorithm, in words: pick photos greedily at the target height. When the
/// row's combined width overflows the available width, scale every tile in
/// the row down so the combined width equals available width exactly. That
/// changes the row's height slightly — so each row's height is in
/// ``Row.height`` (≠ targetHeight).
public enum JustifiedRowPacker {

    public struct Placement: Identifiable {
        public let photo: Photo
        public let frame: CGRect     // origin (0, 0); width/height only
        public var id: PhotoID { photo.id }
    }

    public typealias Row = [Placement]

    public static func pack(
        photos: [Photo],
        availableWidth: CGFloat,
        targetRowHeight: CGFloat,
        gutter: CGFloat
    ) -> [Row] {
        guard availableWidth > 0, targetRowHeight > 0 else { return [] }

        var rows: [Row] = []
        var row: [(Photo, CGFloat)] = []   // (photo, unit width at target height)
        var rowWidth: CGFloat = 0

        for p in photos {
            let w = CGFloat(p.aspect) * targetRowHeight
            row.append((p, w))
            rowWidth += w
            if !row.isEmpty {
                rowWidth += gutter
            }
            let widthWithoutLastGutter = rowWidth - gutter
            if widthWithoutLastGutter >= availableWidth {
                rows.append(justify(row, to: availableWidth, gutter: gutter))
                row.removeAll(keepingCapacity: true)
                rowWidth = 0
            }
        }

        // Trailing row — leave it at target height, don't stretch (prevents
        // a last-row-tiny-stretch artifact on almost-empty libraries).
        if !row.isEmpty {
            let placements = row.map { (photo, w) in
                Placement(photo: photo, frame: CGRect(x: 0, y: 0, width: w, height: targetRowHeight))
            }
            rows.append(placements)
        }

        return rows
    }

    private static func justify(_ row: [(Photo, CGFloat)], to target: CGFloat, gutter: CGFloat) -> Row {
        let count = row.count
        let gutters = CGFloat(max(0, count - 1)) * gutter
        let tilesTotal = row.reduce(0) { $0 + $1.1 }
        let available = target - gutters
        let scale = available / tilesTotal
        return row.map { (photo, w) in
            let scaledW = (w * scale).rounded()
            let scaledH = (w * scale / CGFloat(photo.aspect)).rounded()
            return Placement(
                photo: photo,
                frame: CGRect(x: 0, y: 0, width: scaledW, height: scaledH)
            )
        }
    }
}
