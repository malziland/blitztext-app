import Foundation

/// The catalog of supported local WhisperKit models and the pure logic around them
/// (names, normalization, model-page links). Platform-agnostic and unit-testable.
public enum WhisperModelCatalog {
    public static let defaultModelName = "openai_whisper-large-v3-v20240930_626MB"
    public static let fastModelName = "openai_whisper-large-v3-v20240930_turbo_632MB"
    public static let recommendedFastModelName = BlitztextDefaults.recommendedFastWhisperModelName
    public static let modelRepo = "argmaxinc/whisperkit-coreml"

    public static let supportedModelNames = [
        recommendedFastModelName,
        fastModelName,
        defaultModelName
    ]

    public static let defaultModelPageURL = URL(
        string: "https://huggingface.co/argmaxinc/whisperkit-coreml/tree/main/openai_whisper-large-v3-v20240930_626MB"
    )!
    public static let fastModelPageURL = URL(
        string: "https://huggingface.co/argmaxinc/whisperkit-coreml/tree/main/openai_whisper-large-v3-v20240930_turbo_632MB"
    )!
    public static let recommendedFastModelPageURL = URL(
        string: "https://huggingface.co/argmaxinc/whisperkit-coreml/tree/main/openai_whisper-small_216MB"
    )!

    public static func normalizedModelName(_ modelName: String) -> String {
        let trimmed = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? recommendedFastModelName : trimmed
    }

    public static func modelPageURL(for modelName: String) -> URL {
        switch normalizedModelName(modelName) {
        case recommendedFastModelName:
            return recommendedFastModelPageURL
        case fastModelName:
            return fastModelPageURL
        case defaultModelName:
            return defaultModelPageURL
        default:
            return URL(string: "https://huggingface.co/\(modelRepo)/tree/main/\(normalizedModelName(modelName))")!
        }
    }

    public static func displayName(for modelName: String) -> String {
        if modelName.contains("small") { return "Whisper Small" }
        if modelName.contains("base") { return "Whisper Base" }
        if modelName.contains("tiny") { return "Whisper Tiny" }
        if modelName.contains("turbo") { return "Whisper Large v3 Turbo" }
        if modelName.contains("large-v3") { return "Whisper Large v3" }
        return modelName
            .replacingOccurrences(of: "openai_", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
    }

    public static func shortDisplayName(for modelName: String) -> String {
        if modelName.contains("small") { return "Whisper Small" }
        if modelName.contains("base") { return "Whisper Base" }
        if modelName.contains("tiny") { return "Whisper Tiny" }
        if modelName.contains("turbo") { return "Whisper Turbo" }
        if modelName.contains("large-v3") { return "Whisper Large" }
        return displayName(for: modelName)
    }
}
