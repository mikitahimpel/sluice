import SwiftUI
import SluiceCore

struct RulesTab: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var browsers: [AppInfo] = []
    @State private var apps: [AppInfo] = []
    @State private var editing: EditingTarget?

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
        }
        .onAppear {
            if browsers.isEmpty { browsers = coordinator.browserCatalog.installedBrowsers() }
            if apps.isEmpty { apps = coordinator.appCatalog.installedApps() }
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
                Text(browser.displayName)
            }
        } else {
            HStack(spacing: 6) {
                AppIconView(app: nil, size: 16)
                Text(rule.target).font(.system(.body, design: .monospaced))
            }
        }
    }
}
