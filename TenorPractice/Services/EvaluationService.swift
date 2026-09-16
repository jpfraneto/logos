import Foundation

protocol EvaluationService: Sendable {
    func evaluate(
        scenario: Scenario,
        language: PracticeLanguage,
        transcript: [TranscriptEntry]
    ) async throws -> Evaluation
}

enum EvaluationError: LocalizedError {
    case emptyTranscript
    case invalidResponse
    case requestFailed(Int, String)

    var errorDescription: String? {
        switch self {
        case .emptyTranscript:
            "There isn't enough conversation to score yet. Try again and say at least one thing."
        case .invalidResponse:
            "The evaluator returned an unreadable result. Please try again."
        case let .requestFailed(status, message):
            "Evaluation failed (\(status)): \(message)"
        }
    }
}

struct OpenAIEvaluationService: EvaluationService {
    private let configuration: AppConfiguration
    private let session: URLSession

    init(configuration: AppConfiguration = .current, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func evaluate(
        scenario: Scenario,
        language: PracticeLanguage,
        transcript: [TranscriptEntry]
    ) async throws -> Evaluation {
        guard !transcript.isEmpty else { throw EvaluationError.emptyTranscript }
        guard !configuration.openAIAPIKey.isEmpty else { throw ConfigurationError.missingOpenAIKey }

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(configuration.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody(
            scenario: scenario,
            language: language,
            transcript: transcript
        ))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw EvaluationError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let apiError = (try? JSONDecoder().decode(APIErrorEnvelope.self, from: data).error.message) ?? "Unknown API error"
            throw EvaluationError.requestFailed(http.statusCode, apiError)
        }

        let envelope = try JSONDecoder().decode(ResponsesEnvelope.self, from: data)
        let contents = envelope.output.compactMap(\.content).flatMap { $0 }
        guard let outputText = contents.first(where: { $0.type == "output_text" })?.text,
              let resultData = outputText.data(using: .utf8) else {
            throw EvaluationError.invalidResponse
        }

        return try JSONDecoder().decode(Evaluation.self, from: resultData)
    }

    private func requestBody(
        scenario: Scenario,
        language: PracticeLanguage,
        transcript: [TranscriptEntry]
    ) -> [String: Any] {
        [
            "model": configuration.evaluationModel,
            "input": [
                ["role": "system", "content": EvaluationPrompt.system],
                ["role": "user", "content": EvaluationPrompt.user(
                    scenario: scenario,
                    language: language,
                    transcript: transcript
                )]
            ],
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": "conversation_evaluation",
                    "strict": true,
                    "schema": Self.schema
                ]
            ]
        ]
    }

    static let schema: [String: Any] = [
        "type": "object",
        "additionalProperties": false,
        "required": ["overallScore", "resultLabel", "characterReflection", "turningPoint", "retryFocus", "dimensions", "achievements"],
        "properties": [
            "overallScore": ["type": "integer", "minimum": 0, "maximum": 100],
            "resultLabel": ["type": "string"],
            "characterReflection": ["type": "string"],
            "turningPoint": ["type": "string"],
            "retryFocus": ["type": "string"],
            "dimensions": [
                "type": "array",
                "minItems": 4,
                "maxItems": 4,
                "items": [
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["name", "score", "feedback"],
                    "properties": [
                        "name": ["type": "string"],
                        "score": ["type": "integer", "minimum": 0, "maximum": 100],
                        "feedback": ["type": "string"]
                    ]
                ]
            ],
            "achievements": [
                "type": "array",
                "minItems": 0,
                "maxItems": 2,
                "items": [
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["title", "evidence"],
                    "properties": [
                        "title": ["type": "string"],
                        "evidence": ["type": "string"]
                    ]
                ]
            ]
        ]
    ]
}

private struct ResponsesEnvelope: Decodable {
    let output: [Output]

    struct Output: Decodable {
        let content: [Content]?
    }

    struct Content: Decodable {
        let type: String
        let text: String?
    }
}

private struct APIErrorEnvelope: Decodable {
    let error: APIError

    struct APIError: Decodable {
        let message: String
    }
}
