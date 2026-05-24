import Foundation

public struct RouteRequest: Equatable {
    public var url: URL
    public var sourceBundleID: String?

    public init(url: URL, sourceBundleID: String? = nil) {
        self.url = url
        self.sourceBundleID = sourceBundleID
    }
}

public struct RouteDecision: Equatable {
    public var target: String
    public var matchedRule: Rule?
    public var chromeProfile: String?

    public init(target: String, matchedRule: Rule? = nil, chromeProfile: String? = nil) {
        self.target = target
        self.matchedRule = matchedRule
        self.chromeProfile = chromeProfile
    }
}

public enum RuleEngine {
    public static func decide(_ request: RouteRequest, against ruleSet: RuleSet) -> RouteDecision {
        for rule in ruleSet.rules where rule.enabled {
            if matches(rule: rule, request: request) {
                return RouteDecision(
                    target: rule.target,
                    matchedRule: rule,
                    chromeProfile: rule.chromeProfile
                )
            }
        }
        return RouteDecision(target: ruleSet.defaultBrowser, matchedRule: nil, chromeProfile: nil)
    }

    private static func matches(rule: Rule, request: RouteRequest) -> Bool {
        switch rule.match {
        case .sourceApp(let bundleID):
            return request.sourceBundleID == bundleID
        case .urlHost(let glob):
            return Glob.matches(pattern: glob, host: request.url.host ?? "")
        }
    }
}
