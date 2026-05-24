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
    }
    var calls: [Call] = []
    var errorToThrow: Error?

    func open(_ urls: [URL], with browserBundleID: String) throws {
        if let errorToThrow {
            throw errorToThrow
        }
        calls.append(Call(urls: urls, target: browserBundleID))
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
        XCTAssertEqual(opener.calls[0], FakeOpener.Call(urls: [urls[0]], target: figmaDesktop))
        XCTAssertEqual(opener.calls[1], FakeOpener.Call(urls: [urls[1]], target: safari))
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

    func testFailingSaveDoesNotThrowAndKeepsInMemoryUpdate() {
        let initial = RuleSet(version: 1, defaultBrowser: safari, rules: [])
        let store = FakeRuleStore(initial: initial)
        struct SaveError: Error {}
        store.saveError = SaveError()
        let coordinator = makeCoordinator(store: store)

        let updated = RuleSet(version: 1, defaultBrowser: chrome, rules: [])
        coordinator.updateRuleSet(updated)

        XCTAssertEqual(coordinator.ruleSet, updated)
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
        XCTAssertEqual(opener.calls[0], FakeOpener.Call(urls: [underlying], target: figmaDesktop))
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
