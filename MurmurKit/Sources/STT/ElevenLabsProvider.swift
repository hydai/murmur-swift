import Foundation

/// ElevenLabs streaming STT via WebSocket.
///
/// Protocol: Send base64-encoded WAV chunks as JSON messages,
/// receive partial_transcript / final_transcript events.
public actor ElevenLabsProvider: SttProvider {
    private let apiKey: String
    private let model: String
    private let languageCode: String

    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 3

    private let eventContinuation: AsyncStream<TranscriptionEvent>.Continuation
    public nonisolated let events: AsyncStream<TranscriptionEvent>

    public init(apiKey: String, model: String = "scribe_v1", languageCode: String = "en") {
        self.apiKey = apiKey
        self.model = model
        self.languageCode = languageCode

        var cont: AsyncStream<TranscriptionEvent>.Continuation!
        self.events = AsyncStream { cont = $0 }
        self.eventContinuation = cont
    }

    public func startSession() async throws {
        var components = URLComponents(string: "wss://api.elevenlabs.io/v1/speech-to-text/ws")!
        components.queryItems = [
            URLQueryItem(name: "model_id", value: model),
            URLQueryItem(name: "language_code", value: languageCode),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let session = URLSession(configuration: .default)
        let ws = session.webSocketTask(with: request)
        ws.resume()
        self.webSocketTask = ws

        reconnectAttempts = 0

        // Start receiving messages
        receiveTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                do {
                    let message = try await ws.receive()
                    await self.handleMessage(message)
                } catch {
                    if !Task.isCancelled {
                        await self.handleDisconnect(error: error)
                    }
                    break
                }
            }
        }
    }

    private func handleDisconnect(error: Error) {
        guard reconnectAttempts < maxReconnectAttempts else {
            emit(.error(message: "WebSocket disconnected after \(maxReconnectAttempts) retries: \(error.localizedDescription)"))
            return
        }

        reconnectAttempts += 1
        let delay = UInt64(pow(2.0, Double(reconnectAttempts))) // Exponential backoff: 2, 4, 8 seconds
        emit(.error(message: "WebSocket disconnected, reconnecting in \(delay)s (attempt \(reconnectAttempts)/\(maxReconnectAttempts))..."))

        Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            do {
                try await startSession()
            } catch {
                emit(.error(message: "Reconnection failed: \(error.localizedDescription)"))
            }
        }
    }

    public func sendAudio(_ chunk: AudioChunk) async throws {
        guard let ws = webSocketTask else {
            throw MurmurError.stt("WebSocket not connected")
        }

        let wavData = AudioChunker.encodeWAV(samples: chunk.data)
        let base64 = wavData.base64EncodedString()

        let json: [String: Any] = [
            "type": "audio",
            "audio_base64": base64,
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        try await ws.send(.string(String(data: data, encoding: .utf8)!))
    }

    public func stopSession() async throws {
        // Send end-of-stream signal
        if let ws = webSocketTask {
            let endMsg = #"{"type":"end_of_stream"}"#
            try? await ws.send(.string(endMsg))
            ws.cancel(with: .normalClosure, reason: nil)
        }

        await receiveTask?.value
        receiveTask = nil
        webSocketTask = nil

        eventContinuation.finish()
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String
        else { return }

        let transcriptText = json["text"] as? String ?? ""
        guard !transcriptText.isEmpty else { return }
        let timestamp = json["timestamp"] as? UInt64 ?? 0

        switch type {
        case "partial_transcript":
            emit(.partial(text: transcriptText, timestampMs: timestamp))
        case "final_transcript":
            emit(.committed(text: transcriptText, timestampMs: timestamp))
        case "error":
            let errorMsg = json["message"] as? String ?? "Unknown ElevenLabs error"
            emit(.error(message: errorMsg))
        default:
            break
        }
    }

    private nonisolated func emit(_ event: TranscriptionEvent) {
        eventContinuation.yield(event)
    }
}
