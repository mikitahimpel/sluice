import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator: AppCoordinator

    override init() {
        self.coordinator = MainActor.assumeIsolated { AppCoordinator.makeDefault() }
        super.init()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        MainActor.assumeIsolated {
            coordinator.handle(urls: urls)
        }
    }
}
