import SwiftUI
import MurmurKit

struct LlmSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                PageHeader("LLM Processor", subtitle: "Cleans up transcripts and runs voice commands like shorten / translate.")

                SettingsCard {
                    SectionHeader("Processor")
                    Picker("Processor", selection: $viewModel.llmProcessor) {
                        ForEach(PlatformCapabilities.availableLlmProcessors, id: \.self) { processor in
                            Text(label(for: processor)).tag(processor)
                        }
                    }
                    .pickerStyle(.menu)

                    processorSpecificFields

                    if viewModel.llmProcessor != .appleLlm {
                        SettingsInput(
                            label: "Model override (empty = provider default)",
                            placeholder: ProviderDefaults.defaultModel(for: viewModel.llmProcessor),
                            text: $viewModel.llmModel
                        )
                    }
                }

                SettingsCard {
                    HStack {
                        Button("Check availability") {
                            Task { await viewModel.checkLlmHealth() }
                        }
                        if let status = viewModel.llmHealthStatus {
                            Text(status)
                                .font(.caption)
                                .foregroundStyle(status == "Available" ? .green : .red)
                        }
                        Spacer()
                    }
                }
            }
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .modifier(LlmSaveOnChange(viewModel: viewModel))
    }

    @ViewBuilder
    private var processorSpecificFields: some View {
        switch viewModel.llmProcessor {
        case .appleLlm, .gemini, .copilot:
            EmptyView()
        case .openAILlm:
            SettingsInput(label: "OpenAI API key", placeholder: "sk-...", text: $viewModel.openAIKey, isSecure: true)
        case .claude:
            SettingsInput(label: "Anthropic API key", placeholder: "sk-ant-...", text: $viewModel.anthropicKey, isSecure: true)
        case .geminiApi:
            SettingsInput(label: "Google AI API key", placeholder: "", text: $viewModel.googleAiKey, isSecure: true)
        case .customOpenAI:
            SettingsInput(label: "API key (optional)", placeholder: "", text: $viewModel.customOpenAIKey, isSecure: true)
            SettingsInput(label: "Base URL", placeholder: "http://localhost:11434/v1", text: $viewModel.customBaseUrl)
            SettingsInput(label: "Display name", placeholder: "Ollama", text: $viewModel.customDisplayName)
            Text("Any OpenAI-compatible endpoint (Ollama, LM Studio, vLLM, Azure OpenAI…).")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func label(for processor: LlmProcessorType) -> String {
        switch processor {
        case .appleLlm: return "Apple Foundation Models (on-device)"
        case .gemini: return "Gemini CLI"
        case .copilot: return "Copilot CLI"
        case .openAILlm: return "OpenAI API"
        case .claude: return "Claude API"
        case .geminiApi: return "Gemini API"
        case .customOpenAI: return "Custom OpenAI-compatible"
        }
    }
}

private struct LlmSaveOnChange: ViewModifier {
    @Bindable var viewModel: SettingsViewModel

    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.llmProcessor)      { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.anthropicKey)      { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.googleAiKey)       { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.customOpenAIKey)   { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.customBaseUrl)     { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.customDisplayName) { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.llmModel)          { _, _ in Task { await viewModel.saveConfig() } }
    }
}
