@preconcurrency import AVFoundation
import Combine
import Foundation

enum SpeechServiceError: LocalizedError {
    case invalidResponse
    case requestFailed(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The spoken reflection could not be prepared."
        case let .requestFailed(status, message):
            "Spoken reflection failed (\(status)): \(message)"
        }
    }
}

struct OpenAISpeechService: Sendable {
    private let configuration: AppConfiguration
    private let session: URLSession

    init(configuration: AppConfiguration = .current, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func synthesize(_ text: String, language: PracticeLanguage = .english) async throws -> Data {
        guard !configuration.openAIAPIKey.isEmpty else { throw ConfigurationError.missingOpenAIKey }

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/speech")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(configuration.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": configuration.speechModel,
            "voice": configuration.realtimeVoice,
            "input": text,
            "instructions": "Speak fluently in \(language.englishName) as the same thoughtful person from a difficult conversation. Sound natural, calm, measured, specific, and emotionally honest. Do not sound like a narrator or coach.",
            "response_format": "mp3"
        ])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SpeechServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(SpeechAPIError.self, from: data).error.message) ?? "Unknown API error"
            throw SpeechServiceError.requestFailed(http.statusCode, message)
        }
        guard !data.isEmpty else { throw SpeechServiceError.invalidResponse }
        return data
    }
}

@MainActor
final class AudioPlaybackController: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var isPlaying = false
    @Published private(set) var isReady = false
    @Published private(set) var hasFinished = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var errorMessage: String?

    private let service: OpenAISpeechService
    private var player: AVAudioPlayer?
    private var ticker: Timer?

    init(service: OpenAISpeechService = OpenAISpeechService()) {
        self.service = service
    }

    func prepareAndPlay(text: String, language: PracticeLanguage = .english) async {
        await prepare(text: text, language: language, autoplay: true)
    }

    @discardableResult
    func prepare(text: String, language: PracticeLanguage = .english, autoplay: Bool) async -> Data? {
        guard !isLoading else { return nil }
        reset()
        isLoading = true

        do {
            let data = try await service.synthesize(text, language: language)
            try attach(AVAudioPlayer(data: data))
            isLoading = false
            if autoplay { play() }
            return data
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func load(url: URL) {
        reset()
        do {
            try attach(AVAudioPlayer(contentsOf: url))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func togglePlayback() {
        isPlaying ? pause() : play()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        ticker?.invalidate()
    }

    func seek(to value: TimeInterval) {
        guard let player else { return }
        player.currentTime = min(max(value, 0), player.duration)
        currentTime = player.currentTime
        hasFinished = false
    }

    func reset() {
        pause()
        player = nil
        isReady = false
        isLoading = false
        hasFinished = false
        currentTime = 0
        duration = 0
        errorMessage = nil
    }

    private func attach(_ player: AVAudioPlayer) throws {
        player.prepareToPlay()
        self.player = player
        duration = player.duration
        isReady = true
    }

    private func play() {
        guard let player else { return }
        if player.currentTime >= player.duration - 0.1 { player.currentTime = 0 }
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio)
            try audioSession.setActive(true)
            player.play()
            isPlaying = true
            hasFinished = false
            startTicker()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let player = self.player else { return }
                self.currentTime = player.currentTime
                if !player.isPlaying {
                    self.isPlaying = false
                    self.ticker?.invalidate()
                    if player.currentTime >= player.duration - 0.15 {
                        self.currentTime = player.duration
                        self.hasFinished = true
                    }
                }
            }
        }
    }
}

private struct SpeechAPIError: Decodable {
    let error: Detail

    struct Detail: Decodable {
        let message: String
    }
}
