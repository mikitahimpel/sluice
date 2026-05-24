import SwiftUI

@main
struct SluiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            Text("Sluice preferences — coming soon.")
                .padding()
                .frame(width: 480, height: 320)
        }
    }
}
