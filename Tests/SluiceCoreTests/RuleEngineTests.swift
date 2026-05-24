import XCTest
@testable import SluiceCore

final class RuleEngineTests: XCTestCase {
    private let safari = "com.apple.Safari"
    private let chrome = "com.google.Chrome"
    private let firefox = "org.mozilla.firefox"
    private let figmaDesktop = "com.figma.Desktop"

    func testFallbackToDefaultWhenNoRules() {
        let ruleSet = RuleSet(defaultBrowser: safari, rules: [])
        let request = RouteRequest(url: URL(string: "https://example.com")!, sourceBundleID: nil)
        let decision = RuleEngine.decide(request, against: ruleSet)
        XCTAssertEqual(decision.target, safari)
        XCTAssertNil(decision.matchedRule)
    }

    func testSourceAppMatch() {
        let rule = Rule(match: .sourceApp(bundleID: "com.tinyspeck.slackmacgap"), target: chrome)
        let ruleSet = RuleSet(defaultBrowser: safari, rules: [rule])
        let request = RouteRequest(
            url: URL(string: "https://example.com")!,
            sourceBundleID: "com.tinyspeck.slackmacgap"
        )
        let decision = RuleEngine.decide(request, against: ruleSet)
        XCTAssertEqual(decision.target, chrome)
        XCTAssertEqual(decision.matchedRule, rule)
    }

    func testSourceAppRuleSkippedOnMismatch() {
        let rule = Rule(match: .sourceApp(bundleID: "com.tinyspeck.slackmacgap"), target: chrome)
        let ruleSet = RuleSet(defaultBrowser: safari, rules: [rule])
        let request = RouteRequest(
            url: URL(string: "https://example.com")!,
            sourceBundleID: "com.apple.mail"
        )
        let decision = RuleEngine.decide(request, against: ruleSet)
        XCTAssertEqual(decision.target, safari)
        XCTAssertNil(decision.matchedRule)
    }

    func testNilSourceBundleIDDoesNotMatchSourceAppRule() {
        let rule = Rule(match: .sourceApp(bundleID: "com.tinyspeck.slackmacgap"), target: chrome)
        let ruleSet = RuleSet(defaultBrowser: safari, rules: [rule])
        let request = RouteRequest(url: URL(string: "https://example.com")!, sourceBundleID: nil)
        let decision = RuleEngine.decide(request, against: ruleSet)
        XCTAssertEqual(decision.target, safari)
        XCTAssertNil(decision.matchedRule)
    }

    func testURLHostMatch() {
        let rule = Rule(match: .urlHost(glob: "*.figma.com"), target: figmaDesktop)
        let ruleSet = RuleSet(defaultBrowser: safari, rules: [rule])
        let request = RouteRequest(url: URL(string: "https://www.figma.com/file/abc")!, sourceBundleID: nil)
        let decision = RuleEngine.decide(request, against: ruleSet)
        XCTAssertEqual(decision.target, figmaDesktop)
        XCTAssertEqual(decision.matchedRule, rule)
    }

    func testURLHostNoMatchFallsBackToDefault() {
        let rule = Rule(match: .urlHost(glob: "*.figma.com"), target: figmaDesktop)
        let ruleSet = RuleSet(defaultBrowser: safari, rules: [rule])
        let request = RouteRequest(url: URL(string: "https://example.com")!, sourceBundleID: nil)
        let decision = RuleEngine.decide(request, against: ruleSet)
        XCTAssertEqual(decision.target, safari)
        XCTAssertNil(decision.matchedRule)
    }

    func testFirstMatchWins() {
        let first = Rule(match: .urlHost(glob: "*.figma.com"), target: chrome)
        let second = Rule(match: .urlHost(glob: "*.figma.com"), target: firefox)
        let ruleSet = RuleSet(defaultBrowser: safari, rules: [first, second])
        let request = RouteRequest(url: URL(string: "https://www.figma.com")!, sourceBundleID: nil)
        let decision = RuleEngine.decide(request, against: ruleSet)
        XCTAssertEqual(decision.target, chrome)
        XCTAssertEqual(decision.matchedRule, first)
    }

    func testDisabledRuleSkipped() {
        let disabled = Rule(enabled: false, match: .urlHost(glob: "*.figma.com"), target: chrome)
        let enabled = Rule(enabled: true, match: .urlHost(glob: "*.figma.com"), target: firefox)
        let ruleSet = RuleSet(defaultBrowser: safari, rules: [disabled, enabled])
        let request = RouteRequest(url: URL(string: "https://www.figma.com")!, sourceBundleID: nil)
        let decision = RuleEngine.decide(request, against: ruleSet)
        XCTAssertEqual(decision.target, firefox)
        XCTAssertEqual(decision.matchedRule, enabled)
    }

    func testSourceAppRuleBeatsLaterURLRule() {
        let sourceRule = Rule(match: .sourceApp(bundleID: "com.tinyspeck.slackmacgap"), target: chrome)
        let hostRule = Rule(match: .urlHost(glob: "*.figma.com"), target: figmaDesktop)
        let ruleSet = RuleSet(defaultBrowser: safari, rules: [sourceRule, hostRule])
        let request = RouteRequest(
            url: URL(string: "https://www.figma.com")!,
            sourceBundleID: "com.tinyspeck.slackmacgap"
        )
        let decision = RuleEngine.decide(request, against: ruleSet)
        XCTAssertEqual(decision.target, chrome)
        XCTAssertEqual(decision.matchedRule, sourceRule)
    }

    func testDecisionCarriesChromeProfileFromMatchedRule() {
        let rule = Rule(
            match: .urlHost(glob: "*.example.com"),
            target: chrome,
            chromeProfile: "Profile 1"
        )
        let ruleSet = RuleSet(defaultBrowser: safari, rules: [rule])
        let request = RouteRequest(url: URL(string: "https://www.example.com")!, sourceBundleID: nil)
        let decision = RuleEngine.decide(request, against: ruleSet)
        XCTAssertEqual(decision.target, chrome)
        XCTAssertEqual(decision.chromeProfile, "Profile 1")
    }

    func testDefaultFallbackDecisionHasNilChromeProfile() {
        let rule = Rule(match: .urlHost(glob: "*.figma.com"), target: chrome, chromeProfile: "Profile 1")
        let ruleSet = RuleSet(defaultBrowser: safari, rules: [rule])
        let request = RouteRequest(url: URL(string: "https://example.com")!, sourceBundleID: nil)
        let decision = RuleEngine.decide(request, against: ruleSet)
        XCTAssertEqual(decision.target, safari)
        XCTAssertNil(decision.chromeProfile)
    }

    func testURLWithoutHostUsesEmptyString() {
        let rule = Rule(match: .urlHost(glob: "*"), target: chrome)
        let ruleSet = RuleSet(defaultBrowser: safari, rules: [rule])
        let request = RouteRequest(url: URL(string: "file:///tmp/foo")!, sourceBundleID: nil)
        let decision = RuleEngine.decide(request, against: ruleSet)
        XCTAssertEqual(decision.target, chrome)
    }
}
