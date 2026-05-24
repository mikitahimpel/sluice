import Foundation
import SluiceCore

@MainActor
final class BrowserDisplayNameResolver {
    private let catalog: BrowserCatalog
    private var cache: [String: String]?

    init(catalog: BrowserCatalog) {
        self.catalog = catalog
    }

    func displayName(for bundleID: String) -> String {
        if cache == nil {
            var map: [String: String] = [:]
            for info in catalog.installedBrowsers() {
                map[info.bundleID.lowercased()] = info.displayName
            }
            cache = map
        }
        return cache?[bundleID.lowercased()] ?? bundleID
    }

    func invalidate() {
        cache = nil
    }
}
