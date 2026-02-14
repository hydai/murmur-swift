import Foundation

/// All error types for the Murmur application.
public enum MurmurError: Error, Sendable {
    case audio(String)
    case stt(String)
    case llm(String)
    case config(String)
    case output(String)
    case permission(String)
    case invalidState(String)
    case io(String)
    case network(String)
}

extension MurmurError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .audio(let msg): "Audio error: \(msg)"
        case .stt(let msg): "STT error: \(msg)"
        case .llm(let msg): "LLM error: \(msg)"
        case .config(let msg): "Config error: \(msg)"
        case .output(let msg): "Output error: \(msg)"
        case .permission(let msg): "Permission error: \(msg)"
        case .invalidState(let msg): "Invalid state: \(msg)"
        case .io(let msg): "IO error: \(msg)"
        case .network(let msg): "Network error: \(msg)"
        }
    }
}
