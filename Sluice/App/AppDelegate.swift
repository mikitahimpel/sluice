import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // URL routing wires up here in a later task.
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        // Routed in a later task. For now, log so we can see we're being invoked.
        for url in urls {
            NSLog("Sluice received URL: %@", url.absoluteString)
        }
    }
}
