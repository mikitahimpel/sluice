import SwiftUI
import AppKit
import UniformTypeIdentifiers
import SluiceCore

struct GeneralTab: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var browsers: [AppInfo] = []
    @State private var refreshTick: Int = 0
    @State private var pendingImportURL: URL?
    @State private var backupErrorMessage: String?

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

            Section("Backup") {
                HStack {
                    Button("Import rules…", action: presentImportPanel)
                    Button("Export rules…", action: presentExportPanel)
                }
                Text("Export to share or back up your rules. Importing replaces all current rules.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if browsers.isEmpty {
                browsers = coordinator.browserCatalog.installedBrowsers()
            }
        }
        .id(refreshTick)
        .alert(
            "Replace current rules?",
            isPresented: Binding(
                get: { pendingImportURL != nil },
                set: { if !$0 { pendingImportURL = nil } }
            ),
            presenting: pendingImportURL
        ) { url in
            Button("Replace", role: .destructive) {
                performImport(from: url)
                pendingImportURL = nil
            }
            Button("Cancel", role: .cancel) {
                pendingImportURL = nil
            }
        } message: { _ in
            Text("This will replace your current rules with the imported set.")
        }
        .alert(
            "Backup failed",
            isPresented: Binding(
                get: { backupErrorMessage != nil },
                set: { if !$0 { backupErrorMessage = nil } }
            ),
            presenting: backupErrorMessage
        ) { _ in
            Button("OK", role: .cancel) { backupErrorMessage = nil }
        } message: { message in
            Text(message)
        }
    }

    private func presentImportPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Import"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        pendingImportURL = url
    }

    private func presentExportPanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "sluice-rules.json"
        panel.prompt = "Export"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try coordinator.exportRuleSet(to: url)
        } catch {
            backupErrorMessage = "Could not export rules: \(error.localizedDescription)"
        }
    }

    private func performImport(from url: URL) {
        do {
            try coordinator.importRuleSet(from: url)
        } catch {
            backupErrorMessage = "Could not import rules: \(error.localizedDescription)"
        }
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
