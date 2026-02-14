import Foundation

/// Custom terms for STT/LLM post-processing.
public struct PersonalDictionary: Codable, Sendable {
    /// Custom terms the user frequently uses (domain-specific words).
    public var terms: [String]

    public init(terms: [String] = []) {
        self.terms = terms
    }
}
