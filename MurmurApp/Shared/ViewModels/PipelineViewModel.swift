import SwiftUI
import MurmurKit

/// Drives the UI by observing PipelineOrchestrator events.
/// Shared across overlay, tray, and main window.
@MainActor
@Observable
final class PipelineViewModel {
    // MARK: - Published state
    var pipelineState: PipelineState = .idle
    var partialText: String = ""
    var committedSegments: [String] = []
    var finalResult: String = ""
    var errorMessage: String?
    var currentRMS: Float = 0
    var voiceActive: Bool = false
    var processingTimeMs: UInt64 = 0
    var detectedCommand: String?

    /// Rolling buffer of recent RMS levels for waveform display.
    var recentLevels: [Float] = []
    private let maxLevelHistory = 80

    /// Full display text combining committed segments + current partial.
    var displayText: String {
        var parts = committedSegments
        if !partialText.isEmpty {
            parts.append(partialText)
        }
        return parts.joined(separator: " ")
    }

    var isRecording: Bool {
        pipelineState == .recording || pipelineState == .transcribing
    }

    // MARK: - Internal
    private let orchestrator = PipelineOrchestrator()
    let configManager = ConfigManager()
    private var eventTask: Task<Void, Never>?

    init() {
        startEventLoop()
        Task { try? await configManager.load() }
    }

    // MARK: - Actions

    func toggleRecording() async {
        if isRecording {
            await stopRecording()
        } else {
            await startRecording()
        }
    }

    func startRecording() async {
        // Reset UI state
        partialText = ""
        committedSegments = []
        finalResult = ""
        errorMessage = nil
        detectedCommand = nil
        processingTimeMs = 0
        recentLevels = []

        let config = await configManager.getConfig()

        // Configure STT provider based on config
        let stt: any SttProvider = createSttProvider(config)
        await orchestrator.setSttProvider(stt)

        // Configure LLM processor based on config
        let llm: any LlmProcessor = createLlmProcessor(config)
        await orchestrator.setLlmProcessor(llm)

        // Configure output based on config
        let output = CombinedOutput(mode: config.outputMode)
        await orchestrator.setOutputSink(output)

        // Set dictionary terms (includes both legacy terms and rich entry terms/aliases)
        await orchestrator.setDictionaryTerms(config.personalDictionary.allTermStrings)

        do {
            try await orchestrator.start()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopRecording() async {
        await orchestrator.stop()
    }

    // MARK: - Provider factories

    private func createSttProvider(_ config: AppConfig) -> any SttProvider {
        // Convert "auto" to nil — nil means let the API auto-detect
        let lang: String? = config.sttLanguage == "auto" ? nil : config.sttLanguage

        switch config.sttProvider {
        case .appleStt:
            // Apple STT uses its own locale-based config, not the language hint
            let locale = config.appleSttLocale == "auto" ? nil : Locale(identifier: config.appleSttLocale)
            return AppleSttProvider(locale: locale)
        case .elevenLabs:
            let key = config.apiKeys["elevenlabs"] ?? ""
            let elevenLabsLang: String? = lang.flatMap { ElevenLabsLanguages.iso639_3(for: $0) ?? $0 }
            return ElevenLabsProvider(apiKey: key, languageCode: elevenLabsLang)
        case .openAI:
            let key = config.apiKeys["openai"] ?? ""
            return OpenAIProvider(apiKey: key, language: lang)
        case .groq:
            let key = config.apiKeys["groq"] ?? ""
            return GroqProvider(apiKey: key, language: lang)
        case .customStt:
            let key = config.apiKeys["custom_stt"]
            let apiKey: String? = (key ?? "").isEmpty ? nil : key
            return CustomSttProvider(
                apiKey: apiKey,
                model: config.httpSttConfig.customModel,
                baseURL: config.httpSttConfig.customBaseUrl,
                language: lang
            )
        }
    }

    private func createLlmProcessor(_ config: AppConfig) -> any LlmProcessor {
        let modelOverride = config.llmModel.isEmpty ? nil : config.llmModel

        switch config.llmProcessor {
        case .appleLlm:
            return AppleLlmProcessor()
        case .gemini:
            return GeminiProcessor(model: modelOverride ?? "gemini-2.5-flash")
        case .copilot:
            return CopilotProcessor()
        case .openAILlm:
            let key = config.apiKeys["openai_llm"] ?? config.apiKeys["openai"] ?? ""
            return OpenAILlmProcessor(apiKey: key, model: modelOverride ?? "gpt-4o-mini")
        case .claude:
            let key = config.apiKeys["anthropic"] ?? ""
            return ClaudeLlmProcessor(apiKey: key, model: modelOverride ?? "claude-sonnet-4-20250514")
        case .geminiApi:
            let key = config.apiKeys["google_ai"] ?? ""
            return GeminiApiProcessor(apiKey: key, model: modelOverride ?? "gemini-2.0-flash")
        case .customOpenAI:
            let key = config.apiKeys["custom_openai"] ?? ""
            return CustomOpenAIProcessor(
                apiKey: key,
                model: modelOverride ?? "llama3",
                baseURL: config.httpLlmConfig.customBaseUrl
            )
        }
    }

    // MARK: - Event loop

    private func startEventLoop() {
        let events = orchestrator.events
        eventTask = Task { [weak self] in
            for await event in events {
                guard let self, !Task.isCancelled else { break }
                self.handleEvent(event)
            }
        }
    }

    private func handleEvent(_ event: PipelineEvent) {
        switch event {
        case .stateChanged(let state):
            pipelineState = state

        case .audioLevel(let level):
            currentRMS = level.rms
            voiceActive = level.voiceActive
            recentLevels.append(level.rms)
            if recentLevels.count > maxLevelHistory {
                recentLevels.removeFirst(recentLevels.count - maxLevelHistory)
            }

        case .partialTranscription(let text):
            partialText = text

        case .committedTranscription(let text):
            committedSegments.append(text)
            partialText = ""

        case .commandDetected(let command):
            detectedCommand = command

        case .finalResult(let text, let timeMs):
            finalResult = text
            processingTimeMs = timeMs

        case .error(let message, _):
            errorMessage = message
        }
    }
}
