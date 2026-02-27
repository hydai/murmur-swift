import Foundation

/// Custom OpenAI-compatible STT via REST API.
///
/// Same batched multipart/form-data pattern as OpenAIProvider,
/// but with configurable base URL and optional API key.
public actor CustomSttProvider: SttProvider {
    private let apiKey: String?
    private let model: String
    private let baseURL: String
    private let language: String?

    /// Accumulated samples for batching.
    private var sampleBuffer: [Int16] = []

    /// Batch size: ~4 seconds of audio at 16kHz.
    private let batchSampleCount = 16000 * 4

    private let eventContinuation: AsyncStream<TranscriptionEvent>.Continuation
    public nonisolated let events: AsyncStream<TranscriptionEvent>

    public init(apiKey: String? = nil, model: String = "whisper-1", baseURL: String = "http://localhost:8080", language: String? = nil) {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL
        self.language = language

        var cont: AsyncStream<TranscriptionEvent>.Continuation!
        self.events = AsyncStream { cont = $0 }
        self.eventContinuation = cont
    }

    public func startSession() async throws {
        sampleBuffer = []
    }

    public func sendAudio(_ chunk: AudioChunk) async throws {
        sampleBuffer.append(contentsOf: chunk.data)

        if sampleBuffer.count >= batchSampleCount {
            let batch = sampleBuffer
            sampleBuffer = []
            await transcribeBatch(batch)
        }
    }

    public func stopSession() async throws {
        if !sampleBuffer.isEmpty {
            let batch = sampleBuffer
            sampleBuffer = []
            await transcribeBatch(batch)
        }

        eventContinuation.finish()
    }

    private func transcribeBatch(_ samples: [Int16]) async {
        let wavData = AudioChunker.encodeWAV(samples: samples)

        let boundary = UUID().uuidString
        var body = Data()

        // File part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(wavData)
        body.append("\r\n".data(using: .utf8)!)

        // Model part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)

        // Response format part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json\r\n".data(using: .utf8)!)

        // Language hint (ISO 639-1)
        if let language {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(language)\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        // Build URL: append /v1/audio/transcriptions if base doesn't already end with it
        let endpoint = baseURL.hasSuffix("/")
            ? "\(baseURL)v1/audio/transcriptions"
            : "\(baseURL)/v1/audio/transcriptions"

        guard let url = URL(string: endpoint) else {
            emit(.error(message: "Invalid custom STT URL: \(endpoint)"))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let text = json["text"] as? String, !text.isEmpty
            {
                emit(.committed(text: text, timestampMs: 0))
            }
        } catch {
            emit(.error(message: "Custom STT API error: \(error.localizedDescription)"))
        }
    }

    private nonisolated func emit(_ event: TranscriptionEvent) {
        eventContinuation.yield(event)
    }
}
