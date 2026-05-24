import XCTest
@testable import SluiceCore

final class GlobTests: XCTestCase {
    func testExactMatch() {
        XCTAssertTrue(Glob.matches(pattern: "figma.com", host: "figma.com"))
        XCTAssertFalse(Glob.matches(pattern: "figma.com", host: "figma.org"))
    }

    func testStarSuffix() {
        XCTAssertTrue(Glob.matches(pattern: "figma.*", host: "figma.com"))
        XCTAssertTrue(Glob.matches(pattern: "figma.*", host: "figma.co.uk"))
    }

    func testStarPrefix() {
        XCTAssertTrue(Glob.matches(pattern: "*.figma.com", host: "www.figma.com"))
        XCTAssertTrue(Glob.matches(pattern: "*.figma.com", host: "a.b.figma.com"))
    }

    func testStarPrefixAnchoring() {
        XCTAssertFalse(Glob.matches(pattern: "*.figma.com", host: "figma.com"))
        XCTAssertFalse(Glob.matches(pattern: "*.figma.com", host: "evil-figma.com.attacker.com"))
    }

    func testStarMiddle() {
        XCTAssertTrue(Glob.matches(pattern: "a*z", host: "az"))
        XCTAssertTrue(Glob.matches(pattern: "a*z", host: "abz"))
        XCTAssertTrue(Glob.matches(pattern: "a*z", host: "abcdefz"))
        XCTAssertFalse(Glob.matches(pattern: "a*z", host: "aby"))
    }

    func testQuestionMark() {
        XCTAssertTrue(Glob.matches(pattern: "a?c", host: "abc"))
        XCTAssertTrue(Glob.matches(pattern: "a?c", host: "axc"))
        XCTAssertFalse(Glob.matches(pattern: "a?c", host: "ac"))
        XCTAssertFalse(Glob.matches(pattern: "a?c", host: "abbc"))
    }

    func testCaseInsensitive() {
        XCTAssertTrue(Glob.matches(pattern: "*.Figma.COM", host: "WWW.figma.com"))
        XCTAssertTrue(Glob.matches(pattern: "GitHub.com", host: "github.com"))
    }

    func testAnchoredFullString() {
        XCTAssertFalse(Glob.matches(pattern: "figma.com", host: "www.figma.com"))
        XCTAssertFalse(Glob.matches(pattern: "figma.com", host: "figma.com.attacker.com"))
    }

    func testEmptyPattern() {
        XCTAssertTrue(Glob.matches(pattern: "", host: ""))
        XCTAssertFalse(Glob.matches(pattern: "", host: "figma.com"))
    }

    func testEmptyHost() {
        XCTAssertFalse(Glob.matches(pattern: "figma.com", host: ""))
        XCTAssertTrue(Glob.matches(pattern: "*", host: ""))
        XCTAssertTrue(Glob.matches(pattern: "***", host: ""))
    }

    func testStarMatchesEmptyString() {
        XCTAssertTrue(Glob.matches(pattern: "a*b", host: "ab"))
        XCTAssertTrue(Glob.matches(pattern: "*figma.com", host: "figma.com"))
    }

    func testStarMatchesEverything() {
        XCTAssertTrue(Glob.matches(pattern: "*", host: "anything.example.com"))
    }
}
