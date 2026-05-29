import SwiftUI
import SluiceCore

struct RuleEditorSheet: View {
    let initialRule: Rule?
    let apps: [AppInfo]
    let browsers: [AppInfo]
    let chromeProfiles: [ChromeProfile]
    let onSave: (Rule) -> Void
    let onCancel: () -> Void

    @State private var matchKind: MatchKind
    @State private var sourceAppBundleID: String?
    @State private var urlHostGlob: String
    @State private var targetBundleID: String?
    @State private var chromeProfile: String?

    init(
        initialRule: Rule?,
        apps: [AppInfo],
        browsers: [AppInfo],
        chromeProfiles: [ChromeProfile],
        onSave: @escaping (Rule) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialRule = initialRule
        self.apps = apps
        self.browsers = browsers
        self.chromeProfiles = chromeProfiles
        self.onSave = onSave
        self.onCancel = onCancel

        // Seed state synchronously so the view's first frame matches the
        // rule's final shape — otherwise animation-watching modifiers would
        // cascade as `.onAppear` flipped defaults into the rule's values.
        if let rule = initialRule {
            switch rule.match {
            case .sourceApp(let bundleID):
                _matchKind = State(initialValue: .sourceApp)
                _sourceAppBundleID = State(initialValue: bundleID)
                _urlHostGlob = State(initialValue: "")
            case .urlHost(let glob):
                _matchKind = State(initialValue: .urlHost)
                _sourceAppBundleID = State(initialValue: nil)
                _urlHostGlob = State(initialValue: glob)
            }
            _targetBundleID = State(initialValue: rule.target)
            _chromeProfile = State(initialValue: rule.chromeProfile)
        } else {
            _matchKind = State(initialValue: .sourceApp)
            _sourceAppBundleID = State(initialValue: nil)
            _urlHostGlob = State(initialValue: "")
            _targetBundleID = State(initialValue: nil)
            _chromeProfile = State(initialValue: nil)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(DS.Hairline.color).frame(height: DS.Hairline.width)

            HStack(alignment: .top, spacing: DS.Space.xl) {
                whenPane
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                openInPane
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(DS.Space.xl)

            Spacer(minLength: 0)

            Rectangle().fill(DS.Hairline.color).frame(height: DS.Hairline.width)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.windowBackground)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: DS.Space.m) {
            Button(action: onCancel) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(IconButtonStyle())
            .help("Back to rules")
            .keyboardShortcut("[", modifiers: .command)

            VStack(alignment: .leading, spacing: 2) {
                Text(initialRule == nil ? "New Rule" : "Edit Rule")
                    .font(.system(size: 15, weight: .semibold))
                Text(initialRule == nil
                     ? "Send links matching a condition to a specific browser."
                     : "Update the condition or target browser.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, DS.Space.xl)
        .padding(.vertical, DS.Space.l)
    }

    // MARK: When pane

    private var whenPane: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            HStack {
                SectionEyebrow(text: "When")
                Spacer()
            }

            MatchKindTabs(selection: $matchKind)

            ZStack(alignment: .topLeading) {
                switch matchKind {
                case .sourceApp:
                    AppPalette(
                        apps: apps,
                        selection: $sourceAppBundleID,
                        placeholder: "Search source apps",
                        height: 240,
                        initialFocus: false
                    )
                    .transition(.opacity)
                case .urlHost:
                    VStack(alignment: .leading, spacing: DS.Space.m) {
                        InlineTextField(
                            placeholder: "*.figma.com",
                            text: $urlHostGlob,
                            monospaced: true
                        )
                        HStack(spacing: DS.Space.xs) {
                            GlobChip(symbol: "*", description: "any sequence")
                            GlobChip(symbol: "?", description: "one character")
                        }
                        GlobExamplesCard()
                        Spacer(minLength: 0)
                    }
                    .transition(.opacity)
                }
            }
            .frame(height: 240, alignment: .top)
            .animation(DS.Motion.reveal, value: matchKind)
        }
    }

    // MARK: Open-in pane

    private var openInPane: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            HStack {
                SectionEyebrow(text: "Open in")
                Spacer()
            }

            // Palette height is fixed and the Chrome-profile row sits in a
            // reserved-height slot below so only one geometry change happens
            // per state transition — avoids a layout "pop".
            BrowserPalette(
                browsers: browsers,
                selection: $targetBundleID,
                height: 240
            )

            ZStack(alignment: .topLeading) {
                if targetBundleID == chromeBundleID {
                    VStack(alignment: .leading, spacing: DS.Space.s) {
                        SectionEyebrow(text: "Chrome profile")
                        ChromeProfilePicker(selection: $chromeProfile, profiles: chromeProfiles)
                    }
                    .transition(
                        .asymmetric(
                            insertion: .offset(y: 6).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
                }
            }
            .frame(height: 64, alignment: .top)
            .clipped()
        }
        .onChange(of: targetBundleID) { _, newValue in
            if newValue != chromeBundleID {
                chromeProfile = nil
            }
        }
        .animation(DS.Motion.reveal, value: targetBundleID == chromeBundleID)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: DS.Space.s) {
            ValidationHint(text: validationHint)
            Spacer()
            Button("Cancel", role: .cancel) { onCancel() }
                .buttonStyle(GhostButtonStyle())
                .keyboardShortcut(.cancelAction)
            Button {
                save()
            } label: {
                HStack(spacing: 6) {
                    Text("Save Rule")
                    Text("↩")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 0.5)
                        .background(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color.white.opacity(0.18))
                        )
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .buttonStyle(PrimaryPillButtonStyle())
            .keyboardShortcut(.defaultAction)
            .disabled(!isValid)
        }
        .padding(.horizontal, DS.Space.xl)
        .padding(.vertical, DS.Space.m)
    }

    // MARK: Helpers

    private var validationHint: String? {
        if !isValid {
            switch matchKind {
            case .sourceApp:
                if sourceAppBundleID == nil { return "Pick a source app to match." }
            case .urlHost:
                if urlHostGlob.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return "Enter a host pattern."
                }
            }
            if targetBundleID == nil { return "Pick a browser to open with." }
        }
        return nil
    }

    private var isValid: Bool {
        guard let target = targetBundleID, !target.isEmpty else { return false }
        switch matchKind {
        case .sourceApp:
            return (sourceAppBundleID?.isEmpty == false)
        case .urlHost:
            return !urlHostGlob.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func save() {
        guard let target = targetBundleID else { return }
        let match: Match
        switch matchKind {
        case .sourceApp:
            guard let bundleID = sourceAppBundleID, !bundleID.isEmpty else { return }
            match = .sourceApp(bundleID: bundleID)
        case .urlHost:
            let trimmed = urlHostGlob.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            match = .urlHost(glob: trimmed)
        }
        let effectiveProfile = (target == chromeBundleID) ? chromeProfile : nil
        let saved = Rule(
            id: initialRule?.id ?? UUID(),
            enabled: initialRule?.enabled ?? true,
            match: match,
            target: target,
            chromeProfile: effectiveProfile
        )
        onSave(saved)
    }
}

private let chromeBundleID = BundleID.chrome

private enum MatchKind: Hashable {
    case sourceApp
    case urlHost
}

private struct MatchKindTabs: View {
    @Binding var selection: MatchKind
    @Namespace private var underline

    var body: some View {
        HStack(spacing: DS.Space.l) {
            tab(.sourceApp, title: "Source app", systemImage: "app.dashed")
            tab(.urlHost, title: "URL host", systemImage: "link")
            Spacer(minLength: 0)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DS.Hairline.color)
                .frame(height: DS.Hairline.width)
        }
        // Scoped to the tab strip — the sliding underline animates here, the
        // pane below animates on its own `value: matchKind`, so the two never
        // share a transaction.
        .animation(DS.Motion.indicator, value: selection)
    }

    private func tab(_ kind: MatchKind, title: String, systemImage: String) -> some View {
        let selected = selection == kind
        return Button {
            selection = kind
        } label: {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .medium))
                    Text(title)
                        .font(.system(size: 13, weight: selected ? .semibold : .medium))
                }
                .foregroundStyle(selected ? Color.primary : Color.secondary)

                ZStack {
                    if selected {
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(Color.accentColor)
                            .matchedGeometryEffect(id: "whenTabUnderline", in: underline)
                    } else {
                        Color.clear
                    }
                }
                .frame(height: 2)
            }
            // Hit target spans the whole tab (icon, label, underline slot).
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct GlobExamplesCard: View {
    private let examples: [(pattern: String, matches: String)] = [
        ("*.github.com", "any github.com subdomain"),
        ("figma.com",    "exactly figma.com"),
        ("*.slack.com",  "Slack workspace URLs"),
        ("docs.*.com",   "any docs subdomain"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Text("Examples")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(examples, id: \.pattern) { row in
                    HStack(spacing: DS.Space.s) {
                        Text(row.pattern)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.primary)
                            .frame(minWidth: 120, alignment: .leading)
                        Text(row.matches)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(DS.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.surface, style: .continuous)
                .fill(DS.SurfaceFill.card)
        )
        .hairline()
    }
}

private struct GlobChip: View {
    let symbol: String
    let description: String

    var body: some View {
        HStack(spacing: 4) {
            Text(symbol)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(DS.SurfaceFill.card)
                )
            Text(description)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.trailing, DS.Space.s)
    }
}

private struct ValidationHint: View {
    let text: String?
    var body: some View {
        if let text {
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                Text(text)
                    .font(.system(size: 12))
            }
            .foregroundStyle(.tertiary)
            .transition(.opacity)
        }
    }
}
