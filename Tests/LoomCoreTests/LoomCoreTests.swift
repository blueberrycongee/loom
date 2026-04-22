import XCTest
@testable import LoomCore

final class LoomCoreTests: XCTestCase {

    // MARK: — SeededRNG

    func testRNGDeterminism() {
        var a = SeededRNG(seed: 42)
        var b = SeededRNG(seed: 42)
        for _ in 0..<1000 {
            XCTAssertEqual(a.next(), b.next())
        }
    }

    func testRNGDifferentSeedsDiverge() {
        var a = SeededRNG(seed: 1)
        var b = SeededRNG(seed: 2)
        var same = 0
        for _ in 0..<1000 where a.next() == b.next() { same += 1 }
        // Collisions of 64-bit values should be vanishingly rare.
        XCTAssertLessThan(same, 3)
    }

    func testRNGUnitRange() {
        var rng = SeededRNG(seed: 7)
        for _ in 0..<10_000 {
            let v = rng.unit()
            XCTAssertGreaterThanOrEqual(v, 0)
            XCTAssertLessThan(v, 1)
        }
    }

    func testRNGSampleIndicesDistinct() {
        var rng = SeededRNG(seed: 99)
        let sample = rng.sampleIndices(7, from: 50)
        XCTAssertEqual(sample.count, 7)
        XCTAssertEqual(Set(sample).count, 7)
        for i in sample {
            XCTAssertGreaterThanOrEqual(i, 0)
            XCTAssertLessThan(i, 50)
        }
    }

    func testRNGSampleIndicesOvershoot() {
        var rng = SeededRNG(seed: 1)
        let sample = rng.sampleIndices(20, from: 5)
        XCTAssertEqual(Set(sample), Set(0..<5))
    }

    // MARK: — Aspect

    func testAspectBuckets() {
        XCTAssertEqual(Aspect.bucket(of: 0.50), .tallPortrait)
        XCTAssertEqual(Aspect.bucket(of: 0.75), .portrait)
        XCTAssertEqual(Aspect.bucket(of: 1.00), .square)
        XCTAssertEqual(Aspect.bucket(of: 1.33), .landscape)
        XCTAssertEqual(Aspect.bucket(of: 2.00), .wide)
        XCTAssertEqual(Aspect.bucket(of: 3.00), .ultraWide)
    }

    func testAspectFitPreservesRatio() {
        let target = CGRect(x: 0, y: 0, width: 200, height: 100)
        let fitted = Aspect.fit(aspect: 2.0, into: target)
        // Source is 2:1, target is 2:1 → fitted == target.
        XCTAssertEqual(fitted, target)

        let portraitFit = Aspect.fit(aspect: 0.5, into: target)
        // Portrait → height-constrained → h=100, w=50.
        XCTAssertEqual(portraitFit.width, 50, accuracy: 0.01)
        XCTAssertEqual(portraitFit.height, 100, accuracy: 0.01)
    }

    // MARK: — LabColor

    func testLabDeltaESymmetric() {
        let a = LabColor(l: 50, a: 10, b: -5)
        let b = LabColor(l: 60, a: -15, b: 20)
        XCTAssertEqual(a.deltaE(b), b.deltaE(a), accuracy: 1e-9)
    }

    func testLabNeutralDetection() {
        XCTAssertTrue(LabColor(l: 50, a: 0, b: 0).isNeutral)
        XCTAssertTrue(LabColor(l: 20, a: 1.5, b: -0.5).isNeutral)
        XCTAssertFalse(LabColor(l: 50, a: 20, b: 10).isNeutral)
    }

    // MARK: — PixelSize

    func testPixelSizeAspect() {
        let p = PixelSize(width: 4000, height: 3000)
        XCTAssertEqual(p.aspect, 4.0/3.0, accuracy: 1e-9)
        XCTAssertFalse(p.isSquare)
        XCTAssertTrue(PixelSize(width: 1000, height: 1010).isSquare)
    }
}
