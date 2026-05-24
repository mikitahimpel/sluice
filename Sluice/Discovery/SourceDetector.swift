import AppKit
import SluiceCore

public protocol WorkspaceLike: AnyObject {
    var frontmostBundleID: String? { get }
    var workspaceNotificationCenter: NotificationCenter { get }
}

extension NSWorkspace: WorkspaceLike {
    public var frontmostBundleID: String? {
        frontmostApplication?.bundleIdentifier
    }
    public var workspaceNotificationCenter: NotificationCenter {
        notificationCenter
    }
}

public final class SourceDetector: SourceDetecting {
    public struct Activation: Equatable {
        public let bundleID: String
        public let date: Date
    }

    private let workspace: WorkspaceLike
    private let selfBundleID: String?
    private let historyDepth: Int
    private let lock = NSLock()
    private var buffer: [Activation] = []
    private var observer: NSObjectProtocol?

    public convenience init(
        workspace: NSWorkspace = .shared,
        selfBundleID: String? = Bundle.main.bundleIdentifier,
        historyDepth: Int = 8
    ) {
        self.init(workspaceLike: workspace, selfBundleID: selfBundleID, historyDepth: historyDepth)
    }

    public init(
        workspaceLike: WorkspaceLike,
        selfBundleID: String? = Bundle.main.bundleIdentifier,
        historyDepth: Int = 8,
        clock: @escaping () -> Date = Date.init
    ) {
        self.workspace = workspaceLike
        self.selfBundleID = selfBundleID
        self.historyDepth = max(1, historyDepth)
        self.observer = workspaceLike.workspaceNotificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: nil
        ) { [weak self] note in
            guard let self else { return }
            let bid: String?
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                bid = app.bundleIdentifier
            } else {
                bid = note.userInfo?["bundleID"] as? String
            }
            guard let bundleID = bid else { return }
            self.recordActivation(bundleID: bundleID, date: clock())
        }
    }

    deinit {
        if let observer {
            workspace.workspaceNotificationCenter.removeObserver(observer)
        }
    }

    public func currentSourceApp() -> String? {
        if let front = workspace.frontmostBundleID, front != selfBundleID {
            return front
        }
        lock.lock()
        defer { lock.unlock() }
        return buffer.first?.bundleID
    }

    public func recentActivations() -> [Activation] {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }

    private func recordActivation(bundleID: String, date: Date) {
        if bundleID == selfBundleID { return }
        lock.lock()
        defer { lock.unlock() }
        buffer.insert(Activation(bundleID: bundleID, date: date), at: 0)
        if buffer.count > historyDepth {
            buffer.removeLast(buffer.count - historyDepth)
        }
    }
}
