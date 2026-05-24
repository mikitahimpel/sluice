import AppKit
import SwiftUI
import SluiceCore

@MainActor
final class OverridePickerWindowController: NSWindowController {
    private let urls: [URL]
    private let browsers: [AppInfo]
    private let onPick: (String) -> Void
    private let onCancel: () -> Void

    private var didPick: Bool = false
    private var didCancel: Bool = false
    private var keyMonitor: Any?

    init(
        urls: [URL],
        browsers: [AppInfo],
        onPick: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.urls = urls
        self.browsers = browsers
        self.onPick = onPick
        self.onCancel = onCancel

        let panel = OverridePickerPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 380),
            styleMask: [.titled, .fullSizeContentView, .hudWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false

        super.init(window: panel)

        panel.cancelHandler = { [weak self] in
            self?.handleCancel()
        }

        let rootView = OverridePickerView(
            urls: urls,
            browsers: browsers,
            onPick: { [weak self] bundleID in
                self?.handlePick(bundleID)
            },
            onCancel: { [weak self] in
                self?.handleCancel()
            }
        )

        let hosting = NSHostingView(rootView: rootView)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        if let contentView = panel.contentView {
            contentView.addSubview(hosting)
            NSLayoutConstraint.activate([
                hosting.topAnchor.constraint(equalTo: contentView.topAnchor),
                hosting.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                hosting.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                hosting.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            ])
        } else {
            panel.contentView = hosting
        }

        panel.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func present() {
        if let screen = NSScreen.main, let window {
            let frame = window.frame
            let visible = screen.visibleFrame
            let originX = visible.midX - frame.width / 2
            let originY = visible.midY - frame.height / 2 + visible.height * 0.1
            window.setFrameOrigin(NSPoint(x: originX, y: originY))
        }

        // Sluice runs LSUIElement so it has no Dock presence; for a user-initiated
        // override the panel must accept first-responder focus, so we deliberately
        // promote the app here. This is the only path that steals focus.
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)

        installKeyMonitor()
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.window === self.window, event.keyCode == 53 {
                self.handleCancel()
                return nil
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func handlePick(_ bundleID: String) {
        guard !didPick, !didCancel else { return }
        didPick = true
        removeKeyMonitor()
        onPick(bundleID)
        close()
    }

    private func handleCancel() {
        guard !didPick, !didCancel else { return }
        didCancel = true
        removeKeyMonitor()
        onCancel()
        close()
    }
}

extension OverridePickerWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        removeKeyMonitor()
        if !didPick, !didCancel {
            didCancel = true
            onCancel()
        }
    }
}

private final class OverridePickerPanel: NSPanel {
    var cancelHandler: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        cancelHandler?()
    }
}
