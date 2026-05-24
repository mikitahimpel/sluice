import XCTest
@testable import SluiceCore

final class RoutePreviewTests: XCTestCase {
    private let safari = "com.apple.Safari"
    private let chrome = "com.google.Chrome"
    private let firefox = "org.mozilla.firefox"
    private let figmaDesktop = "com.figma.Desktop"
    private let slack = "com.tinyspeck.slackmacgap"

    func testInvalidURLString() {
        let ruleSet = RuleSet(defaultBrowser: safari, rules: [])
        let result = RoutePreviewer.preview(
            urlString: "not a url",
            sourceBundleID: nil,
            ruleSet: ruleSet
        )
        XCTAssertEqual(result, .failure(.invalidURL))
    }

    func testEmptyInput() {
        let ruleSet = RuleSet(defaultBrowser: safari, rules: [])
        let result = RoutePreviewer.preview(
            urlString: "",
            sourceBundleID: nil,
            ruleSet: ruleSet
        )
        XCTAssertEqual(result, .failure(.invalidURL))
    }

    func testWhitespaceInput() {
        let ruleSet = RuleSet(defaultBrowser: safari, rules: [])
        let result = RoutePreviewer.preview(
            urlString: "   \n\t  ",
            sourceBundleID: nil,
            ruleSet: ruleSet
        )
        XCTAssertEqual(result, .failure(.invalidURL))
    }

    func testMissingSchemeIsInvalid() {
        let ruleSet = RuleSet(defaultBrowser: safari, rules: [])
        let result = RoutePreviewer.preview(
            urlString: "example.com/foo",
            sourceBundleID: nil,
            ruleSet: ruleSet
        )
        XCTAssertEqual(result, .failure(.invalidURL))
    }

    func testUnwrapsBeforeMatching() {
        let rule = Rule(match: .urlHost(glob: "*.figma.com"), target: figmaDesktop)
        let ruleSet = RuleSet(defaultBrowser: safari, rules: [rule])
        let wrapped = "https://www.google.com/url?q=https%3A%2F%2Fwww.figma.com%2Ffile%2Fabc&sa=U"
        let result = RoutePreviewer.preview(
            urlString: wrapped,
            sourceBundleID: nil,
            ruleSet: ruleSet
        )
        guard case let .success(preview) = result else {
            XCTFail("expected success, got \(result)")
            return
        }
        XCTAssertEqual(preview.unwrappedURL, URL(string: "https://www.figma.com/file/abc"))
        XCTAssertTrue(preview.didUnwrap)
        XCTAssertEqual(preview.target, figmaDesktop)
        XCTAssertEqual(preview.matchedRule, rule)
    }

    func testSourceAppMatch() {
        let rule = Rule(match: .sourceApp(bundleID: slack), target: chrome)
        let ruleSet = RuleSet(defaultBrowser: safari, rules: [rule])
        let result = RoutePreviewer.preview(
            urlString: "https://example.com/x",
            sourceBundleID: slack,
            ruleSet: ruleSet
        )
        guard case let .success(preview) = result else {
            XCTFail("expected success, got \(result)")
            return
        }
        XCTAssertEqual(preview.target, chrome)
        XCTAssertEqual(preview.matchedRule, rule)
        XCTAssertFalse(preview.didUnwrap)
        XCTAssertEqual(preview.originalURL, preview.unwrappedURL)
        XCTAssertEqual(preview.sourceBundleID, slack)
    }

    func testURLHostMatch() {
        let rule = Rule(match: .urlHost(glob: "*.figma.com"), target: figmaDesktop)
        let ruleSet = RuleSet(defaultBrowser: safari, rules: [rule])
        let result = RoutePreviewer.preview(
            urlString: "https://www.figma.com/file/abc",
            sourceBundleID: nil,
            ruleSet: ruleSet
        )
        guard case let .success(preview) = result else {
            XCTFail("expected success, got \(result)")
            return
        }
        XCTAssertEqual(preview.target, figmaDesktop)
        XCTAssertEqual(preview.matchedRule, rule)
    }

    func testFallbackToDefault() {
        let rule = Rule(match: .urlHost(glob: "*.figma.com"), target: figmaDesktop)
        let ruleSet = RuleSet(defaultBrowser: firefox, rules: [rule])
        let result = RoutePreviewer.preview(
            urlString: "https://example.com/abc",
            sourceBundleID: nil,
            ruleSet: ruleSet
        )
        guard case let .success(preview) = result else {
            XCTFail("expected success, got \(result)")
            return
        }
        XCTAssertEqual(preview.target, firefox)
        XCTAssertNil(preview.matchedRule)
    }
}
