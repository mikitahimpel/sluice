import SwiftUI
import SluiceCore

struct GeneralTab: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var browsers: [AppInfo] = []
    @State private var refreshTick: Int = 0

    var body: some View {
        Form {
            Section("Default browser") {
                HStack(spacing: 6) {
                    Text("Current system default:")
                    Text(currentDefaultLabel)
                        .fontWeight(.medium)
                }
                Button("Make Sluice the default browser") {
                    coordinator.defaultBrowserClient.requestBecomeDefault()
                    refreshTick &+= 1
                }
                .disabled(isSluiceDefault)
                Text("macOS will ask you to confirm.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Fallback browser") {
                Text("Used when no rule matches.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Fallback", selection: fallbackBinding) {
                    ForEach(browsers) { browser in
                        Text(browser.displayName).tag(browser.bundleID as String?)
                    }
                    if !browsers.contains(where: { $0.bundleID == coordinator.ruleSet.defaultBrowser }) {
                        Text(coordinator.ruleSet.defaultBrowser)
                            .tag(coordinator.ruleSet.defaultBrowser as String?)
                    }
                }
                .labelsHidden()
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if browsers.isEmpty {
                browsers = coordinator.browserCatalog.installedBrowsers()
            }
        }
        .id(refreshTick)
    }

    private var isSluiceDefault: Bool {
        coordinator.defaultBrowserClient.isSluiceDefault()
    }

    private var currentDefaultLabel: String {
        let resolver = BrowserDisplayNameResolver(catalog: coordinator.browserCatalog)
        if isSluiceDefault {
            return "Sluice ✓ (Sluice)"
        }
        guard let bundleID = coordinator.defaultBrowserClient.currentDefaultBrowser() else {
            return "unknown"
        }
        return resolver.displayName(for: bundleID)
    }

    private var fallbackBinding: Binding<String?> {
        Binding(
            get: { coordinator.ruleSet.defaultBrowser },
            set: { newValue in
                guard let newValue, newValue != coordinator.ruleSet.defaultBrowser else { return }
                var updated = coordinator.ruleSet
                updated.defaultBrowser = newValue
                coordinator.updateRuleSet(updated)
            }
        )
    }
}
