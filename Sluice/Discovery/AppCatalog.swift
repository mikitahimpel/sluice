import AppKit

public final class AppCatalog {
    private let searchPaths: [URL]
    private let selfBundleID: String?

    public init(searchPaths: [URL]? = nil) {
        self.searchPaths = searchPaths ?? AppCatalog.defaultSearchPaths()
        self.selfBundleID = Bundle.main.bundleIdentifier
    }

    public init(searchPaths: [URL]? = nil, selfBundleID: String?) {
        self.searchPaths = searchPaths ?? AppCatalog.defaultSearchPaths()
        self.selfBundleID = selfBundleID
    }

    public func installedApps() -> [AppInfo] {
        let fm = FileManager.default
        var seen = Set<String>()
        var results: [AppInfo] = []
        for dir in searchPaths {
            guard let entries = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for entry in entries where entry.pathExtension == "app" {
                guard let info = makeAppInfo(from: entry) else { continue }
                if let selfID = selfBundleID, info.bundleID == selfID { continue }
                if seen.insert(info.bundleID).inserted {
                    results.append(info)
                }
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

    private static func defaultSearchPaths() -> [URL] {
        var paths: [URL] = [URL(fileURLWithPath: "/Applications", isDirectory: true)]
        let home = FileManager.default.homeDirectoryForCurrentUser
        paths.append(home.appendingPathComponent("Applications", isDirectory: true))
        return paths
    }
}
