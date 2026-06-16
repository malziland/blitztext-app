import XCTest
@testable import BlitztextCore

final class TranscriptionServiceNetworkTests: XCTestCase {
    private func http(_ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://api.openai.com")!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    func testSendReturnsTrimmedTextOnSuccess() async throws {
        let result = try await TranscriptionService.send(
            audioData: Data("audio".utf8),
            apiKey: "test-key",
            customTerms: ["malziland"],
            language: "de",
            transport: { _ in (Data("  hallo welt \n".utf8), self.http(200)) }
        )
        XCTAssertEqual(result, "hallo welt")
    }

    func testSendSetsAuthorizationAndMultipartBody() async throws {
        let box = RequestBox()
        _ = try await TranscriptionService.send(
            audioData: Data("audio".utf8),
            apiKey: "secret-9",
            customTerms: [],
            language: nil,
            transport: { request in box.value = request; return (Data("x".utf8), self.http(200)) }
        )
        XCTAssertEqual(box.value?.value(forHTTPHeaderField: "Authorization"), "Bearer secret-9")
        let contentType = box.value?.value(forHTTPHeaderField: "Content-Type") ?? ""
        XCTAssertTrue(contentType.hasPrefix("multipart/form-data; boundary="))
        let body = String(decoding: box.value?.httpBody ?? Data(), as: UTF8.self)
        XCTAssertTrue(body.contains("whisper-1"))
    }

    func testSendThrowsApiErrorOnBadStatus() async {
        do {
            _ = try await TranscriptionService.send(
                audioData: Data(), apiKey: "k", customTerms: [], language: nil,
                transport: { _ in (Data(), self.http(500)) }
            )
            XCTFail("expected throw")
        } catch {
            guard case TranscriptionError.apiError(let message) = error else { return XCTFail("got \(error)") }
            XCTAssertEqual(message, "Status 500")
        }
    }

    func testSendThrowsNetworkErrorOnNonHTTPResponse() async {
        let response = URLResponse(url: URL(string: "https://x")!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        do {
            _ = try await TranscriptionService.send(
                audioData: Data(), apiKey: "k", customTerms: [], language: nil,
                transport: { _ in (Data(), response) }
            )
            XCTFail("expected throw")
        } catch {
            guard case TranscriptionError.networkError = error else { return XCTFail("got \(error)") }
        }
    }
}

private final class RequestBox {
    var value: URLRequest?
}
