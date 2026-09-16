import Foundation

struct SavedSession: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let createdAt: Date
    let scenarioID: String
    let scenarioTitle: String
    let characterName: String
    let characterRole: String
    let portraitName: String?
    let theme: String
    let language: PracticeLanguage
    let transcript: [TranscriptEntry]
    let evaluation: Evaluation
    let xpEarned: Int
    let hasConversationAudio: Bool

    init(result: ConversationResult, hasConversationAudio: Bool) {
        id = result.id
        createdAt = result.createdAt
        scenarioID = result.scenario.id
        scenarioTitle = result.scenario.title
        characterName = result.scenario.characterName
        characterRole = result.scenario.characterRole
        portraitName = result.scenario.portraitName
        theme = result.scenario.theme.rawValue
        language = result.language
        transcript = result.transcript
        evaluation = result.evaluation
        xpEarned = result.xpEarned
        self.hasConversationAudio = hasConversationAudio
    }

    func conversationResult(audioURL: URL?) -> ConversationResult {
        ConversationResult(
            id: id,
            scenario: displayScenario,
            language: language,
            transcript: transcript,
            evaluation: evaluation,
            xpEarned: xpEarned,
            createdAt: createdAt,
            conversationAudioURL: hasConversationAudio ? audioURL : nil
        )
    }

    var displayScenario: Scenario {
        if let existing = Scenario.find(scenarioID) { return existing }
        return Scenario(
            id: scenarioID,
            title: scenarioTitle,
            cardDescription: "",
            difficulty: .foundation,
            durationMinutes: 3,
            skill: "",
            xpReward: 0,
            characterName: characterName,
            characterRole: characterRole,
            portraitName: portraitName,
            theme: Scenario.Theme(rawValue: theme) ?? .slate,
            context: "",
            objective: "",
            scoringDimensions: ["Clarity", "Listening", "Directness", "Composure"],
            characterBrief: "",
            motivation: "",
            pressure: "",
            softensWhen: "",
            firstMessage: ""
        )
    }
}