import Foundation

/// Disk persistence for user prompt overrides.
///
/// Layout (mirrors Rust `crates/lt-llm/src/prompt_store.rs`):
/// `{configDir}/prompts/{name}.md` — missing files mean "no override".
public enum PromptStore {
    public static let subdirectory = "prompts"

    public static func directory(in configDir: URL) -> URL {
        configDir.appendingPathComponent(subdirectory, isDirectory: true)
    }

    public static func file(for name: PromptName, in configDir: URL) -> URL {
        directory(in: configDir).appendingPathComponent("\(name.fileStem).md")
    }

    /// Load every override that exists on disk into a fresh `PromptSet`.
    /// Missing directory or missing individual files are treated as
    /// "no override" — other I/O errors propagate.
    public static func loadAll(configDir: URL) throws -> PromptSet {
        var set = PromptSet()
        let dir = directory(in: configDir)
        guard FileManager.default.fileExists(atPath: dir.path) else {
            return set
        }
        for name in PromptName.allCases {
            let url = file(for: name, in: configDir)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let content = try String(contentsOf: url, encoding: .utf8)
            set.setOverride(name, content: content)
        }
        return set
    }

    public static func save(_ name: PromptName, content: String, in configDir: URL) throws {
        let dir = directory(in: configDir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try content.write(to: file(for: name, in: configDir), atomically: true, encoding: .utf8)
    }

    /// Remove an override from disk. Missing files are a no-op (matches the
    /// Rust implementation, which swallows `NotFound`).
    public static func reset(_ name: PromptName, in configDir: URL) throws {
        let url = file(for: name, in: configDir)
        do {
            try FileManager.default.removeItem(at: url)
        } catch CocoaError.fileNoSuchFile {
            return
        } catch let error as NSError where error.domain == NSCocoaErrorDomain
            && error.code == NSFileNoSuchFileError {
            return
        }
    }
}
