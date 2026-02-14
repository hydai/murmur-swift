import Foundation

/// How processed text is delivered to the user.
public enum OutputMode: String, Codable, Sendable, CaseIterable {
    case clipboard
    case keyboard
    case both
}
