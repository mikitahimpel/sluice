import SwiftUI

struct PreferencesWindow: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var selection: Page = .rules

    enum Page: Hashable, CaseIterable {
        case rules, general

        var title: String {
            switch self {
            case .rules: return "Rules"
            case .general: return "General"
            }
        }

        var icon: String {
            switch self {
            case .rules: return "list.bullet.indent"
            case .general: return "gearshape"
            }
        }
    }

    // Reserved strip above the sidebar so the macOS traffic-light buttons
    // (positioned by the system when `.windowStyle(.hiddenTitleBar)` is set)
    // don't overlap the brand mark.
    private let trafficLightInset: CGFloat = 18

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 200)
            Rectangle()
                .fill(DS.Hairline.color)
                .frame(width: DS.Hairline.width)
            Group {
                switch selection {
                case .rules: RulesTab()
                case .general: GeneralTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 760, idealWidth: 820, minHeight: 520, idealHeight: 560)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: trafficLightInset)

            HStack(alignment: .center, spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Sluice")
                        .font(.system(size: 13, weight: .semibold))
                    Text("URL router")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .padding(.horizontal, DS.Space.m)
            .padding(.bottom, DS.Space.m)

            VStack(alignment: .leading, spacing: 1) {
                ForEach(Page.allCases, id: \.self) { page in
                    SidebarRow(
                        title: page.title,
                        systemImage: page.icon,
                        isSelected: selection == page
                    ) {
                        withAnimation(DS.Motion.hover) { selection = page }
                    }
                }
            }
            .padding(.horizontal, DS.Space.s)

            Spacer()

            HStack {
                Text(appVersionLabel)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.horizontal, DS.Space.m)
            .padding(.bottom, DS.Space.m)
        }
        .frame(maxHeight: .infinity)
        .background(.regularMaterial)
    }

    private var appVersionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        return "v\(version)"
    }
}

private struct SidebarRow: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void
    @State private var hovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Space.s) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(width: 2, height: 14)

                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 16)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                Spacer()
            }
            .padding(.horizontal, DS.Space.s)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.row, style: .continuous)
                    .fill(background)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(DS.Motion.hover, value: hovered)
    }

    private var background: Color {
        if isSelected { return Color.primary.opacity(0.07) }
        if hovered { return Color.primary.opacity(0.04) }
        return .clear
    }
}
