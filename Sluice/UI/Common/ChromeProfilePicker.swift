import SwiftUI

/// Compact Chrome-profile picker — same visual language as `AppPicker`.
struct ChromeProfilePicker: View {
    @Binding var selection: String?
    let profiles: [ChromeProfile]

    var body: some View {
        if profiles.isEmpty {
            HStack(spacing: DS.Space.s) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                Text("Chrome not installed or no profiles found.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DS.Space.m)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.surface, style: .continuous)
                    .fill(DS.SurfaceFill.card)
            )
            .hairline()
        } else {
            Menu {
                Button("Default profile") { selection = nil }
                Divider()
                ForEach(profiles) { profile in
                    Button(label(for: profile)) { selection = profile.directory }
                }
            } label: {
                HStack(spacing: DS.Space.s) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text(currentLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
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
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }
    }

    private var currentLabel: String {
        guard let directory = selection,
              let profile = profiles.first(where: { $0.directory == directory })
        else { return "Default profile" }
        return label(for: profile)
    }

    private func label(for profile: ChromeProfile) -> String {
        if let userName = profile.userName, !userName.isEmpty {
            return "\(profile.name) — \(userName)"
        }
        return profile.name
    }
}
