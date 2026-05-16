import SwiftUI
import MurmurKit

struct ProviderSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                PageHeader("Speech-to-Text", subtitle: "Choose how Murmur transcribes your audio.")

                SettingsCard {
                    SectionHeader("Provider")
                    Picker("Provider", selection: $viewModel.sttProvider) {
                        Text("Apple Speech (on-device)").tag(SttProviderType.appleStt)
                        Text("ElevenLabs Scribe v2").tag(SttProviderType.elevenLabs)
                        Text("OpenAI Whisper").tag(SttProviderType.openAI)
                        Text("Groq Whisper Turbo").tag(SttProviderType.groq)
                        Text("Custom OpenAI-compatible").tag(SttProviderType.customStt)
                    }
                    .pickerStyle(.menu)

                    providerSpecificFields
                }

                if viewModel.sttProvider != .appleStt {
                    SettingsCard {
                        SectionHeader("Language hint")
                        if viewModel.sttProvider == .elevenLabs {
                            Picker("Language", selection: $viewModel.sttLanguage) {
                                ForEach(ElevenLabsLanguages.all, id: \.id) { lang in
                                    Text(lang.displayName).tag(lang.id)
                                }
                            }
                        } else {
                            Picker("Language", selection: $viewModel.sttLanguage) {
                                Text("Auto-detect").tag("auto")
                                Text("English").tag("en")
                                Text("Chinese").tag("zh")
                                Text("Japanese").tag("ja")
                                Text("Korean").tag("ko")
                                Text("Spanish").tag("es")
                                Text("French").tag("fr")
                                Text("German").tag("de")
                            }
                        }
                        Text("Auto-detect works best for mixed-language speech.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .modifier(ProviderSaveOnChange(viewModel: viewModel))
    }

    @ViewBuilder
    private var providerSpecificFields: some View {
        switch viewModel.sttProvider {
        case .appleStt:
            SettingsInput(label: "Locale", placeholder: "auto", text: $viewModel.appleSttLocale)
            Text("Use \"auto\" for the system locale, or codes like \"en-US\", \"zh-TW\", \"ja-JP\".")
                .font(.caption).foregroundStyle(.secondary)
            Divider().padding(.vertical, Spacing.xs)
            AppleSttModelStatusView(viewModel: viewModel)
        case .elevenLabs:
            SettingsInput(label: "ElevenLabs API key", placeholder: "xi-...", text: $viewModel.elevenLabsKey, isSecure: true)
        case .openAI:
            SettingsInput(label: "OpenAI API key", placeholder: "sk-...", text: $viewModel.openAIKey, isSecure: true)
        case .groq:
            SettingsInput(label: "Groq API key", placeholder: "gsk-...", text: $viewModel.groqKey, isSecure: true)
        case .customStt:
            SettingsInput(label: "API key (optional)", placeholder: "", text: $viewModel.customSttKey, isSecure: true)
            SettingsInput(label: "Base URL", placeholder: "http://localhost:8080", text: $viewModel.customSttBaseUrl)
            SettingsInput(label: "Display name", placeholder: "Custom STT", text: $viewModel.customSttDisplayName)
            SettingsInput(label: "Model", placeholder: "whisper-1", text: $viewModel.customSttModel)
            Text("Any OpenAI-compatible STT endpoint (Whisper.cpp, Faster Whisper, LocalAI…).")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct ProviderSaveOnChange: ViewModifier {
    @Bindable var viewModel: SettingsViewModel

    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.sttProvider)        { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.elevenLabsKey)      { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.openAIKey)          { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.groqKey)            { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.appleSttLocale)     { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.sttLanguage)        { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.customSttKey)       { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.customSttBaseUrl)   { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.customSttDisplayName) { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.customSttModel)     { _, _ in Task { await viewModel.saveConfig() } }
    }
}
