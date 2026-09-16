import Foundation

@MainActor
protocol RealtimeConversationProvider: ObservableObject {
    var phase: ConversationPhase { get }
    var transcript: [TranscriptEntry] { get }
    var liveCaption: LiveCaption? { get }
    var isMuted: Bool { get }
    var isSpeakerEnabled: Bool { get }
    var audioLevel: Double { get }
    var isUserSpeaking: Bool { get }

    func connect(scenario: Scenario, language: PracticeLanguage) async throws
    func disconnect() async
    func toggleMute() async throws
    func toggleSpeaker() async throws
}
