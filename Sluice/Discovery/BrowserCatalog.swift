import AppKit

public final class BrowserCatalog {
    private let probeURL: URL
    private let selfBundleID: String?

    public init(probeURL: URL = URL(string: "https://example.com")!) {
        self.probeURL = probeURL
        self.selfBundleID = Bundle.main.bundleIdentifier
    }

    public init(probeURL: URL = URL(string: "https://example.com")!, selfBundleID: String?) {
        self.probeURL = probeURL
        self.selfBundleID = selfBundleID
    }

    public func installedBrowsers() -> [AppInfo] {
        let urls = NSWorkspace.shared.urlsForApplications(toOpen: probeURL)
        var seen = Set<String>()
        var results: [AppInfo] = []
        for url in urls {
            guard let info = makeAppInfo(from: url) else { continue }
            if let selfID = selfBundleID, info.bundleID == selfID { continue }
            if seen.insert(info.bundleID).inserted {
                results.append(info)
            }
        }
        results.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        return results
    }

    private func makeAppInfo(from url: URL) -> AppInfo? {
        guard let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier else { return nil }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        return AppInfo(bundleID: bundleID, displayName: name, bundleURL: url)
    }
}
