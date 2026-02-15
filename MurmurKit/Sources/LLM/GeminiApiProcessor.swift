import Foundation

/// LLM processor using Google Gemini REST API (not CLI).
public actor GeminiApiProcessor: LlmProcessor {
    private let apiKey: String
    private let model: String
    private let client: HttpLlmClient
    private let promptManager = PromptManager()

    public init(apiKey: String, model: String = "gemini-2.0-flash", timeoutSeconds: TimeInterval = 30) {
        self.apiKey = apiKey
        self.model = model
        self.client = HttpLlmClient(timeoutSeconds: timeoutSeconds)
    }

    public func process(_ task: ProcessingTask) async throws -> ProcessingOutput {
        let (instructions, prompt) = promptManager.buildPrompt(for: task)
        let start = ContinuousClock.now

        let fullPrompt = "\(instructions)\n\n## Input\n\n\(prompt)"

        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": fullPrompt]]],
            ],
        ]

        let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let url = try HttpLlmClient.buildURL(base: baseURL, auth: .queryParam(key: "key", value: apiKey))
        let data = try await client.post(url: url, body: bodyData, auth: .queryParam(key: "key", value: apiKey))
        let text = try Self.parseGeminiResponse(data)

        let elapsed = start.duration(to: .now)
        let ms = UInt64(elapsed.components.seconds * 1000)
            + UInt64(elapsed.components.attoseconds / 1_000_000_000_000_000)

        return ProcessingOutput(text: text, processingTimeMs: ms)
    }

    public func healthCheck() async -> Bool {
        !apiKey.isEmpty
    }

    /// Parse Google Gemini REST API response.
    static func parseGeminiResponse(_ data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String
        else {
            throw MurmurError.llm("Failed to parse Gemini API response")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
