import XCTest
@testable import SluiceCore

private final class FakeSourceDetector: SourceDetecting {
    var source: String?
    private(set) var callCount = 0

    init(source: String? = nil) {
        self.source = source
    }

    func currentSourceApp() -> String? {
        callCount += 1
        return source
    }
}

private final class FakeOpener: URLOpening {
    struct Call: Equatable {
        let urls: [URL]
        let target: String
        let chromeProfile: String?
    }
    var calls: [Call] = []
    var errorToThrow: Error?

    func open(_ urls: [URL], with browserBundleID: String, chromeProfile: String?) throws {
        if let errorToThrow {
            throw errorToThrow
        }
        calls.append(Call(urls: urls, target: browserBundleID, chromeProfile: chromeProfile))
    }
}

private struct OpenerError: Error, Equatable {}

final class RouterTests: XCTestCase {
    private let safari = "com.apple.Safari"
    private let chrome = "com.google.Chrome"
    private let figmaDesktop = "com.figma.Desktop"

    func testSourceDetectorCalledOncePerRouteRegardlessOfURLCount() throws {
        let detector = FakeSourceDetector(source: "com.tinyspeck.slackmacgap")
        let opener = FakeOpener()
        let log = RouteLog()
        let ruleSet = RuleSet(defaultBrowser: safari, rules: [])
        let router = Router(
            ruleSetProvider: { ruleSet },
            sourceDetector: detector,
            opener: opener,
            log: log
        )
        let urls = [
            URL(string: "https://a.com")!,
            URL(string: "https://b.com")!,
            URL(string: "https://c.com")!,
        ]
        try router.route(urls)
        XCTAssertEqual(detector.callCount, 1)
    }

    func testEachURLOpenedWithItsDecidedTarget() throws {
        let detector = FakeSourceDetector(source: nil)
        let opener = FakeOpener()
        let log = RouteLog()
        let figmaRule = Rule(match: .urlHost(glob: "*.figma.com"), target: figmaDesktop)
        let ruleSet = RuleSet(defaultBrowser: safari, rules: [figmaRule])
        let router = Router(
            ruleSetProvider: { ruleSet },
            sourceDetector: detector,
            opener: opener,
            log: log
        )
        let urls = [
            URL(string: "https://www.figma.com/file/1")!,
            URL(string: "https://example.com")!,
        ]
        try router.route(urls)
        XCTAssertEqual(opener.calls.count, 2)
        XCTAssertEqual(opener.calls[0].urls, [urls[0]])
        XCTAssertEqual(opener.calls[0].target, figmaDesktop)
        XCTAssertNil(opener.calls[0].chromeProfile)
        XCTAssertEqual(opener.calls[1].urls, [urls[1]])
        XCTAssertEqual(opener.calls[1].target, safari)
        XCTAssertNil(opener.calls[1].chromeProfile)
    }

    func testChromeProfileFromMatchedRuleIsPassedToOpener() throws {
        let detector = FakeSourceDetector(source: nil)
        let opener = FakeOpener()
        let log = RouteLog()
        let chromeRule = Rule(
            match: .urlHost(glob: "*.example.com"),
            target: chrome,
            chromeProfile: "Profile 1"
        )
        let ruleSet = RuleSet(defaultBrowser: safari, rules: [chromeRule])
        let router = Router(
            ruleSetProvider: { ruleSet },
            sourceDetector: detector,
            opener: opener,
            log: log
        )
        try router.route([URL(string: "https://www.example.com/x")!])
        XCTAssertEqual(opener.calls.count, 1)
        XCTAssertEqual(opener.calls[0].target, chrome)
        XCTAssertEqual(opener.calls[0].chromeProfile, "Profile 1")
        XCTAssertEqual(log.recent().first?.chromeProfile, "Profile 1")
    }

    func testMatchedRuleIDRecordedInLog() throws {
        let detector = FakeSourceDetector(source: nil)
        let opener = FakeOpener()
        let log = RouteLog()
        let rule = Rule(match: .urlHost(glob: "*.figma.com"), target: figmaDesktop)
        let ruleSet = RuleSet(defaultBrowser: safari, rules: [rule])
        let router = Router(
            ruleSetProvider: { ruleSet },
            sourceDetector: detector,
            opener: opener,
            log: log
        )
        try router.route([URL(string: "https://www.figma.com")!])
        let events = log.recent()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].matchedRuleID, rule.id)
        XCTAssertEqual(events[0].target, figmaDesktop)
        XCTAssertEqual(events[0].url, URL(string: "https://www.figma.com"))
        XCTAssertNil(events[0].sourceBundleID)
    }

    func testDefaultFallbackEventHasNilMatchedRuleID() throws {
        let detector = FakeSourceDetector(source: "com.apple.mail")
        let opener = FakeOpener()
        let log = RouteLog()
        let ruleSet = RuleSet(defaultBrowser: safari, rules: [])
        let router = Router(
            ruleSetProvider: { ruleSet },
            sourceDetector: detector,
            opener: opener,
            log: log
        )
        try router.route([URL(string: "https://example.com")!])
        let events = log.recent()
        XCTAssertEqual(events.count, 1)
        XCTAssertNil(events[0].matchedRuleID)
        XCTAssertEqual(events[0].target, safari)
        XCTAssertEqual(events[0].sourceBundleID, "com.apple.mail")
    }

    func testOpenerErrorPropagates() {
        let detector = FakeSourceDetector(source: nil)
        let opener = FakeOpener()
        opener.errorToThrow = OpenerError()
        let log = RouteLog()
        let ruleSet = RuleSet(defaultBrowser: safari, rules: [])
        let router = Router(
            ruleSetProvider: { ruleSet },
            sourceDetector: detector,
            opener: opener,
            log: log
        )
        XCTAssertThrowsError(try router.route([URL(string: "https://example.com")!])) { error in
            XCTAssertTrue(error is OpenerError)
        }
    }

    func testRuleSetProviderReadEachInvocation() throws {
        let detector = FakeSourceDetector(source: nil)
        let opener = FakeOpener()
        let log = RouteLog()
        var current = RuleSet(defaultBrowser: safari, rules: [])
        let router = Router(
            ruleSetProvider: { current },
            sourceDetector: detector,
            opener: opener,
            log: log
        )
        try router.route([URL(string: "https://example.com")!])
        XCTAssertEqual(opener.calls.last?.target, safari)

        current = RuleSet(defaultBrowser: chrome, rules: [])
        try router.route([URL(string: "https://example.com")!])
        XCTAssertEqual(opener.calls.last?.target, chrome)
    }

    func testEventTimestampUsesClock() throws {
        let detector = FakeSourceDetector(source: nil)
        let opener = FakeOpener()
        let log = RouteLog()
        let fixed = Date(timeIntervalSince1970: 42)
        let ruleSet = RuleSet(defaultBrowser: safari, rules: [])
        let router = Router(
            ruleSetProvider: { ruleSet },
            sourceDetector: detector,
            opener: opener,
            log: log,
            clock: { fixed }
        )
        try router.route([URL(string: "https://example.com")!])
        XCTAssertEqual(log.recent().first?.timestamp, fixed)
    }
}
