import Foundation

/// A rich dictionary entry with optional alias and description.
public struct DictionaryEntry: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public var term: String
    public var alias: String?
    public var description: String?

    public init(id: UUID = UUID(), term: String, alias: String? = nil, description: String? = nil) {
        self.id = id
        self.term = term
        self.alias = alias
        self.description = description
    }
}

/// Custom terms for STT/LLM post-processing.
public struct PersonalDictionary: Codable, Sendable {
    /// Legacy flat list of custom terms.
    public var terms: [String]
    /// Rich dictionary entries with aliases and descriptions.
    public var entries: [DictionaryEntry]

    public init(terms: [String] = [], entries: [DictionaryEntry] = []) {
        self.terms = terms
        self.entries = entries
    }

    /// Merges legacy terms + entry terms/aliases into a flat list for prompt injection.
    public var allTermStrings: [String] {
        var result = terms
        for entry in entries {
            if !result.contains(entry.term) {
                result.append(entry.term)
            }
            if let alias = entry.alias, !alias.isEmpty, !result.contains(alias) {
                result.append(alias)
            }
        }
        return result
    }

    /// Case-insensitive partial match on term, alias, and description.
    public func search(_ query: String) -> [DictionaryEntry] {
        let q = query.lowercased()
        return entries.filter { entry in
            entry.term.lowercased().contains(q)
                || (entry.alias?.lowercased().contains(q) ?? false)
                || (entry.description?.lowercased().contains(q) ?? false)
        }
    }

    // Custom decoder for backward compatibility — existing config files
    // without `entries` will load cleanly with an empty array.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        terms = try container.decode([String].self, forKey: .terms)
        entries = try container.decodeIfPresent([DictionaryEntry].self, forKey: .entries) ?? []
    }
}
