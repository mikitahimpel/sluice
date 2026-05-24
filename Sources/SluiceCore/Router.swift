import Foundation

public protocol SourceDetecting {
    func currentSourceApp() -> String?
}

public protocol URLOpening {
    func open(_ urls: [URL], with browserBundleID: String, chromeProfile: String?) throws
}

public final class Router {
    private let ruleSetProvider: () -> RuleSet
    private let sourceDetector: SourceDetecting
    private let opener: URLOpening
    private let log: RouteLog
    private let clock: () -> Date

    public init(
        ruleSetProvider: @escaping () -> RuleSet,
        sourceDetector: SourceDetecting,
        opener: URLOpening,
        log: RouteLog,
        clock: @escaping () -> Date = Date.init
    ) {
        self.ruleSetProvider = ruleSetProvider
        self.sourceDetector = sourceDetector
        self.opener = opener
        self.log = log
        self.clock = clock
    }

    public func route(_ urls: [URL]) throws {
        let source = sourceDetector.currentSourceApp()
        let ruleSet = ruleSetProvider()
        for url in urls {
            let request = RouteRequest(url: url, sourceBundleID: source)
            let decision = RuleEngine.decide(request, against: ruleSet)
            try opener.open([url], with: decision.target, chromeProfile: decision.chromeProfile)
            log.append(RouteEvent(
                timestamp: clock(),
                url: url,
                sourceBundleID: source,
                target: decision.target,
                matchedRuleID: decision.matchedRule?.id,
                chromeProfile: decision.chromeProfile
            ))
        }
    }
}
