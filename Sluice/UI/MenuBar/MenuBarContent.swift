import AppKit
import SwiftUI
import SluiceCore

struct MenuBarContent: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        let resolver = coordinator.browserResolver
        let isSluiceDefault = coordinator.isSluiceDefault
        let ruleCount = coordinator.ruleSet.rules.filter(\.enabled).count

        if isSluiceDefault {
            Text(activeHeaderText(ruleCount: ruleCount))
                .font(.system(size: 12))
        } else {
            Button("⚠ Set Sluice as default browser") {
                coordinator.defaultBrowserClient.requestBecomeDefault()
            }
        }

        Divider()

        OpenPreferencesButton()

        Divider()

        RecentRoutesMenu(coordinator: coordinator, resolver: resolver)

        Divider()

        Button("Quit Sluice") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func activeHeaderText(ruleCount: Int) -> String {
        switch ruleCount {
        case 0: return "Routing — no rules yet"
        case 1: return "Routing through 1 rule"
        default: return "Routing through \(ruleCount) rules"
        }
    }
}

private struct OpenPreferencesButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Preferences…") {
            // LSUIElement apps must explicitly activate before openSettings,
            // otherwise the Settings window opens behind the active app.
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
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
                Button("No links routed yet") {}.disabled(true)
            } else {
                ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                    Text(label(for: event))
                }
            }
        }
    }

    private func label(for event: RouteEvent) -> String {
        let left = event.url.host ?? truncate(event.url.absoluteString, to: 36)
        let right = resolver.displayName(for: event.target)
        return "\(left)  →  \(right)"
    }

    private func truncate(_ s: String, to limit: Int) -> String {
        guard s.count > limit else { return s }
        return String(s.prefix(limit - 1)) + "…"
    }
}
