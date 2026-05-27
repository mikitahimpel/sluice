import SwiftUI
import SluiceCore

struct OverridePickerView: View {
    let urls: [URL]
    let browsers: [AppInfo]
    let onPick: (String) -> Void
    let onCancel: () -> Void

    @State private var search: String = ""
    @FocusState private var searchFocused: Bool

    private var filteredBrowsers: [AppInfo] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return browsers }
        return browsers.filter { app in
            app.displayName.range(of: query, options: .caseInsensitive) != nil
                || app.bundleID.range(of: query, options: .caseInsensitive) != nil
        }
    }

    private var headerTitle: String {
        urls.count == 1 ? "Open URL in…" : "Open \(urls.count) URLs in…"
    }

    private var headerSubtitle: String {
        guard let first = urls.first else { return "" }
        let raw = first.host ?? first.absoluteString
        let limit = 56
        if raw.count <= limit { return raw }
        return String(raw.prefix(limit - 1)) + "…"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(headerTitle)
                    .font(.headline)
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            TextField("Filter browsers", text: $search)
                .textFieldStyle(.roundedBorder)
                .focused($searchFocused)
                .onSubmit {
                    // Only commit when the user has typed a filter — pressing
                    // Return with an empty field would otherwise open whichever
                    // browser sorts first, which is a surprise.
                    guard !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          let first = filteredBrowsers.first else { return }
                    onPick(first.bundleID)
                }
                .padding(.horizontal, 14)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if filteredBrowsers.isEmpty {
                        Text("No browsers match")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(filteredBrowsers) { browser in
                            OverridePickerRow(app: browser) {
                                onPick(browser.bundleID)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            HStack {
                Spacer()
                Text("Esc to cancel")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .frame(width: 360, height: 380)
        .onAppear {
            searchFocused = true
        }
    }
}

private struct OverridePickerRow: View {
    let app: AppInfo
    let onPick: () -> Void

    @State private var hovered: Bool = false

    var body: some View {
        Button(action: onPick) {
            AppRow(app: app, iconSize: 18, showBundleID: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 5)
                .padding(.horizontal, 14)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(hovered ? DS.SurfaceFill.rowHover : Color.clear)
                        .padding(.horizontal, 8)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(DS.Motion.hover, value: hovered)
    }
}
