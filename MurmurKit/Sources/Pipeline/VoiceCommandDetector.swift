import Foundation

/// Protocol for individual voice command parsers.
protocol VoiceCommandParser: Sendable {
    /// Attempts to parse a transcription into a specific ProcessingTask.
    /// Returns the task and the command name if matched, otherwise nil.
    func parse(transcription: String) -> (ProcessingTask, String)?
}

/// Parses voice commands using a registered list of strategies.
/// Supported commands include:
/// - Shorten: `shorten this: <text>`, `shorten: <text>`
/// - Formal Tone: `make it formal: <text>`, `formalize: <text>`, `make this formal: <text>`
/// - Casual Tone: `make it casual: <text>`, `casualize: <text>`, `make this casual: <text>`
/// - Reply: `reply to: <text>`, `generate reply: <text>`, `reply to this: <text>`
/// - Translate: `translate to <language>: <text>`
public struct VoiceCommandDetector: Sendable {
    private let parsers: [any VoiceCommandParser]

    public init() {
        self.parsers = [
            PrefixRegexCommandParser(
                pattern: "^(?:shorten this|shorten)\\s*:\\s*(.*)$",
                commandName: "shorten",
                taskBuilder: { .shorten(text: $0) }
            ),
            PrefixRegexCommandParser(
                pattern: "^(?:make it formal|formalize|make this formal)\\s*:\\s*(.*)$",
                commandName: "formal",
                taskBuilder: { .changeTone(text: $0, targetTone: "formal") }
            ),
            PrefixRegexCommandParser(
                pattern: "^(?:make it casual|casualize|make this casual)\\s*:\\s*(.*)$",
                commandName: "casual",
                taskBuilder: { .changeTone(text: $0, targetTone: "casual") }
            ),
            PrefixRegexCommandParser(
                pattern: "^(?:reply to|generate reply|reply to this)\\s*:\\s*(.*)$",
                commandName: "reply",
                taskBuilder: { .generateReply(context: $0) }
            ),
            TranslateCommandParser()
        ]
    }

    /// Detect a voice command from transcription text.
    public func detect(
        transcription: String,
        dictionaryTerms: [String] = []
    ) -> (task: ProcessingTask, commandName: String?) {
        let trimmed = transcription.trimmingCharacters(in: .whitespaces)

        for parser in parsers {
            if let result = parser.parse(transcription: trimmed) {
                return (result.0, result.1)
            }
        }

        return (.postProcess(text: transcription, dictionaryTerms: dictionaryTerms), nil)
    }
}

// MARK: - Parser Implementations

/// A generalized parser using regular expressions to match a prefix and extract the trailing text.
private struct PrefixRegexCommandParser: VoiceCommandParser {
    let regex: NSRegularExpression
    let commandName: String
    let taskBuilder: @Sendable (String) -> ProcessingTask
    init(pattern: String, commandName: String, taskBuilder: @escaping @Sendable (String) -> ProcessingTask) {
        do {
            self.regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        } catch {
            preconditionFailure("Invalid regex pattern '\(pattern)': \(error)")
        }
        self.commandName = commandName
        self.taskBuilder = taskBuilder
    }

    func parse(transcription: String) -> (ProcessingTask, String)? {
        let nsString = transcription as NSString
        let match = regex.firstMatch(in: transcription, range: NSRange(location: 0, length: nsString.length))
        
        guard let match = match, match.numberOfRanges > 1 else { return nil }
        let textRange = match.range(at: 1)
        guard textRange.location != NSNotFound else { return nil }
        
        let extractedText = nsString.substring(with: textRange).trimmingCharacters(in: .whitespaces)
        return (taskBuilder(extractedText), commandName)
    }
}

/// Specific parser for translation commands.
private struct TranslateCommandParser: VoiceCommandParser {
    let regex: NSRegularExpression

    init() {
        do {
            self.regex = try NSRegularExpression(pattern: "^translate to\\s+([^:]+)\\s*:\\s*(.*)$", options: [.caseInsensitive, .dotMatchesLineSeparators])
        } catch {
            preconditionFailure("Invalid regex pattern for TranslateCommandParser: \(error)")
        }
    }
    func parse(transcription: String) -> (ProcessingTask, String)? {
        let nsString = transcription as NSString
        let match = regex.firstMatch(in: transcription, range: NSRange(location: 0, length: nsString.length))
        
        guard let match = match, match.numberOfRanges > 2 else { return nil }
        
        let langRange = match.range(at: 1)
        let textRange = match.range(at: 2)
        
        guard langRange.location != NSNotFound, textRange.location != NSNotFound else { return nil }
        
        let language = nsString.substring(with: langRange).trimmingCharacters(in: .whitespaces)
        let extractedText = nsString.substring(with: textRange).trimmingCharacters(in: .whitespaces)
        
        return (.translate(text: extractedText, targetLanguage: language), "translate")
    }
}
