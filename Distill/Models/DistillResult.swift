import Foundation

struct DistillResult: Identifiable, Codable {
    let id: UUID
    let sourceTitle: String
    let transcription: TranscriptionResult
    let outputs: [ContentOutput]
    let createdAt: Date

    init(sourceTitle: String, transcription: TranscriptionResult, outputs: [ContentOutput]) {
        self.id = UUID()
        self.sourceTitle = sourceTitle
        self.transcription = transcription
        self.outputs = outputs
        self.createdAt = Date()
    }
}

struct ContentOutput: Identifiable, Codable {
    let id: UUID
    let type: OutputType
    let content: String

    init(type: OutputType, content: String) {
        self.id = UUID()
        self.type = type
        self.content = content
    }
}

enum OutputType: String, Codable, CaseIterable {
    case highlights = "金句摘录"
    case xiaohongshu = "小红书笔记"
    case wechat = "公众号草稿"
    case twitter = "推特/即刻"
    case notes = "要点笔记"
}
