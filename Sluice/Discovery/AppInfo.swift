import AppKit

public struct AppInfo: Identifiable, Equatable, Hashable {
    public let bundleID: String
    public let displayName: String
    public let bundleURL: URL
    public var id: String { bundleID }

    public init(bundleID: String, displayName: String, bundleURL: URL) {
        self.bundleID = bundleID
        self.displayName = displayName
        self.bundleURL = bundleURL
    }
}

extension AppInfo {
    /// Load the app icon. Not part of `==` / `hashValue` so app lists can diff cleanly.
    public func icon() -> NSImage {
        NSWorkspace.shared.icon(forFile: bundleURL.path)
    }
}
