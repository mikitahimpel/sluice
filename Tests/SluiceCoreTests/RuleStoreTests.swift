import XCTest
@testable import SluiceCore

final class RuleStoreTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try FileManager.default.removeItem(at: tempDir)
        }
    }

    private func makeStore() throws -> FileSystemRuleStore {
        try FileSystemRuleStore(directory: tempDir)
    }

    func testLoadReturnsDefaultWhenFileMissing() throws {
        let store = try makeStore()
        let ruleSet = try store.load()
        XCTAssertEqual(ruleSet.version, 1)
        XCTAssertEqual(ruleSet.defaultBrowser, "com.apple.Safari")
        XCTAssertTrue(ruleSet.rules.isEmpty)
    }

    func testRoundTripSaveLoad() throws {
        let store = try makeStore()
        let rule = Rule(match: .urlHost(glob: "*.figma.com"), target: "com.figma.Desktop")
        let original = RuleSet(
            version: 1,
            defaultBrowser: "com.google.Chrome",
            rules: [rule]
        )
        try store.save(original)
        let loaded = try store.load()
        XCTAssertEqual(loaded, original)
    }

    func testMalformedJSONThrows() throws {
        let store = try makeStore()
        try Data("{ not json".utf8).write(to: store.fileURL)
        XCTAssertThrowsError(try store.load()) { error in
            guard case RuleStoreError.malformedConfig = error else {
                XCTFail("Expected malformedConfig, got \(error)")
                return
            }
        }
    }

    func testInvalidVersionThrows() throws {
        let store = try makeStore()
        let future = RuleSet(version: 99, defaultBrowser: "com.apple.Safari", rules: [])
        let data = try JSONEncoder().encode(future)
        try data.write(to: store.fileURL)
        XCTAssertThrowsError(try store.load()) { error in
            guard case RuleStoreError.invalidVersion(let v) = error else {
                XCTFail("Expected invalidVersion, got \(error)")
                return
            }
            XCTAssertEqual(v, 99)
        }
    }

    func testSaveDoesNotLeaveTmpArtifact() throws {
        let store = try makeStore()
        let ruleSet = RuleSet(version: 1, defaultBrowser: "com.apple.Safari", rules: [])
        try store.save(ruleSet)
        let tmpPath = store.fileURL.path + ".tmp"
        XCTAssertFalse(FileManager.default.fileExists(atPath: tmpPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
    }

    func testSavedJSONIsPrettyPrinted() throws {
        let store = try makeStore()
        let rule = Rule(match: .sourceApp(bundleID: "com.tinyspeck.slackmacgap"), target: "com.google.Chrome")
        let ruleSet = RuleSet(version: 1, defaultBrowser: "com.apple.Safari", rules: [rule])
        try store.save(ruleSet)
        let raw = try String(contentsOf: store.fileURL, encoding: .utf8)
        XCTAssertTrue(raw.contains("\n"), "Pretty-printed JSON should contain newlines")
    }

    func testDirectoryIsCreatedIfMissing() throws {
        let nested = tempDir.appendingPathComponent("nested/dir", isDirectory: true)
        let store = try FileSystemRuleStore(directory: nested)
        let ruleSet = RuleSet(version: 1, defaultBrowser: "com.apple.Safari", rules: [])
        try store.save(ruleSet)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
    }
}
