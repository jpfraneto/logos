import Foundation

enum EvaluationPrompt {
    static let system = """
    You analyze a completed difficult-conversation role-play for Logos.

    The primary output is a mirror, not coaching: write the characterReflection entirely in first person as the character the user just spoke with. Describe what it felt like to be on the other side of the user, what specific words or moments changed your reaction, and what remained unresolved. Make it emotionally credible, nuanced, and grounded only in the transcript. It will be spoken aloud, so use natural spoken language and no more than 65 words. Do not mention AI, evaluation, scores, rubrics, or communication technique in that reflection.

    The turningPoint is also in the character's first person. Name the single moment that most changed how the character thought or felt.
    The retryFocus is one short, practical experiment for the user's next attempt. It may be written in the product voice, but must not sound clinical or therapeutic.

    Scores are secondary. Evaluate communication behavior only, never personality or worth. Return exactly four dimension results using the supplied rubric and zero, one, or two achievements. Every achievement must describe something observable that actually happened and cite the evidence briefly. If the transcript does not support an achievement, return fewer achievements. Never invent a badge merely because the session ended.

    Scores are integers from 0 through 100. resultLabel is a short human label such as "Strong conversation", "Clear but unfinished", or "A promising start". Return only data matching the supplied JSON schema.
    """

    static func user(
        scenario: Scenario,
        language: PracticeLanguage,
        transcript: [TranscriptEntry]
    ) -> String {
        let rubric = scenario.scoringDimensions.map { "- \($0)" }.joined(separator: "\n")
        let dialogue = transcript.map { entry in
            let name = entry.speaker == .user ? "USER" : scenario.characterName.uppercased()
            return "\(name): \(entry.text)"
        }.joined(separator: "\n")

        return """
        # Output language
        Write every user-facing string value in \(language.englishName). This includes the reflection, result label, turning point, retry focus, dimension names and feedback, achievement titles, and evidence. Keep JSON property names unchanged.

        # Character
        \(scenario.characterName), \(scenario.characterRole)
        Private motivation: \(scenario.motivation)
        Current pressure: \(scenario.pressure)

        # Scenario
        \(scenario.title)
        User objective: \(scenario.objective)

        # Score dimensions
        \(rubric)

        # Complete transcript
        \(dialogue)

        First create the character's truthful first-person reflection from the transcript. Then supply the secondary game layer.
        """
    }
}
