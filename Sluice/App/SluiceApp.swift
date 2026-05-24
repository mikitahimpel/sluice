import SwiftUI

@main
struct SluiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarScene(coordinator: appDelegate.coordinator)

        Settings {
            PreferencesWindow()
                .environmentObject(appDelegate.coordinator)
        }
    }
}
