import Foundation

/// Tasks that can be performed by an LLM processor.
public enum ProcessingTask: Sendable {
    /// Clean up raw transcription (default when no command detected).
    case postProcess(text: String, dictionaryTerms: [String])

    /// Shorten/condense text.
    case shorten(text: String)

    /// Rewrite text in a different tone.
    case changeTone(text: String, targetTone: String)

    /// Generate a reply to the given context.
    case generateReply(context: String)

    /// Translate text to a target language.
    case translate(text: String, targetLanguage: String)
}
