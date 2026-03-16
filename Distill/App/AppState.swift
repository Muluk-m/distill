import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var currentTab: Tab = .home

    enum Tab: Hashable {
        case home
        case history
        case settings
    }

    // MARK: - Services
    let whisperService = WhisperService()
    let llmService = LLMService()
    let audioService = AudioService()
    let urlExtractor = URLExtractor()
}
