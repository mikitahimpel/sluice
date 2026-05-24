import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator: AppCoordinator

    override init() {
        self.coordinator = MainActor.assumeIsolated { AppCoordinator.makeDefault() }
        super.init()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let optionHeld = NSEvent.modifierFlags.contains(.option)
        MainActor.assumeIsolated {
            if optionHeld {
                coordinator.handleWithOverride(urls: urls)
            } else {
                coordinator.handle(urls: urls)
            }
        }
    }
}
