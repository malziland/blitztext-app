import Foundation

public enum TranscriptionError: LocalizedError {
    case noFile
    case notConfigured
    case networkError(String)
    case apiError(String)

    public var errorDescription: String? {
        switch self {
        case .noFile:
            return "Keine Audio-Datei gefunden"
        case .notConfigured:
            return "OpenAI API Key fehlt. Bitte in den Einstellungen hinterlegen."
        case .networkError(let msg):
            return "Netzwerkfehler: \(msg)"
        case .apiError(let msg):
            return "OpenAI-Fehler: \(msg)"
        }
    }
}

private struct TranscriptionOpenAIErrorResponse: Decodable {
    struct APIError: Decodable {
        let message: String?
    }

    let error: APIError?
}

public enum TranscriptionService {
    static let remoteModel = "whisper-1"
    private static let transcriptionsURL = URL(string: "https://api.openai.com/v1/audio/transcriptions")!

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60
        return URLSession(configuration: configuration)
    }()

    /// Builds the multipart/form-data body for the OpenAI audio transcription request.
    /// Extracted as a pure function so it can be unit-tested without a network call.
    static func multipartBody(
        boundary: String,
        audioData: Data,
        model: String,
        customTerms: [String],
        language: String?
    ) -> Data {
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n")
        body.append("Content-Type: audio/m4a\r\n\r\n")
        body.append(audioData)
        body.append("\r\n")

        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        body.append(model)
        body.append("\r\n")

        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n")
        body.append("text")
        body.append("\r\n")

        if let prompt = transcriptionPrompt(customTerms: customTerms, language: language) {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n")
            body.append(prompt)
            body.append("\r\n")
        }

        if let language, !language.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
            body.append(language.trimmingCharacters(in: .whitespacesAndNewlines))
            body.append("\r\n")
        }

        body.append("--\(boundary)--\r\n")
        return body
    }

    /// Builds the optional Whisper `prompt` field. The prompt biases Whisper's
    /// output *style* (capitalization, punctuation) and vocabulary; it is not
    /// transcribed into the result. For German we seed a correctly written
    /// sentence so the raw transcript already comes back better formatted (free,
    /// no extra request). Custom terms are appended so proper nouns are spelled
    /// right. Returns nil when there is nothing useful to send.
    static func transcriptionPrompt(customTerms: [String], language: String?) -> String? {
        let normalizedLanguage = language?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let isGerman = normalizedLanguage?.hasPrefix("de") ?? false

        var parts: [String] = []
        if isGerman {
            parts.append("Transkribiere in korrektem Deutsch mit Gross- und Kleinschreibung sowie Satzzeichen.")
        }
        if !customTerms.isEmpty {
            parts.append("Eigennamen und Begriffe: \(customTerms.joined(separator: ", "))")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    /// Injectable HTTP transport so the request/response flow can be unit-tested.
    typealias Transport = (URLRequest) async throws -> (Data, URLResponse)
    private static let liveTransport: Transport = { try await session.data(for: $0) }

    public static func transcribe(
        audioURL: URL,
        customTerms: [String] = [],
        language: String? = nil
    ) async throws -> String {
        guard let apiKey = KeychainService.load(key: .openAIAPIKey) else {
            throw TranscriptionError.notConfigured
        }

        return try await Task.detached(priority: .userInitiated) {
            defer {
                try? FileManager.default.removeItem(at: audioURL)
            }
            let audioData = try Data(contentsOf: audioURL, options: [.mappedIfSafe])
            return try await send(
                audioData: audioData,
                apiKey: apiKey,
                customTerms: customTerms,
                language: language
            )
        }.value
    }

    /// Builds and sends the transcription request, then interprets the response.
    /// Pure of file I/O so it can be unit-tested with an injected transport.
    static func send(
        audioData: Data,
        apiKey: String,
        customTerms: [String],
        language: String?,
        transport: Transport? = nil
    ) async throws -> String {
        let boundary = UUID().uuidString
        var request = URLRequest(url: transcriptionsURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("text/plain, application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 60
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpBody = multipartBody(
            boundary: boundary,
            audioData: audioData,
            model: remoteModel,
            customTerms: customTerms,
            language: language
        )

        let (data, response) = try await (transport ?? liveTransport)(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.networkError("Ungueltige Antwort")
        }

        return try parseTranscription(status: httpResponse.statusCode, data: data)
    }

    /// Interprets the transcription HTTP response. Pure and unit-testable.
    static func parseTranscription(status: Int, data: Data) throws -> String {
        guard status == 200 else {
            throw TranscriptionError.apiError(openAIErrorMessage(from: data) ?? "Status \(status)")
        }

        guard let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            throw TranscriptionError.apiError("Transkription fehlgeschlagen")
        }

        return text
    }

    private static func openAIErrorMessage(from data: Data) -> String? {
        (try? JSONDecoder().decode(TranscriptionOpenAIErrorResponse.self, from: data))?.error?.message
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
