import Foundation

/// LLM processor using the GitHub Copilot CLI via subprocess. macOS only.
public actor CopilotProcessor: LlmProcessor {
    private let executor: CliExecutor
    private let promptManager = PromptManager()
    private let model: String

    public init(model: String = "gpt-5-mini", timeoutSeconds: TimeInterval = 30) {
        self.model = model
        self.executor = CliExecutor(timeoutSeconds: timeoutSeconds)
    }

    public func process(_ task: ProcessingTask) async throws -> ProcessingOutput {
        let (instructions, prompt) = promptManager.buildPrompt(for: task)
        let fullPrompt = "\(instructions)\n\n## Input\n\n\(prompt)"
        let start = ContinuousClock.now

        let output = try await executor.execute(
            program: "copilot",
            arguments: ["--prompt", fullPrompt, "--model", model]
        )

        guard output.exitCode == 0 else {
            throw MurmurError.llm("Copilot CLI exited with code \(output.exitCode): \(output.stderr)")
        }

        let text = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let elapsed = start.duration(to: .now)
        let ms = UInt64(elapsed.components.seconds * 1000)
            + UInt64(elapsed.components.attoseconds / 1_000_000_000_000_000)

        return ProcessingOutput(text: text, processingTimeMs: ms)
    }

    public func healthCheck() async -> Bool {
        await executor.isAvailable(program: "copilot")
    }
}
