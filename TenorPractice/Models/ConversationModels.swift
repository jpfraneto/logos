import Foundation

enum Speaker: String, Codable, Sendable {
    case user
    case character
}

struct TranscriptEntry: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let speaker: Speaker
    let text: String

    init(id: UUID = UUID(), speaker: Speaker, text: String) {
        self.id = id
        self.speaker = speaker
        self.text = text
    }
}

struct LiveCaption: Equatable, Sendable {
    let speaker: Speaker
    let text: String
}

enum ConversationPhase: Equatable, Sendable {
    case idle
    case connecting
    case listening
    case thinking
    case speaking
    case ended
    case failed(String)

    var label: String {
        switch self {
        case .idle: "Ready"
        case .connecting: "Connecting…"
        case .listening: "Listening…"
        case .thinking: "Thinking…"
        case .speaking: "Speaking…"
        case .ended: "Conversation ended"
        case .failed: "Couldn't connect"
        }
    }
}

struct ScoreDimension: Codable, Equatable, Sendable {
    let name: String
    let score: Int
    let feedback: String
}

struct Achievement: Codable, Equatable, Sendable {
    let title: String
    let evidence: String
}

struct Evaluation: Codable, Equatable, Sendable {
    let overallScore: Int
    let resultLabel: String
    let characterReflection: String
    let turningPoint: String
    let retryFocus: String
    let dimensions: [ScoreDimension]
    let achievements: [Achievement]
}

struct ConversationResult: Identifiable, Sendable {
    let id: UUID
    let scenario: Scenario
    let language: PracticeLanguage
    let transcript: [TranscriptEntry]
    let evaluation: Evaluation
    let xpEarned: Int
    let createdAt: Date
    let conversationAudioURL: URL?

    init(
        id: UUID = UUID(),
        scenario: Scenario,
        language: PracticeLanguage,
        transcript: [TranscriptEntry],
        evaluation: Evaluation,
        xpEarned: Int? = nil,
        createdAt: Date = Date(),
        conversationAudioURL: URL? = nil
    ) {
        self.id = id
        self.scenario = scenario
        self.language = language
        self.transcript = transcript
        self.evaluation = evaluation
        self.xpEarned = xpEarned ?? scenario.xpReward + evaluation.overallScore / 5
        self.createdAt = createdAt
        self.conversationAudioURL = conversationAudioURL
    }

    func withConversationAudioURL(_ url: URL?) -> ConversationResult {
        ConversationResult(
            id: id,
            scenario: scenario,
            language: language,
            transcript: transcript,
            evaluation: evaluation,
            xpEarned: xpEarned,
            createdAt: createdAt,
            conversationAudioURL: url
        )
    }
}
