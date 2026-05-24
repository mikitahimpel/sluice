import Foundation

public enum LinkUnwrapper {
    // Cap iterations to guard against pathological inputs that could chain
    // wrappers indefinitely (e.g. a Google URL whose `q` is another Google URL,
    // ad infinitum) or otherwise loop. Four is well above realistic depths.
    private static let maxIterations = 4

    public static func unwrap(_ url: URL) -> URL {
        var current = url
        for _ in 0..<maxIterations {
            guard let next = unwrapOnce(current), next != current else {
                return current
            }
            current = next
        }
        return current
    }

    private static func unwrapOnce(_ url: URL) -> URL? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let host = (components.host ?? "").lowercased()
        let path = components.path

        if host == "www.google.com" || host == "google.com" {
            if path.lowercased() == "/url" {
                return extractQueryParam(components, name: "q")
            }
            if path.lowercased().hasPrefix("/amp/s/") {
                let suffix = String(path.dropFirst("/amp/s/".count))
                guard !suffix.isEmpty else { return nil }
                return URL(string: "https://" + suffix)
            }
        }

        if host.hasSuffix(".safelinks.protection.outlook.com") {
            return extractQueryParam(components, name: "url")
        }

        if host == "www.linkedin.com", path.lowercased().hasPrefix("/redir/") {
            return extractQueryParam(components, name: "url")
        }

        return nil
    }

    private static func extractQueryParam(_ components: URLComponents, name: String) -> URL? {
        guard let items = components.queryItems else { return nil }
        for item in items where item.name.lowercased() == name.lowercased() {
            guard let value = item.value, !value.isEmpty else { return nil }
            if let url = URL(string: value) {
                return url
            }
        }
        return nil
    }
}
