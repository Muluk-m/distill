import AVFoundation
import Foundation

@MainActor
final class AudioService: ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?

    /// Get the directory for storing recordings
    static var recordingsDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Start recording audio
    func startRecording() throws -> URL {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        try session.setActive(true)

        let fileName = "recording_\(Int(Date().timeIntervalSince1970)).m4a"
        let fileURL = Self.recordingsDirectory.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
        audioRecorder?.record()

        isRecording = true
        recordingDuration = 0

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration += 1
            }
        }

        return fileURL
    }

    /// Stop recording and return the file URL
    func stopRecording() -> URL? {
        let url = audioRecorder?.url
        audioRecorder?.stop()
        audioRecorder = nil

        timer?.invalidate()
        timer = nil
        isRecording = false

        return url
    }

    /// Extract audio from a video file to a WAV suitable for Whisper
    static func extractAudio(from videoURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw AudioError.exportFailed
        }

        // Use a composition to convert to mono 16kHz PCM
        let composition = AVMutableComposition()
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first,
              let compositionTrack = composition.addMutableTrack(
                  withMediaType: .audio,
                  preferredTrackID: kCMPersistentTrackID_Invalid
              ) else {
            throw AudioError.noAudioTrack
        }

        let duration = try await asset.load(.duration)
        try compositionTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: duration),
            of: audioTrack,
            at: .zero
        )

        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw AudioError.exportFailed
        }

        session.outputURL = outputURL.deletingPathExtension().appendingPathExtension("m4a")
        session.outputFileType = .m4a
        await session.export()

        if session.status == .completed, let url = session.outputURL {
            return url
        }

        throw AudioError.exportFailed
    }

    enum AudioError: LocalizedError {
        case exportFailed
        case noAudioTrack

        var errorDescription: String? {
            switch self {
            case .exportFailed: return "音频导出失败"
            case .noAudioTrack: return "文件中没有音频轨道"
            }
        }
    }
}
