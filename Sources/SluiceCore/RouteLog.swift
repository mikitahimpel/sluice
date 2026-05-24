import Foundation

public struct RouteEvent: Equatable {
    public let timestamp: Date
    public let url: URL
    public let sourceBundleID: String?
    public let target: String
    public let matchedRuleID: UUID?
    public let chromeProfile: String?

    public init(
        timestamp: Date,
        url: URL,
        sourceBundleID: String?,
        target: String,
        matchedRuleID: UUID?,
        chromeProfile: String? = nil
    ) {
        self.timestamp = timestamp
        self.url = url
        self.sourceBundleID = sourceBundleID
        self.target = target
        self.matchedRuleID = matchedRuleID
        self.chromeProfile = chromeProfile
    }
}

public final class RouteLog {
    private let capacity: Int
    private var buffer: [RouteEvent] = []
    private let lock = NSLock()

    public init(capacity: Int = 50) {
        precondition(capacity > 0, "RouteLog capacity must be positive")
        self.capacity = capacity
        self.buffer.reserveCapacity(capacity)
    }

    public func append(_ event: RouteEvent) {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(event)
        if buffer.count > capacity {
            buffer.removeFirst(buffer.count - capacity)
        }
    }

    public func recent() -> [RouteEvent] {
        lock.lock()
        let snapshot = buffer
        lock.unlock()
        return snapshot.reversed()
    }

    public func clear() {
        lock.lock()
        buffer.removeAll(keepingCapacity: true)
        lock.unlock()
    }
}
