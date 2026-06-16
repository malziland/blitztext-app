import XCTest
@testable import BlitztextCore

final class TranscriptionServiceTests: XCTestCase {
    func testMultipartBodyContainsFileAndModel() {
        let body = TranscriptionService.multipartBody(
            boundary: "BOUNDARY",
            audioData: Data("audio".utf8),
            model: "whisper-1",
            customTerms: [],
            language: nil
        )
        let text = String(decoding: body, as: UTF8.self)

        XCTAssertTrue(text.contains("--BOUNDARY"))
        XCTAssertTrue(text.contains("name=\"file\"; filename=\"audio.m4a\""))
        XCTAssertTrue(text.contains("name=\"model\""))
        XCTAssertTrue(text.contains("whisper-1"))
        XCTAssertTrue(text.contains("name=\"response_format\""))
        XCTAssertTrue(text.hasSuffix("--BOUNDARY--\r\n"))
        XCTAssertFalse(text.contains("name=\"prompt\""))
        XCTAssertFalse(text.contains("name=\"language\""))
    }

    func testMultipartBodyIncludesCustomTermsAndTrimmedLanguage() {
        let body = TranscriptionService.multipartBody(
            boundary: "B",
            audioData: Data(),
            model: "whisper-1",
            customTerms: ["malziland", "Blitztext"],
            language: " de "
        )
        let text = String(decoding: body, as: UTF8.self)

        XCTAssertTrue(text.contains("name=\"prompt\""))
        XCTAssertTrue(text.contains("Eigennamen und Begriffe: malziland, Blitztext"))
        XCTAssertTrue(text.contains("name=\"language\"\r\n\r\nde\r\n"))
    }

    func testMultipartBodyOmitsBlankLanguage() {
        let body = TranscriptionService.multipartBody(
            boundary: "B",
            audioData: Data(),
            model: "whisper-1",
            customTerms: [],
            language: "   "
        )
        XCTAssertFalse(String(decoding: body, as: UTF8.self).contains("name=\"language\""))
    }

    func testRemoteModelIsWhisper1() {
        XCTAssertEqual(TranscriptionService.remoteModel, "whisper-1")
    }
}
