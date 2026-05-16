import Foundation
import Testing
@testable import MurmurKit

@Suite("PromptManager")
struct PromptManagerTests {
    @Test("All default templates include the Chinese Language Rule")
    func allTemplatesIncludeChineseRule() {
        for name in PromptName.allCases {
            let template = name.defaultTemplate
            #expect(template.contains("繁體中文"), "template \(name) missing 繁體中文")
            #expect(template.contains("台灣用語"), "template \(name) missing 台灣用語")
        }
    }

    @Test("Post-process template includes Preserve Original Language")
    func postProcessIncludesPreserveOriginalLanguage() {
        let t = PromptName.postProcess.defaultTemplate
        #expect(t.contains("Preserve Original Language"))
        #expect(t.contains("Do not translate, transliterate, or anglicize"))
    }

    @Test("Post-process template includes non-English misrecognition guard")
    func postProcessIncludesMisrecognitionGuard() {
        #expect(PromptName.postProcess.defaultTemplate.contains("do not \"correct\" them into English"))
    }

    @Test("Default PromptManager substitutes dictionary terms")
    func substitutesDictionaryTerms() {
        let manager = PromptManager()
        let (instructions, prompt) = manager.buildPrompt(
            for: .postProcess(text: "raw", dictionaryTerms: ["foo", "bar"])
        )
        #expect(prompt == "raw")
        #expect(instructions.contains("foo, bar"))
        #expect(!instructions.contains("{dictionary_terms}"))
    }

    @Test("Empty dictionary substitutes the no-terms placeholder")
    func substitutesEmptyDictionary() {
        let manager = PromptManager()
        let (instructions, _) = manager.buildPrompt(
            for: .postProcess(text: "raw", dictionaryTerms: [])
        )
        #expect(instructions.contains("No custom terms defined."))
    }

    @Test("Override is preferred over default when present")
    func overrideTakesPrecedence() {
        var set = PromptSet()
        set.setOverride(.shorten, content: "CUSTOM SHORTEN PROMPT")
        let manager = PromptManager(set: set)
        let (instructions, _) = manager.buildPrompt(for: .shorten(text: "x"))
        #expect(instructions == "CUSTOM SHORTEN PROMPT")
    }

    @Test("Override still has placeholders substituted")
    func overrideSubstitutesPlaceholders() {
        var set = PromptSet()
        set.setOverride(.changeTone, content: "Make this {tone}: input follows")
        let manager = PromptManager(set: set)
        let (instructions, _) = manager.buildPrompt(
            for: .changeTone(text: "hi", targetTone: "formal")
        )
        #expect(instructions == "Make this formal: input follows")
    }
}
