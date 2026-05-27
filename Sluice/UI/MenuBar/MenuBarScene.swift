import SwiftUI

struct MenuBarScene: Scene {
    // Plain `let` — `MenuBarContent` is the View that observes the coordinator.
    // `@ObservedObject` on `Scene` isn't formally guaranteed by SwiftUI.
    let coordinator: AppCoordinator

    var body: some Scene {
        // Template image; macOS auto-inverts for light/dark menu bars. Source
        // generator: docs/assets/generate_menu_bar_icon.py.
        MenuBarExtra("Sluice", image: "MenuBarIcon") {
            MenuBarContent(coordinator: coordinator)
        }
    }
}
