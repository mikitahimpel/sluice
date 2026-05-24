import AppKit
import ApplicationServices

public final class DefaultBrowserClient {
    private let selfBundleID: String?

    public init(selfBundleID: String? = Bundle.main.bundleIdentifier) {
        self.selfBundleID = selfBundleID
    }

    // LSCopyDefaultHandlerForURLScheme is formally deprecated but remains the only
    // working way to read the current default scheme handler as of macOS 14;
    // there is no public modern replacement.
    public func currentDefaultBrowser() -> String? {
        LSCopyDefaultHandlerForURLScheme("https" as CFString)?.takeRetainedValue() as String?
    }

    public func isSluiceDefault() -> Bool {
        guard let selfBundleID else { return false }
        let http = LSCopyDefaultHandlerForURLScheme("http" as CFString)?.takeRetainedValue() as String?
        let https = LSCopyDefaultHandlerForURLScheme("https" as CFString)?.takeRetainedValue() as String?
        return http?.caseInsensitiveCompare(selfBundleID) == .orderedSame
            && https?.caseInsensitiveCompare(selfBundleID) == .orderedSame
    }

    public func requestBecomeDefault() {
        guard let selfBundleID else { return }
        setDefault(bundleID: selfBundleID)
    }

    public func setDefault(bundleID: String) {
        LSSetDefaultHandlerForURLScheme("http" as CFString, bundleID as CFString)
        LSSetDefaultHandlerForURLScheme("https" as CFString, bundleID as CFString)
    }
}
