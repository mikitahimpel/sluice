import XCTest
@testable import SluiceCore

final class SluiceCoreTests: XCTestCase {
    func testVersionIsSet() {
        XCTAssertFalse(SluiceCore.version.isEmpty)
    }
}
