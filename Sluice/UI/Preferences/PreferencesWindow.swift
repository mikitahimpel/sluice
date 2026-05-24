import SwiftUI

struct PreferencesWindow: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        TabView {
            GeneralTab().tabItem { Label("General", systemImage: "gearshape") }
            RulesTab().tabItem { Label("Rules", systemImage: "list.bullet") }
        }
        .frame(width: 620, height: 460)
    }
}
