import Foundation

public enum Match: Codable, Equatable {
    case sourceApp(bundleID: String)
    case urlHost(glob: String)

    private enum CodingKeys: String, CodingKey {
        case type
        case bundleID
        case glob
    }

    private enum Kind: String, Codable {
        case sourceApp
        case urlHost
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .type)
        switch kind {
        case .sourceApp:
            let bundleID = try container.decode(String.self, forKey: .bundleID)
            self = .sourceApp(bundleID: bundleID)
        case .urlHost:
            let glob = try container.decode(String.self, forKey: .glob)
            self = .urlHost(glob: glob)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .sourceApp(let bundleID):
            try container.encode(Kind.sourceApp, forKey: .type)
            try container.encode(bundleID, forKey: .bundleID)
        case .urlHost(let glob):
            try container.encode(Kind.urlHost, forKey: .type)
            try container.encode(glob, forKey: .glob)
        }
    }
}

public struct Rule: Codable, Identifiable, Equatable {
    public let id: UUID
    public var enabled: Bool
    public var match: Match
    public var target: String
    public var chromeProfile: String?

    public init(
        id: UUID = UUID(),
        enabled: Bool = true,
        match: Match,
        target: String,
        chromeProfile: String? = nil
    ) {
        self.id = id
        self.enabled = enabled
        self.match = match
        self.target = target
        self.chromeProfile = chromeProfile
    }
}

public struct RuleSet: Codable, Equatable {
    public var version: Int
    public var defaultBrowser: String
    public var rules: [Rule]

    public init(version: Int = 1, defaultBrowser: String, rules: [Rule] = []) {
        self.version = version
        self.defaultBrowser = defaultBrowser
        self.rules = rules
    }
}
