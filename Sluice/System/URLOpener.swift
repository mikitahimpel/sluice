import AppKit
import SluiceCore

public protocol WorkspaceResolving: AnyObject {
    func urlForApplication(withBundleIdentifier bundleID: String) -> URL?
}

extension NSWorkspace: WorkspaceResolving {}

public protocol WorkspaceLaunching: AnyObject {
    func launch(
        urls: [URL],
        applicationURL: URL,
        configuration: NSWorkspace.OpenConfiguration,
        completionHandler: (@Sendable (NSRunningApplication?, Error?) -> Void)?
    )
}

extension NSWorkspace: WorkspaceLaunching {
    public func launch(
        urls: [URL],
        applicationURL: URL,
        configuration: NSWorkspace.OpenConfiguration,
        completionHandler: (@Sendable (NSRunningApplication?, Error?) -> Void)?
    ) {
        open(urls, withApplicationAt: applicationURL, configuration: configuration, completionHandler: completionHandler)
    }
}

public final class URLOpener: URLOpening {
    public enum URLOpenerError: Error, Equatable {
        case browserNotInstalled(bundleID: String)
        case openFailed(bundleID: String, underlying: Error)

        public static func == (lhs: URLOpenerError, rhs: URLOpenerError) -> Bool {
            switch (lhs, rhs) {
            case let (.browserNotInstalled(a), .browserNotInstalled(b)):
                return a == b
            case let (.openFailed(a, _), .openFailed(b, _)):
                return a == b
            default:
                return false
            }
        }
    }

    private let resolver: WorkspaceResolving
    private let launcher: WorkspaceLaunching

    public convenience init(workspace: NSWorkspace = .shared) {
        self.init(resolver: workspace, launcher: workspace)
    }

    public init(resolver: WorkspaceResolving, launcher: WorkspaceLaunching) {
        self.resolver = resolver
        self.launcher = launcher
    }

    public func open(_ urls: [URL], with browserBundleID: String, chromeProfile: String?) throws {
        guard let appURL = resolver.urlForApplication(withBundleIdentifier: browserBundleID) else {
            throw URLOpenerError.browserNotInstalled(bundleID: browserBundleID)
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        // The flag is Chromium-family (Chrome, Brave, Edge); harmless to set on
        // non-Chromium browsers since the UI only surfaces it for Chrome.
        if let chromeProfile, !chromeProfile.isEmpty {
            config.arguments = ["--profile-directory=\(chromeProfile)"]
        }
        // v1: `throws` only covers synchronous resolution failure. The async launch result
        // is logged but not surfaced — wiring it back to the caller requires a richer
        // async/Result-returning API which we'll add when the UI layer needs it.
        launcher.launch(urls: urls, applicationURL: appURL, configuration: config) { _, error in
            if let error {
                NSLog("URLOpener: openURLs failed for \(browserBundleID): \(error.localizedDescription)")
            }
        }
    }
}
