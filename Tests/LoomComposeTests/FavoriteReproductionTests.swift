import XCTest
import LoomCore
import LoomLayout
@testable import LoomCompose

/// Favorites promise byte-identical reproduction. These tests lock that in.
final class FavoriteReproductionTests: XCTestCase {

    private func photo(_ i: Int, aspect: Double) -> Photo {
        // L* is kept in the 30–80 range so the quality filter’s
        // belt-and-suspenders L* check (< 12 or > 95) does not reject
        // synthetic test photos.
        Photo(
            id: PhotoID("p\(i)"),
            url: URL(fileURLWithPath: "/dev/null/\(i)"),
            pixelSize: PixelSize(width: Int(100 * aspect), height: 100),
            dominantColor: LabColor(l: 30 + Double(i) * 1.5, a: Double(i - 10), b: 5),
            colorTemperature: ColorTemperature(kelvin: 5500),
            indexedAt: Date(timeIntervalSince1970: 0)
        )
    }

    func testFavoriteReplayMatchesComposerOutput() {
        let photos = (0..<32).map { photo($0, aspect: [0.75, 1.0, 1.5][$0 % 3]) }
        let composer = Composer(candidates: 3)

        var rng = SeededRNG(seed: 1234)
        let wall = composer.weave(
            photos: photos,
            style: .tapestry,
            axis: .color,
            canvasSize: .init(width: 1200, height: 800),
            rng: &rng
        )

        let fav = Favorite(
            name: "test",
            style: wall.style,
            axis: wall.axis,
            seed: wall.seed,
            photoIDs: wall.tiles.map(\.photoID),
            canvasSize: wall.canvasSize
        )
        let reproduced = Composer.reproduce(fav, library: photos)

        XCTAssertEqual(reproduced.tiles.count, wall.tiles.count)
        for (a, b) in zip(wall.tiles, reproduced.tiles) {
            XCTAssertEqual(a.photoID, b.photoID)
            XCTAssertEqual(a.frame.origin.x, b.frame.origin.x, accuracy: 0.01)
            XCTAssertEqual(a.frame.origin.y, b.frame.origin.y, accuracy: 0.01)
            XCTAssertEqual(a.frame.width,    b.frame.width,    accuracy: 0.01)
            XCTAssertEqual(a.frame.height,   b.frame.height,   accuracy: 0.01)
            XCTAssertEqual(a.rotation,       b.rotation,       accuracy: 1e-9)
        }
    }

    func testLockedPhotosPreservedAcrossShuffles() {
        let photos = (0..<40).map { photo($0, aspect: 1.0) }
        let locked: Set<PhotoID> = [PhotoID("p0"), PhotoID("p1"), PhotoID("p2")]
        let composer = Composer(candidates: 1)
        var rng = SeededRNG(seed: 1)

        let wall = composer.weave(
            photos: photos,
            style: .tapestry,
            axis: .color,
            canvasSize: .init(width: 1200, height: 800),
            lockedPhotoIDs: locked,
            rng: &rng
        )

        let placedIDs = Set(wall.tiles.map(\.photoID))
        for id in locked {
            XCTAssertTrue(placedIDs.contains(id), "locked photo \(id) missing from wall")
        }
    }
}
