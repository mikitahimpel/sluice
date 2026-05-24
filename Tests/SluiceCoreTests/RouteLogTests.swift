import XCTest
@testable import SluiceCore

final class RouteLogTests: XCTestCase {
    private func event(_ host: String, target: String = "com.apple.Safari", at offset: TimeInterval = 0) -> RouteEvent {
        RouteEvent(
            timestamp: Date(timeIntervalSince1970: offset),
            url: URL(string: "https://\(host)")!,
            sourceBundleID: nil,
            target: target,
            matchedRuleID: nil
        )
    }

    func testAppendAndRecentNewestFirst() {
        let log = RouteLog(capacity: 10)
        let a = event("a.com", at: 1)
        let b = event("b.com", at: 2)
        let c = event("c.com", at: 3)
        log.append(a)
        log.append(b)
        log.append(c)
        XCTAssertEqual(log.recent(), [c, b, a])
    }

    func testCapacityDropsOldest() {
        let log = RouteLog(capacity: 3)
        let a = event("a.com", at: 1)
        let b = event("b.com", at: 2)
        let c = event("c.com", at: 3)
        let d = event("d.com", at: 4)
        log.append(a)
        log.append(b)
        log.append(c)
        log.append(d)
        XCTAssertEqual(log.recent(), [d, c, b])
    }

    func testClear() {
        let log = RouteLog(capacity: 3)
        log.append(event("a.com"))
        log.append(event("b.com"))
        log.clear()
        XCTAssertEqual(log.recent(), [])
    }

    func testRecentReturnsSnapshotCopy() {
        let log = RouteLog(capacity: 5)
        log.append(event("a.com", at: 1))
        let snapshot = log.recent()
        log.append(event("b.com", at: 2))
        XCTAssertEqual(snapshot.count, 1)
        XCTAssertEqual(log.recent().count, 2)
    }

    func testConcurrentAppendsRespectCapacity() {
        let capacity = 50
        let log = RouteLog(capacity: capacity)
        let queue = DispatchQueue(label: "log.test", attributes: .concurrent)
        let group = DispatchGroup()
        for i in 0..<1000 {
            group.enter()
            queue.async {
                log.append(self.event("host\(i).com", at: TimeInterval(i)))
                group.leave()
            }
        }
        group.wait()
        XCTAssertEqual(log.recent().count, capacity)
    }
}
