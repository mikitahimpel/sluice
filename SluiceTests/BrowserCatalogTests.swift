import XCTest
@testable import Sluice

final class BrowserCatalogTests: XCTestCase {
    func testReturnsNonEmpty() {
        let catalog = BrowserCatalog()
        XCTAssertFalse(catalog.installedBrowsers().isEmpty)
    }

    func testIncludesSafari() {
        let catalog = BrowserCatalog()
        let ids = catalog.installedBrowsers().map(\.bundleID)
        XCTAssertTrue(ids.contains("com.apple.Safari"), "Expected Safari among browsers; got \(ids)")
    }

    func testExcludesSelf() {
        let fakeSelf = "com.apple.Safari"
        let catalog = BrowserCatalog(probeURL: URL(string: "https://example.com")!, selfBundleID: fakeSelf)
        let ids = catalog.installedBrowsers().map(\.bundleID)
        XCTAssertFalse(ids.contains(fakeSelf), "Self bundle ID should be excluded")
    }

    func testSortedAndDeduped() {
        let catalog = BrowserCatalog()
        let browsers = catalog.installedBrowsers()
        let ids = browsers.map(\.bundleID)
        XCTAssertEqual(ids.count, Set(ids).count, "Bundle IDs must be unique")

        let names = browsers.map(\.displayName)
        let sorted = names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        XCTAssertEqual(names, sorted, "Browsers should be sorted by display name")
    }
}
