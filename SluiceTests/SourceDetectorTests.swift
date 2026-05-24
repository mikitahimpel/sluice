import XCTest
@testable import Sluice

private final class FakeWorkspace: WorkspaceLike {
    var frontmostBundleID: String?
    let workspaceNotificationCenter: NotificationCenter

    init(notificationCenter: NotificationCenter = NotificationCenter()) {
        self.workspaceNotificationCenter = notificationCenter
    }

    func postActivation(bundleID: String) {
        workspaceNotificationCenter.post(
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            userInfo: ["bundleID": bundleID]
        )
    }
}

final class SourceDetectorTests: XCTestCase {
    private let selfID = "com.gimpel.Sluice"

    func testReturnsFrontmostWhenNotSelf() {
        let ws = FakeWorkspace()
        ws.frontmostBundleID = "com.example.editor"
        let detector = SourceDetector(workspaceLike: ws, selfBundleID: selfID)
        XCTAssertEqual(detector.currentSourceApp(), "com.example.editor")
    }

    func testFallsBackToBufferWhenFrontmostIsSelf() {
        let ws = FakeWorkspace()
        let detector = SourceDetector(workspaceLike: ws, selfBundleID: selfID)
        ws.postActivation(bundleID: "com.example.first")
        ws.postActivation(bundleID: "com.example.second")
        ws.frontmostBundleID = selfID
        XCTAssertEqual(detector.currentSourceApp(), "com.example.second")
    }

    func testReturnsNilWhenBufferEmptyAndFrontmostIsSelf() {
        let ws = FakeWorkspace()
        ws.frontmostBundleID = selfID
        let detector = SourceDetector(workspaceLike: ws, selfBundleID: selfID)
        XCTAssertNil(detector.currentSourceApp())
    }

    func testReturnsNilWhenFrontmostNilAndBufferEmpty() {
        let ws = FakeWorkspace()
        ws.frontmostBundleID = nil
        let detector = SourceDetector(workspaceLike: ws, selfBundleID: selfID)
        XCTAssertNil(detector.currentSourceApp())
    }

    func testBufferOrderAndCapacity() {
        let ws = FakeWorkspace()
        let detector = SourceDetector(workspaceLike: ws, selfBundleID: selfID, historyDepth: 3)
        ws.postActivation(bundleID: "a")
        ws.postActivation(bundleID: "b")
        ws.postActivation(bundleID: "c")
        ws.postActivation(bundleID: "d")
        let bids = detector.recentActivations().map(\.bundleID)
        XCTAssertEqual(bids, ["d", "c", "b"])
    }

    func testSelfActivationsNotBuffered() {
        let ws = FakeWorkspace()
        let detector = SourceDetector(workspaceLike: ws, selfBundleID: selfID)
        ws.postActivation(bundleID: "com.example.real")
        ws.postActivation(bundleID: selfID)
        ws.postActivation(bundleID: "com.example.another")
        let bids = detector.recentActivations().map(\.bundleID)
        XCTAssertEqual(bids, ["com.example.another", "com.example.real"])
    }

    func testFrontmostNilFallsBackToBuffer() {
        let ws = FakeWorkspace()
        let detector = SourceDetector(workspaceLike: ws, selfBundleID: selfID)
        ws.postActivation(bundleID: "com.example.recent")
        ws.frontmostBundleID = nil
        XCTAssertEqual(detector.currentSourceApp(), "com.example.recent")
    }
}
