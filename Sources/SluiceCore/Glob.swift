import Foundation

public enum Glob {
    public static func matches(pattern: String, host: String) -> Bool {
        let p = Array(pattern.lowercased())
        let s = Array(host.lowercased())
        return match(p, 0, s, 0)
    }

    private static func match(_ p: [Character], _ pi: Int, _ s: [Character], _ si: Int) -> Bool {
        var pi = pi
        var si = si
        var starPi = -1
        var starSi = -1

        while si < s.count {
            if pi < p.count && p[pi] == "*" {
                starPi = pi
                starSi = si
                pi += 1
            } else if pi < p.count && (p[pi] == "?" || p[pi] == s[si]) {
                pi += 1
                si += 1
            } else if starPi != -1 {
                pi = starPi + 1
                starSi += 1
                si = starSi
            } else {
                return false
            }
        }

        while pi < p.count && p[pi] == "*" {
            pi += 1
        }

        return pi == p.count
    }
}
