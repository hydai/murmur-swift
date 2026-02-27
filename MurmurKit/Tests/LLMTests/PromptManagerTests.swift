import Foundation
import Testing
@testable import MurmurKit

@Suite("PromptManager")
struct PromptManagerTests {
    @Test("All templates include Chinese Language Rule")
    func allTemplatesIncludeChineseRule() {
        let templates = [
            PromptManager.postProcessTemplate,
            PromptManager.shortenTemplate,
            PromptManager.changeToneTemplate,
            PromptManager.generateReplyTemplate,
            PromptManager.translateTemplate,
        ]

        for template in templates {
            #expect(template.contains("繁體中文"))
            #expect(template.contains("台灣用語"))
        }
    }

    @Test("Post-process template includes Preserve Original Language")
    func postProcessIncludesPreserveOriginalLanguage() {
        #expect(PromptManager.postProcessTemplate.contains("Preserve Original Language"))
        #expect(PromptManager.postProcessTemplate.contains("Do not translate, transliterate, or anglicize"))
    }

    @Test("Post-process template includes non-English misrecognition guard")
    func postProcessIncludesMisrecognitionGuard() {
        #expect(PromptManager.postProcessTemplate.contains("do not \"correct\" them into English"))
    }
}
