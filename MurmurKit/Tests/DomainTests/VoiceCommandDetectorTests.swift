import Testing
@testable import MurmurKit

@Suite("VoiceCommandDetector")
struct VoiceCommandDetectorTests {
    let detector = VoiceCommandDetector()

    @Test("Default to postProcess when no command detected")
    func defaultPostProcess() {
        let (task, command) = detector.detect(transcription: "Hello world")
        #expect(command == nil)
        if case .postProcess(let text, _) = task {
            #expect(text == "Hello world")
        } else {
            Issue.record("Expected postProcess task")
        }
    }

    @Test("Detect shorten command")
    func shortenCommand() {
        let (task, command) = detector.detect(transcription: "shorten this: I was wondering if perhaps")
        #expect(command == "shorten")
        if case .shorten(let text) = task {
            #expect(text == "I was wondering if perhaps")
        } else {
            Issue.record("Expected shorten task")
        }
    }

    @Test("Detect formal tone command")
    func formalToneCommand() {
        let (task, command) = detector.detect(transcription: "make it formal: hey what's up")
        #expect(command == "formal")
        if case .changeTone(let text, let tone) = task {
            #expect(text == "hey what's up")
            #expect(tone == "formal")
        } else {
            Issue.record("Expected changeTone task")
        }
    }

    @Test("Detect translate command")
    func translateCommand() {
        let (task, command) = detector.detect(transcription: "translate to Japanese: good morning")
        #expect(command == "translate")
        if case .translate(let text, let language) = task {
            #expect(text == "good morning")
            #expect(language == "Japanese")
        } else {
            Issue.record("Expected translate task")
        }
    }

    @Test("Detect reply command")
    func replyCommand() {
        let (task, command) = detector.detect(transcription: "reply to: can you join the meeting?")
        #expect(command == "reply")
        if case .generateReply(let context) = task {
            #expect(context == "can you join the meeting?")
        } else {
            Issue.record("Expected generateReply task")
        }
    }
}
