import Foundation
import Testing
@testable import MurmurKit

@Suite("HTTP LLM Processors")
struct HttpLlmTests {

    // MARK: - OpenAI Response Parsing

    @Test("Parse valid OpenAI response")
    func parseOpenAIResponse() throws {
        let json = """
        {
            "choices": [
                {
                    "message": {
                        "role": "assistant",
                        "content": "Hello, world!"
                    },
                    "index": 0
                }
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let result = try OpenAILlmProcessor.parseOpenAIResponse(data)
        #expect(result == "Hello, world!")
    }

    @Test("OpenAI response trims whitespace")
    func parseOpenAIResponseTrimsWhitespace() throws {
        let json = """
        {
            "choices": [
                {
                    "message": {
                        "role": "assistant",
                        "content": "  trimmed  \\n"
                    },
                    "index": 0
                }
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let result = try OpenAILlmProcessor.parseOpenAIResponse(data)
        #expect(result == "trimmed")
    }

    @Test("OpenAI response with malformed JSON throws")
    func parseOpenAIResponseMalformed() {
        let json = """
        {"not_choices": []}
        """
        let data = json.data(using: .utf8)!
        #expect(throws: MurmurError.self) {
            try OpenAILlmProcessor.parseOpenAIResponse(data)
        }
    }

    // MARK: - Claude Response Parsing

    @Test("Parse valid Claude response")
    func parseClaudeResponse() throws {
        let json = """
        {
            "content": [
                {
                    "type": "text",
                    "text": "Here is the response."
                }
            ],
            "model": "claude-sonnet-4-20250514",
            "role": "assistant"
        }
        """
        let data = json.data(using: .utf8)!
        let result = try ClaudeLlmProcessor.parseClaudeResponse(data)
        #expect(result == "Here is the response.")
    }

    @Test("Claude response with malformed JSON throws")
    func parseClaudeResponseMalformed() {
        let json = """
        {"content": "not_an_array"}
        """
        let data = json.data(using: .utf8)!
        #expect(throws: MurmurError.self) {
            try ClaudeLlmProcessor.parseClaudeResponse(data)
        }
    }

    // MARK: - Gemini API Response Parsing

    @Test("Parse valid Gemini API response")
    func parseGeminiResponse() throws {
        let json = """
        {
            "candidates": [
                {
                    "content": {
                        "parts": [
                            {"text": "Gemini says hello."}
                        ],
                        "role": "model"
                    }
                }
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let result = try GeminiApiProcessor.parseGeminiResponse(data)
        #expect(result == "Gemini says hello.")
    }

    @Test("Gemini API response with malformed JSON throws")
    func parseGeminiResponseMalformed() {
        let json = """
        {"candidates": []}
        """
        let data = json.data(using: .utf8)!
        #expect(throws: MurmurError.self) {
            try GeminiApiProcessor.parseGeminiResponse(data)
        }
    }

    // MARK: - HttpLlmAuth

    @Test("Bearer auth creates correct header")
    func bearerAuth() {
        let auth = HttpLlmAuth.bearer("test-token")
        switch auth {
        case .bearer(let token):
            #expect(token == "test-token")
        default:
            Issue.record("Expected bearer auth")
        }
    }

    @Test("Anthropic auth creates correct header")
    func anthropicAuth() {
        let auth = HttpLlmAuth.anthropicHeader("sk-ant-test")
        switch auth {
        case .anthropicHeader(let key):
            #expect(key == "sk-ant-test")
        default:
            Issue.record("Expected anthropic auth")
        }
    }

    @Test("Query param auth builds URL correctly")
    func queryParamAuth() throws {
        let url = try HttpLlmClient.buildURL(
            base: "https://example.com/api",
            auth: .queryParam(key: "key", value: "test-key")
        )
        #expect(url.absoluteString.contains("key=test-key"))
    }

    @Test("Build URL with invalid base throws")
    func buildURLInvalid() {
        #expect(throws: MurmurError.self) {
            try HttpLlmClient.buildURL(base: "", auth: .none)
        }
    }
}
