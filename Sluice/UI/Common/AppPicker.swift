import SwiftUI
import SluiceCore

struct AppPicker: View {
    @Binding var selection: String?
    let apps: [AppInfo]
    var placeholder: String = "Select an app…"

    @State private var isPresented = false
    @State private var query: String = ""

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: 8) {
                if let app = selectedApp {
                    AppIconView(app: app, size: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(app.displayName)
                        Text(app.bundleID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    AppIconView(app: nil, size: 24)
                    Text(placeholder).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            AppPickerList(
                apps: apps,
                selection: $selection,
                query: $query,
                dismiss: { isPresented = false }
            )
            .frame(width: 320, height: 360)
        }
    }

    private var selectedApp: AppInfo? {
        guard let id = selection else { return nil }
        return apps.first(where: { $0.bundleID == id })
    }
}

private struct AppPickerList: View {
    let apps: [AppInfo]
    @Binding var selection: String?
    @Binding var query: String
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search", text: $query)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            Divider()
            if filtered.isEmpty {
                VStack {
                    Spacer()
                    Text("No apps found").foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(filtered, selection: $selection) { app in
                    Button {
                        selection = app.bundleID
                        dismiss()
                    } label: {
                        AppRow(app: app)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .tag(app.bundleID as String?)
                }
                .listStyle(.plain)
            }
        }
    }

    private var filtered: [AppInfo] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return apps }
        return apps.filter {
            $0.displayName.localizedCaseInsensitiveContains(trimmed)
                || $0.bundleID.localizedCaseInsensitiveContains(trimmed)
        }
    }
}
