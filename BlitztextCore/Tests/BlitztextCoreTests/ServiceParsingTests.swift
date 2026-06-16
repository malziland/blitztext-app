import XCTest
@testable import BlitztextCore

final class ServiceParsingTests: XCTestCase {
    // MARK: - LLMService.chatRequestBody

    func testChatRequestBodyContainsModelMessagesTemperature() throws {
        let body = try LLMService.chatRequestBody(
            model: "gpt-4o-mini",
            systemPrompt: "SYS",
            userText: "USR",
            temperature: 0.3
        )
        let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]
        XCTAssertEqual(json["model"] as? String, "gpt-4o-mini")
        XCTAssertEqual(json["temperature"] as? Double, 0.3)
        let messages = json["messages"] as! [[String: String]]
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0]["role"], "system")
        XCTAssertEqual(messages[0]["content"], "SYS")
        XCTAssertEqual(messages[1]["role"], "user")
        XCTAssertEqual(messages[1]["content"], "USR")
    }

    // MARK: - LLMService.parseChatContent

    func testParseChatContentSuccessTrimsWhitespace() throws {
        let data = Data(#"{"choices":[{"message":{"content":"  verbessert \n"}}]}"#.utf8)
        XCTAssertEqual(try LLMService.parseChatContent(status: 200, data: data), "verbessert")
    }

    func testParseChatContentEmptyThrowsNoContent() {
        let data = Data(#"{"choices":[{"message":{"content":"   "}}]}"#.utf8)
        XCTAssertThrowsError(try LLMService.parseChatContent(status: 200, data: data)) { error in
            guard case LLMError.noContent = error else { return XCTFail("expected noContent, got \(error)") }
        }
    }

    func testParseChatContentMissingChoicesThrowsNoContent() {
        let data = Data(#"{"choices":[]}"#.utf8)
        XCTAssertThrowsError(try LLMService.parseChatContent(status: 200, data: data)) { error in
            guard case LLMError.noContent = error else { return XCTFail("expected noContent, got \(error)") }
        }
    }

    func testParseChatContentErrorStatusExtractsMessage() {
        let data = Data(#"{"error":{"message":"bad request"}}"#.utf8)
        XCTAssertThrowsError(try LLMService.parseChatContent(status: 400, data: data)) { error in
            guard case LLMError.apiError(let message) = error else { return XCTFail("expected apiError, got \(error)") }
            XCTAssertEqual(message, "bad request")
        }
    }

    func testParseChatContentErrorStatusFallsBackToStatusCode() {
        XCTAssertThrowsError(try LLMService.parseChatContent(status: 500, data: Data())) { error in
            guard case LLMError.apiError(let message) = error else { return XCTFail("expected apiError, got \(error)") }
            XCTAssertEqual(message, "Status 500")
        }
    }

    // MARK: - TranscriptionService.parseTranscription

    func testParseTranscriptionSuccessTrims() throws {
        let data = Data("  hallo welt \n".utf8)
        XCTAssertEqual(try TranscriptionService.parseTranscription(status: 200, data: data), "hallo welt")
    }

    func testParseTranscriptionEmptyThrows() {
        XCTAssertThrowsError(try TranscriptionService.parseTranscription(status: 200, data: Data("   ".utf8))) { error in
            guard case TranscriptionError.apiError(let message) = error else { return XCTFail("expected apiError, got \(error)") }
            XCTAssertEqual(message, "Transkription fehlgeschlagen")
        }
    }

    func testParseTranscriptionErrorStatusExtractsMessage() {
        let data = Data(#"{"error":{"message":"rate limited"}}"#.utf8)
        XCTAssertThrowsError(try TranscriptionService.parseTranscription(status: 429, data: data)) { error in
            guard case TranscriptionError.apiError(let message) = error else { return XCTFail("expected apiError, got \(error)") }
            XCTAssertEqual(message, "rate limited")
        }
    }

    func testParseTranscriptionErrorStatusFallback() {
        XCTAssertThrowsError(try TranscriptionService.parseTranscription(status: 503, data: Data())) { error in
            guard case TranscriptionError.apiError(let message) = error else { return XCTFail("expected apiError, got \(error)") }
            XCTAssertEqual(message, "Status 503")
        }
    }

    // MARK: - Error descriptions

    func testErrorDescriptionsAreNonEmpty() {
        let llmErrors: [LLMError] = [.notConfigured, .networkError("x"), .apiError("y"), .noContent]
        for error in llmErrors {
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
        let transcriptionErrors: [TranscriptionError] = [.noFile, .notConfigured, .networkError("x"), .apiError("y")]
        for error in transcriptionErrors {
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
        XCTAssertNotNil(KeychainError.saveFailed(-1).errorDescription)
    }
}
