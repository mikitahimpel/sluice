import Foundation
import AppKit
import SwiftUI
import SluiceCore

@MainActor
public final class AppCoordinator: ObservableObject {
    @Published public private(set) var ruleSet: RuleSet {
        didSet { ruleSetBox.value = ruleSet }
    }
    @Published public private(set) var installedBrowsers: [AppInfo] = []
    @Published public private(set) var installedApps: [AppInfo] = []
    @Published public private(set) var chromeProfiles: [ChromeProfile] = []
    @Published public private(set) var isSluiceDefault: Bool = false
    public let routeLog: RouteLog
    public let browserCatalog: BrowserCatalog
    public let appCatalog: AppCatalog
    public let defaultBrowserClient: DefaultBrowserClient
    lazy var browserResolver: BrowserDisplayNameResolver
        = BrowserDisplayNameResolver(catalog: browserCatalog)
    private let chromeProfileCatalog: ChromeProfileCatalog
    private let ruleStore: RuleStore
    private let router: Router
    private let sourceDetector: SourceDetecting
    private let opener: URLOpening
    // Indirection so Router's escaping closure can read the latest RuleSet
    // without capturing `self` (avoids retain cycle and init-order issues).
    private let ruleSetBox: RuleSetBox
    private var defaultBrowserObservers: [NSObjectProtocol] = []

    @Published var activeOverridePicker: OverridePickerWindowController?

    public init(
        ruleStore: RuleStore,
        sourceDetector: SourceDetecting,
        opener: URLOpening,
        browserCatalog: BrowserCatalog = BrowserCatalog(),
        appCatalog: AppCatalog = AppCatalog(),
        defaultBrowserClient: DefaultBrowserClient = DefaultBrowserClient(),
        chromeProfileCatalog: ChromeProfileCatalog = ChromeProfileCatalog(),
        routeLog: RouteLog = RouteLog()
    ) {
        self.ruleStore = ruleStore
        self.sourceDetector = sourceDetector
        self.opener = opener
        self.browserCatalog = browserCatalog
        self.appCatalog = appCatalog
        self.defaultBrowserClient = defaultBrowserClient
        self.chromeProfileCatalog = chromeProfileCatalog
        self.routeLog = routeLog

        let loaded: RuleSet
        do {
            loaded = try ruleStore.load()
        } catch {
            NSLog("AppCoordinator: failed to load RuleSet, using default: %@", String(describing: error))
            loaded = RuleSet(version: 1, defaultBrowser: BundleID.safari, rules: [])
        }
        let box = RuleSetBox(value: loaded)
        self.ruleSetBox = box
        self.ruleSet = loaded

        self.router = Router(
            ruleSetProvider: { box.value },
            sourceDetector: sourceDetector,
            opener: opener,
            log: routeLog
        )

        self.installedBrowsers = browserCatalog.installedBrowsers()
        self.installedApps = appCatalog.installedApps()
        self.chromeProfiles = chromeProfileCatalog.profiles()
        self.isSluiceDefault = defaultBrowserClient.isSluiceDefault()

        subscribeToDefaultBrowserChanges()
    }

    private func subscribeToDefaultBrowserChanges() {
        let dist = DistributedNotificationCenter.default()
        defaultBrowserObservers.append(dist.addObserver(
            forName: Notification.Name("com.apple.LaunchServices.databaseChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshIsSluiceDefault() }
        })

        let local = NotificationCenter.default
        defaultBrowserObservers.append(local.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshIsSluiceDefault() }
        })
    }

    private func refreshIsSluiceDefault() {
        let next = defaultBrowserClient.isSluiceDefault()
        if next != isSluiceDefault { isSluiceDefault = next }
    }

    public func handle(urls: [URL]) {
        let unwrapped = urls.map { LinkUnwrapper.unwrap($0) }
        do {
            try router.route(unwrapped)
        } catch {
            NSLog("AppCoordinator: routing failed: %@", String(describing: error))
        }
    }

    public func handleWithOverride(urls: [URL]) {
        let unwrapped = urls.map { LinkUnwrapper.unwrap($0) }
        guard !unwrapped.isEmpty else { return }
        let source = sourceDetector.currentSourceApp()
        let browsers = browserCatalog.installedBrowsers()

        let controller = OverridePickerWindowController(
            urls: unwrapped,
            browsers: browsers,
            onPick: { [weak self] bundleID in
                guard let self else { return }
                do {
                    try self.opener.open(unwrapped, with: bundleID, chromeProfile: nil)
                } catch {
                    NSLog("AppCoordinator: override open failed: %@", String(describing: error))
                }
                let now = Date()
                for url in unwrapped {
                    self.routeLog.append(RouteEvent(
                        timestamp: now,
                        url: url,
                        sourceBundleID: source,
                        target: bundleID,
                        matchedRuleID: nil,
                        chromeProfile: nil
                    ))
                }
                self.activeOverridePicker = nil
            },
            onCancel: { [weak self] in
                self?.activeOverridePicker = nil
            }
        )
        activeOverridePicker = controller
        controller.present()
    }

    public func updateRuleSet(_ newRuleSet: RuleSet) {
        // Save before assigning so memory and disk can't diverge. If save
        // throws, the @Published stays at its previous value and the UI
        // reflects what's actually on disk.
        do {
            try ruleStore.save(newRuleSet)
        } catch {
            NSLog("AppCoordinator: failed to save RuleSet: %@", String(describing: error))
            return
        }
        ruleSet = newRuleSet
    }

    public func reloadRuleSet() {
        do {
            ruleSet = try ruleStore.load()
        } catch {
            NSLog("AppCoordinator: failed to reload RuleSet: %@", String(describing: error))
        }
    }

    public func preview(urlString: String, sourceBundleID: String?) -> Result<RoutePreview, RoutePreviewError> {
        RoutePreviewer.preview(
            urlString: urlString,
            sourceBundleID: sourceBundleID,
            ruleSet: ruleSet
        )
    }

    public func exportRuleSet(to fileURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(ruleSet)
        try data.write(to: fileURL, options: .atomic)
    }

    public func importRuleSet(from fileURL: URL) throws {
        let data = try Data(contentsOf: fileURL)
        let decoded: RuleSet
        do {
            decoded = try JSONDecoder().decode(RuleSet.self, from: data)
        } catch {
            throw RuleStoreError.malformedConfig(underlying: error)
        }
        guard decoded.version == 1 else {
            throw RuleStoreError.invalidVersion(decoded.version)
        }
        // Save via the store directly so a write failure propagates to the
        // import sheet. `updateRuleSet` swallows save errors (acceptable for
        // ambient UI edits) — for import, the user is waiting for an answer.
        try ruleStore.save(decoded)
        ruleSet = decoded
    }

    public static func makeDefault() -> AppCoordinator {
        let store: RuleStore
        do {
            store = try FileSystemRuleStore()
        } catch {
            NSLog("AppCoordinator: FileSystemRuleStore init failed, falling back to in-memory store: %@", String(describing: error))
            store = InMemoryRuleStore()
        }
        return AppCoordinator(
            ruleStore: store,
            sourceDetector: SourceDetector(),
            opener: URLOpener()
        )
    }
}

private final class RuleSetBox {
    var value: RuleSet
    init(value: RuleSet) {
        self.value = value
    }
}

private final class InMemoryRuleStore: RuleStore {
    private var ruleSet: RuleSet
    private let lock = NSLock()

    init(initial: RuleSet = RuleSet(version: 1, defaultBrowser: BundleID.safari, rules: [])) {
        self.ruleSet = initial
    }

    func load() throws -> RuleSet {
        lock.lock()
        defer { lock.unlock() }
        return ruleSet
    }

    func save(_ ruleSet: RuleSet) throws {
        lock.lock()
        defer { lock.unlock() }
        self.ruleSet = ruleSet
    }
}
