import Foundation

struct LLMConfig: Codable {
    var provider: Provider
    var apiKey: String
    var baseURL: String
    var model: String

    enum Provider: String, Codable, CaseIterable {
        case deepseek = "DeepSeek"
        case openai = "OpenAI"
        case custom = "自定义"

        var defaultBaseURL: String {
            switch self {
            case .deepseek: return "https://api.deepseek.com"
            case .openai: return "https://api.openai.com"
            case .custom: return ""
            }
        }

        var defaultModel: String {
            switch self {
            case .deepseek: return "deepseek-chat"
            case .openai: return "gpt-4o-mini"
            case .custom: return ""
            }
        }
    }

    static var `default`: LLMConfig {
        LLMConfig(
            provider: .deepseek,
            apiKey: "",
            baseURL: Provider.deepseek.defaultBaseURL,
            model: Provider.deepseek.defaultModel
        )
    }
}
