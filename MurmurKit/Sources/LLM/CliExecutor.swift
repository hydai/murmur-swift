import Foundation

/// Output from a CLI subprocess.
public struct CliOutput: Sendable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32
}

/// Spawns CLI subprocesses with timeout handling. macOS only.
public struct CliExecutor: Sendable {
    public let timeoutSeconds: TimeInterval

    public init(timeoutSeconds: TimeInterval = 30) {
        self.timeoutSeconds = timeoutSeconds
    }

    /// Execute a CLI command and capture output.
    public func execute(program: String, arguments: [String]) async throws -> CliOutput {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [program] + arguments

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            // Timeout handler
            let timer = DispatchSource.makeTimerSource()
            timer.schedule(deadline: .now() + timeoutSeconds)
            timer.setEventHandler {
                process.terminate()
            }
            timer.resume()

            do {
                try process.run()
                process.waitUntilExit()
                timer.cancel()

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                let output = CliOutput(
                    stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                    stderr: String(data: stderrData, encoding: .utf8) ?? "",
                    exitCode: process.terminationStatus
                )
                continuation.resume(returning: output)
            } catch {
                timer.cancel()
                continuation.resume(throwing: MurmurError.llm("Failed to execute \(program): \(error.localizedDescription)"))
            }
        }
    }

    /// Check if a CLI program is available in PATH.
    public func isAvailable(program: String) async -> Bool {
        do {
            let output = try await execute(program: "which", arguments: [program])
            return output.exitCode == 0
        } catch {
            return false
        }
    }
}
