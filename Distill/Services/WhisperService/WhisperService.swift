import Foundation
import WhisperKit

@MainActor
final class WhisperService: ObservableObject {
    @Published var isModelLoaded = false
    @Published var isTranscribing = false
    @Published var progress: Double = 0
    @Published var statusMessage = ""

    private var whisperKit: WhisperKit?

    /// Load the Whisper model (downloads on first use, ~150MB for base)
    func loadModel(modelName: String = "base") async throws {
        statusMessage = "正在加载模型..."
        whisperKit = try await WhisperKit(model: modelName)
        isModelLoaded = true
        statusMessage = "模型已就绪"
    }

    /// Transcribe an audio file at the given URL
    func transcribe(audioURL: URL) async throws -> Transcript {
        guard let whisperKit else {
            throw WhisperError.modelNotLoaded
        }

        isTranscribing = true
        progress = 0
        statusMessage = "正在转录..."

        defer {
            isTranscribing = false
            progress = 1.0
            statusMessage = "转录完成"
        }

        // WhisperKit 0.8.0 API: transcribe(audioPaths:) -> [[TranscriptionResult]?]
        let results = await whisperKit.transcribe(audioPaths: [audioURL.path])

        let segments: [Transcript.Segment] = results
            .compactMap { $0 } // unwrap optionals
            .flatMap { $0 }    // flatten arrays
            .flatMap { result in
                result.segments.map { segment in
                    Transcript.Segment(
                        id: UUID(),
                        text: segment.text,
                        start: TimeInterval(segment.start),
                        end: TimeInterval(segment.end)
                    )
                }
            }

        let duration = segments.last?.end ?? 0
        return Transcript(segments: segments, duration: duration)
    }

    enum WhisperError: LocalizedError {
        case modelNotLoaded

        var errorDescription: String? {
            switch self {
            case .modelNotLoaded: return "Whisper 模型未加载"
            }
        }
    }
}
