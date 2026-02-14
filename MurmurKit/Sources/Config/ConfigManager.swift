import Foundation

/// Reads and writes AppConfig as JSON.
public actor ConfigManager {
    private var config: AppConfig
    private let fileURL: URL

    /// Default config directory: ~/Library/Application Support/com.hydai.Murmur/
    public static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.hydai.Murmur", isDirectory: true)
    }

    /// Default config file path.
    public static var defaultFileURL: URL {
        defaultDirectory.appendingPathComponent("config.json")
    }

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
        self.config = AppConfig()
    }

    /// Load config from disk, or use defaults if file doesn't exist.
    public func load() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return // Use defaults
        }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        config = try decoder.decode(AppConfig.self, from: data)
    }

    /// Save current config to disk.
    public func save() throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Get current config.
    public func getConfig() -> AppConfig {
        config
    }

    /// Update config and save.
    public func update(_ transform: (inout AppConfig) -> Void) throws {
        transform(&config)
        try save()
    }
}
