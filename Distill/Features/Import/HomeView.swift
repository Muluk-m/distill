import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var urlInput = ""
    @State private var processingState: ProcessingState = .idle
    @State private var selectedOutputTypes: Set<OutputType> = Set(OutputType.allCases)
    @State private var transcriptionResult: Transcript?
    @State private var distillResult: DistillResult?
    @State private var errorMessage: String?
    @State private var recordingURL: URL?
    @FocusState private var isURLFieldFocused: Bool

    enum ProcessingState: Equatable {
        case idle
        case extracting
        case loadingModel
        case transcribing
        case distilling
        case done
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    urlInputSection
                    outputTypePicker
                    if processingState != .idle && processingState != .done {
                        progressSection
                    }
                    if let distillResult {
                        resultSection(distillResult)
                    }
                    if let errorMessage {
                        errorSection(errorMessage)
                    }
                    recordSection
                }
                .padding()
            }
            .navigationTitle("Distill 炼金")
            .onAppear { checkClipboard() }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 6) {
            Text("把长内容炼成金")
                .font(.title2)
                .fontWeight(.bold)
            Text("粘贴链接，AI 帮你提炼出可直接发布的内容")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - URL Input

    private var urlInputSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                TextField("粘贴 B站/YouTube/小宇宙/播客链接", text: $urlInput)
                    .textFieldStyle(.plain)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($isURLFieldFocused)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                Button {
                    if let str = UIPasteboard.general.string, !str.isEmpty {
                        urlInput = str
                    }
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.title3)
                        .foregroundStyle(.orange)
                        .frame(width: 44, height: 44)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                }
            }

            Button {
                isURLFieldFocused = false
                Task { await processURL() }
            } label: {
                HStack {
                    if processingState != .idle && processingState != .done {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    }
                    Text(startButtonText)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canStart ? Color.orange : Color.gray.opacity(0.3))
                .foregroundStyle(canStart ? .white : .gray)
                .cornerRadius(14)
            }
            .disabled(!canStart)

            // Supported platforms hint
            HStack(spacing: 16) {
                ForEach(["B站", "YouTube", "小宇宙", "播客RSS", "直链"], id: \.self) { name in
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var canStart: Bool {
        !urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (processingState == .idle || processingState == .done)
    }

    private var startButtonText: String {
        switch processingState {
        case .idle, .done: return "开始炼金"
        case .extracting: return "正在解析链接..."
        case .loadingModel: return "加载 Whisper 模型..."
        case .transcribing: return "正在转录..."
        case .distilling: return "AI 正在提炼..."
        }
    }

    // MARK: - Output Type Picker

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
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.large)
            Text(appState.urlExtractor.statusMessage.isEmpty
                 ? startButtonText
                 : appState.urlExtractor.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    // MARK: - Results

    private func resultSection(_ result: DistillResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(result.sourceTitle)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                Button {
                    resetState()
                } label: {
                    Label("新任务", systemImage: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }

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
            Spacer()
            Button("重试") {
                errorMessage = nil
                Task { await processURL() }
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .tint(.orange)
        }
        .padding()
        .background(.red.opacity(0.08))
        .cornerRadius(12)
    }

    // MARK: - Record (secondary)

    private var recordSection: some View {
        VStack(spacing: 8) {
            Divider().padding(.vertical, 4)
            Text("或者现场录音")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button {
                toggleRecording()
            } label: {
                Label(
                    appState.audioService.isRecording
                        ? "停止录音 (\(formatDuration(appState.audioService.recordingDuration)))"
                        : "开始录音",
                    systemImage: appState.audioService.isRecording ? "stop.circle.fill" : "mic.circle"
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(appState.audioService.isRecording ? Color.red.opacity(0.1) : Color(.systemGray6))
                .foregroundStyle(appState.audioService.isRecording ? .red : .secondary)
                .cornerRadius(12)
            }
            .disabled(processingState != .idle && processingState != .done && !appState.audioService.isRecording)
        }
    }

    // MARK: - Actions

    private func processURL() async {
        errorMessage = nil
        distillResult = nil

        let input = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        do {
            // Step 1: Extract audio from URL
            processingState = .extracting
            let (audioURL, title) = try await appState.urlExtractor.extractAudio(from: input)

            // Step 2: Load Whisper model if needed
            if !appState.whisperService.isModelLoaded {
                processingState = .loadingModel
                try await appState.whisperService.loadModel()
            }

            // Step 3: Transcribe
            processingState = .transcribing
            let transcription = try await appState.whisperService.transcribe(audioURL: audioURL)
            transcriptionResult = transcription

            // Step 4: Distill with LLM
            processingState = .distilling
            let config = loadLLMConfig()
            let outputs = try await appState.llmService.distill(
                transcript: transcription.fullText,
                outputTypes: Array(selectedOutputTypes),
                config: config
            )

            distillResult = DistillResult(
                sourceTitle: title,
                transcription: transcription,
                outputs: outputs
            )
            processingState = .done

            // Clean up temp audio file
            try? FileManager.default.removeItem(at: audioURL)

        } catch {
            errorMessage = error.localizedDescription
            processingState = .idle
        }
    }

    private func processAudioFile(url: URL) async {
        errorMessage = nil
        distillResult = nil

        do {
            if !appState.whisperService.isModelLoaded {
                processingState = .loadingModel
                try await appState.whisperService.loadModel()
            }

            processingState = .transcribing
            let transcription = try await appState.whisperService.transcribe(audioURL: url)
            transcriptionResult = transcription

            processingState = .distilling
            let config = loadLLMConfig()
            let outputs = try await appState.llmService.distill(
                transcript: transcription.fullText,
                outputTypes: Array(selectedOutputTypes),
                config: config
            )

            distillResult = DistillResult(
                sourceTitle: "录音",
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
                Task { await processAudioFile(url: url) }
            }
        } else {
            do {
                recordingURL = try appState.audioService.startRecording()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func checkClipboard() {
        if let str = UIPasteboard.general.string,
           str.hasPrefix("http"),
           urlInput.isEmpty {
            // Don't auto-fill, just leave it — user can tap paste button
        }
    }

    private func resetState() {
        processingState = .idle
        distillResult = nil
        transcriptionResult = nil
        errorMessage = nil
        urlInput = ""
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
