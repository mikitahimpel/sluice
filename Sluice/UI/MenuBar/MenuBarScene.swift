import SwiftUI

struct MenuBarScene: Scene {
    @ObservedObject var coordinator: AppCoordinator

    var body: some Scene {
        MenuBarExtra("Sluice", image: "MenuBarIcon") {
            MenuBarContent(coordinator: coordinator)
        }
    }
}
