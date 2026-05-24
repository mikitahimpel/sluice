import XCTest
import AppKit
@testable import Sluice

private final class FakeResolver: WorkspaceResolving {
    var map: [String: URL] = [:]
    func urlForApplication(withBundleIdentifier bundleID: String) -> URL? {
        map[bundleID]
    }
}

private final class FakeLauncher: WorkspaceLaunching {
    struct Call {
        let urls: [URL]
        let applicationURL: URL
        let activates: Bool
        let arguments: [String]
    }
    private(set) var calls: [Call] = []
    var errorToReport: Error?

    func launch(
        urls: [URL],
        applicationURL: URL,
        configuration: NSWorkspace.OpenConfiguration,
        completionHandler: (@Sendable (NSRunningApplication?, Error?) -> Void)?
    ) {
        calls.append(Call(
            urls: urls,
            applicationURL: applicationURL,
            activates: configuration.activates,
            arguments: configuration.arguments
        ))
        completionHandler?(nil, errorToReport)
    }
}

final class URLOpenerTests: XCTestCase {
    func testThrowsBrowserNotInstalledForUnknownBundleID() {
        let resolver = FakeResolver()
        let launcher = FakeLauncher()
        let opener = URLOpener(resolver: resolver, launcher: launcher)
        let url = URL(string: "https://example.com")!

        XCTAssertThrowsError(try opener.open([url], with: "com.example.does.not.exist", chromeProfile: nil)) { error in
            guard case URLOpener.URLOpenerError.browserNotInstalled(let bid) = error else {
                XCTFail("Expected .browserNotInstalled, got \(error)")
                return
            }
            XCTAssertEqual(bid, "com.example.does.not.exist")
        }
        XCTAssertTrue(launcher.calls.isEmpty)
    }

    func testRealWorkspaceResolvesSafari() {
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari")
        XCTAssertNotNil(url, "Safari should be resolvable on macOS")
    }

    func testHappyPathLaunchesViaInjectedLauncher() throws {
        let resolver = FakeResolver()
        let safariURL = URL(fileURLWithPath: "/Applications/Safari.app")
        resolver.map["com.apple.Safari"] = safariURL
        let launcher = FakeLauncher()
        let opener = URLOpener(resolver: resolver, launcher: launcher)
        let url = URL(string: "https://example.com")!

        try opener.open([url], with: "com.apple.Safari", chromeProfile: nil)

        XCTAssertEqual(launcher.calls.count, 1)
        XCTAssertEqual(launcher.calls.first?.urls, [url])
        XCTAssertEqual(launcher.calls.first?.applicationURL, safariURL)
        XCTAssertTrue(launcher.calls.first?.activates ?? false)
        XCTAssertEqual(launcher.calls.first?.arguments, [])
    }

    func testChromeProfileBecomesProfileDirectoryArgument() throws {
        let resolver = FakeResolver()
        let chromeURL = URL(fileURLWithPath: "/Applications/Google Chrome.app")
        resolver.map["com.google.Chrome"] = chromeURL
        let launcher = FakeLauncher()
        let opener = URLOpener(resolver: resolver, launcher: launcher)
        let url = URL(string: "https://example.com")!

        try opener.open([url], with: "com.google.Chrome", chromeProfile: "Profile 1")

        XCTAssertEqual(launcher.calls.count, 1)
        XCTAssertEqual(launcher.calls.first?.arguments, ["--profile-directory=Profile 1"])
    }

    func testEmptyChromeProfileIsTreatedAsNone() throws {
        let resolver = FakeResolver()
        let chromeURL = URL(fileURLWithPath: "/Applications/Google Chrome.app")
        resolver.map["com.google.Chrome"] = chromeURL
        let launcher = FakeLauncher()
        let opener = URLOpener(resolver: resolver, launcher: launcher)
        let url = URL(string: "https://example.com")!

        try opener.open([url], with: "com.google.Chrome", chromeProfile: "")

        XCTAssertEqual(launcher.calls.count, 1)
        XCTAssertEqual(launcher.calls.first?.arguments, [])
    }

    func testAsyncLaunchErrorDoesNotThrowSynchronously() throws {
        let resolver = FakeResolver()
        let safariURL = URL(fileURLWithPath: "/Applications/Safari.app")
        resolver.map["com.apple.Safari"] = safariURL
        let launcher = FakeLauncher()
        launcher.errorToReport = NSError(domain: "test", code: 1)
        let opener = URLOpener(resolver: resolver, launcher: launcher)
        let url = URL(string: "https://example.com")!

        XCTAssertNoThrow(try opener.open([url], with: "com.apple.Safari", chromeProfile: nil))
        XCTAssertEqual(launcher.calls.count, 1)
    }
}
