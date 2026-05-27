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
                        Text("WhisperKit (on-device)").tag(SttProviderType.whisperKit)
                        Text("ElevenLabs Scribe v2").tag(SttProviderType.elevenLabs)
                        Text("OpenAI Whisper").tag(SttProviderType.openAI)
                        Text("Groq Whisper Turbo").tag(SttProviderType.groq)
                        Text("Custom OpenAI-compatible").tag(SttProviderType.customStt)
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("stt-provider-picker")

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
        case .whisperKit:
            Picker("Model", selection: $viewModel.whisperKitModel) {
                ForEach(viewModel.whisperKitModelChoices, id: \.self) { model in
                    Text(model == viewModel.whisperKitRecommendedModel ? "\(model) (recommended)" : model)
                        .tag(model)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("whisperkit-model-picker")
            HStack {
                Button {
                    viewModel.useRecommendedWhisperKitModel()
                } label: {
                    Label("Use Recommended", systemImage: "sparkles")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.whisperKitModel == viewModel.whisperKitRecommendedModel)
                .accessibilityIdentifier("whisperkit-model-use-recommended")

                Button {
                    Task { await viewModel.refreshWhisperKitModelInventory() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("whisperkit-model-catalog-refresh")
            }
            SettingsInput(
                label: "Custom model",
                placeholder: ProviderDefaults.whisperKitSttModel,
                text: $viewModel.whisperKitModel,
                accessibilityIdentifier: "whisperkit-custom-model-field"
            )
            SettingsInput(
                label: "Model repo",
                placeholder: ProviderDefaults.whisperKitModelRepo,
                text: $viewModel.whisperKitModelRepo,
                accessibilityIdentifier: "whisperkit-model-repo-field"
            )
            SettingsInput(
                label: "Model folder (optional)",
                placeholder: "",
                text: $viewModel.whisperKitModelFolder,
                accessibilityIdentifier: "whisperkit-model-folder-field"
            )
            HStack {
                Button {
                    viewModel.chooseWhisperKitModelFolder()
                } label: {
                    Label("Choose Folder", systemImage: "folder")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("whisperkit-model-choose-folder")

                Button {
                    viewModel.clearWhisperKitModelFolder()
                } label: {
                    Label("Use Cache", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.whisperKitModelFolder.isEmpty)
                .accessibilityIdentifier("whisperkit-model-use-cache")
            }
            Toggle("Prewarm model", isOn: $viewModel.whisperKitPrewarm)
                .accessibilityIdentifier("whisperkit-model-prewarm-toggle")

            Divider().padding(.vertical, Spacing.xs)
            SectionHeader("Realtime partials")
            Stepper(value: $viewModel.whisperKitRealtimeIntervalMilliseconds, in: 100...5_000, step: 100) {
                StatusRow("Pass interval", value: viewModel.whisperKitRealtimeIntervalText)
            }
            Stepper(value: $viewModel.whisperKitRealtimeMinimumSamples, in: 1...96_000, step: 1_000) {
                StatusRow("Minimum audio", value: viewModel.whisperKitRealtimeMinimumAudioText)
            }
            Stepper(value: $viewModel.whisperKitRealtimeRequiredSegmentsForConfirmation, in: 0...5) {
                StatusRow("Stable segments", value: viewModel.whisperKitRealtimeStableSegmentsText)
            }
            HStack {
                Button {
                    viewModel.resetWhisperKitRealtimeOptions()
                } label: {
                    Label("Reset Defaults", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }
            Text("Runs native WhisperKit in-process. First use may download and compile Core ML model files.")
                .font(.caption).foregroundStyle(.secondary)
            Divider().padding(.vertical, Spacing.xs)
            WhisperKitModelStatusView(viewModel: viewModel)
            Divider().padding(.vertical, Spacing.xs)
            WhisperKitDiagnosticsView(viewModel: viewModel)
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
            .modifier(ProviderPrimarySaveOnChange(viewModel: viewModel))
            .modifier(WhisperKitSaveOnChange(viewModel: viewModel))
            .modifier(CustomSttSaveOnChange(viewModel: viewModel))
    }
}

private struct ProviderPrimarySaveOnChange: ViewModifier {
    @Bindable var viewModel: SettingsViewModel

    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.sttProvider)        { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.elevenLabsKey)      { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.openAIKey)          { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.groqKey)            { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.appleSttLocale)     { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.sttLanguage)        { _, _ in Task { await viewModel.saveConfig() } }
    }
}

private struct WhisperKitSaveOnChange: ViewModifier {
    @Bindable var viewModel: SettingsViewModel

    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.whisperKitModel)    { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.whisperKitModelRepo) { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.whisperKitModelFolder) { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.whisperKitPrewarm)  { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.whisperKitRealtimeIntervalMilliseconds) { _, _ in
                Task { await viewModel.saveConfig() }
            }
            .onChange(of: viewModel.whisperKitRealtimeMinimumSamples) { _, _ in
                Task { await viewModel.saveConfig() }
            }
            .onChange(of: viewModel.whisperKitRealtimeRequiredSegmentsForConfirmation) { _, _ in
                Task { await viewModel.saveConfig() }
            }
    }
}

private struct CustomSttSaveOnChange: ViewModifier {
    @Bindable var viewModel: SettingsViewModel

    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.customSttKey)       { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.customSttBaseUrl)   { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.customSttDisplayName) { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.customSttModel)     { _, _ in Task { await viewModel.saveConfig() } }
    }
}
