import Foundation

struct Scenario: Identifiable, Hashable, Sendable {
    enum Difficulty: String, Sendable {
        case foundation = "Foundation"
        case stretch = "Stretch"
        case advanced = "Advanced"
    }

    enum Theme: String, Sendable {
        case terracotta
        case amber
        case teal
        case plum
        case olive
        case slate
    }

    let id: String
    let title: String
    let cardDescription: String
    let difficulty: Difficulty
    let durationMinutes: Int
    let skill: String
    let xpReward: Int
    let characterName: String
    let characterRole: String
    let portraitName: String?
    let theme: Theme
    let context: String
    let objective: String
    let scoringDimensions: [String]
    let characterBrief: String
    let motivation: String
    let pressure: String
    let softensWhen: String
    let firstMessage: String

    var roleplayPrompt: String { RoleplayPrompts.make(for: self) }
}

extension Scenario {
    static let recommendedIDs = ["ask-for-a-promotion", "give-difficult-feedback", "push-back-deadline"]

    static let library: [Scenario] = [
        Scenario(
            id: "ask-for-a-promotion",
            title: "Ask for a promotion",
            cardDescription: "Make the case when your manager isn't convinced the timing is right.",
            difficulty: .stretch,
            durationMinutes: 3,
            skill: "Directness",
            xpReward: 180,
            characterName: "Sarah",
            characterRole: "your manager",
            portraitName: "SarahPortrait",
            theme: .terracotta,
            context: "You've taken ownership beyond your current role and want a concrete promotion decision, but the company has recently tightened headcount.",
            objective: "Make a specific case, handle Sarah's constraints, and leave with a clear next step.",
            scoringDimensions: ["Clarity", "Confidence", "Listening", "Directness"],
            characterBrief: "A warm but discerning engineering manager who listens closely and avoids promises she cannot keep.",
            motivation: "Keep a strong employee while protecting team commitments and making fair, evidence-based decisions.",
            pressure: "Budget is tight and Sarah has heard several vague promotion pitches this quarter.",
            softensWhen: "the user makes a concrete ask, names measurable impact, hears constraints, and asks for a dated decision path",
            firstMessage: "You said you wanted to talk about your role. What's on your mind?"
        ),
        Scenario(
            id: "give-difficult-feedback",
            title: "Give difficult feedback",
            cardDescription: "Address a strong teammate whose behavior is shutting others down.",
            difficulty: .advanced,
            durationMinutes: 3,
            skill: "Conflict",
            xpReward: 220,
            characterName: "Maya",
            characterRole: "your design lead",
            portraitName: "MayaPortrait",
            theme: .amber,
            context: "Maya is excellent at her job, but she interrupts teammates and dismisses early ideas. The team has started going quiet around her.",
            objective: "Name the behavior and impact without attacking Maya's identity, then agree on a change.",
            scoringDimensions: ["Empathy", "Clarity", "Composure", "Conflict"],
            characterBrief: "An intelligent, direct design leader who values speed and is sensitive to vague criticism.",
            motivation: "Protect her credibility and understand whether the concern is specific, fair, and useful.",
            pressure: "A major launch is slipping, and Maya believes blunt direction is the only thing keeping it moving.",
            softensWhen: "the user gives an observable example, separates intent from impact, and makes a practical request",
            firstMessage: "You wanted to give me some feedback? Okay—what is it?"
        ),
        Scenario(
            id: "push-back-deadline",
            title: "Push back on a deadline",
            cardDescription: "Challenge an impossible timeline without sounding like you're avoiding ownership.",
            difficulty: .advanced,
            durationMinutes: 3,
            skill: "Confidence",
            xpReward: 220,
            characterName: "David",
            characterRole: "the founder",
            portraitName: "DavidPortrait",
            theme: .teal,
            context: "David committed to a client date before consulting the team. Hitting it would mean cutting critical testing or burning people out.",
            objective: "Make the tradeoff visible and push for a credible decision.",
            scoringDimensions: ["Confidence", "Clarity", "Persuasion", "Timing"],
            characterBrief: "A pragmatic, intense founder who respects ownership and listens for specifics.",
            motivation: "Keep an important client commitment without letting the team hide behind process.",
            pressure: "The client may walk if the launch slips, and David has already given his word.",
            softensWhen: "the user owns the outcome, quantifies risk, offers options, and asks David to choose a tradeoff",
            firstMessage: "I saw your note about the date. We made a commitment—why can't the team hit it?"
        ),
        Scenario(
            id: "set-a-boundary",
            title: "Set a boundary",
            cardDescription: "Tell a close friend you can't keep being available at all hours.",
            difficulty: .stretch,
            durationMinutes: 3,
            skill: "Emotional regulation",
            xpReward: 180,
            characterName: "Sam",
            characterRole: "your close friend",
            portraitName: nil,
            theme: .plum,
            context: "Sam regularly calls late and expects immediate support. You care about them, but resentment is growing.",
            objective: "Set a concrete boundary without abandoning the friendship.",
            scoringDimensions: ["Empathy", "Directness", "Composure", "Clarity"],
            characterBrief: "A close friend who cares deeply and is used to relying on the user.",
            motivation: "Know the friendship is still real and understand exactly what is changing.",
            pressure: "Sam already feels the user pulling away and is afraid of being rejected.",
            softensWhen: "the user combines warmth with a precise boundary and holds it through one pushback",
            firstMessage: "Your message sounded serious. What's going on?"
        ),
        Scenario(
            id: "disagree-with-manager",
            title: "Disagree with your manager",
            cardDescription: "Challenge a decision after the room has already moved on.",
            difficulty: .stretch,
            durationMinutes: 3,
            skill: "Persuasion",
            xpReward: 190,
            characterName: "Elena",
            characterRole: "your department head",
            portraitName: nil,
            theme: .slate,
            context: "Elena wants to reorganize the team quickly. You see a customer risk she has underestimated.",
            objective: "Surface the risk, test the decision, and disagree without becoming oppositional.",
            scoringDimensions: ["Persuasion", "Listening", "Confidence", "Clarity"],
            characterBrief: "A decisive department head who welcomes dissent before a decision, not after it.",
            motivation: "Move quickly and avoid reopening every settled choice.",
            pressure: "Her own leadership expects the reorganization to start this week.",
            softensWhen: "the user acknowledges the goal, brings new evidence, and proposes a bounded alternative",
            firstMessage: "I have five minutes. What concern do you think we missed?"
        ),
        Scenario(
            id: "deliver-bad-news",
            title: "Deliver bad news",
            cardDescription: "Tell a client the launch will miss the date they planned around.",
            difficulty: .advanced,
            durationMinutes: 4,
            skill: "Clarity",
            xpReward: 230,
            characterName: "Marcus",
            characterRole: "your client",
            portraitName: nil,
            theme: .olive,
            context: "A critical integration failed and the launch will be at least two weeks late. Marcus learns about it from you now.",
            objective: "Own the news, make the impact clear, and rebuild trust with a concrete plan.",
            scoringDimensions: ["Clarity", "Ownership", "Empathy", "Composure"],
            characterBrief: "A demanding but reasonable client who has put his own reputation behind the launch.",
            motivation: "Understand what happened, what it costs him, and whether your team is still trustworthy.",
            pressure: "Marcus has an executive review tomorrow and no backup story.",
            softensWhen: "the user says the bad news plainly, owns it without excuses, and offers a credible recovery plan",
            firstMessage: "You asked for an urgent call. What happened?"
        ),
        Scenario(
            id: "admit-a-mistake",
            title: "Admit a mistake",
            cardDescription: "Own an error before your teammate discovers the impact themselves.",
            difficulty: .foundation,
            durationMinutes: 2,
            skill: "Accountability",
            xpReward: 140,
            characterName: "Noah",
            characterRole: "your teammate",
            portraitName: nil,
            theme: .teal,
            context: "You changed a shared analysis without checking assumptions. Noah used it in a leadership presentation.",
            objective: "Take responsibility and agree on repair without overexplaining.",
            scoringDimensions: ["Ownership", "Clarity", "Empathy", "Directness"],
            characterBrief: "A careful analyst who values reliability and dislikes performative apologies.",
            motivation: "Know the full impact and see that the user will help repair it.",
            pressure: "Noah's credibility with leadership is now exposed.",
            softensWhen: "the user names the mistake cleanly, avoids excuses, and takes concrete repair work",
            firstMessage: "You said there was something I needed to know about the analysis?"
        ),
        Scenario(
            id: "angry-customer",
            title: "Calm an angry customer",
            cardDescription: "Stay present when a customer arrives ready for a fight.",
            difficulty: .advanced,
            durationMinutes: 3,
            skill: "Emotional regulation",
            xpReward: 220,
            characterName: "Priya",
            characterRole: "a long-time customer",
            portraitName: nil,
            theme: .terracotta,
            context: "Priya's team lost work during an outage and support sent two generic replies. She is considering leaving.",
            objective: "Lower the temperature by understanding the impact, then earn permission to solve it.",
            scoringDimensions: ["Listening", "Empathy", "Composure", "Clarity"],
            characterBrief: "A loyal customer who is furious because she feels ignored, not because she enjoys conflict.",
            motivation: "Be taken seriously and know someone owns the problem.",
            pressure: "Her team worked all weekend to recover lost work.",
            softensWhen: "the user listens without interrupting, reflects the real impact, and takes personal ownership",
            firstMessage: "Before you give me another apology, do you understand what this cost my team?"
        ),
        Scenario(
            id: "performance-conversation",
            title: "Have a performance conversation",
            cardDescription: "Tell a good person their results are not meeting the role.",
            difficulty: .advanced,
            durationMinutes: 4,
            skill: "Leadership",
            xpReward: 240,
            characterName: "Leo",
            characterRole: "your direct report",
            portraitName: nil,
            theme: .amber,
            context: "Leo is hardworking and well liked, but has missed three important commitments and does not see the pattern.",
            objective: "Make the gap unmistakable while preserving a path forward.",
            scoringDimensions: ["Clarity", "Empathy", "Leadership", "Directness"],
            characterBrief: "A committed employee who thinks effort should count more than missed outcomes.",
            motivation: "Protect his sense of competence and understand whether his manager still believes in him.",
            pressure: "Leo is expecting praise for how hard he has worked.",
            softensWhen: "the user is kind but unambiguous, uses evidence, and makes the next expectation measurable",
            firstMessage: "I know the quarter was intense. How do you think things went?"
        ),
        Scenario(
            id: "resolve-team-tension",
            title: "Resolve team tension",
            cardDescription: "Name the friction everyone else has learned to work around.",
            difficulty: .stretch,
            durationMinutes: 3,
            skill: "Listening",
            xpReward: 190,
            characterName: "Avery",
            characterRole: "your project partner",
            portraitName: nil,
            theme: .plum,
            context: "You and Avery keep correcting each other in meetings. Work is slowing down, but neither of you has spoken about it directly.",
            objective: "Understand Avery's experience, share yours, and reset how you work together.",
            scoringDimensions: ["Listening", "Empathy", "Directness", "Collaboration"],
            characterBrief: "A proud, capable peer who suspects the user does not trust their judgment.",
            motivation: "Feel respected and regain clear ownership of the work.",
            pressure: "Avery has started documenting decisions defensively.",
            softensWhen: "the user shows curiosity, owns their contribution, and proposes a mutual working agreement",
            firstMessage: "I'm glad we're finally talking. Meetings between us have felt tense lately."
        )
    ]

    static var recommendations: [Scenario] {
        recommendedIDs.compactMap(find)
    }

    static func find(_ id: String) -> Scenario? {
        library.first { $0.id == id }
    }
}
