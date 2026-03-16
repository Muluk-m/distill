import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.currentTab) {
            HomeView()
                .tabItem {
                    Label("炼金", systemImage: "wand.and.stars")
                }
                .tag(AppState.Tab.home)

            HistoryView()
                .tabItem {
                    Label("历史", systemImage: "clock.arrow.circlepath")
                }
                .tag(AppState.Tab.history)

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
                .tag(AppState.Tab.settings)
        }
        .tint(.orange)
    }
}
