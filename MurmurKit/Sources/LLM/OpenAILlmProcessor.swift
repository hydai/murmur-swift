import Foundation

/// LLM processor using OpenAI Chat Completions API.
public actor OpenAILlmProcessor: LlmProcessor {
    private let apiKey: String
    private let model: String
    private let client: HttpLlmClient
    private let promptManager = PromptManager()

    public init(apiKey: String, model: String = "gpt-4o-mini", timeoutSeconds: TimeInterval = 30) {
        self.apiKey = apiKey
        self.model = model
        self.client = HttpLlmClient(timeoutSeconds: timeoutSeconds)
    }

    public func process(_ task: ProcessingTask) async throws -> ProcessingOutput {
        let (instructions, prompt) = promptManager.buildPrompt(for: task)
        let start = ContinuousClock.now

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": instructions],
                ["role": "user", "content": prompt],
            ],
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let url = try HttpLlmClient.buildURL(base: "https://api.openai.com/v1/chat/completions", auth: .none)
        let data = try await client.post(url: url, body: bodyData, auth: .bearer(apiKey))
        let text = try Self.parseOpenAIResponse(data)

        let elapsed = start.duration(to: .now)
        let ms = UInt64(elapsed.components.seconds * 1000)
            + UInt64(elapsed.components.attoseconds / 1_000_000_000_000_000)

        return ProcessingOutput(text: text, processingTimeMs: ms)
    }

    public func healthCheck() async -> Bool {
        !apiKey.isEmpty
    }

    /// Parse OpenAI-format chat completion response. Static for reuse by CustomOpenAIProcessor.
    public static func parseOpenAIResponse(_ data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw MurmurError.llm("Failed to parse OpenAI response")
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
