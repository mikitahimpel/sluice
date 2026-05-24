import SwiftUI
import SluiceCore

struct RuleEditorSheet: View {
    let initialRule: Rule?
    let apps: [AppInfo]
    let browsers: [AppInfo]
    let onSave: (Rule) -> Void
    let onCancel: () -> Void

    @State private var matchKind: MatchKind = .sourceApp
    @State private var sourceAppBundleID: String?
    @State private var urlHostGlob: String = ""
    @State private var targetBundleID: String?
    @State private var chromeProfile: String?
    @State private var chromeProfiles: [ChromeProfile] = []
    @State private var enabled: Bool = true
    @State private var didInit = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(initialRule == nil ? "New Rule" : "Edit Rule")
                .font(.title2)

            Picker("Match", selection: $matchKind) {
                Text("When source app is").tag(MatchKind.sourceApp)
                Text("When URL host matches").tag(MatchKind.urlHost)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Group {
                switch matchKind {
                case .sourceApp:
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Source app").font(.subheadline)
                        AppPicker(selection: $sourceAppBundleID, apps: apps)
                    }
                case .urlHost:
                    VStack(alignment: .leading, spacing: 6) {
                        Text("URL host").font(.subheadline)
                        TextField("e.g. *.figma.com", text: $urlHostGlob)
                            .textFieldStyle(.roundedBorder)
                        Text("* matches any sequence; ? matches one character.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Open in").font(.subheadline)
                BrowserPicker(selection: $targetBundleID, browsers: browsers)

                if targetBundleID == chromeBundleID {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Chrome profile").font(.subheadline)
                        ChromeProfilePicker(selection: $chromeProfile, profiles: chromeProfiles)
                    }
                    .padding(.top, 6)
                }
            }
            .onChange(of: targetBundleID) { newValue in
                if newValue != chromeBundleID {
                    chromeProfile = nil
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 480, height: 420)
        .onAppear(perform: hydrateIfNeeded)
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

    private func hydrateIfNeeded() {
        guard !didInit else { return }
        didInit = true
        if chromeProfiles.isEmpty {
            chromeProfiles = ChromeProfileCatalog().profiles()
        }
        if let rule = initialRule {
            enabled = rule.enabled
            targetBundleID = rule.target
            chromeProfile = rule.chromeProfile
            switch rule.match {
            case .sourceApp(let bundleID):
                matchKind = .sourceApp
                sourceAppBundleID = bundleID
            case .urlHost(let glob):
                matchKind = .urlHost
                urlHostGlob = glob
            }
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
            enabled: initialRule?.enabled ?? enabled,
            match: match,
            target: target,
            chromeProfile: effectiveProfile
        )
        onSave(saved)
    }
}

private let chromeBundleID = "com.google.Chrome"

private enum MatchKind: Hashable {
    case sourceApp
    case urlHost
}
