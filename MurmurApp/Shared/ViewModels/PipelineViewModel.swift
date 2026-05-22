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
    var recentLevels = RingBuffer<Float>(capacity: 80)

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
    private let providerFactory = ProviderFactory()
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
        recentLevels.clear()

        let config = await configManager.getConfig()

        // Configure STT provider based on config
        let stt: any SttProvider = providerFactory.createSttProvider(from: config)
        await orchestrator.setSttProvider(stt)

        // Configure LLM processor based on config
        let llm: any LlmProcessor = await providerFactory.createLlmProcessor(from: config)
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

    /// Reapply LLM, output mode, and dictionary terms from the current config
    /// to the running orchestrator. STT is intentionally not swapped because
    /// it is bound to the active session; STT changes take effect on the next
    /// recording. Called by AppDelegate when `.murmurConfigDidChange` fires.
    func updateRuntimeConfig() async {
        let config = await configManager.getConfig()
        let llm = await providerFactory.createLlmProcessor(from: config)
        await orchestrator.setLlmProcessor(llm)
        let output = CombinedOutput(mode: config.outputMode)
        await orchestrator.setOutputSink(output)
        await orchestrator.setDictionaryTerms(config.personalDictionary.allTermStrings)
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
