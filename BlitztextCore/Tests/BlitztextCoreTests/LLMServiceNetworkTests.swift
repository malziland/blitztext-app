import XCTest
@testable import BlitztextCore

final class LLMServiceNetworkTests: XCTestCase {
    private func http(_ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://api.openai.com")!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    func testCompleteReturnsContentOnSuccess() async throws {
        let data = Data(#"{"choices":[{"message":{"content":"  verbessert "}}]}"#.utf8)
        let result = try await LLMService.complete(
            text: "roh", systemPrompt: "sys", model: .fastEdit, temperature: 0.3,
            apiKey: "test-key",
            transport: { _ in (data, self.http(200)) }
        )
        XCTAssertEqual(result, "verbessert")
    }

    func testCompleteThrowsApiErrorOnBadStatus() async {
        let data = Data(#"{"error":{"message":"nope"}}"#.utf8)
        do {
            _ = try await LLMService.complete(
                text: "x", systemPrompt: "s", model: .fastEdit, temperature: 0.4,
                apiKey: "test-key",
                transport: { _ in (data, self.http(400)) }
            )
            XCTFail("expected throw")
        } catch {
            guard case LLMError.apiError(let message) = error else { return XCTFail("got \(error)") }
            XCTAssertEqual(message, "nope")
        }
    }

    func testCompleteThrowsNetworkErrorOnNonHTTPResponse() async {
        let response = URLResponse(url: URL(string: "https://x")!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        do {
            _ = try await LLMService.complete(
                text: "x", systemPrompt: "s", model: .fastEdit, temperature: 0.3,
                apiKey: "test-key",
                transport: { _ in (Data(), response) }
            )
            XCTFail("expected throw")
        } catch {
            guard case LLMError.networkError = error else { return XCTFail("got \(error)") }
        }
    }

    func testCompleteSendsBearerKeyAndModelBody() async throws {
        let data = Data(#"{"choices":[{"message":{"content":"ok"}}]}"#.utf8)
        let box = RequestBox()
        _ = try await LLMService.complete(
            text: "hallo", systemPrompt: "sys", model: .fastEdit, temperature: 0.3,
            apiKey: "secret-123",
            transport: { request in box.value = request; return (data, self.http(200)) }
        )
        XCTAssertEqual(box.value?.value(forHTTPHeaderField: "Authorization"), "Bearer secret-123")
        let bodyJSON = try JSONSerialization.jsonObject(with: box.value?.httpBody ?? Data()) as? [String: Any]
        XCTAssertEqual(bodyJSON?["model"] as? String, "gpt-4o-mini")
    }
}

private final class RequestBox {
    var value: URLRequest?
}
