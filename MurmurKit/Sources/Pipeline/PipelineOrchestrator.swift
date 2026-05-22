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
    private var activeSttProvider: (any SttProvider)?
    private var llmProcessor: (any LlmProcessor)?
    private var outputSink: (any OutputSink)?
    private var dictionaryTerms: [String] = []

    private var sessionTask: Task<Void, Never>?
    private var activeSessionId: UUID?

    private var accumulator = TranscriptionAccumulator()

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

        accumulator = TranscriptionAccumulator()
        let sessionId = UUID()
        activeSessionId = sessionId
        activeSttProvider = sttProvider

        // Start STT session
        try await sttProvider.startSession()

        // Start audio capture
        do {
            try await audioCapture.start()
        } catch {
            if let provider = claimSessionTeardown(for: sessionId) {
                try? await provider.stopSession()
            }
            throw error
        }
        transition(to: .recording)

        // Combine streams into a structured task group
        sessionTask = Task { [weak self] in
            guard let capture = self?.audioCapture else { return }
            let chunks = await capture.chunks!
            let levels = await capture.levels!
            
            await withDiscardingTaskGroup { group in
                // 1. Forward audio chunks to STT
                group.addTask {
                    for await chunk in chunks {
                        guard let self else { break }
                        if Task.isCancelled { break }
                        do {
                            try await sttProvider.sendAudio(chunk)
                        } catch {
                            self.emit(.error(message: "Audio send error: \(error.localizedDescription)", recoverable: true))
                        }
                    }
                    if !Task.isCancelled {
                        if let provider = await self?.claimSessionTeardown(for: sessionId) {
                            try? await provider.stopSession()
                        }
                    }
                }

                // 2. Forward audio levels for UI
                group.addTask {
                    for await level in levels {
                        guard let self else { break }
                        if Task.isCancelled { break }
                        self.emit(.audioLevel(level))
                    }
                }

                // 3. Process transcription events
                group.addTask {
                    for await event in sttProvider.events {
                        guard let self else { break }
                        if Task.isCancelled { break }
                        await self.handleTranscriptionEvent(event)
                    }
                    if !Task.isCancelled {
                        await self?.finishTranscription()
                    }
                }
            }
        }
    }

    /// Stop recording. Awaits pipeline teardown with timeout to prevent deadlocks.
    public func stop() async {
        guard state == .recording || state == .transcribing else { return }

        await audioCapture.stop()
        // Wait for pipeline task to complete naturally (driven by stream closures),
        // but enforce an overall timeout just in case.
        let session = sessionTask
        let didFinish = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await session?.value
                return true
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(5))
                return false
            }
            let first = await group.next()!
            group.cancelAll()
            return first
        }

        if !didFinish {
            sessionTask?.cancel()
            let provider = claimCurrentSessionTeardown()
            if let provider {
                Task.detached {
                    try? await provider.stopSession()
                }
            }
        }
        sessionTask = nil

        // Safety net: if state is still mid-pipeline after cleanup,
        // force transition to idle so the UI never gets permanently stuck.
        if state == .recording || state == .transcribing {
            transition(to: .idle)
        }
    }

    /// Hard cancel — immediately tears down all tasks and resets to idle.
    /// Use as an escape hatch when `stop()` itself can't recover.
    public func cancel() async {
        await audioCapture.stop()

        sessionTask?.cancel()
        sessionTask = nil
        
        let provider = claimCurrentSessionTeardown()
        if let provider {
            Task.detached {
                try? await provider.stopSession()
            }
        }

        accumulator = TranscriptionAccumulator()
        transition(to: .idle)
    }

    // MARK: - Internal

    private func claimSessionTeardown(for sessionId: UUID) -> (any SttProvider)? {
        guard activeSessionId == sessionId else { return nil }
        let provider = activeSttProvider
        activeSttProvider = nil
        activeSessionId = nil
        return provider
    }

    private func claimCurrentSessionTeardown() -> (any SttProvider)? {
        let provider = activeSttProvider
        activeSttProvider = nil
        activeSessionId = nil
        return provider
    }

    private func handleTranscriptionEvent(_ event: TranscriptionEvent) {
        switch event {
        case .partial(let text, _):
            if state == .recording { transition(to: .transcribing) }
            accumulator.handle(event)
            emit(.partialTranscription(text))

        case .committed(let text, _):
            if state == .recording { transition(to: .transcribing) }
            accumulator.handle(event)
            emit(.committedTranscription(text))

        case .error(let message):
            emit(.error(message: "STT error: \(message)", recoverable: true))
        }
    }

    private func finishTranscription() async {
        let transcription = accumulator.finalize()
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
