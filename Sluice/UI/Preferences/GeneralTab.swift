import SwiftUI
import AppKit
import UniformTypeIdentifiers
import SluiceCore

struct GeneralTab: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var pendingImportURL: URL?
    @State private var backupErrorMessage: String?

    private var browsers: [AppInfo] { coordinator.installedBrowsers }
    private var isSluiceDefault: Bool { coordinator.isSluiceDefault }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(DS.Hairline.color).frame(height: DS.Hairline.width)

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.xxl) {
                    defaultBrowserSection
                    fallbackSection
                    backupSection
                }
                .padding(DS.Space.xl)
            }
        }
        .background(.windowBackground)
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

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("General")
                    .font(.system(size: 15, weight: .semibold))
                Text("System defaults and backup.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, DS.Space.xl)
        .padding(.top, DS.Space.m)
        .padding(.bottom, DS.Space.l)
    }

    // MARK: Sections

    private var defaultBrowserSection: some View {
        Section {
            if isSluiceDefault {
                HStack(spacing: DS.Space.s) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Sluice is your macOS default browser")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, DS.Space.m)
                .padding(.vertical, DS.Space.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.surface, style: .continuous)
                        .fill(Color.green.opacity(0.07))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.surface, style: .continuous)
                        .strokeBorder(Color.green.opacity(0.18), lineWidth: DS.Hairline.width)
                )
            } else {
                // Amber onboarding card — until Sluice is the macOS default,
                // no link-click reaches the rules engine.
                HStack(spacing: DS.Space.m) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.orange)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.orange.opacity(0.12))
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sluice isn't receiving links yet")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Set Sluice as your macOS default browser so it can route links through your rules.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: DS.Space.m)
                    Button {
                        coordinator.defaultBrowserClient.requestBecomeDefault()
                    } label: {
                        Text("Set as default")
                    }
                    .buttonStyle(PrimaryPillButtonStyle())
                }
                .padding(DS.Space.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.surface, style: .continuous)
                        .fill(Color.orange.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.surface, style: .continuous)
                        .strokeBorder(Color.orange.opacity(0.22), lineWidth: DS.Hairline.width)
                )
            }
        } header: {
            sectionHeader(
                "macOS integration",
                note: isSluiceDefault
                    ? "Sluice receives every link click."
                    : "macOS will ask you to confirm."
            )
        }
    }

    private var fallbackSection: some View {
        Section {
            VStack(spacing: 0) {
                ForEach(Array(browsers.enumerated()), id: \.element.bundleID) { index, browser in
                    fallbackRow(browser: browser, isLast: index == browsers.count - 1)
                }
                if !browsers.contains(where: { $0.bundleID == coordinator.ruleSet.defaultBrowser }) {
                    unknownFallbackRow
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.surface, style: .continuous)
                    .fill(DS.SurfaceFill.card)
            )
            .hairline()
        } header: {
            sectionHeader("Fallback browser", note: "Used when no rule matches.")
        }
    }

    private func fallbackRow(browser: AppInfo, isLast: Bool) -> some View {
        let isSelected = coordinator.ruleSet.defaultBrowser == browser.bundleID
        return VStack(spacing: 0) {
            Button {
                setFallback(browser.bundleID)
            } label: {
                HStack(spacing: DS.Space.m) {
                    AppIconView(app: browser, size: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(browser.displayName)
                            .font(.system(size: 13, weight: .medium))
                        Text(browser.bundleID)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .padding(.horizontal, DS.Space.m)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .background(isSelected ? DS.SurfaceFill.rowSelected : Color.clear)
            }
            .buttonStyle(.plain)
            if !isLast {
                Rectangle().fill(DS.Hairline.color).frame(height: DS.Hairline.width)
                    .padding(.leading, DS.Space.m + 22 + DS.Space.m)
            }
        }
    }

    private var unknownFallbackRow: some View {
        HStack(spacing: DS.Space.m) {
            AppIconView(app: nil, size: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(coordinator.ruleSet.defaultBrowser)
                    .font(.system(size: 13, design: .monospaced))
                Text("Not installed on this Mac")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, DS.Space.m)
        .padding(.vertical, 8)
        .background(DS.SurfaceFill.rowSelected)
    }

    private var backupSection: some View {
        Section {
            HStack(spacing: DS.Space.s) {
                Button {
                    presentImportPanel()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 11, weight: .medium))
                        Text("Import…")
                    }
                }
                .buttonStyle(GhostButtonStyle())

                Button {
                    presentExportPanel()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.doc")
                            .font(.system(size: 11, weight: .medium))
                        Text("Export…")
                    }
                }
                .buttonStyle(GhostButtonStyle())

                Spacer()
            }
        } header: {
            sectionHeader(
                "Backup",
                note: "Export to share or back up your rules. Importing replaces all current rules."
            )
        }
    }

    private func sectionHeader(_ title: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionEyebrow(text: title)
            Text(note)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, DS.Space.s)
    }

    // MARK: Actions

    private func setFallback(_ bundleID: String) {
        guard bundleID != coordinator.ruleSet.defaultBrowser else { return }
        var updated = coordinator.ruleSet
        updated.defaultBrowser = bundleID
        coordinator.updateRuleSet(updated)
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

}
