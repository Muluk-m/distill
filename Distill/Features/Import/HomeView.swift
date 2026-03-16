import SwiftUI
import PhotosUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showFilePicker = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var processingState: ProcessingState = .idle
    @State private var selectedOutputTypes: Set<OutputType> = Set(OutputType.allCases)
    @State private var transcriptionResult: Transcript?
    @State private var distillResult: DistillResult?
    @State private var errorMessage: String?
    @State private var recordingURL: URL?

    enum ProcessingState: Equatable {
        case idle
        case loadingModel
        case transcribing
        case distilling
        case done
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    importSection
                    if processingState != .idle {
                        progressSection
                    }
                    if let distillResult {
                        resultSection(distillResult)
                    }
                    if let errorMessage {
                        errorSection(errorMessage)
                    }
                }
                .padding()
            }
            .navigationTitle("Distill 炼金")
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.audio, .movie, .mpeg4Movie, .mp3, .wav],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    Task { await processFile(url: url) }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("把长内容炼成金")
                .font(.title2)
                .fontWeight(.bold)
            Text("导入音视频，AI 帮你提炼出可直接发布的内容")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Import

    private var importSection: some View {
        VStack(spacing: 12) {
            // File import
            Button {
                showFilePicker = true
            } label: {
                Label("导入音视频文件", systemImage: "doc.badge.plus")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.orange.opacity(0.1))
                    .foregroundStyle(.orange)
                    .cornerRadius(12)
            }
            .disabled(processingState != .idle)

            // Record
            Button {
                toggleRecording()
            } label: {
                Label(
                    appState.audioService.isRecording
                        ? "停止录音 (\(formatDuration(appState.audioService.recordingDuration)))"
                        : "录音",
                    systemImage: appState.audioService.isRecording ? "stop.circle.fill" : "mic.circle"
                )
                .frame(maxWidth: .infinity)
                .padding()
                .background(appState.audioService.isRecording ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                .foregroundStyle(appState.audioService.isRecording ? .red : .blue)
                .cornerRadius(12)
            }
            .disabled(processingState != .idle && !appState.audioService.isRecording)

            // Output type picker
            outputTypePicker
        }
    }

    private var outputTypePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("输出格式")
                .font(.headline)
            FlowLayout(spacing: 8) {
                ForEach(OutputType.allCases, id: \.self) { type in
                    Toggle(isOn: Binding(
                        get: { selectedOutputTypes.contains(type) },
                        set: { isOn in
                            if isOn { selectedOutputTypes.insert(type) }
                            else { selectedOutputTypes.remove(type) }
                        }
                    )) {
                        Text(type.rawValue)
                            .font(.caption)
                    }
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)
                    .tint(selectedOutputTypes.contains(type) ? .orange : .gray)
                }
            }
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)

            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    private var statusText: String {
        switch processingState {
        case .idle: return ""
        case .loadingModel: return "正在加载 Whisper 模型..."
        case .transcribing: return "正在转录音频..."
        case .distilling: return "AI 正在提炼内容..."
        case .done: return "完成！"
        }
    }

    // MARK: - Results

    private func resultSection(_ result: DistillResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(result.outputs) { output in
                OutputCard(output: output)
            }
        }
    }

    private func errorSection(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.red.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Actions

    private func processFile(url: URL) async {
        errorMessage = nil
        distillResult = nil

        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            // Step 1: Load model if needed
            if !appState.whisperService.isModelLoaded {
                processingState = .loadingModel
                try await appState.whisperService.loadModel()
            }

            // Step 2: Transcribe
            processingState = .transcribing
            let audioURL: URL
            if url.pathExtension.lowercased() == "mp4" || url.pathExtension.lowercased() == "mov" {
                audioURL = try await AudioService.extractAudio(from: url)
            } else {
                audioURL = url
            }

            let transcription = try await appState.whisperService.transcribe(audioURL: audioURL)
            transcriptionResult = transcription

            // Step 3: Distill with LLM
            processingState = .distilling
            let config = loadLLMConfig()
            let outputs = try await appState.llmService.distill(
                transcript: transcription.fullText,
                outputTypes: Array(selectedOutputTypes),
                config: config
            )

            distillResult = DistillResult(
                sourceTitle: url.lastPathComponent,
                transcription: transcription,
                outputs: outputs
            )
            processingState = .done

        } catch {
            errorMessage = error.localizedDescription
            processingState = .idle
        }
    }

    private func toggleRecording() {
        if appState.audioService.isRecording {
            if let url = appState.audioService.stopRecording() {
                Task { await processFile(url: url) }
            }
        } else {
            do {
                recordingURL = try appState.audioService.startRecording()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadLLMConfig() -> LLMConfig {
        guard let data = UserDefaults.standard.data(forKey: "llm_config"),
              let config = try? JSONDecoder().decode(LLMConfig.self, from: data) else {
            return .default
        }
        return config
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let m = Int(duration) / 60
        let s = Int(duration) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}
