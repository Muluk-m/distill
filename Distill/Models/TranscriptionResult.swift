import Foundation

struct TranscriptionResult: Identifiable, Codable {
    let id: UUID
    let segments: [Segment]
    let fullText: String
    let duration: TimeInterval
    let createdAt: Date

    struct Segment: Identifiable, Codable {
        let id: UUID
        let text: String
        let start: TimeInterval
        let end: TimeInterval

        var timestamp: String {
            let m = Int(start) / 60
            let s = Int(start) % 60
            return String(format: "%02d:%02d", m, s)
        }
    }

    init(segments: [Segment], duration: TimeInterval) {
        self.id = UUID()
        self.segments = segments
        self.fullText = segments.map(\.text).joined(separator: "")
        self.duration = duration
        self.createdAt = Date()
    }
}
