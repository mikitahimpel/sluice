import SwiftUI
import SluiceCore

struct RulesTab: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var editing: EditingTarget?
    @State private var showAIRules: Bool = false
    @State private var testURLString: String = ""
    @State private var testSourceBundleID: String?
    @State private var testResult: Result<RoutePreview, RoutePreviewError>?
    @State private var showTester: Bool = false

    private var browsers: [AppInfo] { coordinator.installedBrowsers }
    private var apps: [AppInfo] { coordinator.installedApps }
    private var chromeProfiles: [ChromeProfile] { coordinator.chromeProfiles }

    var body: some View {
        ZStack {
            if let target = editing {
                editorPage(for: target)
                    .transition(.pageForward)
            } else if showAIRules {
                aiPage
                    .transition(.pageForward)
            } else {
                rulesListView
                    .transition(.pageBackward)
            }
        }
        .animation(DS.Motion.reveal, value: routeID)
    }

    // Distinguishes the three content states so `.animation(value:)` knows
    // when to run the page transition.
    private var routeID: Int {
        if editing != nil { return 1 }
        if showAIRules { return 2 }
        return 0
    }

    private var rulesListView: some View {
        VStack(spacing: 0) {
            header

            Rectangle().fill(DS.Hairline.color).frame(height: DS.Hairline.width)

            content

            Rectangle().fill(DS.Hairline.color).frame(height: DS.Hairline.width)

            footer
        }
        .background(.windowBackground)
    }

    // MARK: Pages

    private func editorPage(for target: EditingTarget) -> some View {
        RuleEditorSheet(
            initialRule: rule(for: target),
            apps: apps,
            browsers: browsers,
            chromeProfiles: chromeProfiles,
            onSave: { saved in
                apply(savedRule: saved, target: target)
                dismissPage()
            },
            onCancel: { dismissPage() }
        )
    }

    private var aiPage: some View {
        AIRulesSheet(
            apps: apps,
            browsers: browsers,
            currentDefaultBrowser: coordinator.ruleSet.defaultBrowser,
            onApply: { incoming, mode in
                applyAIRules(incoming, mode: mode)
                dismissPage()
            },
            onCancel: { dismissPage() }
        )
    }

    private func openEditor(_ target: EditingTarget) {
        showAIRules = false
        editing = target
    }

    private func openAIRules() {
        editing = nil
        showAIRules = true
    }

    private func dismissPage() {
        editing = nil
        showAIRules = false
    }

    private func applyAIRules(_ incoming: RuleSet, mode: AIRulesSheet.ApplyMode) {
        var updated = coordinator.ruleSet
        switch mode {
        case .replace:
            updated = incoming
        case .append:
            // Keep the user's existing fallback browser on append — they
            // already chose one. Only the rules merge.
            updated.rules.append(contentsOf: incoming.rules)
        }
        coordinator.updateRuleSet(updated)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: DS.Space.s) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Rules")
                        .font(.system(size: 15, weight: .semibold))
                    if !coordinator.ruleSet.rules.isEmpty {
                        Text("\(coordinator.ruleSet.rules.count)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(
                                Capsule().fill(Color.primary.opacity(0.07))
                            )
                    }
                }
                Text(headerSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !coordinator.ruleSet.rules.isEmpty {
                Button {
                    openAIRules()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Generate with AI")
                    }
                }
                .buttonStyle(GhostButtonStyle())

                Button {
                    openEditor(.new)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Add Rule")
                    }
                }
                .buttonStyle(PrimaryPillButtonStyle())
            }
        }
        .padding(.horizontal, DS.Space.xl)
        .padding(.top, DS.Space.m)
        .padding(.bottom, DS.Space.l)
    }

    private var headerSubtitle: String {
        let count = coordinator.ruleSet.rules.count
        switch count {
        case 0: return "Define how Sluice routes links."
        case 1: return "1 rule, evaluated top-to-bottom."
        default: return "\(count) rules, evaluated top-to-bottom."
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if coordinator.ruleSet.rules.isEmpty {
            emptyState
        } else {
            ruleList
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Space.l) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.appIconContainer, style: .continuous)
                    .fill(DS.SurfaceFill.card)
                    .frame(width: 72, height: 72)
                RoundedRectangle(cornerRadius: DS.Radius.appIconContainer, style: .continuous)
                    .strokeBorder(DS.Hairline.color, lineWidth: DS.Hairline.width)
                    .frame(width: 72, height: 72)
                BrandMark(size: 44, tint: .secondary)
            }
            VStack(spacing: 6) {
                Text("No rules yet")
                    .font(.system(size: 15, weight: .semibold))
                Text("Send links from a specific source app — or matching a URL pattern —\nto the browser of your choice.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: DS.Space.s) {
                Button {
                    openEditor(.new)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Create your first rule")
                    }
                }
                .buttonStyle(PrimaryPillButtonStyle())

                Button {
                    openAIRules()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Generate with AI")
                    }
                }
                .buttonStyle(GhostButtonStyle())
            }
            .padding(.top, DS.Space.xs)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DS.Space.xl)
    }

    private var ruleList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(Array(coordinator.ruleSet.rules.enumerated()), id: \.element.id) { _, rule in
                    RuleRow(
                        rule: rule,
                        apps: apps,
                        browsers: browsers,
                        chromeProfiles: chromeProfiles,
                        onToggleEnabled: { newValue in toggle(ruleID: rule.id, enabled: newValue) },
                        onDelete: { delete(ruleID: rule.id) },
                        onEdit: { openEditor(.existing(rule.id)) },
                        onMoveUp: { moveOne(ruleID: rule.id, delta: -1) },
                        onMoveDown: { moveOne(ruleID: rule.id, delta: 1) }
                    )
                }
            }
            .padding(.horizontal, DS.Space.l)
            .padding(.vertical, DS.Space.s)
        }
    }

    // MARK: Footer (test URL)

    private var footer: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(DS.Motion.reveal) { showTester.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(showTester ? 90 : 0))
                    Text("Test a URL")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !showTester {
                        Text("⇧⌘T")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("t", modifiers: [.shift, .command])
            .padding(.horizontal, DS.Space.xl)
            .padding(.vertical, DS.Space.s)

            if showTester {
                testURLBody
                    .padding(.horizontal, DS.Space.xl)
                    .padding(.bottom, DS.Space.m)
                    .transition(
                        .asymmetric(
                            insertion: .offset(y: 8).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            }
        }
    }

    private var testURLBody: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack(spacing: DS.Space.s) {
                InlineTextField(
                    placeholder: "https://example.com/...",
                    text: $testURLString
                )
                .frame(maxWidth: .infinity)

                Button("Test", action: runTest)
                    .buttonStyle(PrimaryPillButtonStyle())
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(testURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            HStack(spacing: DS.Space.s) {
                Text("From")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                AppPicker(
                    selection: $testSourceBundleID,
                    apps: apps,
                    placeholder: "Any source app"
                )
                if testSourceBundleID != nil {
                    Button {
                        testSourceBundleID = nil
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(IconButtonStyle())
                    .help("Clear source app")
                }
            }

            if let result = testResult {
                testResultView(result)
                    .padding(.top, DS.Space.xs)
            }
        }
    }

    @ViewBuilder
    private func testResultView(_ result: Result<RoutePreview, RoutePreviewError>) -> some View {
        switch result {
        case .failure(.invalidURL):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                Text("Invalid URL. Include a scheme like https://.")
                    .font(.system(size: 12))
            }
            .foregroundStyle(.red)
            .padding(.horizontal, DS.Space.m)
            .padding(.vertical, DS.Space.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.surface, style: .continuous)
                    .fill(Color.red.opacity(0.08))
            )

        case .success(let preview):
            VStack(alignment: .leading, spacing: 6) {
                if preview.didUnwrap {
                    Text(preview.unwrappedURL.absoluteString)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                HStack(spacing: DS.Space.s) {
                    Text(matchedSummary(for: preview.matchedRule))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    let browser = browsers.first(where: { $0.bundleID == preview.target })
                    AppIconView(app: browser, size: 16)
                    Text(browserDisplayName(for: preview.target))
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .padding(.horizontal, DS.Space.m)
            .padding(.vertical, DS.Space.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.surface, style: .continuous)
                    .fill(DS.SurfaceFill.card)
            )
        }
    }

    // MARK: Data

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

    private func moveOne(ruleID: Rule.ID, delta: Int) {
        var updated = coordinator.ruleSet
        guard let idx = updated.rules.firstIndex(where: { $0.id == ruleID }) else { return }
        let target = idx + delta
        guard target >= 0, target < updated.rules.count else { return }
        let rule = updated.rules.remove(at: idx)
        updated.rules.insert(rule, at: target)
        coordinator.updateRuleSet(updated)
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
        guard let rule else { return "Default fallback" }
        switch rule.match {
        case .sourceApp(let bundleID):
            let name = apps.first(where: { $0.bundleID == bundleID })?.displayName ?? bundleID
            return "Source = \(name)"
        case .urlHost(let glob):
            return "Host matches \(glob)"
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

private extension AnyTransition {
    /// A page pushed in from the right (editor / AI pages).
    static var pageForward: AnyTransition {
        .offset(x: 26).combined(with: .opacity)
    }

    /// The list, which recedes slightly left as a page covers it.
    static var pageBackward: AnyTransition {
        .offset(x: -18).combined(with: .opacity)
    }
}

// MARK: Rule row

private struct RuleRow: View {
    let rule: Rule
    let apps: [AppInfo]
    let browsers: [AppInfo]
    let chromeProfiles: [ChromeProfile]
    let onToggleEnabled: (Bool) -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    @State private var hovered: Bool = false

    var body: some View {
        HStack(spacing: DS.Space.m) {
            Toggle("", isOn: Binding(
                get: { rule.enabled },
                set: { onToggleEnabled($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)

            HStack(spacing: DS.Space.s) {
                matchView
                    .frame(minWidth: 140, maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                targetView
                    .frame(minWidth: 140, maxWidth: .infinity, alignment: .leading)
            }
            .opacity(rule.enabled ? 1.0 : 0.55)
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)

            HStack(spacing: 2) {
                Button { onMoveUp() } label: { Image(systemName: "chevron.up") }
                    .buttonStyle(IconButtonStyle())
                    .help("Move up")
                Button { onMoveDown() } label: { Image(systemName: "chevron.down") }
                    .buttonStyle(IconButtonStyle())
                    .help("Move down")
                Button { onDelete() } label: { Image(systemName: "trash") }
                    .buttonStyle(IconButtonStyle(tint: .secondary))
                    .help("Delete rule")
            }
            .opacity(hovered ? 1.0 : 0.0)
            .offset(x: hovered ? 0 : 6)
            .animation(DS.Motion.reveal, value: hovered)
        }
        .padding(.horizontal, DS.Space.m)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.row, style: .continuous)
                .fill(hovered ? DS.SurfaceFill.rowHover : Color.clear)
        )
        .animation(DS.Motion.hover, value: hovered)
        .onHover { hovered = $0 }
    }

    @ViewBuilder
    private var matchView: some View {
        switch rule.match {
        case .sourceApp(let bundleID):
            let app = apps.first(where: { $0.bundleID == bundleID })
            HStack(spacing: DS.Space.s) {
                AppIconView(app: app, size: 18)
                Text(app?.displayName ?? bundleID)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        case .urlHost(let glob):
            HStack(spacing: DS.Space.s) {
                Image(systemName: "link")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.secondary)
                Text(glob)
                    .font(.system(size: 13, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    @ViewBuilder
    private var targetView: some View {
        let browser = browsers.first(where: { $0.bundleID == rule.target })
        HStack(spacing: DS.Space.s) {
            AppIconView(app: browser, size: 18)
            VStack(alignment: .leading, spacing: 0) {
                Text(browser?.displayName ?? rule.target)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                if let profileLabel {
                    Text(profileLabel)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var profileLabel: String? {
        guard let directory = rule.chromeProfile else { return nil }
        return chromeProfiles.first(where: { $0.directory == directory })?.name ?? directory
    }
}
