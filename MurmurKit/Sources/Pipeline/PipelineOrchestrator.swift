import Foundation

/// Actor-based orchestrator for the audio -> STT -> LLM -> output pipeline.
///
/// State machine: Idle -> Recording -> Transcribing -> Processing -> Done
/// Maps to Rust's `PipelineOrchestrator` but uses Swift actors and AsyncStream
/// instead of Arc<Mutex<T>> and tokio channels.
public actor PipelineOrchestrator {
    private var state: PipelineState = .idle
    private let audioCapture = AudioCaptureService()
    private let commandDetector = VoiceCommandDetector()

    private var sttProvider: (any SttProvider)?
    private var llmProcessor: (any LlmProcessor)?
    private var outputSink: (any OutputSink)?
    private var dictionaryTerms: [String] = []

    private var audioTask: Task<Void, Never>?
    private var levelTask: Task<Void, Never>?
    private var transcriptionTask: Task<Void, Never>?

    private var fullTranscription = ""
    private var lastPartialText = ""

    private let eventContinuation: AsyncStream<PipelineEvent>.Continuation
    public nonisolated let events: AsyncStream<PipelineEvent>

    public init() {
        var cont: AsyncStream<PipelineEvent>.Continuation!
        self.events = AsyncStream { cont = $0 }
        self.eventContinuation = cont
    }

    // MARK: - Configuration

    /// Set the STT provider to use.
    public func setSttProvider(_ provider: any SttProvider) {
        self.sttProvider = provider
    }

    /// Set the LLM processor to use.
    public func setLlmProcessor(_ processor: any LlmProcessor) {
        self.llmProcessor = processor
    }

    /// Set the output sink.
    public func setOutputSink(_ sink: any OutputSink) {
        self.outputSink = sink
    }

    /// Set personal dictionary terms.
    public func setDictionaryTerms(_ terms: [String]) {
        self.dictionaryTerms = terms
    }

    // MARK: - Pipeline control

    /// Start the recording pipeline.
    public func start() async throws {
        switch state {
        case .recording, .transcribing, .processing:
            throw MurmurError.invalidState("Cannot start: pipeline is \(state.rawValue)")
        case .done, .error:
            // Reset from terminal state
            transition(to: .idle)
        case .idle:
            break
        }

        guard let sttProvider else {
            throw MurmurError.invalidState("No STT provider configured")
        }

        fullTranscription = ""
        lastPartialText = ""

        // Start STT session
        try await sttProvider.startSession()

        // Start audio capture
        try await audioCapture.start()
        transition(to: .recording)

        // Forward audio chunks to STT
        let chunks = await audioCapture.chunks!
        audioTask = Task { [weak self] in
            for await chunk in chunks {
                guard let self else { break }
                do {
                    try await sttProvider.sendAudio(chunk)
                } catch {
                    await self.emit(.error(message: "Audio send error: \(error.localizedDescription)", recoverable: true))
                }
            }
            // Audio stream ended (stop was called) — finalize STT
            try? await sttProvider.stopSession()
        }

        // Forward audio levels for UI
        let levels = await audioCapture.levels!
        levelTask = Task { [weak self] in
            for await level in levels {
                guard let self else { break }
                self.emit(.audioLevel(level))
            }
        }

        // Process transcription events
        transcriptionTask = Task { [weak self] in
            for await event in sttProvider.events {
                guard let self else { break }
                await self.handleTranscriptionEvent(event)
            }
            // Transcription stream ended — run post-processing
            await self?.finishTranscription()
        }
    }

    /// Stop recording. Post-processing continues automatically.
    public func stop() async {
        guard state == .recording || state == .transcribing else { return }

        await audioCapture.stop()
        // audioTask and transcriptionTask will finish naturally
        levelTask?.cancel()
        levelTask = nil
    }

    // MARK: - Internal

    private func handleTranscriptionEvent(_ event: TranscriptionEvent) {
        switch event {
        case .partial(let text, _):
            if state == .recording {
                transition(to: .transcribing)
            }
            lastPartialText = text
            emit(.partialTranscription(text))

        case .committed(let text, _):
            if state == .recording {
                transition(to: .transcribing)
            }
            if !fullTranscription.isEmpty {
                fullTranscription += " "
            }
            fullTranscription += text
            lastPartialText = ""
            emit(.committedTranscription(text))

        case .error(let message):
            emit(.error(message: "STT error: \(message)", recoverable: true))
        }
    }

    private func finishTranscription() async {
        // Append any trailing partial text
        if !lastPartialText.isEmpty {
            if !fullTranscription.isEmpty {
                fullTranscription += " "
            }
            fullTranscription += lastPartialText
            lastPartialText = ""
        }

        let transcription = fullTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcription.isEmpty else {
            transition(to: .idle)
            return
        }

        // Detect voice commands
        let (task, commandName) = commandDetector.detect(
            transcription: transcription,
            dictionaryTerms: dictionaryTerms
        )
        if let commandName {
            emit(.commandDetected(commandName))
        }

        // LLM processing
        if let llmProcessor {
            transition(to: .processing)
            do {
                let result = try await llmProcessor.process(task)
                try? await outputSink?.outputText(result.text)
                emit(.finalResult(text: result.text, processingTimeMs: result.processingTimeMs))
                transition(to: .done)
            } catch {
                // Fallback: output raw transcription
                try? await outputSink?.outputText(transcription)
                emit(.error(message: "LLM error: \(error.localizedDescription)", recoverable: false))
                emit(.finalResult(text: transcription, processingTimeMs: 0))
                transition(to: .error)
            }
        } else {
            // No LLM configured — output raw transcription
            try? await outputSink?.outputText(transcription)
            emit(.finalResult(text: transcription, processingTimeMs: 0))
            transition(to: .done)
        }
    }

    private func transition(to newState: PipelineState) {
        state = newState
        emit(.stateChanged(newState))
    }

    private nonisolated func emit(_ event: PipelineEvent) {
        eventContinuation.yield(event)
    }
}
