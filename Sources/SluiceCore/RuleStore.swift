import Foundation

public protocol RuleStore {
    func load() throws -> RuleSet
    func save(_ ruleSet: RuleSet) throws
}

public enum RuleStoreError: Error {
    case malformedConfig(underlying: Error)
    case invalidVersion(Int)
}

public final class FileSystemRuleStore: RuleStore {
    private let directory: URL
    private let fileName: String

    public init(directory: URL? = nil, fileName: String = "rules.json") throws {
        if let directory {
            self.directory = directory
        } else {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            self.directory = appSupport.appendingPathComponent("Sluice", isDirectory: true)
        }
        self.fileName = fileName
        try FileManager.default.createDirectory(
            at: self.directory,
            withIntermediateDirectories: true
        )
    }

    public var fileURL: URL {
        directory.appendingPathComponent(fileName)
    }

    private var tempURL: URL {
        directory.appendingPathComponent(fileName + ".tmp")
    }

    public func load() throws -> RuleSet {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return RuleSet(version: 1, defaultBrowser: "com.apple.Safari", rules: [])
        }
        let data = try Data(contentsOf: url)
        let ruleSet: RuleSet
        do {
            ruleSet = try JSONDecoder().decode(RuleSet.self, from: data)
        } catch {
            throw RuleStoreError.malformedConfig(underlying: error)
        }
        guard ruleSet.version == 1 else {
            throw RuleStoreError.invalidVersion(ruleSet.version)
        }
        return ruleSet
    }

    public func save(_ ruleSet: RuleSet) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(ruleSet)
        let tmp = tempURL
        let target = fileURL
        if FileManager.default.fileExists(atPath: tmp.path) {
            try FileManager.default.removeItem(at: tmp)
        }
        try data.write(to: tmp, options: .atomic)
        _ = try FileManager.default.replaceItemAt(target, withItemAt: tmp)
    }
}
