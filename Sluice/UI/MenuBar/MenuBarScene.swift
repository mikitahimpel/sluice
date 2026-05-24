import SwiftUI

struct MenuBarScene: Scene {
    @ObservedObject var coordinator: AppCoordinator

    var body: some Scene {
        MenuBarExtra("Sluice", systemImage: "arrow.triangle.branch") {
            MenuBarContent(coordinator: coordinator)
        }
    }
}
