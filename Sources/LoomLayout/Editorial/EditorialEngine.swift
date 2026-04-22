import CoreGraphics
import Foundation
import LoomCore

/// Editorial — one hero, supporting satellites.
///
/// Feel: a magazine double-page spread. A single photo carries 55-65% of
/// the canvas; four to eight satellites fill the remainder, stacked in a
/// column or a tight grid. The split is left-right on wide canvases,
/// top-bottom on tall ones.
///
/// Hero selection: the photo whose aspect best matches the hero zone's
/// aspect — so the hero doesn't letterbox. Satellites are everything else
/// with aspect alternation.
public struct EditorialEngine: LayoutEngine, Sendable {

    public let style: Style = .editorial

    public init() {}

    public func compose(
        photos: [Photo],
        canvasSize: CGSize,
        rng: inout SeededRNG
    ) -> Wall {
        guard photos.count >= 2, canvasSize.width > 0, canvasSize.height > 0 else {
            return Wall(style: .editorial, axis: .color, seed: rng.state,
                        tiles: [], canvasSize: canvasSize)
        }

        let wide = canvasSize.width >= canvasSize.height
        let heroFraction: CGFloat = 0.62

        // Hero zone rect.
        let heroRect: CGRect
        let satellitesRect: CGRect
        if wide {
            // Hero on the left randomly, on the right half the time.
            let heroOnLeft = rng.unit() < 0.5
            let hw = canvasSize.width * heroFraction
            if heroOnLeft {
                heroRect = CGRect(x: 0, y: 0, width: hw, height: canvasSize.height)
                satellitesRect = CGRect(x: hw, y: 0, width: canvasSize.width - hw, height: canvasSize.height)
            } else {
                heroRect = CGRect(x: canvasSize.width - hw, y: 0, width: hw, height: canvasSize.height)
                satellitesRect = CGRect(x: 0, y: 0, width: canvasSize.width - hw, height: canvasSize.height)
            }
        } else {
            // Tall canvas — hero on top or bottom.
            let heroOnTop = rng.unit() < 0.5
            let hh = canvasSize.height * heroFraction
            if heroOnTop {
                heroRect = CGRect(x: 0, y: 0, width: canvasSize.width, height: hh)
                satellitesRect = CGRect(x: 0, y: hh, width: canvasSize.width, height: canvasSize.height - hh)
            } else {
                heroRect = CGRect(x: 0, y: canvasSize.height - hh, width: canvasSize.width, height: hh)
                satellitesRect = CGRect(x: 0, y: 0, width: canvasSize.width, height: canvasSize.height - hh)
            }
        }

        let heroAspect = Double(heroRect.width / heroRect.height)
        let heroMargin: CGFloat = 24

        // Hero: the photo whose aspect is closest to the hero zone's aspect.
        let heroIdx = photos.indices.min(by: {
            abs(photos[$0].aspect - heroAspect) < abs(photos[$1].aspect - heroAspect)
        })!
        let hero = photos[heroIdx]
        var satellites = photos
        satellites.remove(at: heroIdx)

        var tiles: [Tile] = []
        let heroFitted = Aspect.fit(
            aspect: hero.aspect,
            into: heroRect.insetBy(dx: heroMargin, dy: heroMargin)
        )
        tiles.append(Tile(photoID: hero.id, frame: heroFitted))

        // Satellites: stack inside the satellites rect. Orient stacks
        // perpendicular to the hero split.
        let satMargin: CGFloat = 18
        let inner = satellitesRect.insetBy(dx: satMargin, dy: satMargin)
        let count = min(satellites.count, wide ? 4 : 3)

        if wide {
            // Vertical stack, uniform height.
            let gutter: CGFloat = 10
            let h = (inner.height - CGFloat(count - 1) * gutter) / CGFloat(count)
            var y = inner.minY
            for p in satellites.prefix(count) {
                let w = inner.width
                let fitted = Aspect.fit(aspect: p.aspect,
                                        into: CGRect(x: inner.minX, y: y, width: w, height: h))
                tiles.append(Tile(photoID: p.id, frame: fitted))
                y += h + gutter
            }
        } else {
            // Horizontal row.
            let gutter: CGFloat = 10
            let w = (inner.width - CGFloat(count - 1) * gutter) / CGFloat(count)
            var x = inner.minX
            for p in satellites.prefix(count) {
                let h = inner.height
                let fitted = Aspect.fit(aspect: p.aspect,
                                        into: CGRect(x: x, y: inner.minY, width: w, height: h))
                tiles.append(Tile(photoID: p.id, frame: fitted))
                x += w + gutter
            }
        }

        return Wall(
            style: .editorial,
            axis: .color,
            seed: rng.state,
            tiles: tiles,
            canvasSize: canvasSize
        )
    }
}
