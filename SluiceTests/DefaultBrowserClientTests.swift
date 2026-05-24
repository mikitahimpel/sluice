import XCTest
@testable import Sluice

final class DefaultBrowserClientTests: XCTestCase {
    func testCurrentDefaultBrowserReturnsBundleID() {
        let client = DefaultBrowserClient(selfBundleID: "com.gimpel.Sluice")
        let bid = client.currentDefaultBrowser()
        XCTAssertNotNil(bid, "Expected a non-nil default https handler on a normal macOS install")
        XCTAssertFalse(bid?.isEmpty ?? true)
    }

    func testIsSluiceDefaultFalseWhenSafariIsDefault() throws {
        let client = DefaultBrowserClient(selfBundleID: "com.gimpel.Sluice")
        let current = client.currentDefaultBrowser()
        if current?.caseInsensitiveCompare("com.gimpel.Sluice") == .orderedSame {
            throw XCTSkip("Sluice is currently the default browser on this machine; skipping negative-state assertion.")
        }
        XCTAssertFalse(client.isSluiceDefault())
    }

    func testIsSluiceDefaultFalseWhenSelfBundleIDNil() {
        let client = DefaultBrowserClient(selfBundleID: nil)
        XCTAssertFalse(client.isSluiceDefault())
    }
}
