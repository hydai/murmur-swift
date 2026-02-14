import Foundation

/// Groq STT via REST API (Whisper-compatible endpoint).
///
/// Same batching pattern as OpenAI but pointed at Groq's API.
public actor GroqProvider: SttProvider {
    private let apiKey: String
    private let model: String

    private var sampleBuffer: [Int16] = []
    private let batchSampleCount = 16000 * 4

    private let eventContinuation: AsyncStream<TranscriptionEvent>.Continuation
    public nonisolated let events: AsyncStream<TranscriptionEvent>

    public init(apiKey: String, model: String = "whisper-large-v3") {
        self.apiKey = apiKey
        self.model = model

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

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(wavData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
            emit(.error(message: "Groq API error: \(error.localizedDescription)"))
        }
    }

    private nonisolated func emit(_ event: TranscriptionEvent) {
        eventContinuation.yield(event)
    }
}
