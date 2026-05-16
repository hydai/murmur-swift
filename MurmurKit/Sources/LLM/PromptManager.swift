import Foundation

/// Builds prompts for `ProcessingTask`s using a `PromptSet`.
///
/// Templates come from `PromptName.defaultTemplate` unless the supplied
/// `PromptSet` carries an override. The substitution layer (placeholders
/// like `{dictionary_terms}`, `{tone}`, `{language}`) is identical to the
/// pre-override behaviour.
public struct PromptManager: Sendable {
    private let set: PromptSet

    public init(set: PromptSet = PromptSet()) {
        self.set = set
    }

    /// Build the full prompt string for a given task.
    public func buildPrompt(for task: ProcessingTask) -> (instructions: String, prompt: String) {
        switch task {
        case .postProcess(let text, let dictionaryTerms):
            let termsStr = dictionaryTerms.isEmpty
                ? "No custom terms defined."
                : dictionaryTerms.joined(separator: ", ")
            let instructions = set.get(.postProcess)
                .replacingOccurrences(of: "{dictionary_terms}", with: termsStr)
            return (instructions, text)

        case .shorten(let text):
            return (set.get(.shorten), text)

        case .changeTone(let text, let targetTone):
            let instructions = set.get(.changeTone)
                .replacingOccurrences(of: "{tone}", with: targetTone)
            return (instructions, text)

        case .generateReply(let context):
            return (set.get(.generateReply), context)

        case .translate(let text, let targetLanguage):
            let instructions = set.get(.translate)
                .replacingOccurrences(of: "{language}", with: targetLanguage)
            return (instructions, text)
        }
    }
}
