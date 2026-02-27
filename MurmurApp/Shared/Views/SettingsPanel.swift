import SwiftUI
import MurmurKit

/// Settings window content with tabbed sections.
struct SettingsPanel: View {
    @State var viewModel: SettingsViewModel

    var body: some View {
        TabView {
            GeneralTab(viewModel: viewModel)
                .tabItem { Label("General", systemImage: "gear") }

            ProvidersTab(viewModel: viewModel)
                .tabItem { Label("Providers", systemImage: "cloud") }

            DictionaryTab(viewModel: viewModel)
                .tabItem { Label("Dictionary", systemImage: "textformat") }

            AppearanceTab(viewModel: viewModel)
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
        }
        .frame(width: 580, height: 480)
        .task { await viewModel.loadConfig() }
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Output") {
                Picker("Output Mode", selection: $viewModel.outputMode) {
                    Text("Clipboard").tag(OutputMode.clipboard)
                    Text("Keyboard").tag(OutputMode.keyboard)
                    Text("Both").tag(OutputMode.both)
                }

                Text("Clipboard copies text. Keyboard types it at cursor position.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Hotkey") {
                TextField("Hotkey", text: $viewModel.hotkey)
                    .textFieldStyle(.roundedBorder)

                Text("Default: Ctrl+` — toggles recording.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Apple STT Locale") {
                TextField("Locale (or \"auto\")", text: $viewModel.appleSttLocale)
                    .textFieldStyle(.roundedBorder)

                Text("Use \"auto\" for system default, or a locale like \"en-US\", \"ja-JP\".")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = viewModel.saveError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .onChange(of: viewModel.outputMode) { _, _ in Task { await viewModel.saveConfig() } }
        .onChange(of: viewModel.hotkey) { _, _ in Task { await viewModel.saveConfig() } }
        .onChange(of: viewModel.appleSttLocale) { _, _ in Task { await viewModel.saveConfig() } }
    }
}

// MARK: - Providers Tab

private struct ProvidersTab: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            sttSection
            llmSection
            if let error = viewModel.saveError {
                Text(error).foregroundStyle(.red).font(.caption)
            }
        }
        .formStyle(.grouped)
        .modifier(SttSaveOnChange(viewModel: viewModel))
        .modifier(LlmSaveOnChange(viewModel: viewModel))
    }

    @ViewBuilder
    private var sttSection: some View {
        Section("Speech-to-Text") {
            Picker("STT Provider", selection: $viewModel.sttProvider) {
                Text("Apple (on-device)").tag(SttProviderType.appleStt)
                Text("ElevenLabs").tag(SttProviderType.elevenLabs)
                Text("OpenAI Whisper").tag(SttProviderType.openAI)
                Text("Groq").tag(SttProviderType.groq)
                Text("Custom (OpenAI-compat)").tag(SttProviderType.customStt)
            }

            if viewModel.sttProvider == .elevenLabs {
                SecureField("ElevenLabs API Key", text: $viewModel.elevenLabsKey)
                    .textFieldStyle(.roundedBorder)
            }
            if viewModel.sttProvider == .openAI {
                SecureField("OpenAI API Key", text: $viewModel.openAIKey)
                    .textFieldStyle(.roundedBorder)
            }
            if viewModel.sttProvider == .groq {
                SecureField("Groq API Key", text: $viewModel.groqKey)
                    .textFieldStyle(.roundedBorder)
            }
            if viewModel.sttProvider == .customStt {
                SecureField("API Key (optional)", text: $viewModel.customSttKey)
                    .textFieldStyle(.roundedBorder)
                TextField("Base URL", text: $viewModel.customSttBaseUrl)
                    .textFieldStyle(.roundedBorder)
                TextField("Display Name", text: $viewModel.customSttDisplayName)
                    .textFieldStyle(.roundedBorder)
                TextField("Model", text: $viewModel.customSttModel)
                    .textFieldStyle(.roundedBorder)
                Text("OpenAI-compatible STT endpoint (Whisper.cpp, Faster Whisper, etc.)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if viewModel.sttProvider != .appleStt {
                if viewModel.sttProvider == .elevenLabs {
                    Picker("STT Language", selection: $viewModel.sttLanguage) {
                        ForEach(ElevenLabsLanguages.all, id: \.id) { lang in
                            Text(lang.displayName).tag(lang.id)
                        }
                    }
                } else {
                    Picker("STT Language", selection: $viewModel.sttLanguage) {
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

                Text("For mixed-language speech, 'Auto-detect' works best with cloud providers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var llmSection: some View {
        Section("LLM Processor") {
            Picker("LLM Processor", selection: $viewModel.llmProcessor) {
                Text("Apple (on-device)").tag(LlmProcessorType.appleLlm)
                Text("Gemini CLI").tag(LlmProcessorType.gemini)
                Text("Copilot CLI").tag(LlmProcessorType.copilot)
                Text("OpenAI API").tag(LlmProcessorType.openAILlm)
                Text("Claude API").tag(LlmProcessorType.claude)
                Text("Gemini API").tag(LlmProcessorType.geminiApi)
                Text("Custom (OpenAI-compat)").tag(LlmProcessorType.customOpenAI)
            }

            llmApiKeyFields
            llmModelOverride
            llmHealthCheck
        }
    }

    @ViewBuilder
    private var llmApiKeyFields: some View {
        if viewModel.llmProcessor == .openAILlm {
            SecureField("OpenAI API Key", text: $viewModel.openAIKey)
                .textFieldStyle(.roundedBorder)
        }
        if viewModel.llmProcessor == .claude {
            SecureField("Anthropic API Key", text: $viewModel.anthropicKey)
                .textFieldStyle(.roundedBorder)
        }
        if viewModel.llmProcessor == .geminiApi {
            SecureField("Google AI API Key", text: $viewModel.googleAiKey)
                .textFieldStyle(.roundedBorder)
        }
        if viewModel.llmProcessor == .customOpenAI {
            SecureField("API Key (optional)", text: $viewModel.customOpenAIKey)
                .textFieldStyle(.roundedBorder)
            TextField("Base URL", text: $viewModel.customBaseUrl)
                .textFieldStyle(.roundedBorder)
            TextField("Display Name", text: $viewModel.customDisplayName)
                .textFieldStyle(.roundedBorder)
            Text("OpenAI-compatible endpoint (Ollama, LM Studio, vLLM, etc.)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var llmModelOverride: some View {
        if viewModel.llmProcessor != .appleLlm {
            TextField("Model Override (empty = default)", text: $viewModel.llmModel)
                .textFieldStyle(.roundedBorder)
            Text("Leave empty to use the provider's default model.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var llmHealthCheck: some View {
        HStack {
            Button("Check Availability") {
                Task { await viewModel.checkLlmHealth() }
            }
            if let status = viewModel.llmHealthStatus {
                Text(status)
                    .foregroundStyle(status == "Available" ? .green : .red)
                    .font(.caption)
            }
        }
    }
}

/// Extracted ViewModifiers to avoid SwiftUI type-checker timeout with many .onChange calls.
private struct SttSaveOnChange: ViewModifier {
    @Bindable var viewModel: SettingsViewModel

    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.sttProvider) { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.elevenLabsKey) { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.openAIKey) { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.groqKey) { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.sttLanguage) { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.customSttKey) { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.customSttBaseUrl) { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.customSttDisplayName) { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.customSttModel) { _, _ in Task { await viewModel.saveConfig() } }
    }
}

private struct LlmSaveOnChange: ViewModifier {
    @Bindable var viewModel: SettingsViewModel

    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.llmProcessor) { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.anthropicKey) { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.googleAiKey) { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.customOpenAIKey) { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.customBaseUrl) { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.customDisplayName) { _, _ in Task { await viewModel.saveConfig() } }
            .onChange(of: viewModel.llmModel) { _, _ in Task { await viewModel.saveConfig() } }
    }
}

// MARK: - Dictionary Tab

private struct DictionaryTab: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal Dictionary")
                .font(.headline)

            Text("Add terms with optional aliases and descriptions to improve transcription accuracy.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Search bar
            TextField("Search entries...", text: $viewModel.dictionarySearch)
                .textFieldStyle(.roundedBorder)

            // Add new entry form
            HStack(spacing: 8) {
                TextField("Term", text: $viewModel.newEntryTerm)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { viewModel.addEntry() }

                TextField("Alias (optional)", text: $viewModel.newEntryAlias)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 120)

                TextField("Description (optional)", text: $viewModel.newEntryDescription)
                    .textFieldStyle(.roundedBorder)

                Button("Add") { viewModel.addEntry() }
                    .disabled(viewModel.newEntryTerm.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            // Rich entries list
            List {
                ForEach(viewModel.filteredEntries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.term).fontWeight(.medium)
                            if let alias = entry.alias, !alias.isEmpty {
                                Text("aka: \(alias)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let desc = entry.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button(role: .destructive) {
                            viewModel.removeEntry(entry)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.bordered)

            // Legacy terms section
            if !viewModel.dictionaryTerms.isEmpty {
                Divider()

                HStack {
                    Text("Legacy Terms")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(viewModel.dictionaryTerms.count) terms")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    TextField("Add simple term...", text: $viewModel.newTerm)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { viewModel.addTerm() }

                    Button("Add") { viewModel.addTerm() }
                        .disabled(viewModel.newTerm.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                List {
                    ForEach(viewModel.dictionaryTerms, id: \.self) { term in
                        Text(term)
                    }
                    .onDelete { offsets in
                        viewModel.removeTerm(at: offsets)
                    }
                }
                .listStyle(.bordered)
                .frame(maxHeight: 100)
            }

            if viewModel.dictionaryEntries.isEmpty && viewModel.dictionaryTerms.isEmpty {
                Text("No terms added yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding()
    }
}

// MARK: - Appearance Tab

private struct AppearanceTab: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Overlay") {
                Slider(value: $viewModel.opacity, in: 0.3...1.0, step: 0.05) {
                    Text("Opacity: \(Int(viewModel.opacity * 100))%")
                }

                Toggle("Show Waveform", isOn: $viewModel.showWaveform)
            }

            Section("Theme") {
                Picker("Theme", selection: $viewModel.theme) {
                    Text("Dark").tag("dark")
                    Text("Light").tag("light")
                    Text("System").tag("system")
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: viewModel.opacity) { _, _ in Task { await viewModel.saveConfig() } }
        .onChange(of: viewModel.showWaveform) { _, _ in Task { await viewModel.saveConfig() } }
        .onChange(of: viewModel.theme) { _, _ in Task { await viewModel.saveConfig() } }
    }
}
