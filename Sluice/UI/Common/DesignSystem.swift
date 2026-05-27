import SwiftUI

/// Shared design tokens — spacing, radii, hairlines, surface fills, motion.
enum DS {
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    enum Radius {
        static let row: CGFloat = 6
        static let surface: CGFloat = 8
        static let pill: CGFloat = 999
        /// For app-icon-sized containers (≈ 25% of side). Matches the macOS
        /// Big Sur app-icon proportion so brand-mark tiles read as logos.
        static let appIconContainer: CGFloat = 18
    }

    enum Hairline {
        static let width: CGFloat = 0.5
        static var color: Color { Color.primary.opacity(0.10) }
        static var strong: Color { Color.primary.opacity(0.16) }
    }

    enum SurfaceFill {
        static var card: Color { Color.primary.opacity(0.04) }
        static var elevated: Color { Color.primary.opacity(0.06) }
        static var rowHover: Color { Color.primary.opacity(0.06) }
        static var rowSelected: Color { Color.primary.opacity(0.10) }
        static var rowAccent: Color { Color.accentColor.opacity(0.14) }
    }

    enum Motion {
        static var reveal: Animation { .spring(response: 0.32, dampingFraction: 0.88) }
        static var indicator: Animation { .spring(response: 0.26, dampingFraction: 0.86) }
        static var hover: Animation { .easeOut(duration: 0.14) }
        static var focus: Animation { .easeOut(duration: 0.16) }
    }
}

struct Elevation: ViewModifier {
    var level: Int = 1
    func body(content: Content) -> some View {
        switch level {
        case 2:
            content
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                .shadow(color: Color.black.opacity(0.06), radius: 1, x: 0, y: 1)
        default:
            content
                .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
        }
    }
}

extension View {
    func elevated(_ level: Int = 1) -> some View { modifier(Elevation(level: level)) }
}

/// The three-bar Sluice mark, rendered at any size. Shape mirrors the AppIcon
/// and the menu-bar template so all three surfaces share one silhouette.
struct BrandMark: View {
    var size: CGFloat
    var tint: Color = .primary

    var body: some View {
        Canvas { ctx, canvasSize in
            let w = canvasSize.width
            let barW = w * 0.56
            let barH = w * 0.135
            let dx = w * 0.16
            let dy = w * 0.19
            let cx = w / 2
            let cy = w / 2
            let tilt = Angle(degrees: 35)
            for offset in -1...1 {
                let bx = cx + CGFloat(offset) * dx
                let by = cy - CGFloat(offset) * dy
                let rect = CGRect(x: bx - barW / 2, y: by - barH / 2, width: barW, height: barH)
                let path = Path(roundedRect: rect, cornerRadius: barH * 0.18)
                ctx.translateBy(x: bx, y: by)
                ctx.rotate(by: tilt)
                ctx.translateBy(x: -bx, y: -by)
                ctx.fill(path, with: .color(tint))
                ctx.translateBy(x: bx, y: by)
                ctx.rotate(by: -tilt)
                ctx.translateBy(x: -bx, y: -by)
            }
        }
        .frame(width: size, height: size)
    }
}

struct Hairline: ViewModifier {
    let radius: CGFloat
    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(DS.Hairline.color, lineWidth: DS.Hairline.width)
        )
    }
}

extension View {
    func hairline(radius: CGFloat = DS.Radius.surface) -> some View {
        modifier(Hairline(radius: radius))
    }
}

struct SectionEyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(.secondary)
    }
}

struct PrimaryPillButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        PrimaryPillBody(configuration: configuration, isEnabled: isEnabled)
    }

    private struct PrimaryPillBody: View {
        let configuration: ButtonStyle.Configuration
        let isEnabled: Bool
        @State private var hovered: Bool = false

        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, DS.Space.m)
                .padding(.vertical, 6)
                .foregroundStyle(.white)
                .background(
                    Capsule().fill(fillColor)
                )
                .overlay(
                    // Inner top highlight — gives the pill volume without a
                    // heavy gradient.
                    Capsule()
                        .strokeBorder(Color.white.opacity(isEnabled ? 0.18 : 0.0), lineWidth: 0.5)
                        .blendMode(.plusLighter)
                )
                .contentShape(Capsule())
                .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
                .elevated(isEnabled && !configuration.isPressed ? 1 : 0)
                .onHover { hovered = $0 }
                .animation(DS.Motion.hover, value: hovered)
                .animation(DS.Motion.indicator, value: configuration.isPressed)
        }

        private var fillColor: Color {
            guard isEnabled else { return Color.accentColor.opacity(0.40) }
            if configuration.isPressed { return Color.accentColor.opacity(0.88) }
            if hovered { return Color.accentColor.opacity(0.94) }
            return Color.accentColor
        }
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        GhostButtonBody(configuration: configuration)
    }

    private struct GhostButtonBody: View {
        let configuration: ButtonStyle.Configuration
        @State private var hovered = false

        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, DS.Space.m)
                .padding(.vertical, 6)
                .foregroundStyle(.primary)
                .background(
                    Capsule().fill(hovered ? DS.SurfaceFill.rowHover : Color.clear)
                )
                .contentShape(Capsule())
                .onHover { hovered = $0 }
                .opacity(configuration.isPressed ? 0.6 : 1.0)
        }
    }
}

struct IconButtonStyle: ButtonStyle {
    var tint: Color = .secondary

    func makeBody(configuration: Configuration) -> some View {
        IconButtonBody(configuration: configuration, tint: tint)
    }

    private struct IconButtonBody: View {
        let configuration: ButtonStyle.Configuration
        let tint: Color
        @State private var hovered = false

        var body: some View {
            configuration.label
                .font(.system(size: 12, weight: .medium))
                .frame(width: 22, height: 22)
                .foregroundStyle(hovered ? .primary : tint)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.row, style: .continuous)
                        .fill(hovered ? DS.SurfaceFill.rowHover : Color.clear)
                )
                .contentShape(Rectangle())
                .onHover { hovered = $0 }
                .opacity(configuration.isPressed ? 0.6 : 1.0)
        }
    }
}

struct PaletteSearchField: View {
    let placeholder: String
    @Binding var text: String
    @FocusState.Binding var focused: Bool
    var onSubmit: () -> Void = {}

    var body: some View {
        HStack(spacing: DS.Space.s) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($focused)
                .onSubmit(onSubmit)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Space.m)
        .padding(.vertical, 8)
    }
}

struct InlineTextField: View {
    let placeholder: String
    @Binding var text: String
    var monospaced: Bool = false
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(monospaced ? .system(size: 13, design: .monospaced) : .system(size: 13))
            .focused($focused)
            .padding(.horizontal, DS.Space.m)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.surface, style: .continuous)
                    .fill(DS.SurfaceFill.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.surface, style: .continuous)
                    .strokeBorder(
                        focused ? Color.accentColor.opacity(0.55) : DS.Hairline.color,
                        lineWidth: focused ? 1.0 : DS.Hairline.width
                    )
            )
            .overlay(
                // Outer bloom — signals focus without a hard accent border.
                RoundedRectangle(cornerRadius: DS.Radius.surface, style: .continuous)
                    .stroke(Color.accentColor.opacity(focused ? 0.22 : 0.0), lineWidth: 3)
                    .blur(radius: 2)
                    .allowsHitTesting(false)
            )
            .animation(DS.Motion.focus, value: focused)
    }
}
