import SwiftUI
import SluiceCore

/// Compact app picker that reveals a `PaletteList` in a popover. Use
/// `AppPalette` / `BrowserPalette` directly for the full-height embedded form.
struct AppPicker: View {
    @Binding var selection: String?
    let apps: [AppInfo]
    var placeholder: String = "Select an app…"

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: DS.Space.s) {
                AppIconView(app: selectedApp, size: 18)
                if let app = selectedApp {
                    Text(app.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                } else {
                    Text(placeholder)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: DS.Space.s)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, DS.Space.m)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.surface, style: .continuous)
                    .fill(DS.SurfaceFill.card)
            )
            .hairline()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            AppPalette(
                apps: apps,
                selection: $selection,
                onCommit: { isPresented = false }
            )
            .frame(width: 320, height: 320)
            .padding(DS.Space.s)
        }
    }

    private var selectedApp: AppInfo? {
        guard let id = selection else { return nil }
        return apps.first(where: { $0.bundleID == id })
    }
}

/// Full-bleed embedded app palette — search field + scrollable rows.
struct AppPalette: View {
    let apps: [AppInfo]
    @Binding var selection: String?
    var placeholder: String = "Search apps"
    var height: CGFloat = 240
    var initialFocus: Bool = false
    var onCommit: (() -> Void)? = nil

    var body: some View {
        PaletteList(
            items: apps,
            filter: { app, q in
                app.displayName.localizedCaseInsensitiveContains(q)
                    || app.bundleID.localizedCaseInsensitiveContains(q)
            },
            selection: $selection,
            row: { app, isSelected in
                AppPaletteRow(app: app, isSelected: isSelected)
            },
            placeholder: placeholder,
            emptyTitle: "No apps match",
            emptySubtitle: "Search by display name or bundle ID.",
            initialFocus: initialFocus,
            height: height,
            onCommit: { _ in onCommit?() }
        )
    }
}

struct BrowserPalette: View {
    let browsers: [AppInfo]
    @Binding var selection: String?
    var height: CGFloat = 240
    var initialFocus: Bool = false
    var onCommit: (() -> Void)? = nil

    var body: some View {
        PaletteList(
            items: browsers,
            filter: { app, q in
                app.displayName.localizedCaseInsensitiveContains(q)
                    || app.bundleID.localizedCaseInsensitiveContains(q)
            },
            selection: $selection,
            row: { app, isSelected in
                AppPaletteRow(app: app, isSelected: isSelected)
            },
            placeholder: "Search browsers",
            emptyTitle: "No browsers match",
            emptySubtitle: "Sluice discovers any installed browser.",
            initialFocus: initialFocus,
            height: height,
            onCommit: { _ in onCommit?() }
        )
    }
}

struct AppPaletteRow: View {
    let app: AppInfo
    let isSelected: Bool

    var body: some View {
        HStack(spacing: DS.Space.m) {
            AppIconView(app: app, size: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(app.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                Text(app.bundleID)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: DS.Space.s)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}
