import XCTest
@testable import Logos

final class ScenarioTests: XCTestCase {
    func testScenarioLibraryAndRecommendationsAreDistinct() {
        XCTAssertGreaterThanOrEqual(Scenario.library.count, 10)
        XCTAssertEqual(Set(Scenario.library.map(\.id)).count, Scenario.library.count)
        XCTAssertEqual(Scenario.recommendations.count, 3)
        XCTAssertEqual(Set(Scenario.recommendations.map(\.id)).count, 3)
    }

    func testEveryScenarioHasFourScoringDimensionsAndRoleplayPrompt() {
        for scenario in Scenario.library {
            XCTAssertEqual(scenario.scoringDimensions.count, 4)
            XCTAssertFalse(scenario.roleplayPrompt.isEmpty)
            XCTAssertTrue(scenario.roleplayPrompt.contains("Do not coach"))
            XCTAssertTrue(scenario.roleplayPrompt.contains("do not break character"))
            XCTAssertGreaterThan(scenario.durationMinutes, 0)
            XCTAssertGreaterThan(scenario.xpReward, 0)
        }
    }

    func testEvaluationSchemaRequiresStrictShape() {
        XCTAssertEqual(OpenAIEvaluationService.schema["additionalProperties"] as? Bool, false)
        let properties = OpenAIEvaluationService.schema["properties"] as? [String: Any]
        let dimensions = properties?["dimensions"] as? [String: Any]
        XCTAssertEqual(dimensions?["minItems"] as? Int, 4)
        XCTAssertEqual(dimensions?["maxItems"] as? Int, 4)
    }

    func testEvaluationSchemaRequiresMirrorAndAchievements() {
        let properties = OpenAIEvaluationService.schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties?["characterReflection"])
        let achievements = properties?["achievements"] as? [String: Any]
        XCTAssertEqual(achievements?["minItems"] as? Int, 0)
        XCTAssertEqual(achievements?["maxItems"] as? Int, 2)
    }

    func testFreshProgressionContainsNoInventedHistory() {
        let progression = ProgressionSnapshot.empty
        XCTAssertEqual(progression.totalXP, 0)
        XCTAssertEqual(progression.completedConversations, 0)
        XCTAssertEqual(progression.currentStreak, 0)
        XCTAssertTrue(progression.skillScores.isEmpty)
        XCTAssertTrue(progression.scenarioCompletions.isEmpty)
        XCTAssertNil(progression.weakestSkill)
    }

    func testSixStarterPracticeLanguagesHaveDistinctCodes() {
        XCTAssertEqual(PracticeLanguage.allCases.count, 6)
        XCTAssertEqual(Set(PracticeLanguage.allCases.map(\.rawValue)).count, 6)
        XCTAssertEqual(
            Set(PracticeLanguage.allCases.map(\.rawValue)),
            Set(["en", "es", "fr", "de", "it", "pt"])
        )
    }

    func testEvaluationPromptKeepsSelectedOutputLanguage() {
        let prompt = EvaluationPrompt.user(
            scenario: Scenario.library[0],
            language: .spanish,
            transcript: [TranscriptEntry(speaker: .user, text: "Quiero hablar de mi puesto.")]
        )
        XCTAssertTrue(prompt.contains("Write every user-facing string value in Spanish"))
    }

    @MainActor
    func testSessionStorePersistsTranscriptWithoutInventingAudio() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = SessionStore(directory: directory)
        let result = ConversationResult(
            scenario: Scenario.library[0],
            language: .spanish,
            transcript: [TranscriptEntry(speaker: .user, text: "Quiero hablar de mi puesto.")],
            evaluation: Self.sampleEvaluation
        )

        store.save(result)
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions.first?.transcript.first?.text, "Quiero hablar de mi puesto.")
        XCTAssertFalse(store.sessions.first?.hasConversationAudio ?? true)

        let reloaded = SessionStore(directory: directory)
        XCTAssertEqual(reloaded.sessions.count, 1)
        XCTAssertEqual(reloaded.sessions.first?.characterName, "Sarah")
        XCTAssertEqual(reloaded.sessions.first?.language, .spanish)
        XCTAssertEqual(reloaded.result(for: reloaded.sessions[0]).evaluation.retryFocus, Self.sampleEvaluation.retryFocus)
    }

    @MainActor
    func testSessionStoreKeepsConversationAudioAndCanDeleteIt() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = SessionStore(directory: directory)
        let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
        try Data(repeating: 3, count: 2_048).write(to: audioURL)

        let saved = store.save(
            ConversationResult(
                scenario: Scenario.library[0],
                language: .english,
                transcript: [TranscriptEntry(speaker: .character, text: "What's on your mind?")],
                evaluation: Self.sampleEvaluation,
                conversationAudioURL: audioURL
            )
        )
        XCTAssertNotNil(saved.conversationAudioURL)
        XCTAssertTrue(store.sessions.first?.hasConversationAudio ?? false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.audioURL(for: saved.id).path))

        store.delete(store.sessions[0])
        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.audioURL(for: saved.id).path))
    }

    func testBundledAppCopyChangesWithPracticeLanguage() {
        XCTAssertEqual(PracticeLanguage.english.text("Speaker"), "Speaker")
        XCTAssertEqual(PracticeLanguage.spanish.text("Speaker"), "Altavoz")
        XCTAssertEqual(PracticeLanguage.french.text("Speaker"), "Haut-parleur")
        XCTAssertEqual(PracticeLanguage.german.text("Speaker"), "Lautsprecher")
        XCTAssertEqual(PracticeLanguage.italian.text("Speaker"), "Vivavoce")
        XCTAssertEqual(PracticeLanguage.portuguese.text("Speaker"), "Viva-voz")
    }

    /// Opt-in because it creates a real, billable OpenAI Realtime session.
    /// Run with RUN_OPENAI_INTEGRATION=1 after granting simulator microphone access.
    @MainActor
    func testLiveRealtimeOpeningWhenExplicitlyEnabled() async throws {
        guard ProcessInfo.processInfo.environment["RUN_OPENAI_INTEGRATION"] == "1" else {
            throw XCTSkip("Set RUN_OPENAI_INTEGRATION=1 to exercise the billable Realtime API.")
        }

        let provider = OpenAIRealtimeConversationProvider()
        try await provider.connect(scenario: Scenario.library[0], language: .spanish)

        let deadline = Date().addingTimeInterval(35)
        while (provider.transcript.first(where: { $0.speaker == .character }) == nil || provider.phase != .listening),
              Date() < deadline {
            if case let .failed(message) = provider.phase {
                XCTFail(message)
                break
            }
            try await Task.sleep(for: .milliseconds(100))
        }

        let opening = provider.transcript.first(where: { $0.speaker == .character })
        let caption = provider.liveCaption
        await provider.disconnect()
        XCTAssertNotNil(opening, "The character did not finish a spoken opening within 35 seconds.")
        XCTAssertEqual(caption?.speaker, .character)
        XCTAssertEqual(caption?.text, opening?.text)
        XCTAssertNotEqual(caption?.text, Scenario.library[0].firstMessage)
    }

    private static let sampleEvaluation = Evaluation(
        overallScore: 72,
        resultLabel: "Clear but unfinished",
        characterReflection: "I understood what you wanted when you named the impact.",
        turningPoint: "When you asked for a dated next step.",
        retryFocus: "Name the decision you want before you explain the work.",
        dimensions: [
            ScoreDimension(name: "Clarity", score: 74, feedback: "The ask was understandable."),
            ScoreDimension(name: "Confidence", score: 68, feedback: "You stayed present."),
            ScoreDimension(name: "Listening", score: 70, feedback: "You heard the constraint."),
            ScoreDimension(name: "Directness", score: 76, feedback: "You did not hide the request.")
        ],
        achievements: []
    )

    func testLiveSpokenReflectionWhenExplicitlyEnabled() async throws {
        guard ProcessInfo.processInfo.environment["RUN_OPENAI_INTEGRATION"] == "1" else {
            throw XCTSkip("Set RUN_OPENAI_INTEGRATION=1 to exercise the billable Speech API.")
        }

        let audio = try await OpenAISpeechService().synthesize(
            "I understood what you wanted, and I appreciated how directly you said it."
        )
        XCTAssertGreaterThan(audio.count, 1_000)
    }
}
