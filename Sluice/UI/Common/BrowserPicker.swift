import SwiftUI
import SluiceCore

/// Thin wrapper over `AppPicker` so callers can express intent ("browser" vs "any app"),
/// and so future browser-only refinements (e.g. profile picking) stay isolated.
struct BrowserPicker: View {
    @Binding var selection: String?
    let browsers: [AppInfo]
    var placeholder: String = "Select a browser…"

    var body: some View {
        AppPicker(selection: $selection, apps: browsers, placeholder: placeholder)
    }
}
