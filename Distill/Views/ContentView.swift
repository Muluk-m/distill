import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Namespace private var tabNamespace

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            Group {
                switch appState.currentTab {
                case .home: HomeView()
                case .history: HistoryView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar
            customTabBar
        }
        .background(Theme.Colors.surface)
        .preferredColorScheme(.dark)
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabItem(tab: .home, icon: "flame", label: "炼金")
            tabItem(tab: .history, icon: "archivebox", label: "历史")
            tabItem(tab: .settings, icon: "slider.horizontal.3", label: "设置")
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(
            Theme.Colors.surface
                .overlay(
                    LinearGradient(
                        colors: [Theme.Colors.surface.opacity(0), Theme.Colors.surface],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .ignoresSafeArea()
        )
    }

    private func tabItem(tab: AppState.Tab, icon: String, label: String) -> some View {
        let isSelected = appState.currentTab == tab

        return Button {
            withAnimation(.snappy(duration: 0.3)) {
                appState.currentTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(Theme.Colors.amber.opacity(0.15))
                            .frame(width: 56, height: 28)
                            .matchedGeometryEffect(id: "tab_pill", in: tabNamespace)
                    }

                    Image(systemName: isSelected ? "\(icon).fill" : icon)
                        .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Theme.Colors.amber : Theme.Colors.textTertiary)
                }
                .frame(height: 28)

                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? Theme.Colors.amber : Theme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
