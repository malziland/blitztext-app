import Foundation

public enum LLMError: LocalizedError {
    case notConfigured
    case networkError(String)
    case apiError(String)
    case noContent

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "OpenAI API Key fehlt. Bitte in den Einstellungen hinterlegen."
        case .networkError(let msg):
            return "Verbindungsproblem: \(msg)"
        case .apiError(let msg):
            return "Fehler von OpenAI: \(msg)"
        case .noContent:
            return "Keine Antwort erhalten. Bitte nochmal versuchen."
        }
    }
}

public enum RewriteModel: String {
    case fastEdit = "gpt-4o-mini"
}

private struct OpenAIChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
    let temperature: Double
}

private struct OpenAIChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }

        let message: Message?
    }

    let choices: [Choice]?
}

private struct OpenAIErrorResponse: Decodable {
    struct APIError: Decodable {
        let message: String?
    }

    let error: APIError?
}

public enum LLMService {
    private static let chatCompletionsURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 45
        configuration.timeoutIntervalForResource = 45
        return URLSession(configuration: configuration)
    }()

    /// Injectable HTTP transport so the full request/response flow can be unit-tested
    /// without a real network call. Defaults to the live URLSession.
    typealias Transport = (URLRequest) async throws -> (Data, URLResponse)
    private static let liveTransport: Transport = { try await session.data(for: $0) }

    public static func improve(
        text: String,
        settings: TextImprovementSettings,
        model: RewriteModel = .fastEdit
    ) async throws -> String {
        try await complete(
            text: text,
            systemPrompt: buildSystemPrompt(settings: settings),
            model: model,
            temperature: 0.3
        )
    }

    static func complete(
        text: String,
        systemPrompt: String,
        model: RewriteModel,
        temperature: Double,
        apiKey: String? = nil,
        transport: Transport? = nil
    ) async throws -> String {
        guard let key = apiKey ?? KeychainService.load(key: .openAIAPIKey) else {
            throw LLMError.notConfigured
        }

        var request = URLRequest(url: chatCompletionsURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45
        request.httpBody = try chatRequestBody(
            model: model.rawValue,
            systemPrompt: systemPrompt,
            userText: text,
            temperature: temperature
        )

        let (data, response) = try await (transport ?? liveTransport)(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.networkError("Keine gültige Antwort")
        }

        return try parseChatContent(status: httpResponse.statusCode, data: data)
    }

    /// Builds the chat-completions request body. Pure and unit-testable.
    static func chatRequestBody(
        model: String,
        systemPrompt: String,
        userText: String,
        temperature: Double
    ) throws -> Data {
        let payload = OpenAIChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userText),
            ],
            temperature: temperature
        )
        return try JSONEncoder().encode(payload)
    }

    /// Interprets the chat-completions HTTP response. Pure and unit-testable.
    static func parseChatContent(status: Int, data: Data) throws -> String {
        guard status == 200 else {
            throw LLMError.apiError(openAIErrorMessage(from: data) ?? "Status \(status)")
        }

        let result = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = result.choices?.first?.message?.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMError.noContent
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func openAIErrorMessage(from data: Data) -> String? {
        (try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data))?.error?.message
    }

    public static func buildSystemPrompt(settings: TextImprovementSettings) -> String {
        if !settings.systemPrompt.isEmpty {
            var prompt = settings.systemPrompt
            if !settings.customTerms.isEmpty {
                prompt += "\n\nWichtig: Diese Eigennamen und Fachbegriffe muessen exakt so geschrieben werden: \(settings.customTerms.joined(separator: ", "))"
            }
            return prompt
        }

        var prompt = """
        Du bist ein Lektor und Schreibassistent. Verbessere den folgenden Text:
        - Korrigiere Rechtschreibung und Grammatik
        - Verbessere die Formulierung und den Lesefluss
        - Behalte die urspruengliche Bedeutung bei
        - Gib NUR den verbesserten Text zurueck, keine Erklaerungen
        """

        switch settings.tone {
        case .formal:
            prompt += "\n- Verwende einen formellen, professionellen Ton"
        case .neutral:
            prompt += "\n- Verwende einen neutralen, klaren Ton"
        case .casual:
            prompt += "\n- Verwende einen lockeren, natuerlichen Ton"
        }

        if !settings.customTerms.isEmpty {
            prompt += "\n\nWichtig: Diese Eigennamen und Fachbegriffe muessen exakt so geschrieben werden: \(settings.customTerms.joined(separator: ", "))"
        }

        if !settings.context.isEmpty {
            prompt += "\n\nKontext: \(settings.context)"
        }

        return prompt
    }
}
