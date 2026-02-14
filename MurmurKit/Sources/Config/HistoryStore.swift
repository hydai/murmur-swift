import Foundation

/// Persists transcription history as JSON.
public actor HistoryStore {
    private var entries: [HistoryEntry] = []
    private let fileURL: URL
    private let maxEntries: Int

    public init(fileURL: URL? = nil, maxEntries: Int = 500) {
        self.fileURL = fileURL ?? Self.defaultFileURL
        self.maxEntries = maxEntries
    }

    public static var defaultFileURL: URL {
        ConfigManager.defaultDirectory.appendingPathComponent("history.json")
    }

    public func load() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        entries = try decoder.decode([HistoryEntry].self, from: data)
    }

    public func save() throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(entries)
        try data.write(to: fileURL, options: .atomic)
    }

    public func add(_ entry: HistoryEntry) throws {
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        try save()
    }

    public func getAll() -> [HistoryEntry] {
        entries
    }

    public func delete(id: UUID) throws {
        entries.removeAll { $0.id == id }
        try save()
    }

    public func clear() throws {
        entries.removeAll()
        try save()
    }

    public func search(_ query: String) -> [HistoryEntry] {
        guard !query.isEmpty else { return entries }
        let lowered = query.lowercased()
        return entries.filter {
            $0.rawText.lowercased().contains(lowered) ||
            $0.processedText.lowercased().contains(lowered) ||
            ($0.command?.lowercased().contains(lowered) ?? false)
        }
    }
}
