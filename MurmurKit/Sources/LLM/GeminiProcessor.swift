import Foundation

/// LLM processor using the Gemini CLI tool via subprocess. macOS only.
public actor GeminiProcessor: LlmProcessor {
    private let executor: CliExecutor
    private let promptManager = PromptManager()
    private let model: String

    public init(model: String = "gemini-2.5-flash", timeoutSeconds: TimeInterval = 30) {
        self.model = model
        self.executor = CliExecutor(timeoutSeconds: timeoutSeconds)
    }

    public func process(_ task: ProcessingTask) async throws -> ProcessingOutput {
        let (instructions, prompt) = promptManager.buildPrompt(for: task)
        let fullPrompt = "\(instructions)\n\n## Input\n\n\(prompt)"
        let start = ContinuousClock.now

        let output = try await executor.execute(
            program: "gemini",
            arguments: ["-p", fullPrompt, "--output-format", "json", "-m", model]
        )

        guard output.exitCode == 0 else {
            throw MurmurError.llm("Gemini CLI exited with code \(output.exitCode): \(output.stderr)")
        }

        let text = parseGeminiOutput(output.stdout)
        let elapsed = start.duration(to: .now)
        let ms = UInt64(elapsed.components.seconds * 1000)
            + UInt64(elapsed.components.attoseconds / 1_000_000_000_000_000)

        return ProcessingOutput(text: text, processingTimeMs: ms)
    }

    public func healthCheck() async -> Bool {
        await executor.isAvailable(program: "gemini")
    }

    /// Parse Gemini JSON output, with fallback to plain text.
    private func parseGeminiOutput(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return trimmed
        }

        // Try common JSON keys
        for key in ["text", "content", "response"] {
            if let value = json[key] as? String {
                return value
            }
        }

        return trimmed
    }
}
