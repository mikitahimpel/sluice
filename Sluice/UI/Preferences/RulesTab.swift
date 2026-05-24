import SwiftUI
import SluiceCore

struct RulesTab: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var browsers: [AppInfo] = []
    @State private var apps: [AppInfo] = []
    @State private var chromeProfiles: [ChromeProfile] = []
    @State private var editing: EditingTarget?
    @State private var testURLString: String = ""
    @State private var testSourceBundleID: String?
    @State private var testResult: Result<RoutePreview, RoutePreviewError>?

    var body: some View {
        VStack(spacing: 0) {
            ruleList

            Divider()

            HStack {
                Button {
                    editing = .new
                } label: {
                    Label("Add Rule", systemImage: "plus")
                }
                Text("Rules evaluate top-to-bottom; first match wins.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(8)

            Divider()

            testURLSection
                .padding(8)
        }
        .onAppear {
            if browsers.isEmpty { browsers = coordinator.browserCatalog.installedBrowsers() }
            if apps.isEmpty { apps = coordinator.appCatalog.installedApps() }
            if chromeProfiles.isEmpty { chromeProfiles = ChromeProfileCatalog().profiles() }
        }
        .sheet(item: $editing) { target in
            RuleEditorSheet(
                initialRule: rule(for: target),
                apps: apps,
                browsers: browsers,
                onSave: { saved in
                    apply(savedRule: saved, target: target)
                    editing = nil
                },
                onCancel: { editing = nil }
            )
        }
    }

    @ViewBuilder
    private var ruleList: some View {
        if coordinator.ruleSet.rules.isEmpty {
            VStack(spacing: 8) {
                Text("No rules yet")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Add a rule to send specific apps or URL hosts to a browser of your choice.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else {
            List {
                ForEach(coordinator.ruleSet.rules) { rule in
                    RuleRow(
                        rule: rule,
                        apps: apps,
                        browsers: browsers,
                        chromeProfiles: chromeProfiles,
                        onToggleEnabled: { newValue in
                            toggle(ruleID: rule.id, enabled: newValue)
                        },
                        onDelete: {
                            delete(ruleID: rule.id)
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editing = .existing(rule.id)
                    }
                }
                .onMove(perform: move)
            }
            .listStyle(.inset)
        }
    }

    private func rule(for target: EditingTarget) -> Rule? {
        switch target {
        case .new: return nil
        case .existing(let id): return coordinator.ruleSet.rules.first(where: { $0.id == id })
        }
    }

    private func apply(savedRule: Rule, target: EditingTarget) {
        var updated = coordinator.ruleSet
        switch target {
        case .new:
            updated.rules.append(savedRule)
        case .existing(let id):
            if let idx = updated.rules.firstIndex(where: { $0.id == id }) {
                updated.rules[idx] = savedRule
            } else {
                updated.rules.append(savedRule)
            }
        }
        coordinator.updateRuleSet(updated)
    }

    private func toggle(ruleID: Rule.ID, enabled: Bool) {
        var updated = coordinator.ruleSet
        guard let idx = updated.rules.firstIndex(where: { $0.id == ruleID }) else { return }
        updated.rules[idx].enabled = enabled
        coordinator.updateRuleSet(updated)
    }

    private func delete(ruleID: Rule.ID) {
        var updated = coordinator.ruleSet
        updated.rules.removeAll(where: { $0.id == ruleID })
        coordinator.updateRuleSet(updated)
    }

    private func move(from source: IndexSet, to destination: Int) {
        var updated = coordinator.ruleSet
        updated.rules.move(fromOffsets: source, toOffset: destination)
        coordinator.updateRuleSet(updated)
    }

    private var testURLSection: some View {
        GroupBox("Test a URL") {
            VStack(alignment: .leading, spacing: 8) {
                TextField("https://example.com/...", text: $testURLString, onCommit: runTest)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        AppPicker(
                            selection: $testSourceBundleID,
                            apps: apps,
                            placeholder: "(any/no source)"
                        )
                        if testSourceBundleID != nil {
                            Button {
                                testSourceBundleID = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.borderless)
                            .help("Clear source app")
                        }
                    }
                    Text("Source app (optional)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Test", action: runTest)
                        .keyboardShortcut(.defaultAction)
                        .disabled(testURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Spacer()
                }

                if let result = testResult {
                    testResultView(result)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func testResultView(_ result: Result<RoutePreview, RoutePreviewError>) -> some View {
        switch result {
        case .failure(.invalidURL):
            Text("Invalid URL. Include a scheme (e.g. https://).")
                .foregroundStyle(.red)
                .font(.callout)
        case .success(let preview):
            VStack(alignment: .leading, spacing: 4) {
                if preview.didUnwrap {
                    HStack(alignment: .top, spacing: 4) {
                        Text("Unwrapped to:").foregroundStyle(.secondary)
                        Text(preview.unwrappedURL.absoluteString)
                            .font(.system(.callout, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                HStack(spacing: 4) {
                    Text("Matched:").foregroundStyle(.secondary)
                    Text(matchedSummary(for: preview.matchedRule))
                        .fontWeight(.bold)
                }
                HStack(spacing: 6) {
                    Text("→ Opens in:").foregroundStyle(.secondary)
                    let browser = browsers.first(where: { $0.bundleID == preview.target })
                    AppIconView(app: browser, size: 16)
                    Text(browserDisplayName(for: preview.target))
                }
            }
            .font(.callout)
        }
    }

    private func runTest() {
        let trimmed = testURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            testResult = nil
            return
        }
        testResult = coordinator.preview(
            urlString: testURLString,
            sourceBundleID: testSourceBundleID
        )
    }

    private func matchedSummary(for rule: Rule?) -> String {
        guard let rule else { return "default fallback" }
        switch rule.match {
        case .sourceApp(let bundleID):
            let name = apps.first(where: { $0.bundleID == bundleID })?.displayName ?? bundleID
            return "source app = \(name)"
        case .urlHost(let glob):
            return "URL host matches \(glob)"
        }
    }

    private func browserDisplayName(for bundleID: String) -> String {
        browsers.first(where: { $0.bundleID == bundleID })?.displayName ?? bundleID
    }
}

private enum EditingTarget: Identifiable {
    case new
    case existing(UUID)

    var id: String {
        switch self {
        case .new: return "new"
        case .existing(let uuid): return uuid.uuidString
        }
    }
}

private struct RuleRow: View {
    let rule: Rule
    let apps: [AppInfo]
    let browsers: [AppInfo]
    let chromeProfiles: [ChromeProfile]
    let onToggleEnabled: (Bool) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
                .help("Drag to reorder")

            Toggle("", isOn: Binding(
                get: { rule.enabled },
                set: { onToggleEnabled($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)

            matchView
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)

            targetView

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete rule")
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var matchView: some View {
        switch rule.match {
        case .sourceApp(let bundleID):
            if let app = apps.first(where: { $0.bundleID == bundleID }) {
                HStack(spacing: 6) {
                    AppIconView(app: app, size: 16)
                    Text(app.displayName)
                }
            } else {
                HStack(spacing: 6) {
                    AppIconView(app: nil, size: 16)
                    Text(bundleID).font(.system(.body, design: .monospaced))
                }
            }
        case .urlHost(let glob):
            Text(glob).font(.system(.body, design: .monospaced))
        }
    }

    @ViewBuilder
    private var targetView: some View {
        if let browser = browsers.first(where: { $0.bundleID == rule.target }) {
            HStack(spacing: 6) {
                AppIconView(app: browser, size: 16)
                Text(browser.displayName + profileSuffix)
            }
        } else {
            HStack(spacing: 6) {
                AppIconView(app: nil, size: 16)
                Text(rule.target + profileSuffix).font(.system(.body, design: .monospaced))
            }
        }
    }

    private var profileSuffix: String {
        guard let directory = rule.chromeProfile else { return "" }
        let label = chromeProfiles.first(where: { $0.directory == directory })?.name ?? directory
        return " (\(label))"
    }
}
