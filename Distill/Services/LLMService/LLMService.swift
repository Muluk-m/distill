import Foundation

@MainActor
final class LLMService: ObservableObject {
    @Published var isProcessing = false

    func distill(
        transcript: String,
        outputTypes: [OutputType],
        config: LLMConfig
    ) async throws -> [ContentOutput] {
        guard !config.apiKey.isEmpty else {
            throw LLMError.noAPIKey
        }

        isProcessing = true
        defer { isProcessing = false }

        var outputs: [ContentOutput] = []

        for type in outputTypes {
            let prompt = Self.buildPrompt(for: type, transcript: transcript)
            let content = try await callAPI(prompt: prompt, config: config)
            outputs.append(ContentOutput(type: type, content: content))
        }

        return outputs
    }

    // MARK: - API Call

    private func callAPI(prompt: String, config: LLMConfig) async throws -> String {
        let url = URL(string: "\(config.baseURL)/v1/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": config.model,
            "messages": [
                ["role": "system", "content": "你是一个专业的内容提炼助手。用户会给你一段音视频的转录文字，你需要根据要求提炼出精华内容。输出中文。"],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 2000
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw LLMError.apiError(statusCode: statusCode)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String

        guard let content else {
            throw LLMError.emptyResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Prompts

    static func buildPrompt(for type: OutputType, transcript: String) -> String {
        let base = "以下是一段音视频的转录文字：\n\n\(transcript)\n\n"

        switch type {
        case .highlights:
            return base + """
            请从中提取 5-10 条最有价值的金句或核心观点。
            要求：
            - 每条独立成段，前面加序号
            - 保留原话中的精彩表达
            - 如果原文表达不够精炼，可以适当润色但保持原意
            """

        case .xiaohongshu:
            return base + """
            请将内容改写为 1 篇小红书笔记。
            要求：
            - 标题吸引眼球，可以用 emoji
            - 正文 300-500 字，分段清晰
            - 语气亲切自然，像在跟朋友分享
            - 结尾加 3-5 个相关话题标签 #
            """

        case .wechat:
            return base + """
            请将内容整理为 1 篇公众号文章草稿。
            要求：
            - 有吸引力的标题
            - 结构清晰：开头引入、主体分点论述、结尾总结
            - 800-1500 字
            - 专业但不枯燥
            """

        case .twitter:
            return base + """
            请将内容提炼为 5 条适合发推特/即刻的短内容。
            要求：
            - 每条不超过 280 字
            - 独立可读，不依赖上下文
            - 有观点、有信息量
            - 适合社交媒体传播
            """

        case .notes:
            return base + """
            请整理为结构化的学习笔记。
            要求：
            - 用层级列表组织（大纲格式）
            - 提取核心观点、关键数据、重要结论
            - 标注值得深入了解的点
            - 简洁精炼，方便回顾
            """
        }
    }

    // MARK: - Errors

    enum LLMError: LocalizedError {
        case noAPIKey
        case apiError(statusCode: Int)
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "请先在设置中配置 API Key"
            case .apiError(let code): return "API 请求失败 (HTTP \(code))"
            case .emptyResponse: return "API 返回了空内容"
            }
        }
    }
}
