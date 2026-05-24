import SwiftUI

@main
struct SluiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarScene(coordinator: appDelegate.coordinator)

        Settings {
            ContentPlaceholderView()
                .environmentObject(appDelegate.coordinator)
        }
    }
}

private struct ContentPlaceholderView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sluice").font(.title)
            Text("Default browser: \(coordinator.defaultBrowserClient.currentDefaultBrowser() ?? "unknown")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Rules: \(coordinator.ruleSet.rules.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Preferences UI coming soon.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 480, height: 320)
    }
}
