import SwiftUI
import MurmurKit

/// Drives the UI by observing PipelineOrchestrator events.
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
    private var eventTask: Task<Void, Never>?

    init() {
        startEventLoop()
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

        // Configure pipeline
        let stt = AppleSttProvider()
        await orchestrator.setSttProvider(stt)

        let llm = AppleLlmProcessor()
        await orchestrator.setLlmProcessor(llm)

        let output = ClipboardOutput()
        await orchestrator.setOutputSink(output)

        do {
            try await orchestrator.start()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopRecording() async {
        await orchestrator.stop()
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
