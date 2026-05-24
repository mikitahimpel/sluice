import XCTest
@testable import Sluice

final class AppCatalogTests: XCTestCase {
    func testReturnsNonEmpty() {
        let catalog = AppCatalog()
        XCTAssertFalse(catalog.installedApps().isEmpty)
    }

    func testIncludesStockApp() {
        let catalog = AppCatalog(searchPaths: [URL(fileURLWithPath: "/System/Applications", isDirectory: true)])
        let ids = catalog.installedApps().map(\.bundleID)
        // Safari ships in /System/Applications on macOS 13+.
        let stockBundles: Set<String> = [
            "com.apple.Safari",
            "com.apple.mail",
            "com.apple.Notes",
            "com.apple.Maps",
            "com.apple.systempreferences",
        ]
        XCTAssertFalse(stockBundles.isDisjoint(with: Set(ids)),
                       "Expected at least one stock app from \(stockBundles); got \(ids)")
    }

    func testDedupedAcrossDuplicatePaths() {
        let appsDir = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let catalog = AppCatalog(searchPaths: [appsDir, appsDir])
        let ids = catalog.installedApps().map(\.bundleID)
        XCTAssertEqual(ids.count, Set(ids).count, "Duplicate search paths must not yield duplicate bundle IDs")
    }

    func testSortedByDisplayName() {
        let catalog = AppCatalog()
        let names = catalog.installedApps().map(\.displayName)
        let sorted = names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        XCTAssertEqual(names, sorted)
    }

    func testExcludesSelfBundleID() {
        // Pick an arbitrary app likely present, treat its bundle ID as "self".
        let probe = AppCatalog().installedApps()
        guard let victim = probe.first else {
            XCTFail("No apps installed to probe with")
            return
        }
        let catalog = AppCatalog(searchPaths: nil, selfBundleID: victim.bundleID)
        let ids = catalog.installedApps().map(\.bundleID)
        XCTAssertFalse(ids.contains(victim.bundleID))
    }
}
