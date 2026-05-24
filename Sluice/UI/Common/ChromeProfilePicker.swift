import SwiftUI

struct ChromeProfilePicker: View {
    @Binding var selection: String?
    let profiles: [ChromeProfile]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("", selection: $selection) {
                Text("(none)").tag(String?.none)
                ForEach(profiles) { profile in
                    Text(label(for: profile)).tag(String?.some(profile.directory))
                }
            }
            .labelsHidden()
            .disabled(profiles.isEmpty)

            if profiles.isEmpty {
                Text("Chrome not installed or no profiles found.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func label(for profile: ChromeProfile) -> String {
        if let userName = profile.userName, !userName.isEmpty {
            return "\(profile.name) — \(userName)"
        }
        return profile.name
    }
}
