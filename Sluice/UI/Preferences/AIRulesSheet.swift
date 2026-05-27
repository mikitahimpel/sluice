import SwiftUI
import AppKit
import SluiceCore

/// Sheet that hands the user a prompt template for any AI chatbot and accepts
/// the JSON the model returns. No outbound network — paste in, paste out.
struct AIRulesSheet: View {
    let apps: [AppInfo]
    let browsers: [AppInfo]
    let currentDefaultBrowser: String
    let onApply: (RuleSet, ApplyMode) -> Void
    let onCancel: () -> Void

    enum ApplyMode { case replace, append }

    @State private var pastedJSON: String = ""
    @State private var parseError: String?
    @State private var parsedRuleSet: RuleSet?
    @State private var promptCopied: Bool = false
    @State private var promptCopiedResetTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(DS.Hairline.color).frame(height: DS.Hairline.width)

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.xl) {
                    promptStep
                    pasteStep
                }
                .padding(DS.Space.xl)
            }

            Rectangle().fill(DS.Hairline.color).frame(height: DS.Hairline.width)
            footer
        }
        .frame(width: 680, height: 620)
        .background(.windowBackground)
        .onChange(of: pastedJSON) { _, _ in revalidate() }
        .onDisappear { promptCopiedResetTask?.cancel() }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    Text("Generate rules with AI")
                        .font(.system(size: 15, weight: .semibold))
                }
                Text("Copy the prompt into any AI chatbot, then paste the JSON it returns.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, DS.Space.xl)
        .padding(.vertical, DS.Space.l)
    }

    // MARK: Step 1 — prompt template

    private var promptStep: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            stepHeader(number: "1", title: "Copy this prompt", accessory: copyButton)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: DS.Radius.surface, style: .continuous)
                    .fill(DS.SurfaceFill.card)
                ScrollView {
                    Text(promptTemplate)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DS.Space.m)
                }
                .frame(height: 220)
            }
            .hairline()
        }
    }

    private var copyButton: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(promptTemplate, forType: .string)
            withAnimation(DS.Motion.hover) { promptCopied = true }
            promptCopiedResetTask?.cancel()
            promptCopiedResetTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(DS.Motion.hover) { promptCopied = false }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: promptCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .semibold))
                Text(promptCopied ? "Copied" : "Copy prompt")
            }
        }
        .buttonStyle(GhostButtonStyle())
    }

    // MARK: Step 2 — paste

    private var pasteStep: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            stepHeader(number: "2", title: "Paste the AI's JSON response", accessory: pasteFromClipboardButton)

            PasteJSONEditor(text: $pastedJSON)
                .frame(height: 160)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.surface, style: .continuous)
                        .fill(DS.SurfaceFill.card)
                )
                .hairline()

            parseStatus
        }
    }

    private var pasteFromClipboardButton: some View {
        Button {
            if let s = NSPasteboard.general.string(forType: .string) {
                pastedJSON = s
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 11, weight: .semibold))
                Text("Paste from clipboard")
            }
        }
        .buttonStyle(GhostButtonStyle())
    }

    @ViewBuilder
    private var parseStatus: some View {
        if let error = parseError {
            statusRow(
                systemImage: "exclamationmark.triangle.fill",
                tint: .red,
                title: "Could not parse",
                detail: error
            )
        } else if let ruleSet = parsedRuleSet {
            statusRow(
                systemImage: "checkmark.circle.fill",
                tint: .green,
                title: "\(ruleSet.rules.count) rule\(ruleSet.rules.count == 1 ? "" : "s") detected",
                detail: "Fallback browser: \(browserDisplayName(ruleSet.defaultBrowser))"
            )
        } else if !pastedJSON.isEmpty {
            statusRow(
                systemImage: "ellipsis.circle",
                tint: .secondary,
                title: "Waiting for valid JSON",
                detail: "Make sure you copied the full response."
            )
        } else {
            // Reserve the space so the layout doesn't jump when status appears.
            Color.clear.frame(height: 38)
        }
    }

    private func statusRow(systemImage: String, tint: Color, title: String, detail: String) -> some View {
        HStack(spacing: DS.Space.s) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, DS.Space.m)
        .padding(.vertical, DS.Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.surface, style: .continuous)
                .fill(tint.opacity(0.08))
        )
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: DS.Space.s) {
            // Replace is destructive — kept on the left in a quiet ghost style
            // so accidental Return can't nuke the user's rules.
            Button(role: .destructive) {
                guard let ruleSet = parsedRuleSet else { return }
                onApply(ruleSet, .replace)
            } label: {
                Text("Replace all")
                    .foregroundStyle(parsedRuleSet == nil ? .secondary : Color.red)
            }
            .buttonStyle(GhostButtonStyle())
            .disabled(parsedRuleSet == nil)

            Spacer()

            Button("Cancel", role: .cancel) { onCancel() }
                .buttonStyle(GhostButtonStyle())
                .keyboardShortcut(.cancelAction)

            Button {
                guard let ruleSet = parsedRuleSet else { return }
                onApply(ruleSet, .append)
            } label: {
                Text("Append rules")
            }
            .buttonStyle(PrimaryPillButtonStyle())
            .keyboardShortcut(.defaultAction)
            .disabled(parsedRuleSet == nil)
        }
        .padding(.horizontal, DS.Space.xl)
        .padding(.vertical, DS.Space.m)
    }

    // MARK: Helpers

    private func stepHeader<Accessory: View>(number: String, title: String, accessory: Accessory) -> some View {
        HStack(spacing: DS.Space.s) {
            Text(number)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .frame(width: 18, height: 18)
                .foregroundStyle(.primary)
                .background(
                    Circle().fill(DS.SurfaceFill.elevated)
                )
                .overlay(Circle().strokeBorder(DS.Hairline.strong, lineWidth: DS.Hairline.width))
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            accessory
        }
    }

    private func browserDisplayName(_ bundleID: String) -> String {
        browsers.first(where: { $0.bundleID == bundleID })?.displayName ?? bundleID
    }

    private func revalidate() {
        let trimmed = pastedJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            parsedRuleSet = nil
            parseError = nil
            return
        }
        do {
            let cleaned = stripCodeFences(trimmed)
            let ruleSet = try AIRulesDecoder.decode(cleaned, fallbackDefault: currentDefaultBrowser)
            parsedRuleSet = ruleSet
            parseError = nil
        } catch let error as AIRulesDecodeError {
            parsedRuleSet = nil
            parseError = error.message
        } catch {
            parsedRuleSet = nil
            parseError = "\(error.localizedDescription)"
        }
    }

    /// Strip ```json … ``` fences models often wrap output in.
    private func stripCodeFences(_ raw: String) -> String {
        var s = raw
        if s.hasPrefix("```") {
            if let firstNewline = s.firstIndex(of: "\n") {
                s = String(s[s.index(after: firstNewline)...])
            }
        }
        if s.hasSuffix("```") {
            s = String(s.dropLast(3))
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Prompt template

    private var promptTemplate: String {
        let browserLines = browsers.prefix(20).map { "  - \($0.bundleID) (\($0.displayName))" }.joined(separator: "\n")
        let appLines = apps
            .filter { !$0.bundleID.hasPrefix("com.apple.") || $0.bundleID == BundleID.safari }
            .prefix(30)
            .map { "  - \($0.bundleID) (\($0.displayName))" }
            .joined(separator: "\n")

        return """
        You are configuring Sluice, a macOS app that routes URLs to different browsers based on rules. Output ONLY valid JSON in this exact shape — no prose, no markdown fences:

        {
          "version": 1,
          "defaultBrowser": "<browser bundleID>",
          "rules": [
            {
              "id": "<UUIDv4>",
              "enabled": true,
              "match": { "type": "sourceApp", "bundleID": "<app bundleID>" },
              "target": "<browser bundleID>"
            },
            {
              "id": "<UUIDv4>",
              "enabled": true,
              "match": { "type": "urlHost", "glob": "*.example.com" },
              "target": "<browser bundleID>"
            }
          ]
        }

        Field rules:
        - "match.type" is either "sourceApp" (requires "bundleID") or "urlHost" (requires "glob", a host glob with * / ? wildcards).
        - "target" is the destination browser's bundleID.
        - "id" must be a valid UUID v4.
        - Use ONLY bundleIDs from the lists below.

        Installed browsers (valid for "target" and "defaultBrowser"):
        \(browserLines)

        Installed apps (valid for "sourceApp" matches):
        \(appLines)

        My desired routing (describe in plain English — replace this line and the AI will produce the JSON):
        WRITE WHAT YOU WANT HERE. For example: send work Slack links to Chrome with my work profile, send Figma links to Arc, everything else to Safari.
        """
    }
}

// MARK: - Parser

enum AIRulesDecodeError: Error {
    case notJSON
    case unsupportedShape
    case invalidVersion(Int)
    case message(String)

    var message: String {
        switch self {
        case .notJSON: return "That doesn't look like JSON."
        case .unsupportedShape: return "JSON doesn't contain a rules array."
        case .invalidVersion(let v): return "Unsupported version \(v). Expected 1."
        case .message(let m): return m
        }
    }
}

/// Tolerant decoder — accepts the canonical full `RuleSet`, a partial
/// `{ "rules": [...] }`, or a bare array of rules.
enum AIRulesDecoder {
    static func decode(_ raw: String, fallbackDefault: String) throws -> RuleSet {
        guard let data = raw.data(using: .utf8) else { throw AIRulesDecodeError.notJSON }
        let decoder = JSONDecoder()

        if let full = try? decoder.decode(RuleSet.self, from: data) {
            guard full.version == 1 else { throw AIRulesDecodeError.invalidVersion(full.version) }
            return full
        }

        // Partial — { "rules": [...] } maybe with "defaultBrowser"
        if let partial = try? decoder.decode(PartialRuleSet.self, from: data) {
            return RuleSet(
                version: 1,
                defaultBrowser: partial.defaultBrowser ?? fallbackDefault,
                rules: partial.rules
            )
        }

        // Bare array of rules
        if let bare = try? decoder.decode([Rule].self, from: data) {
            return RuleSet(version: 1, defaultBrowser: fallbackDefault, rules: bare)
        }

        // Re-run the canonical decode to surface a real error message.
        do {
            _ = try decoder.decode(RuleSet.self, from: data)
        } catch let error as DecodingError {
            throw AIRulesDecodeError.message(humanize(error))
        } catch {
            throw AIRulesDecodeError.unsupportedShape
        }
        throw AIRulesDecodeError.unsupportedShape
    }

    private struct PartialRuleSet: Codable {
        let defaultBrowser: String?
        let rules: [Rule]
    }

    private static func humanize(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, _):
            return "Missing required field: \(key.stringValue)"
        case .typeMismatch(_, let ctx):
            return "Type mismatch at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
        case .valueNotFound(_, let ctx):
            return "Missing value at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
        case .dataCorrupted(let ctx):
            return ctx.debugDescription
        @unknown default:
            return "Could not decode."
        }
    }
}

// MARK: - Paste editor (NSTextView wrapper)

/// Bezel-free monospaced text editor — `TextEditor` doesn't expose font-design
/// cleanly on macOS 14 and renders with a chrome-heavy bezel.
private struct PasteJSONEditor: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder

        let textView = NSTextView()
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.drawsBackground = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.delegate = context.coordinator
        textView.string = text

        scroll.documentView = textView
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tv = nsView.documentView as? NSTextView else { return }
        if tv.string != text { tv.string = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let text: Binding<String>
        init(text: Binding<String>) { self.text = text }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            text.wrappedValue = tv.string
        }
    }
}
