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
    @State private var showingRecorder = false
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
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                if distillResult == nil {
                    idleContent
                } else if let result = distillResult {
                    resultContent(result)
                }
            }
            .padding(.bottom, 100) // Tab bar clearance
        }
        .background(Theme.Colors.surface)
        .onTapGesture { isURLFieldFocused = false }
    }

    // MARK: - Idle State (Input)

    private var idleContent: some View {
        VStack(spacing: 0) {
            // Hero area
            VStack(spacing: Theme.Spacing.sm) {
                Spacer().frame(height: Theme.Spacing.xxl)

                // Brand mark
                Text("DISTILL")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(6)
                    .foregroundStyle(Theme.Colors.amberDim)

                // Main title
                Text("把长内容\n炼成金")
                    .font(.system(size: 42, weight: .ultraLight))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Spacer().frame(height: Theme.Spacing.xl)
            }

            // URL Input
            urlInputArea
                .padding(.horizontal, Theme.Spacing.lg)

            Spacer().frame(height: Theme.Spacing.xl)

            // Output format selector
            outputSelector
                .padding(.horizontal, Theme.Spacing.lg)

            Spacer().frame(height: Theme.Spacing.xl)

            // Processing state
            if processingState != .idle && processingState != .done {
                processingView
                    .padding(.horizontal, Theme.Spacing.lg)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // Error
            if let errorMessage {
                errorView(errorMessage)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .transition(.opacity)
            }

            Spacer().frame(height: Theme.Spacing.lg)

            // Secondary: Record
            recordButton
                .padding(.horizontal, Theme.Spacing.lg)
        }
    }

    // MARK: - URL Input

    private var urlInputArea: some View {
        VStack(spacing: 12) {
            // Input field
            HStack(spacing: 0) {
                TextField("", text: $urlInput, prompt:
                    Text("粘贴链接")
                        .foregroundStyle(Theme.Colors.textTertiary)
                )
                .font(.system(size: 16))
                .foregroundStyle(Theme.Colors.textPrimary)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .focused($isURLFieldFocused)
                .padding(.leading, 16)
                .padding(.vertical, 16)

                // Paste shortcut
                Button {
                    if let str = UIPasteboard.general.string, !str.isEmpty {
                        withAnimation(.snappy(duration: 0.2)) { urlInput = str }
                    }
                } label: {
                    Text("粘贴")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.Colors.amber)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.Colors.amber.opacity(0.1))
                        .clipShape(Capsule())
                }
                .padding(.trailing, 8)
            }
            .background(Theme.Colors.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        isURLFieldFocused ? Theme.Colors.amber.opacity(0.4) : Theme.Colors.surfaceOverlay,
                        lineWidth: 1
                    )
            )

            // Platform chips
            HStack(spacing: 6) {
                ForEach(["B站", "YouTube", "小宇宙", "播客", "直链"], id: \.self) { name in
                    Text(name)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.Colors.surfaceRaised)
                        .clipShape(Capsule())
                }
            }

            // Start button
            Button {
                isURLFieldFocused = false
                Task { await processURL() }
            } label: {
                ZStack {
                    if isProcessing {
                        HStack(spacing: 10) {
                            DistillSpinner()
                            Text(statusText)
                                .font(.system(size: 15, weight: .medium))
                        }
                    } else {
                        Text("开始炼金")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundStyle(canStart ? Theme.Colors.surface : Theme.Colors.textTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    canStart
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [Theme.Colors.amber, Theme.Colors.amberLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                        : AnyShapeStyle(Theme.Colors.surfaceOverlay)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canStart)
        }
    }

    // MARK: - Output Selector

    private var outputSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("输出")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.Colors.textTertiary)
                .tracking(2)

            HStack(spacing: 6) {
                ForEach(OutputType.allCases, id: \.self) { type in
                    let isSelected = selectedOutputTypes.contains(type)
                    let accent = Theme.Colors.outputAccent(for: type)

                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            if isSelected { selectedOutputTypes.remove(type) }
                            else { selectedOutputTypes.insert(type) }
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: type.icon)
                                .font(.system(size: 16))
                            Text(type.shortLabel)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(isSelected ? accent : Theme.Colors.textTertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(isSelected ? accent.opacity(0.1) : Theme.Colors.surfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(isSelected ? accent.opacity(0.3) : .clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Processing

    private var processingView: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Animated drops
            DistillAnimation(step: processingStep)
                .frame(height: 80)

            Text(statusText)
                .font(.system(size: 14))
                .foregroundStyle(Theme.Colors.textSecondary)

            // Step indicator
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(i <= processingStep
                              ? Theme.Colors.amber
                              : Theme.Colors.surfaceOverlay)
                        .frame(width: i == processingStep ? 24 : 8, height: 3)
                        .animation(.snappy, value: processingStep)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.lg)
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Theme.Colors.ruby.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "exclamationmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.Colors.ruby)
                )

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(2)

            Spacer()

            Button("重试") {
                errorMessage = nil
                Task { await processURL() }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.Colors.amber)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.ruby.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Record

    private var recordButton: some View {
        Button {
            toggleRecording()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: appState.audioService.isRecording ? "stop.fill" : "mic")
                    .font(.system(size: 12))
                    .foregroundStyle(appState.audioService.isRecording ? Theme.Colors.ruby : Theme.Colors.textTertiary)

                Text(appState.audioService.isRecording
                     ? "停止 \(formatDuration(appState.audioService.recordingDuration))"
                     : "或者，现场录音")
                    .font(.system(size: 13))
                    .foregroundStyle(appState.audioService.isRecording ? Theme.Colors.ruby : Theme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(appState.audioService.isRecording ? Theme.Colors.ruby.opacity(0.08) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        appState.audioService.isRecording ? Theme.Colors.ruby.opacity(0.3) : Theme.Colors.surfaceOverlay,
                        lineWidth: 1,
                        antialiased: true
                    )
                    .opacity(appState.audioService.isRecording ? 1 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isProcessing && !appState.audioService.isRecording)
    }

    // MARK: - Result Content

    private func resultContent(_ result: DistillResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Result header
            VStack(alignment: .leading, spacing: 6) {
                Spacer().frame(height: Theme.Spacing.xxl)

                Button {
                    withAnimation(.snappy(duration: 0.35)) { resetState() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("新任务")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Theme.Colors.amber)
                }
                .buttonStyle(.plain)

                Spacer().frame(height: Theme.Spacing.md)

                Text(result.sourceTitle)
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(3)

                Text("\(result.outputs.count) 条内容已生成")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .padding(.top, 2)
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Spacer().frame(height: Theme.Spacing.xl)

            // Output cards
            ForEach(result.outputs) { output in
                OutputCard(output: output)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.md)
            }
        }
    }

    // MARK: - Computed

    private var canStart: Bool {
        !urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isProcessing
    }

    private var isProcessing: Bool {
        processingState != .idle && processingState != .done
    }

    private var processingStep: Int {
        switch processingState {
        case .idle, .done: return -1
        case .extracting: return 0
        case .loadingModel: return 1
        case .transcribing: return 2
        case .distilling: return 3
        }
    }

    private var statusText: String {
        switch processingState {
        case .idle, .done: return ""
        case .extracting: return "解析链接"
        case .loadingModel: return "加载模型"
        case .transcribing: return "转录中"
        case .distilling: return "提炼中"
        }
    }

    // MARK: - Actions

    private func processURL() async {
        errorMessage = nil
        distillResult = nil
        let input = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        do {
            withAnimation(.snappy) { processingState = .extracting }
            let (audioURL, title) = try await appState.urlExtractor.extractAudio(from: input)

            if !appState.whisperService.isModelLoaded {
                withAnimation(.snappy) { processingState = .loadingModel }
                try await appState.whisperService.loadModel()
            }

            withAnimation(.snappy) { processingState = .transcribing }
            let transcription = try await appState.whisperService.transcribe(audioURL: audioURL)
            transcriptionResult = transcription

            withAnimation(.snappy) { processingState = .distilling }
            let config = loadLLMConfig()
            let outputs = try await appState.llmService.distill(
                transcript: transcription.fullText,
                outputTypes: Array(selectedOutputTypes),
                config: config
            )

            withAnimation(.snappy(duration: 0.4)) {
                distillResult = DistillResult(
                    sourceTitle: title,
                    transcription: transcription,
                    outputs: outputs
                )
                processingState = .done
            }

            try? FileManager.default.removeItem(at: audioURL)
        } catch {
            withAnimation(.snappy) {
                errorMessage = error.localizedDescription
                processingState = .idle
            }
        }
    }

    private func processAudioFile(url: URL) async {
        errorMessage = nil
        distillResult = nil

        do {
            if !appState.whisperService.isModelLoaded {
                withAnimation(.snappy) { processingState = .loadingModel }
                try await appState.whisperService.loadModel()
            }

            withAnimation(.snappy) { processingState = .transcribing }
            let transcription = try await appState.whisperService.transcribe(audioURL: url)
            transcriptionResult = transcription

            withAnimation(.snappy) { processingState = .distilling }
            let config = loadLLMConfig()
            let outputs = try await appState.llmService.distill(
                transcript: transcription.fullText,
                outputTypes: Array(selectedOutputTypes),
                config: config
            )

            withAnimation(.snappy(duration: 0.4)) {
                distillResult = DistillResult(
                    sourceTitle: "录音",
                    transcription: transcription,
                    outputs: outputs
                )
                processingState = .done
            }
        } catch {
            withAnimation(.snappy) {
                errorMessage = error.localizedDescription
                processingState = .idle
            }
        }
    }

    private func toggleRecording() {
        if appState.audioService.isRecording {
            if let url = appState.audioService.stopRecording() {
                Task { await processAudioFile(url: url) }
            }
        } else {
            do { recordingURL = try appState.audioService.startRecording() }
            catch { errorMessage = error.localizedDescription }
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
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Distill Spinner (small, for button)

struct DistillSpinner: View {
    @State private var rotation: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(Theme.Colors.surface.opacity(0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: 16, height: 16)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Distill Animation (processing state)

struct DistillAnimation: View {
    let step: Int
    @State private var dropOffset: CGFloat = 0
    @State private var ripple: CGFloat = 0

    var body: some View {
        ZStack {
            // Funnel shape
            Path { path in
                path.move(to: CGPoint(x: 30, y: 0))
                path.addLine(to: CGPoint(x: 50, y: 40))
                path.addLine(to: CGPoint(x: 50, y: 60))
                path.addLine(to: CGPoint(x: 30, y: 60))
                path.addLine(to: CGPoint(x: 30, y: 40))
                path.closeSubpath()
            }
            .stroke(Theme.Colors.amberDim, lineWidth: 1.5)
            .frame(width: 80, height: 60)

            // Animated drop
            Circle()
                .fill(Theme.Colors.amber)
                .frame(width: 6, height: 6)
                .offset(y: dropOffset - 20)
                .opacity(dropOffset < 30 ? 1 : 0)

            // Collection pool
            Ellipse()
                .fill(Theme.Colors.amber.opacity(0.2 + ripple * 0.2))
                .frame(width: 40 + ripple * 10, height: 8 + ripple * 2)
                .offset(y: 35)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 1.2).repeatForever(autoreverses: false)) {
                dropOffset = 50
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                ripple = 1
            }
        }
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
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
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
