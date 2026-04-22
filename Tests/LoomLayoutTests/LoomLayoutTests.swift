import XCTest
import LoomCore
@testable import LoomLayout

final class LoomLayoutTests: XCTestCase {

    // MARK: — Helpers

    private func photo(
        idSeed: Int,
        aspect: Double,
        l: Double = 50,
        a: Double = 0,
        b: Double = 0
    ) -> Photo {
        Photo(
            id: PhotoID("p\(idSeed)"),
            url: URL(fileURLWithPath: "/dev/null/\(idSeed)"),
            pixelSize: PixelSize(width: Int(100 * aspect), height: 100),
            dominantColor: LabColor(l: l, a: a, b: b),
            colorTemperature: ColorTemperature(kelvin: 5500),
            indexedAt: Date(timeIntervalSince1970: 0)
        )
    }

    // MARK: — TapestryEngine

    func testTapestryDeterministicForSameSeed() {
        let engine = TapestryEngine()
        let photos = (0..<24).map { photo(idSeed: $0, aspect: 0.75 + Double($0 % 3) * 0.25) }
        var rng1 = SeededRNG(seed: 999)
        var rng2 = SeededRNG(seed: 999)
        let wall1 = engine.compose(photos: photos, canvasSize: .init(width: 1200, height: 800), rng: &rng1)
        let wall2 = engine.compose(photos: photos, canvasSize: .init(width: 1200, height: 800), rng: &rng2)
        XCTAssertEqual(wall1.tiles.count, wall2.tiles.count)
        for (t1, t2) in zip(wall1.tiles, wall2.tiles) {
            XCTAssertEqual(t1.photoID, t2.photoID)
            XCTAssertEqual(t1.frame.width,  t2.frame.width,  accuracy: 0.01)
            XCTAssertEqual(t1.frame.height, t2.frame.height, accuracy: 0.01)
        }
    }

    func testTapestryCoversEveryPhoto() {
        let engine = TapestryEngine()
        let photos = (0..<18).map { photo(idSeed: $0, aspect: [0.7, 1.0, 1.5][$0 % 3]) }
        var rng = SeededRNG(seed: 1)
        let wall = engine.compose(photos: photos, canvasSize: .init(width: 1200, height: 800), rng: &rng)
        XCTAssertEqual(wall.tiles.count, photos.count)
        XCTAssertEqual(Set(wall.tiles.map(\.photoID)).count, photos.count)
    }

    func testTapestryRowsFitCanvasWidth() {
        let engine = TapestryEngine(gutter: 8, baselineRatio: 0.3, heightJitter: 0.0)
        let photos = (0..<30).map { photo(idSeed: $0, aspect: [0.7, 1.0, 1.4, 2.0][$0 % 4]) }
        var rng = SeededRNG(seed: 1)
        let wall = engine.compose(photos: photos, canvasSize: .init(width: 1200, height: 800), rng: &rng)

        // Group tiles by row (within 2pt of same minY).
        let grouped = Dictionary(grouping: wall.tiles) { Int($0.frame.minY / 2).description }
        for (_, tilesInRow) in grouped {
            guard tilesInRow.count > 1 else { continue }  // trailing row allowed
            let rightEdge = tilesInRow.max(by: { $0.frame.maxX < $1.frame.maxX })!.frame.maxX
            // Justified rows should land within a rounding pixel or two of canvas width.
            XCTAssertLessThanOrEqual(rightEdge, 1202)
        }
    }

    // MARK: — AestheticScore

    func testHarmonyHighForUnifiedPalette() {
        // All close to Lab(50, 10, 5): harmony should be near 1.
        let photos = (0..<10).map { idx -> Photo in
            photo(idSeed: idx, aspect: 1.0, l: 50 + Double(idx) * 0.2, a: 10, b: 5)
        }
        let tiles = photos.map { Tile(photoID: $0.id, frame: .init(x: 0, y: 0, width: 100, height: 100)) }
        let wall = Wall(style: .tapestry, axis: .color, seed: 0, tiles: tiles,
                        canvasSize: .init(width: 500, height: 500))
        let s = AestheticScore.score(wall: wall, photos: photos)
        XCTAssertGreaterThan(s.harmony, 0.9)
    }

    func testHarmonyLowForChaosPalette() {
        let chaoticColors: [(Double, Double, Double)] = [
            (20, -40, 60), (80,  50, -30), (50, -60, -60),
            (30,  20,  40), (90,  60, 10), (10, -20,  50)
        ]
        let photos = chaoticColors.enumerated().map { (i, c) in
            photo(idSeed: i, aspect: 1.0, l: c.0, a: c.1, b: c.2)
        }
        let tiles = photos.map { Tile(photoID: $0.id, frame: .init(x: 0, y: 0, width: 100, height: 100)) }
        let wall = Wall(style: .tapestry, axis: .color, seed: 0, tiles: tiles,
                        canvasSize: .init(width: 500, height: 500))
        let s = AestheticScore.score(wall: wall, photos: photos)
        XCTAssertLessThan(s.harmony, 0.5)
    }

    func testRhythmHighForAlternatingAspects() {
        let photos = (0..<12).map { i -> Photo in
            let aspect = i % 2 == 0 ? 0.75 : 1.5
            return photo(idSeed: i, aspect: aspect)
        }
        let tiles = photos.map { Tile(photoID: $0.id, frame: .init(x: 0, y: 0, width: 100, height: 100)) }
        let wall = Wall(style: .tapestry, axis: .color, seed: 0, tiles: tiles,
                        canvasSize: .init(width: 500, height: 500))
        let s = AestheticScore.score(wall: wall, photos: photos)
        XCTAssertGreaterThan(s.rhythm, 0.4)
    }
}
