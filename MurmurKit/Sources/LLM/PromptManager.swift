import Foundation

/// Builds prompts from embedded markdown templates for each ProcessingTask.
public struct PromptManager: Sendable {
    public init() {}

    /// Build the full prompt string for a given task.
    public func buildPrompt(for task: ProcessingTask) -> (instructions: String, prompt: String) {
        switch task {
        case .postProcess(let text, let dictionaryTerms):
            let termsStr = dictionaryTerms.isEmpty
                ? "No custom terms defined."
                : dictionaryTerms.joined(separator: ", ")
            let instructions = Self.postProcessTemplate
                .replacingOccurrences(of: "{dictionary_terms}", with: termsStr)
            return (instructions, text)

        case .shorten(let text):
            return (Self.shortenTemplate, text)

        case .changeTone(let text, let targetTone):
            let instructions = Self.changeToneTemplate
                .replacingOccurrences(of: "{tone}", with: targetTone)
            return (instructions, text)

        case .generateReply(let context):
            return (Self.generateReplyTemplate, context)

        case .translate(let text, let targetLanguage):
            let instructions = Self.translateTemplate
                .replacingOccurrences(of: "{language}", with: targetLanguage)
            return (instructions, text)
        }
    }

    // MARK: - Embedded templates

    static let postProcessTemplate = """
        # Post-Process Transcription

        You are a transcription post-processor. Your task is to clean up raw voice-to-text output into polished, natural written text.

        ## Instructions

        ### 1. Remove Filler Words and Verbal Tics

        Remove all filler words, hesitation sounds, and discourse markers, including but not limited to:
        - Hesitation sounds: "um", "uh", "hmm", "ah", "er", "mm"
        - Discourse markers: "like", "you know", "I mean", "so", "well", "right", "okay", "basically", "actually", "literally", "honestly", "obviously"
        - Stalling phrases: "let me think", "how do I say this", "what's the word"

        ### 2. Fix STT Misrecognitions

        Speech-to-text engines frequently mishear words. Identify and correct phonetically similar misrecognitions by inferring the intended word from context.

        ### 3. Remove Duplications and Repetitions

        Remove stuttered or repeated words and phrases. Keep only the clearest version of restated sentences.

        ### 4. Reconstruct Fragmented Sentences

        Merge fragments into complete, coherent sentences while preserving the speaker's intent.

        ### 5. Fix Grammar and Punctuation

        Correct grammatical errors, add proper punctuation, capitalization, and sentence boundaries.

        ### 6. Preserve Meaning and Tone

        The cleaned text must faithfully represent the speaker's intent. Do not add, invent, or editorialize content.

        ### 7. Apply Personal Dictionary

        When the transcription contains words phonetically close to terms in the personal dictionary, prefer the dictionary term.

        ## Personal Dictionary Terms

        {dictionary_terms}

        ## Output

        Return only the cleaned text, without any explanation or metadata.
        """

    static let shortenTemplate = """
        # Shorten Text

        You are a text summarization assistant. Your task is to shorten the given text while preserving its core meaning.

        ## Instructions

        1. Condense the text to be more concise
        2. Remove redundancy
        3. Keep essential information
        4. Maintain clarity and readability

        ## Output

        Return only the shortened text, without any explanation or metadata.
        """

    static let changeToneTemplate = """
        # Change Tone

        You are a text tone adjustment assistant. Your task is to rewrite the given text in a different tone while preserving the meaning.

        ## Target Tone

        {tone}

        ## Instructions

        1. Rewrite the text to match the target tone
        2. Preserve the core message and information
        3. Adjust vocabulary and phrasing appropriately
        4. Maintain natural language flow

        ## Output

        Return only the rewritten text, without any explanation or metadata.
        """

    static let generateReplyTemplate = """
        # Generate Reply

        You are a reply generation assistant. Your task is to generate an appropriate response based on the given context.

        ## Instructions

        1. Analyze the context carefully
        2. Generate a relevant and appropriate reply
        3. Match the tone and style of the context
        4. Keep the response concise and to the point

        ## Output

        Return only the generated reply, without any explanation or metadata.
        """

    static let translateTemplate = """
        # Translate Text

        You are a translation assistant. Your task is to translate the given text to the target language.

        ## Target Language

        {language}

        ## Instructions

        1. Translate the text accurately
        2. Maintain the original tone and style
        3. Use natural language in the target language
        4. Preserve formatting when possible

        ## Output

        Return only the translated text, without any explanation or metadata.
        """
}
