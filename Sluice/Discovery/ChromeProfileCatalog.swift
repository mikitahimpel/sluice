import Foundation

public struct ChromeProfile: Identifiable, Equatable {
    public let directory: String
    public let name: String
    public let userName: String?
    public var id: String { directory }

    public init(directory: String, name: String, userName: String?) {
        self.directory = directory
        self.name = name
        self.userName = userName
    }
}

public final class ChromeProfileCatalog {
    private let localStateURL: URL

    public init(localStateURL: URL? = nil) {
        if let url = localStateURL {
            self.localStateURL = url
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.localStateURL = home
                .appendingPathComponent("Library/Application Support/Google/Chrome/Local State")
        }
    }

    public func profiles() -> [ChromeProfile] {
        guard FileManager.default.fileExists(atPath: localStateURL.path),
              let data = try? Data(contentsOf: localStateURL) else {
            return []
        }
        guard let root = try? JSONDecoder().decode(LocalStateRoot.self, from: data) else {
            return []
        }
        let parsed: [ChromeProfile] = root.profile.info_cache.map { directory, entry in
            let trimmedUser = entry.user_name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let userName = (trimmedUser?.isEmpty == false) ? trimmedUser : nil
            return ChromeProfile(directory: directory, name: entry.name, userName: userName)
        }
        return parsed.sorted(by: Self.order)
    }

    // "Default" always sorts first so the picker leads with the most common case.
    private static func order(_ lhs: ChromeProfile, _ rhs: ChromeProfile) -> Bool {
        if lhs.directory == "Default" && rhs.directory != "Default" { return true }
        if rhs.directory == "Default" && lhs.directory != "Default" { return false }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}

private struct LocalStateRoot: Decodable {
    let profile: ProfileSection
}

private struct ProfileSection: Decodable {
    let info_cache: [String: InfoCacheEntry]
}

private struct InfoCacheEntry: Decodable {
    let name: String
    let user_name: String?
}
