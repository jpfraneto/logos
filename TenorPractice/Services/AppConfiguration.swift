import Foundation

struct AppConfiguration: Sendable {
    let openAIAPIKey: String
    let realtimeModel: String
    let realtimeVoice: String
    let evaluationModel: String
    let speechModel: String

    static let current = AppConfiguration(
        openAIAPIKey: value(for: "OpenAIAPIKey"),
        realtimeModel: value(for: "OpenAIRealtimeModel", fallback: "gpt-realtime-2.1"),
        realtimeVoice: value(for: "OpenAIRealtimeVoice", fallback: "marin"),
        evaluationModel: value(for: "OpenAIEvaluationModel", fallback: "gpt-5.6-luna"),
        speechModel: value(for: "OpenAISpeechModel", fallback: "gpt-4o-mini-tts")
    )

    private static func value(for key: String, fallback: String = "") -> String {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return fallback
        }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains("$(") else { return fallback }
        return value
    }
}

enum ConfigurationError: LocalizedError {
    case missingOpenAIKey

    var errorDescription: String? {
        switch self {
        case .missingOpenAIKey:
            "Add OPENAI_API_KEY to Config/Local.xcconfig, then rebuild the app."
        }
    }
}
