import SwiftUI

struct SettingsView: View {
    @AppStorage("llm_config_data") private var configData: Data = Data()
    @State private var config: LLMConfig = .default

    var body: some View {
        NavigationStack {
            Form {
                Section("AI 服务") {
                    Picker("服务商", selection: $config.provider) {
                        ForEach(LLMConfig.Provider.allCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .onChange(of: config.provider) { _, newValue in
                        config.baseURL = newValue.defaultBaseURL
                        config.model = newValue.defaultModel
                    }

                    SecureField("API Key", text: $config.apiKey)
                        .textContentType(.password)

                    if config.provider == .custom {
                        TextField("Base URL", text: $config.baseURL)
                            .keyboardType(.URL)
                            .autocapitalization(.none)

                        TextField("模型名称", text: $config.model)
                            .autocapitalization(.none)
                    }
                }

                Section("Whisper 模型") {
                    Text("base (推荐)")
                        .foregroundStyle(.secondary)
                    Text("首次使用会自动下载 (~150MB)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("0.1.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Distill 炼金")
                        Spacer()
                        Text("本地优先，隐私安全")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .onAppear { loadConfig() }
            .onChange(of: config.apiKey) { _, _ in saveConfig() }
            .onChange(of: config.provider) { _, _ in saveConfig() }
            .onChange(of: config.baseURL) { _, _ in saveConfig() }
            .onChange(of: config.model) { _, _ in saveConfig() }
        }
    }

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
