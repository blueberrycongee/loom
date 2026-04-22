import XCTest
@testable import LoomCore

final class LoomCoreTests: XCTestCase {
    func testVersionPresent() {
        XCTAssertFalse(LoomCore.version.isEmpty)
    }
}
