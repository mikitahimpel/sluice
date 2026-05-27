import XCTest
import SluiceCore
@testable import Sluice

private final class FakeRuleStore: RuleStore {
    var stored: RuleSet
    var loadError: Error?
    var saveError: Error?
    private(set) var saveCallCount = 0
    private(set) var lastSaved: RuleSet?

    init(initial: RuleSet) {
        self.stored = initial
    }

    func load() throws -> RuleSet {
        if let loadError {
            throw loadError
        }
        return stored
    }

    func save(_ ruleSet: RuleSet) throws {
        saveCallCount += 1
        if let saveError {
            throw saveError
        }
        stored = ruleSet
        lastSaved = ruleSet
    }
}

private final class FakeSourceDetector: SourceDetecting {
    var source: String?
    init(source: String? = nil) { self.source = source }
    func currentSourceApp() -> String? { source }
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

@MainActor
final class AppCoordinatorTests: XCTestCase {
    private let safari = "com.apple.Safari"
    private let chrome = "com.google.Chrome"
    private let figmaDesktop = "com.figma.Desktop"

    private func makeCoordinator(
        store: RuleStore,
        detector: SourceDetecting = FakeSourceDetector(),
        opener: URLOpening = FakeOpener()
    ) -> AppCoordinator {
        AppCoordinator(
            ruleStore: store,
            sourceDetector: detector,
            opener: opener
        )
    }

    func testInitLoadsRuleSetFromStore() {
        let initial = RuleSet(version: 1, defaultBrowser: chrome, rules: [
            Rule(match: .urlHost(glob: "*.figma.com"), target: figmaDesktop)
        ])
        let store = FakeRuleStore(initial: initial)
        let coordinator = makeCoordinator(store: store)
        XCTAssertEqual(coordinator.ruleSet, initial)
    }

    func testHandleURLsInvokesOpenerWithRuleTarget() {
        let figmaRule = Rule(match: .urlHost(glob: "*.figma.com"), target: figmaDesktop)
        let initial = RuleSet(version: 1, defaultBrowser: safari, rules: [figmaRule])
        let store = FakeRuleStore(initial: initial)
        let opener = FakeOpener()
        let coordinator = makeCoordinator(store: store, opener: opener)

        let urls = [
            URL(string: "https://www.figma.com/file/1")!,
            URL(string: "https://example.com")!,
        ]
        coordinator.handle(urls: urls)

        XCTAssertEqual(opener.calls.count, 2)
        XCTAssertEqual(opener.calls[0], FakeOpener.Call(urls: [urls[0]], target: figmaDesktop, chromeProfile: nil))
        XCTAssertEqual(opener.calls[1], FakeOpener.Call(urls: [urls[1]], target: safari, chromeProfile: nil))
    }

    func testUpdateRuleSetUpdatesPublishedAndSaves() {
        let initial = RuleSet(version: 1, defaultBrowser: safari, rules: [])
        let store = FakeRuleStore(initial: initial)
        let coordinator = makeCoordinator(store: store)

        let updated = RuleSet(version: 1, defaultBrowser: chrome, rules: [
            Rule(match: .urlHost(glob: "*.example.com"), target: chrome)
        ])
        coordinator.updateRuleSet(updated)

        XCTAssertEqual(coordinator.ruleSet, updated)
        XCTAssertEqual(store.saveCallCount, 1)
        XCTAssertEqual(store.lastSaved, updated)
    }

    func testFailingLoadYieldsSensibleDefault() {
        let store = FakeRuleStore(initial: RuleSet(version: 1, defaultBrowser: chrome, rules: []))
        store.loadError = RuleStoreError.invalidVersion(999)
        let coordinator = makeCoordinator(store: store)

        XCTAssertEqual(coordinator.ruleSet.version, 1)
        XCTAssertEqual(coordinator.ruleSet.defaultBrowser, "com.apple.Safari")
        XCTAssertTrue(coordinator.ruleSet.rules.isEmpty)
    }

    func testFailingSaveDoesNotThrowAndKeepsInMemoryInSyncWithDisk() {
        let initial = RuleSet(version: 1, defaultBrowser: safari, rules: [])
        let store = FakeRuleStore(initial: initial)
        struct SaveError: Error {}
        store.saveError = SaveError()
        let coordinator = makeCoordinator(store: store)

        let updated = RuleSet(version: 1, defaultBrowser: chrome, rules: [])
        coordinator.updateRuleSet(updated)

        // Invariant: memory and disk must not diverge. If the save fails the
        // @Published stays at its prior value so the UI reflects what's on
        // disk; export-after-failed-save can't leak unsaved data.
        XCTAssertEqual(coordinator.ruleSet, initial)
        XCTAssertEqual(store.saveCallCount, 1)
    }

    func testHandleURLsSwallowsOpenerErrors() {
        let store = FakeRuleStore(initial: RuleSet(version: 1, defaultBrowser: safari, rules: []))
        let opener = FakeOpener()
        struct OpenerError: Error {}
        opener.errorToThrow = OpenerError()
        let coordinator = makeCoordinator(store: store, opener: opener)

        coordinator.handle(urls: [URL(string: "https://example.com")!])
        XCTAssertTrue(opener.calls.isEmpty)
    }

    func testHandleURLsUnwrapsWrappedURLBeforeRouting() {
        let figmaRule = Rule(match: .urlHost(glob: "*.figma.com"), target: figmaDesktop)
        let initial = RuleSet(version: 1, defaultBrowser: safari, rules: [figmaRule])
        let store = FakeRuleStore(initial: initial)
        let opener = FakeOpener()
        let coordinator = makeCoordinator(store: store, opener: opener)

        let wrapped = URL(string: "https://www.google.com/url?q=https%3A%2F%2Fwww.figma.com%2Ffile%2Fabc&sa=U")!
        let underlying = URL(string: "https://www.figma.com/file/abc")!
        coordinator.handle(urls: [wrapped])

        XCTAssertEqual(opener.calls.count, 1)
        XCTAssertEqual(opener.calls[0], FakeOpener.Call(urls: [underlying], target: figmaDesktop, chromeProfile: nil))
    }

    func testPreviewReturnsDecisionForConfiguredRuleSet() {
        let figmaRule = Rule(match: .urlHost(glob: "*.figma.com"), target: figmaDesktop)
        let initial = RuleSet(version: 1, defaultBrowser: safari, rules: [figmaRule])
        let store = FakeRuleStore(initial: initial)
        let coordinator = makeCoordinator(store: store)

        let matched = coordinator.preview(urlString: "https://www.figma.com/file/abc", sourceBundleID: nil)
        guard case let .success(preview) = matched else {
            XCTFail("expected success, got \(matched)")
            return
        }
        XCTAssertEqual(preview.target, figmaDesktop)
        XCTAssertEqual(preview.matchedRule, figmaRule)

        let fallback = coordinator.preview(urlString: "https://example.com", sourceBundleID: nil)
        guard case let .success(fallbackPreview) = fallback else {
            XCTFail("expected success, got \(fallback)")
            return
        }
        XCTAssertEqual(fallbackPreview.target, safari)
        XCTAssertNil(fallbackPreview.matchedRule)

        let invalid = coordinator.preview(urlString: "not a url", sourceBundleID: nil)
        XCTAssertEqual(invalid, .failure(.invalidURL))
    }

    func testExportRuleSetWritesParseableJSON() throws {
        let figmaRule = Rule(match: .urlHost(glob: "*.figma.com"), target: figmaDesktop)
        let initial = RuleSet(version: 1, defaultBrowser: safari, rules: [figmaRule])
        let store = FakeRuleStore(initial: initial)
        let coordinator = makeCoordinator(store: store)

        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sluice-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let outURL = tmpDir.appendingPathComponent("rules.json")

        try coordinator.exportRuleSet(to: outURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outURL.path))
        let data = try Data(contentsOf: outURL)
        let decoded = try JSONDecoder().decode(RuleSet.self, from: data)
        XCTAssertEqual(decoded, initial)

        // Verify it's valid JSON object
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        XCTAssertTrue(json is [String: Any])
    }

    func testImportRuleSetUpdatesAndPersists() throws {
        let initial = RuleSet(version: 1, defaultBrowser: safari, rules: [])
        let store = FakeRuleStore(initial: initial)
        let coordinator = makeCoordinator(store: store)

        let imported = RuleSet(version: 1, defaultBrowser: chrome, rules: [
            Rule(match: .urlHost(glob: "*.example.com"), target: chrome)
        ])

        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sluice-import-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let inURL = tmpDir.appendingPathComponent("rules.json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(imported).write(to: inURL, options: .atomic)

        let saveCountBefore = store.saveCallCount
        try coordinator.importRuleSet(from: inURL)

        XCTAssertEqual(coordinator.ruleSet, imported)
        XCTAssertEqual(store.saveCallCount, saveCountBefore + 1)
        XCTAssertEqual(store.lastSaved, imported)
    }

    func testImportRuleSetFromMalformedFileThrowsAndLeavesStateUnchanged() throws {
        let initial = RuleSet(version: 1, defaultBrowser: safari, rules: [
            Rule(match: .urlHost(glob: "*.figma.com"), target: figmaDesktop)
        ])
        let store = FakeRuleStore(initial: initial)
        let coordinator = makeCoordinator(store: store)
        let saveCountBefore = store.saveCallCount

        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sluice-import-bad-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let badURL = tmpDir.appendingPathComponent("rules.json")
        try Data("{ not json".utf8).write(to: badURL, options: .atomic)

        XCTAssertThrowsError(try coordinator.importRuleSet(from: badURL))
        XCTAssertEqual(coordinator.ruleSet, initial)
        XCTAssertEqual(store.saveCallCount, saveCountBefore)
    }

    func testImportRuleSetWithInvalidVersionThrowsAndLeavesStateUnchanged() throws {
        let initial = RuleSet(version: 1, defaultBrowser: safari, rules: [])
        let store = FakeRuleStore(initial: initial)
        let coordinator = makeCoordinator(store: store)
        let saveCountBefore = store.saveCallCount

        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sluice-import-ver-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let badURL = tmpDir.appendingPathComponent("rules.json")
        let bad = #"{"version":99,"defaultBrowser":"com.apple.Safari","rules":[]}"#
        try Data(bad.utf8).write(to: badURL, options: .atomic)

        XCTAssertThrowsError(try coordinator.importRuleSet(from: badURL)) { error in
            guard case RuleStoreError.invalidVersion(let v) = error else {
                XCTFail("expected invalidVersion, got \(error)")
                return
            }
            XCTAssertEqual(v, 99)
        }
        XCTAssertEqual(coordinator.ruleSet, initial)
        XCTAssertEqual(store.saveCallCount, saveCountBefore)
    }

    func testHandleWithOverrideQueuesPickerWithoutRouting() {
        let figmaRule = Rule(match: .urlHost(glob: "*.figma.com"), target: figmaDesktop)
        let initial = RuleSet(version: 1, defaultBrowser: safari, rules: [figmaRule])
        let store = FakeRuleStore(initial: initial)
        let opener = FakeOpener()
        let coordinator = makeCoordinator(store: store, opener: opener)

        XCTAssertNil(coordinator.activeOverridePicker)
        coordinator.handleWithOverride(urls: [URL(string: "https://www.figma.com/file/1")!])

        XCTAssertTrue(opener.calls.isEmpty)
        XCTAssertNotNil(coordinator.activeOverridePicker)
    }

    func testReloadRuleSetReadsFromStore() {
        let initial = RuleSet(version: 1, defaultBrowser: safari, rules: [])
        let store = FakeRuleStore(initial: initial)
        let coordinator = makeCoordinator(store: store)

        let next = RuleSet(version: 1, defaultBrowser: chrome, rules: [
            Rule(match: .sourceApp(bundleID: "com.tinyspeck.slackmacgap"), target: chrome)
        ])
        store.stored = next
        coordinator.reloadRuleSet()

        XCTAssertEqual(coordinator.ruleSet, next)
    }
}
