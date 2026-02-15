import Foundation

/// LLM processor using Anthropic Messages API.
public actor ClaudeLlmProcessor: LlmProcessor {
    private let apiKey: String
    private let model: String
    private let client: HttpLlmClient
    private let promptManager = PromptManager()

    public init(apiKey: String, model: String = "claude-sonnet-4-20250514", timeoutSeconds: TimeInterval = 60) {
        self.apiKey = apiKey
        self.model = model
        self.client = HttpLlmClient(timeoutSeconds: timeoutSeconds)
    }

    public func process(_ task: ProcessingTask) async throws -> ProcessingOutput {
        let (instructions, prompt) = promptManager.buildPrompt(for: task)
        let start = ContinuousClock.now

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": instructions,
            "messages": [
                ["role": "user", "content": prompt],
            ],
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let url = try HttpLlmClient.buildURL(base: "https://api.anthropic.com/v1/messages", auth: .none)
        let data = try await client.post(
            url: url,
            body: bodyData,
            auth: .anthropicHeader(apiKey),
            extraHeaders: ["anthropic-version": "2023-06-01"]
        )
        let text = try Self.parseClaudeResponse(data)

        let elapsed = start.duration(to: .now)
        let ms = UInt64(elapsed.components.seconds * 1000)
            + UInt64(elapsed.components.attoseconds / 1_000_000_000_000_000)

        return ProcessingOutput(text: text, processingTimeMs: ms)
    }

    public func healthCheck() async -> Bool {
        !apiKey.isEmpty
    }

    /// Parse Anthropic Messages API response.
    static func parseClaudeResponse(_ data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let first = content.first,
              let text = first["text"] as? String
        else {
            throw MurmurError.llm("Failed to parse Claude response")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
