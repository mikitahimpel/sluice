import XCTest
@testable import SluiceCore

final class RuleCodableTests: XCTestCase {
    private func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }

    func testSourceAppMatchEncodesWithTypeDiscriminator() throws {
        let match = Match.sourceApp(bundleID: "com.tinyspeck.slackmacgap")
        let data = try encoder().encode(match)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertEqual(json, #"{"bundleID":"com.tinyspeck.slackmacgap","type":"sourceApp"}"#)
    }

    func testURLHostMatchEncodesWithTypeDiscriminator() throws {
        let match = Match.urlHost(glob: "*.figma.com")
        let data = try encoder().encode(match)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertEqual(json, #"{"glob":"*.figma.com","type":"urlHost"}"#)
    }

    func testDecodeSourceAppFromHandWrittenJSON() throws {
        let json = #"{"type":"sourceApp","bundleID":"com.apple.mail"}"#
        let match = try JSONDecoder().decode(Match.self, from: Data(json.utf8))
        XCTAssertEqual(match, .sourceApp(bundleID: "com.apple.mail"))
    }

    func testDecodeURLHostFromHandWrittenJSON() throws {
        let json = #"{"type":"urlHost","glob":"github.com"}"#
        let match = try JSONDecoder().decode(Match.self, from: Data(json.utf8))
        XCTAssertEqual(match, .urlHost(glob: "github.com"))
    }

    func testDecodeUnknownTypeFails() {
        let json = #"{"type":"nope","glob":"x"}"#
        XCTAssertThrowsError(try JSONDecoder().decode(Match.self, from: Data(json.utf8)))
    }

    func testRuleRoundTrip() throws {
        let original = Rule(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            enabled: true,
            match: .urlHost(glob: "*.example.com"),
            target: "com.google.Chrome"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Rule.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testRuleSetRoundTrip() throws {
        let original = RuleSet(
            version: 1,
            defaultBrowser: "com.apple.Safari",
            rules: [
                Rule(match: .sourceApp(bundleID: "com.tinyspeck.slackmacgap"), target: "com.google.Chrome"),
                Rule(enabled: false, match: .urlHost(glob: "*.figma.com"), target: "com.figma.Desktop"),
            ]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RuleSet.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testRuleWithChromeProfileRoundTrips() throws {
        let original = Rule(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            enabled: true,
            match: .urlHost(glob: "*.example.com"),
            target: "com.google.Chrome",
            chromeProfile: "Profile 1"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Rule.self, from: data)
        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.chromeProfile, "Profile 1")
    }

    func testRuleDecodesFromOldFormatWithoutChromeProfileField() throws {
        let json = """
        {
          "id": "33333333-3333-3333-3333-333333333333",
          "enabled": true,
          "match": {"type": "urlHost", "glob": "*.figma.com"},
          "target": "com.figma.Desktop"
        }
        """
        let decoded = try JSONDecoder().decode(Rule.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.target, "com.figma.Desktop")
        XCTAssertNil(decoded.chromeProfile)
    }

    func testRuleSetDecodesFromHandWrittenJSON() throws {
        let json = """
        {
          "version": 1,
          "defaultBrowser": "com.apple.Safari",
          "rules": [
            {
              "id": "11111111-1111-1111-1111-111111111111",
              "enabled": true,
              "match": {"type": "urlHost", "glob": "*.figma.com"},
              "target": "com.figma.Desktop"
            }
          ]
        }
        """
        let decoded = try JSONDecoder().decode(RuleSet.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.defaultBrowser, "com.apple.Safari")
        XCTAssertEqual(decoded.rules.count, 1)
        XCTAssertEqual(decoded.rules[0].match, .urlHost(glob: "*.figma.com"))
        XCTAssertEqual(decoded.rules[0].target, "com.figma.Desktop")
    }
}
