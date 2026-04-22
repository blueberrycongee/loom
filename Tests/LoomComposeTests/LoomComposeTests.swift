import XCTest
import LoomCore
import LoomLayout
@testable import LoomCompose

final class LoomComposeTests: XCTestCase {

    private func photo(
        idSeed: Int,
        aspect: Double,
        lab: LabColor
    ) -> Photo {
        Photo(
            id: PhotoID("p\(idSeed)"),
            url: URL(fileURLWithPath: "/dev/null/\(idSeed)"),
            pixelSize: PixelSize(width: Int(100 * aspect), height: 100),
            dominantColor: lab,
            colorTemperature: ColorTemperature(kelvin: 5500),
            indexedAt: Date(timeIntervalSince1970: 0)
        )
    }

    // MARK: — ColorClusterer

    func testClustererSeparatesColorFamilies() {
        // Two tight blobs far apart in Lab.
        let blues: [Photo] = (0..<8).map { idx in
            photo(idSeed: idx, aspect: 1.0,
                  lab: LabColor(l: 50, a: -10, b: -40 + Double(idx)))
        }
        let reds: [Photo] = (0..<8).map { idx in
            photo(idSeed: idx + 100, aspect: 1.0,
                  lab: LabColor(l: 50, a: 50 + Double(idx) * 0.1, b: 20))
        }
        let all = blues + reds
        var rng = SeededRNG(seed: 1)
        let clusters = ColorClusterer(k: 2).cluster(all, rng: &rng)
        XCTAssertEqual(clusters.count, 2)
        // Every blue should land in one cluster, every red in the other.
        let blueIDs = Set(blues.map(\.id))
        let redIDs  = Set(reds.map(\.id))
        for c in clusters {
            let members = Set(c.memberIDs)
            let allBlue = members.isSubset(of: blueIDs)
            let allRed  = members.isSubset(of: redIDs)
            XCTAssertTrue(allBlue || allRed, "cluster mixed blue/red members: \(members)")
        }
    }

    func testClustererDeterministicForSameSeed() {
        let photos = (0..<24).map { i in
            photo(idSeed: i, aspect: 1.0,
                  lab: LabColor(l: Double(i) * 4, a: Double(i - 12), b: 10))
        }
        var rng1 = SeededRNG(seed: 42)
        var rng2 = SeededRNG(seed: 42)
        let c1 = ColorClusterer(k: 4).cluster(photos, rng: &rng1)
        let c2 = ColorClusterer(k: 4).cluster(photos, rng: &rng2)
        XCTAssertEqual(c1.count, c2.count)
        for (a, b) in zip(c1, c2) {
            XCTAssertEqual(a.memberIDs, b.memberIDs)
        }
    }

    // MARK: — Composer

    func testComposerProducesNonEmptyWall() {
        let photos = (0..<32).map { i in
            photo(idSeed: i, aspect: [0.75, 1.0, 1.5][i % 3],
                  lab: LabColor(l: Double(i) * 3, a: Double(i - 16), b: 0))
        }
        let composer = Composer(candidates: 2)
        var rng = SeededRNG(seed: 7)
        let wall = composer.weave(
            photos: photos,
            style: .tapestry,
            axis: .color,
            canvasSize: .init(width: 1200, height: 800),
            rng: &rng
        )
        XCTAssertFalse(wall.tiles.isEmpty)
        XCTAssertEqual(wall.style, .tapestry)
    }

    func testComposerDifferentSeedsGiveDifferentWalls() {
        let photos = (0..<40).map { i in
            photo(idSeed: i, aspect: [0.75, 1.0, 1.5][i % 3],
                  lab: LabColor(l: 50, a: 0, b: 0))
        }
        let composer = Composer(candidates: 1)
        var rng1 = SeededRNG(seed: 1)
        var rng2 = SeededRNG(seed: 2)
        let w1 = composer.weave(photos: photos, style: .tapestry, axis: .color,
                                canvasSize: .init(width: 1200, height: 800), rng: &rng1)
        let w2 = composer.weave(photos: photos, style: .tapestry, axis: .color,
                                canvasSize: .init(width: 1200, height: 800), rng: &rng2)
        let ids1 = w1.tiles.map(\.photoID)
        let ids2 = w2.tiles.map(\.photoID)
        XCTAssertNotEqual(ids1, ids2, "two seeds should not produce identical walls")
    }
}
