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
        .frame(width: 520, height: 420)
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
            Section("Speech-to-Text") {
                Picker("STT Provider", selection: $viewModel.sttProvider) {
                    Text("Apple (on-device)").tag(SttProviderType.appleStt)
                    Text("ElevenLabs").tag(SttProviderType.elevenLabs)
                    Text("OpenAI Whisper").tag(SttProviderType.openAI)
                    Text("Groq").tag(SttProviderType.groq)
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

                if viewModel.sttProvider != .appleStt {
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

                    Text("For mixed-language speech, 'Auto-detect' works best with cloud providers.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("LLM Processor") {
                Picker("LLM Processor", selection: $viewModel.llmProcessor) {
                    Text("Apple (on-device)").tag(LlmProcessorType.appleLlm)
                    Text("Gemini CLI").tag(LlmProcessorType.gemini)
                    Text("Copilot CLI").tag(LlmProcessorType.copilot)
                }

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

            if let error = viewModel.saveError {
                Text(error).foregroundStyle(.red).font(.caption)
            }
        }
        .formStyle(.grouped)
        .onChange(of: viewModel.sttProvider) { _, _ in Task { await viewModel.saveConfig() } }
        .onChange(of: viewModel.llmProcessor) { _, _ in Task { await viewModel.saveConfig() } }
        .onChange(of: viewModel.elevenLabsKey) { _, _ in Task { await viewModel.saveConfig() } }
        .onChange(of: viewModel.openAIKey) { _, _ in Task { await viewModel.saveConfig() } }
        .onChange(of: viewModel.groqKey) { _, _ in Task { await viewModel.saveConfig() } }
        .onChange(of: viewModel.sttLanguage) { _, _ in Task { await viewModel.saveConfig() } }
    }
}

// MARK: - Dictionary Tab

private struct DictionaryTab: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal Dictionary")
                .font(.headline)

            Text("Add terms to improve transcription accuracy (e.g., proper nouns, technical terms).")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                TextField("Add term...", text: $viewModel.newTerm)
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

            if viewModel.dictionaryTerms.isEmpty {
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
