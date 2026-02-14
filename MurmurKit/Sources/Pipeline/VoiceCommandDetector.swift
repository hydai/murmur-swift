import Foundation

/// Parses voice commands from transcribed text.
///
/// Recognizes prefixes like "shorten this:", "translate to Japanese:",
/// "make it formal:", etc. and maps them to ProcessingTask variants.
public struct VoiceCommandDetector: Sendable {
    public init() {}

    /// Detect a voice command from transcription text.
    /// Returns a ProcessingTask with the appropriate command and remaining text.
    public func detect(
        transcription: String,
        dictionaryTerms: [String] = []
    ) -> (task: ProcessingTask, commandName: String?) {
        let lower = transcription.lowercased().trimmingCharacters(in: .whitespaces)

        // Shorten
        for prefix in ["shorten this:", "shorten:"] {
            if lower.hasPrefix(prefix) {
                let text = String(transcription.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                return (.shorten(text: text), "shorten")
            }
        }

        // Change tone - formal
        for prefix in ["make it formal:", "formalize:", "make this formal:"] {
            if lower.hasPrefix(prefix) {
                let text = String(transcription.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                return (.changeTone(text: text, targetTone: "formal"), "formal")
            }
        }

        // Change tone - casual
        for prefix in ["make it casual:", "casualize:", "make this casual:"] {
            if lower.hasPrefix(prefix) {
                let text = String(transcription.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                return (.changeTone(text: text, targetTone: "casual"), "casual")
            }
        }

        // Generate reply
        for prefix in ["reply to:", "generate reply:", "reply to this:"] {
            if lower.hasPrefix(prefix) {
                let context = String(transcription.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                return (.generateReply(context: context), "reply")
            }
        }

        // Translate
        if lower.hasPrefix("translate to ") {
            // Extract language and text: "translate to Japanese: some text"
            let afterPrefix = String(transcription.dropFirst("translate to ".count))
            if let colonIndex = afterPrefix.firstIndex(of: ":") {
                let language = String(afterPrefix[afterPrefix.startIndex..<colonIndex])
                    .trimmingCharacters(in: .whitespaces)
                let text = String(afterPrefix[afterPrefix.index(after: colonIndex)...])
                    .trimmingCharacters(in: .whitespaces)
                return (.translate(text: text, targetLanguage: language), "translate")
            }
        }

        // Default: post-process
        return (.postProcess(text: transcription, dictionaryTerms: dictionaryTerms), nil)
    }
}
