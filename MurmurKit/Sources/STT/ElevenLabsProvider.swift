import Foundation

/// Reconnection backoff config for the ElevenLabs WebSocket.
public struct ElevenLabsReconnectConfig: Sendable {
    public let maxRetries: Int
    public let baseDelayMs: UInt64
    public let maxDelayMs: UInt64

    public init(maxRetries: Int = 10, baseDelayMs: UInt64 = 1000, maxDelayMs: UInt64 = 30_000) {
        self.maxRetries = maxRetries
        self.baseDelayMs = baseDelayMs
        self.maxDelayMs = maxDelayMs
    }

    public static let `default` = ElevenLabsReconnectConfig()
}

/// ElevenLabs Scribe v2 realtime STT via WebSocket.
///
/// Protocol (matches the Rust `crates/lt-stt/src/elevenlabs.rs` implementation):
/// - Endpoint: `wss://api.elevenlabs.io/v1/speech-to-text/realtime`
/// - Audio: raw 16-bit little-endian PCM @ 16 kHz, base64-encoded inside JSON
/// - Send message: `{"message_type":"input_audio_chunk","audio_base_64":"...","sample_rate":16000}`
/// - On stop: send a final commit message (`commit:true`) and wait briefly
///   so the server can flush a `committed_transcript` before we close.
/// - Responses include `session_started`, `partial_transcript`,
///   `committed_transcript`, `error`, `invalid_request`.
public actor ElevenLabsProvider: SttProvider {
    private let apiKey: String
    private let model: String
    private let languageCode: String?
    private let reconnectConfig: ElevenLabsReconnectConfig

    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var reconnectAttempts = 0
    private var shouldReconnect = true

    private let eventContinuation: AsyncStream<TranscriptionEvent>.Continuation
    public nonisolated let events: AsyncStream<TranscriptionEvent>

    public init(
        apiKey: String,
        model: String = "scribe_v2_realtime",
        languageCode: String? = nil,
        reconnectConfig: ElevenLabsReconnectConfig = .default
    ) {
        self.apiKey = apiKey
        self.model = model
        self.languageCode = languageCode
        self.reconnectConfig = reconnectConfig

        var cont: AsyncStream<TranscriptionEvent>.Continuation!
        self.events = AsyncStream { cont = $0 }
        self.eventContinuation = cont
    }

    // MARK: - URL & encoding helpers (internal, exposed for tests)

    /// Build the WebSocket URL for the configured model and language.
    /// `language` of nil or "auto" omits the `language_code` query parameter.
    static func buildURL(model: String, language: String?) -> URL {
        var components = URLComponents(string: "wss://api.elevenlabs.io/v1/speech-to-text/realtime")!
        var items = [
            URLQueryItem(name: "model_id", value: model),
            URLQueryItem(name: "audio_format", value: "pcm_16000"),
        ]
        if let lang = language, lang != "auto", !lang.isEmpty {
            items.append(URLQueryItem(name: "language_code", value: lang))
        }
        components.queryItems = items
        return components.url!
    }

    /// Encode 16-bit PCM samples to base64-encoded little-endian bytes.
    static func encodePCMBase64(_ samples: [Int16]) -> String {
        var bytes = Data(capacity: samples.count * 2)
        for sample in samples {
            let le = sample.littleEndian
            bytes.append(UInt8(truncatingIfNeeded: le & 0xff))
            bytes.append(UInt8(truncatingIfNeeded: (le >> 8) & 0xff))
        }
        return bytes.base64EncodedString()
    }

    // MARK: - SttProvider

    public func startSession() async throws {
        shouldReconnect = true
        reconnectAttempts = 0
        try connect()
    }

    public func sendAudio(_ chunk: AudioChunk) async throws {
        guard let ws = webSocketTask else {
            throw MurmurError.stt("WebSocket not connected")
        }

        let payload: [String: Any] = [
            "message_type": "input_audio_chunk",
            "audio_base_64": Self.encodePCMBase64(chunk.data),
            "sample_rate": 16000,
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        try await ws.send(.string(String(data: data, encoding: .utf8)!))
    }

    public func stopSession() async throws {
        shouldReconnect = false

        if let ws = webSocketTask {
            // Tell the server to flush its pending transcription buffer.
            let commit: [String: Any] = [
                "message_type": "input_audio_chunk",
                "audio_base_64": "",
                "sample_rate": 16000,
                "commit": true,
            ]
            if let data = try? JSONSerialization.data(withJSONObject: commit),
               let json = String(data: data, encoding: .utf8) {
                try? await ws.send(.string(json))
            }

            // Give the server a moment to send a `committed_transcript` reply.
            try? await Task.sleep(for: .milliseconds(500))
            ws.cancel(with: .normalClosure, reason: nil)
        }

        if let task = receiveTask {
            let didFinish = await withTaskGroup(of: Bool.self) { group in
                group.addTask { await task.value; return true }
                group.addTask { try? await Task.sleep(for: .seconds(2)); return false }
                let first = await group.next() ?? false
                group.cancelAll()
                return first
            }
            if !didFinish {
                task.cancel()
            }
        }

        receiveTask = nil
        webSocketTask = nil
        eventContinuation.finish()
    }

    // MARK: - Internals

    private func connect() throws {
        let url = Self.buildURL(model: model, language: languageCode)
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let session = URLSession(configuration: .default)
        let ws = session.webSocketTask(with: request)
        ws.resume()
        self.webSocketTask = ws

        receiveTask = Task { [weak self] in
            await self?.receiveLoop(on: ws)
        }
    }

    private func receiveLoop(on ws: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            do {
                let message = try await ws.receive()
                handleMessage(message)
            } catch {
                if Task.isCancelled { break }
                await handleDisconnect(error: error)
                break
            }
        }
    }

    private func handleDisconnect(error: Error) async {
        guard shouldReconnect else { return }
        guard reconnectAttempts < reconnectConfig.maxRetries else {
            emit(.error(message: "WebSocket disconnected after \(reconnectConfig.maxRetries) retries: \(error.localizedDescription)"))
            return
        }

        reconnectAttempts += 1
        let exp = UInt64(1) << min(reconnectAttempts - 1, 30)
        let delayMs = min(reconnectConfig.baseDelayMs &* exp, reconnectConfig.maxDelayMs)
        emit(.error(message: "WebSocket disconnected, reconnecting in \(delayMs)ms (attempt \(reconnectAttempts)/\(reconnectConfig.maxRetries))"))

        try? await Task.sleep(for: .milliseconds(Int(delayMs)))
        guard shouldReconnect, !Task.isCancelled else { return }

        do {
            try connect()
        } catch {
            emit(.error(message: "Reconnection failed: \(error.localizedDescription)"))
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messageType = json["message_type"] as? String
        else { return }

        switch messageType {
        case "session_started":
            // Informational; no event needed.
            return
        case "partial_transcript":
            let text = json["text"] as? String ?? ""
            guard !text.isEmpty else { return }
            emit(.partial(text: text, timestampMs: 0))
        case "committed_transcript":
            let text = json["text"] as? String ?? ""
            guard !text.isEmpty else { return }
            emit(.committed(text: text, timestampMs: 0))
        case "error", "invalid_request":
            let message = json["error"] as? String ?? "Unknown ElevenLabs error"
            emit(.error(message: message))
        default:
            return
        }
    }

    private nonisolated func emit(_ event: TranscriptionEvent) {
        eventContinuation.yield(event)
    }
}
