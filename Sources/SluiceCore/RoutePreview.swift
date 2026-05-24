import Foundation

public struct RoutePreview: Equatable {
    public let originalURL: URL
    public let unwrappedURL: URL
    public let sourceBundleID: String?
    public let target: String
    public let matchedRule: Rule?

    public init(
        originalURL: URL,
        unwrappedURL: URL,
        sourceBundleID: String?,
        target: String,
        matchedRule: Rule?
    ) {
        self.originalURL = originalURL
        self.unwrappedURL = unwrappedURL
        self.sourceBundleID = sourceBundleID
        self.target = target
        self.matchedRule = matchedRule
    }

    public var didUnwrap: Bool { originalURL != unwrappedURL }
}

public enum RoutePreviewError: Error, Equatable {
    case invalidURL
}

public enum RoutePreviewer {
    public static func preview(
        urlString: String,
        sourceBundleID: String?,
        ruleSet: RuleSet
    ) -> Result<RoutePreview, RoutePreviewError> {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.invalidURL) }
        guard let url = URL(string: trimmed) else { return .failure(.invalidURL) }
        guard let scheme = url.scheme, !scheme.isEmpty else { return .failure(.invalidURL) }

        let unwrapped = LinkUnwrapper.unwrap(url)
        let request = RouteRequest(url: unwrapped, sourceBundleID: sourceBundleID)
        let decision = RuleEngine.decide(request, against: ruleSet)
        let preview = RoutePreview(
            originalURL: url,
            unwrappedURL: unwrapped,
            sourceBundleID: sourceBundleID,
            target: decision.target,
            matchedRule: decision.matchedRule
        )
        return .success(preview)
    }
}
