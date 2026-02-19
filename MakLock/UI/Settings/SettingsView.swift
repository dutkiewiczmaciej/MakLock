import SwiftUI

/// Root settings view with tabbed navigation.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            AppsSettingsView()
                .tabItem {
                    Label("Apps", systemImage: "square.grid.2x2")
                }

            SecuritySettingsView()
                .tabItem {
                    Label("Security", systemImage: "lock.shield")
                }

            WatchSettingsView()
                .tabItem {
                    Label("Watch", systemImage: "applewatch")
                }
        }
        .frame(width: 520, height: 400)
    }
}
