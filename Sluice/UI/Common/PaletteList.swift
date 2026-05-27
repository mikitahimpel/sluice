import SwiftUI
import SluiceCore

/// Embedded list with a search field at the top, keyboard navigation, and a
/// neutral-accent selection style. Used as the source-app and target-browser
/// picker in the rule editor.
struct PaletteList<Item: Identifiable, Row: View>: View {
    let items: [Item]
    let filter: (Item, String) -> Bool
    @Binding var selection: Item.ID?
    let row: (Item, Bool) -> Row
    var placeholder: String = "Search"
    var emptyTitle: String = "No matches"
    var emptySubtitle: String = "Try a different search."
    var initialFocus: Bool = false
    var height: CGFloat = 240
    var onCommit: ((Item) -> Void)? = nil

    @State private var query: String = ""
    @FocusState private var searchFocused: Bool
    @State private var highlightedID: Item.ID?

    private var filtered: [Item] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        return items.filter { filter($0, trimmed) }
    }

    var body: some View {
        VStack(spacing: 0) {
            PaletteSearchField(
                placeholder: placeholder,
                text: $query,
                focused: $searchFocused,
                onSubmit: {
                    if let id = highlightedID ?? filtered.first?.id,
                       let item = filtered.first(where: { $0.id == id }) {
                        commit(item)
                    }
                }
            )

            Rectangle()
                .fill(DS.Hairline.color)
                .frame(height: DS.Hairline.width)

            if filtered.isEmpty {
                EmptyHint(title: emptyTitle, subtitle: emptySubtitle)
                    .frame(maxWidth: .infinity)
                    .frame(height: height - 40)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            ForEach(filtered) { item in
                                PaletteRow(
                                    isSelected: selection == item.id,
                                    isHighlighted: highlightedID == item.id,
                                    onTap: { commit(item) }
                                ) {
                                    row(item, selection == item.id)
                                }
                                .id(item.id)
                            }
                        }
                        .padding(DS.Space.xs)
                    }
                    .frame(height: height - 40)
                    .onChange(of: highlightedID) { _, id in
                        guard let id else { return }
                        withAnimation(DS.Motion.indicator) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.surface, style: .continuous)
                .fill(DS.SurfaceFill.card)
        )
        .hairline()
        .onAppear {
            if initialFocus { searchFocused = true }
            if highlightedID == nil { highlightedID = selection ?? filtered.first?.id }
        }
        .onChange(of: query) { _, _ in
            highlightedID = filtered.first?.id
        }
        .background(
            KeyHandler(
                onDown: { moveHighlight(by: 1) },
                onUp: { moveHighlight(by: -1) }
            )
        )
    }

    private func commit(_ item: Item) {
        selection = item.id
        onCommit?(item)
    }

    private func moveHighlight(by delta: Int) {
        guard !filtered.isEmpty else { return }
        let ids = filtered.map(\.id)
        if let current = highlightedID, let idx = ids.firstIndex(of: current) {
            let next = (idx + delta).clamped(to: 0...(ids.count - 1))
            highlightedID = ids[next]
        } else {
            highlightedID = ids.first
        }
    }
}

private struct PaletteRow<Content: View>: View {
    let isSelected: Bool
    let isHighlighted: Bool
    let onTap: () -> Void
    @ViewBuilder var content: () -> Content
    @State private var hovered: Bool = false

    var body: some View {
        Button(action: onTap) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
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
        .animation(DS.Motion.hover, value: isHighlighted)
    }

    private var background: Color {
        if isSelected { return DS.SurfaceFill.rowSelected }
        if isHighlighted || hovered { return DS.SurfaceFill.rowHover }
        return .clear
    }
}

private struct EmptyHint: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(spacing: DS.Space.xs) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(DS.Space.l)
    }
}

/// Catches Up/Down arrows for the embedded palette without taking the search
/// field's first responder. Inserted as a transparent background view.
private struct KeyHandler: NSViewRepresentable {
    let onDown: () -> Void
    let onUp: () -> Void

    func makeNSView(context: Context) -> KeyView {
        let v = KeyView()
        v.onDown = onDown
        v.onUp = onUp
        return v
    }

    func updateNSView(_ nsView: KeyView, context: Context) {
        nsView.onDown = onDown
        nsView.onUp = onUp
    }

    final class KeyView: NSView {
        var onDown: (() -> Void)?
        var onUp: (() -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            // Tear down before re-adding. SwiftUI can re-parent the NSView to
            // a new window (sheet → main); the previous branch only removed
            // when `window == nil`, leaking handlers tied to the old window.
            if let m = monitor {
                NSEvent.removeMonitor(m)
                monitor = nil
            }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, let window = self.window, event.window === window else { return event }
                switch event.keyCode {
                case 125: self.onDown?(); return nil
                case 126: self.onUp?(); return nil
                default: return event
                }
            }
        }

        deinit {
            if let m = monitor { NSEvent.removeMonitor(m) }
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
