import AppKit
import SwiftUI
import SluiceCore

struct MenuBarContent: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        let resolver = BrowserDisplayNameResolver(catalog: coordinator.browserCatalog)
        let isSluiceDefault = coordinator.defaultBrowserClient.isSluiceDefault()

        StatusRow(
            coordinator: coordinator,
            resolver: resolver,
            isSluiceDefault: isSluiceDefault
        )

        Divider()

        Button("Set as default browser") {
            coordinator.defaultBrowserClient.requestBecomeDefault()
        }
        .disabled(isSluiceDefault)

        OpenPreferencesButton()

        Divider()

        RecentRoutesMenu(coordinator: coordinator, resolver: resolver)

        Divider()

        Button("Quit Sluice") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

private struct StatusRow: View {
    let coordinator: AppCoordinator
    let resolver: BrowserDisplayNameResolver
    let isSluiceDefault: Bool

    var body: some View {
        Text(statusText)
    }

    private var statusText: String {
        if isSluiceDefault {
            return "Default browser: Sluice ✓"
        }
        if let bundleID = coordinator.defaultBrowserClient.currentDefaultBrowser() {
            return "Default browser: \(resolver.displayName(for: bundleID))"
        }
        return "Default browser: unknown"
    }
}

private struct OpenPreferencesButton: View {
    var body: some View {
        Button("Open Preferences…") {
            // LSUIElement apps don't activate themselves when a panel is requested;
            // without this the Settings window opens off-screen / behind everything.
            NSApp.activate(ignoringOtherApps: true)
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
        .keyboardShortcut(",")
    }
}

private struct RecentRoutesMenu: View {
    let coordinator: AppCoordinator
    let resolver: BrowserDisplayNameResolver

    var body: some View {
        Menu("Recent routes") {
            let events = Array(coordinator.routeLog.recent().prefix(10))
            if events.isEmpty {
                Button("No routes yet") {}.disabled(true)
            } else {
                ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                    Text(label(for: event))
                }
            }
        }
    }

    private func label(for event: RouteEvent) -> String {
        let left = event.url.host ?? truncate(event.url.absoluteString, to: 40)
        let right = resolver.displayName(for: event.target)
        return "\(left) → \(right)"
    }

    private func truncate(_ s: String, to limit: Int) -> String {
        guard s.count > limit else { return s }
        return String(s.prefix(limit - 1)) + "…"
    }
}
