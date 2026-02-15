import Foundation

/// LLM processor for OpenAI-compatible endpoints (Ollama, LM Studio, vLLM, etc.).
public actor CustomOpenAIProcessor: LlmProcessor {
    private let apiKey: String
    private let model: String
    private let baseURL: String
    private let client: HttpLlmClient
    private let promptManager = PromptManager()

    public init(
        apiKey: String = "",
        model: String = "llama3",
        baseURL: String = "http://localhost:11434/v1",
        timeoutSeconds: TimeInterval = 120
    ) {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
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
        let endpoint = "\(baseURL)/chat/completions"
        let url = try HttpLlmClient.buildURL(base: endpoint, auth: .none)
        let auth: HttpLlmAuth = apiKey.isEmpty ? .none : .bearer(apiKey)
        let data = try await client.post(url: url, body: bodyData, auth: auth)

        // Reuse OpenAI response format parser
        let text = try OpenAILlmProcessor.parseOpenAIResponse(data)

        let elapsed = start.duration(to: .now)
        let ms = UInt64(elapsed.components.seconds * 1000)
            + UInt64(elapsed.components.attoseconds / 1_000_000_000_000_000)

        return ProcessingOutput(text: text, processingTimeMs: ms)
    }

    public func healthCheck() async -> Bool {
        // For local models, try a lightweight request to check if the server is up
        guard let url = URL(string: "\(baseURL)/models") else { return false }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return (200...299).contains(httpResponse.statusCode)
        } catch {
            return false
        }
    }
}
