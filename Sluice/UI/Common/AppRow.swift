import SwiftUI
import SluiceCore

struct AppRow: View {
    let app: AppInfo
    var iconSize: CGFloat = 16
    var showBundleID: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            AppIconView(app: app, size: iconSize)
            VStack(alignment: .leading, spacing: 1) {
                Text(app.displayName)
                if showBundleID {
                    Text(app.bundleID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct AppIconView: View {
    let app: AppInfo?
    let size: CGFloat

    var body: some View {
        if let app, let image = nonEmptyIcon(for: app) {
            Image(nsImage: image)
                .resizable()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "questionmark.app.dashed")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(.secondary)
        }
    }

    private func nonEmptyIcon(for app: AppInfo) -> NSImage? {
        let image = app.icon()
        return image.size.width > 0 && image.size.height > 0 ? image : nil
    }
}
