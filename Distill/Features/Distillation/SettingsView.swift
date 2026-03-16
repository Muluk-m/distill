import SwiftUI

struct SettingsView: View {
    @State private var config: LLMConfig = .default

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Spacer().frame(height: Theme.Spacing.xxl)

                    Text("SETTINGS")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .tracking(6)
                        .foregroundStyle(Theme.Colors.amberDim)

                    Text("设置")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                .padding(.horizontal, Theme.Spacing.lg)

                Spacer().frame(height: Theme.Spacing.xl)

                // AI Service Section
                settingsSection(title: "AI 服务") {
                    // Provider picker
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("服务商")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.Colors.textTertiary)

                        HStack(spacing: 6) {
                            ForEach(LLMConfig.Provider.allCases, id: \.self) { provider in
                                let isSelected = config.provider == provider
                                Button {
                                    withAnimation(.snappy(duration: 0.2)) {
                                        config.provider = provider
                                        config.baseURL = provider.defaultBaseURL
                                        config.model = provider.defaultModel
                                    }
                                } label: {
                                    Text(provider.rawValue)
                                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                        .foregroundStyle(isSelected ? Theme.Colors.amber : Theme.Colors.textSecondary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(isSelected ? Theme.Colors.amber.opacity(0.12) : Theme.Colors.surfaceOverlay)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // API Key
                    settingsField(label: "API Key", isSecure: true, text: $config.apiKey)

                    // Custom fields
                    if config.provider == .custom {
                        settingsField(label: "Base URL", text: $config.baseURL)
                        settingsField(label: "模型", text: $config.model)
                    }
                }

                // Whisper Section
                settingsSection(title: "语音识别") {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Whisper Base")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text("首次使用自动下载 (~150MB)")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.Colors.textTertiary)
                        }
                        Spacer()
                        Text("推荐")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.Colors.jade)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.Colors.jade.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }

                // About Section
                settingsSection(title: "关于") {
                    aboutRow(label: "版本", value: "0.1.0")
                    aboutRow(label: "转录引擎", value: "WhisperKit")
                    aboutRow(label: "隐私", value: "音频不离开设备")
                }

                Spacer().frame(height: Theme.Spacing.xxl)

                // Footer
                VStack(spacing: 4) {
                    Text("Distill 炼金")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.Colors.textTertiary)
                    Text("本地优先，隐私安全")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Colors.textTertiary.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 100)
            }
        }
        .background(Theme.Colors.surface)
        .onAppear { loadConfig() }
        .onChange(of: config.apiKey) { _, _ in saveConfig() }
        .onChange(of: config.provider) { _, _ in saveConfig() }
        .onChange(of: config.baseURL) { _, _ in saveConfig() }
        .onChange(of: config.model) { _, _ in saveConfig() }
    }

    // MARK: - Section Builder

    private func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.Colors.textTertiary)
                .tracking(1)
                .padding(.horizontal, Theme.Spacing.lg)

            VStack(spacing: 1) {
                content()
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, Theme.Spacing.lg)
        }
        .padding(.bottom, Theme.Spacing.lg)
    }

    // MARK: - Field

    private func settingsField(label: String, isSecure: Bool = false, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.Colors.textTertiary)

            Group {
                if isSecure {
                    SecureField("", text: text)
                } else {
                    TextField("", text: text)
                }
            }
            .font(.system(size: 14))
            .foregroundStyle(Theme.Colors.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.Colors.surfaceOverlay)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .autocapitalization(.none)
            .autocorrectionDisabled()
        }
    }

    // MARK: - About Row

    private func aboutRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundStyle(Theme.Colors.textTertiary)
        }
    }

    // MARK: - Persistence

    private func loadConfig() {
        if let data = UserDefaults.standard.data(forKey: "llm_config"),
           let saved = try? JSONDecoder().decode(LLMConfig.self, from: data) {
            config = saved
        }
    }

    private func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: "llm_config")
        }
    }
}
