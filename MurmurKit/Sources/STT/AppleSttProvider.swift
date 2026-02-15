import AVFoundation
import Speech

/// On-device STT using Apple's SpeechTranscriber (macOS 26+ / iOS 26+).
///
/// This replaces ~200 lines of Rust<->Swift FFI bridge code with direct
/// framework calls. SpeechTranscriber with progressiveTranscription preset
/// provides streaming partial + committed results.
public actor AppleSttProvider: SttProvider {
    private let locale: Locale
    /// The locale actually used after fallback resolution (for error reporting).
    private var effectiveLocale: Locale?
    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var resultTask: Task<Void, Never>?
    private var audioContinuation: AsyncStream<AnalyzerInput>.Continuation?

    /// Cumulative sample count for monotonic timeline.
    private var cumulativeSampleCount: Int64 = 0

    private let eventContinuation: AsyncStream<TranscriptionEvent>.Continuation
    public nonisolated let events: AsyncStream<TranscriptionEvent>

    /// Create a provider for the given locale (pass nil for system default).
    ///
    /// When nil, resolves the current locale by stripping script subtags
    /// (e.g. zh-Hant-TW → zh-TW) that SpeechTranscriber may not support.
    public init(locale: Locale? = nil) {
        self.locale = locale ?? Self.resolveSystemLocale()

        var cont: AsyncStream<TranscriptionEvent>.Continuation!
        self.events = AsyncStream { cont = $0 }
        self.eventContinuation = cont
    }

    public func startSession() async throws {
        // Validate locale before creating transcriber for actionable error messages
        let supported = await SpeechTranscriber.supportedLocales
        let effectiveLocale: Locale
        if supported.contains(where: { $0.identifier == locale.identifier }) {
            effectiveLocale = locale
        } else {
            // Locale not directly supported — fall back to same language, different region
            // e.g. en-TW → en-US, zh-SG → zh-TW
            let langCode = locale.language.languageCode?.identifier ?? "en"
            if let fallback = supported.first(where: {
                $0.language.languageCode?.identifier == langCode
            }) {
                effectiveLocale = fallback
            } else {
                let langList = supported.map(\.identifier).sorted().joined(separator: ", ")
                throw MurmurError.stt(
                    "Locale '\(locale.identifier)' is not supported by Apple Speech. "
                    + "Supported locales: \(langList). "
                    + "Set 'apple_stt_locale' in config to a supported locale, or change your system language."
                )
            }
        }

        self.effectiveLocale = effectiveLocale

        let stt = SpeechTranscriber(locale: effectiveLocale, preset: .progressiveTranscription)
        transcriber = stt

        // Ensure the on-device speech model is downloaded
        let installed = await SpeechTranscriber.installedLocales
        let isInstalled = installed.contains(where: {
            $0.language.languageCode?.identifier == effectiveLocale.language.languageCode?.identifier
        })

        if !isInstalled {
            emit(.error(
                message: "Downloading speech model for \(effectiveLocale.identifier), please wait..."
            ))
            do {
                if let downloader = try await AssetInventory.assetInstallationRequest(
                    supporting: [stt]
                ) {
                    try await downloader.downloadAndInstall()
                }
            } catch {
                throw MurmurError.stt(
                    "Failed to download speech model for \(effectiveLocale.identifier): "
                    + "\(error.localizedDescription). "
                    + "Try downloading the language in System Settings → General → Language & Region."
                )
            }
        }

        // Create audio input stream for feeding buffers
        var audioCont: AsyncStream<AnalyzerInput>.Continuation!
        let audioStream = AsyncStream<AnalyzerInput> { audioCont = $0 }
        audioContinuation = audioCont

        let speechAnalyzer = SpeechAnalyzer(modules: [stt])
        analyzer = speechAnalyzer

        cumulativeSampleCount = 0

        // Start analyzer processing in a separate task
        let analyzeTask = Task {
            try await speechAnalyzer.start(inputSequence: audioStream)
        }

        // Iterate transcription results
        resultTask = Task { [weak self] in
            _ = analyzeTask
            do {
                for try await result in stt.results {
                    guard let self else { break }
                    let text = String(result.text.characters)
                    guard !text.isEmpty else { continue }

                    let timestampMs = UInt64(max(0, result.range.start.seconds * 1000))

                    if result.isFinal {
                        await self.emit(.committed(text: text, timestampMs: timestampMs))
                    } else {
                        await self.emit(.partial(text: text, timestampMs: timestampMs))
                    }
                }
            } catch {
                guard let self else { return }
                let localeId = await self.effectiveLocale?.identifier ?? self.locale.identifier
                await self.emit(.error(
                    message: "\(error.localizedDescription) (locale: \(localeId))"
                ))
            }
        }
    }

    public func sendAudio(_ chunk: AudioChunk) async throws {
        guard let audioContinuation else {
            throw MurmurError.stt("Session not started")
        }

        let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: true
        )!

        let frameCount = AVAudioFrameCount(chunk.data.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw MurmurError.stt("Failed to create audio buffer")
        }
        buffer.frameLength = frameCount

        chunk.data.withUnsafeBufferPointer { src in
            buffer.int16ChannelData![0].update(from: src.baseAddress!, count: chunk.data.count)
        }

        // Build monotonic timeline
        let startTimeNs = cumulativeSampleCount * 1_000_000_000 / 16000
        cumulativeSampleCount += Int64(chunk.data.count)

        let bufferStartTime = CMTime(value: startTimeNs, timescale: 1_000_000_000)
        let input = AnalyzerInput(buffer: buffer, bufferStartTime: bufferStartTime)
        audioContinuation.yield(input)
    }

    public func stopSession() async throws {
        audioContinuation?.finish()
        audioContinuation = nil

        // Wait for results to drain, but don't block forever.
        // SpeechTranscriber.results may never terminate if the session
        // didn't produce a final result, causing a permanent hang.
        if let task = resultTask {
            let didFinish = await withTaskGroup(of: Bool.self) { group in
                group.addTask { await task.value; return true }
                group.addTask { try? await Task.sleep(for: .seconds(3)); return false }
                let first = await group.next()!
                group.cancelAll()
                return first
            }
            if !didFinish {
                task.cancel()
            }
        }
        resultTask = nil
        transcriber = nil
        analyzer = nil

        // Always finish the event stream — this is the key fix that
        // unblocks PipelineOrchestrator's transcriptionTask.
        eventContinuation.finish()
    }

    private func emit(_ event: TranscriptionEvent) {
        eventContinuation.yield(event)
    }

    /// Build a minimal locale from the system locale.
    ///
    /// `Locale.current` can include script subtags (e.g. `zh-Hant-TW`) and
    /// extra user preferences that `SpeechTranscriber` does not recognise.
    /// This strips it down to language + region (e.g. `zh-TW`).
    private static func resolveSystemLocale() -> Locale {
        let current = Locale.current
        let langCode = current.language.languageCode?.identifier ?? "en"

        if let region = current.language.region?.identifier {
            return Locale(identifier: "\(langCode)-\(region)")
        }
        return Locale(identifier: langCode)
    }
}
