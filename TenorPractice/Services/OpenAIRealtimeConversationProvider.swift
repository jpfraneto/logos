@preconcurrency import AVFoundation
import Combine
import Foundation
@preconcurrency import LiveKitWebRTC

// LiveKit's binary distribution prefixes the upstream WebRTC Objective-C
// symbols with `LK` so it can coexist safely with other WebRTC frameworks.
typealias RTCPeerConnectionFactory = LKRTCPeerConnectionFactory
typealias RTCPeerConnection = LKRTCPeerConnection
typealias RTCDataChannel = LKRTCDataChannel
typealias RTCDataChannelDelegate = LKRTCDataChannelDelegate
typealias RTCDataChannelConfiguration = LKRTCDataChannelConfiguration
typealias RTCDataBuffer = LKRTCDataBuffer
typealias RTCAudioTrack = LKRTCAudioTrack
typealias RTCConfiguration = LKRTCConfiguration
typealias RTCMediaConstraints = LKRTCMediaConstraints
typealias RTCSessionDescription = LKRTCSessionDescription
typealias RTCPeerConnectionDelegate = LKRTCPeerConnectionDelegate
typealias RTCSignalingState = LKRTCSignalingState
typealias RTCMediaStream = LKRTCMediaStream
typealias RTCIceConnectionState = LKRTCIceConnectionState
typealias RTCIceGatheringState = LKRTCIceGatheringState
typealias RTCIceCandidate = LKRTCIceCandidate
typealias RTCRtpReceiver = LKRTCRtpReceiver
typealias RTCPeerConnectionState = LKRTCPeerConnectionState

enum RealtimeProviderError: LocalizedError {
    case microphoneDenied
    case invalidEndpoint
    case audioUnavailable
    case connectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            "Microphone access is off. Allow it in Settings to practice by voice."
        case .invalidEndpoint:
            "The OpenAI Realtime connection could not be created."
        case .audioUnavailable:
            "Audio is unavailable on this device right now."
        case let .connectionFailed(message):
            message
        }
    }
}

/// OpenAI Realtime over WebRTC. WebRTC owns microphone capture, jitter buffering,
/// decoding, and speaker playback so model audio remains a single media stream.
@MainActor
final class OpenAIRealtimeConversationProvider: NSObject, RealtimeConversationProvider {
    @Published private(set) var phase: ConversationPhase = .idle
    @Published private(set) var transcript: [TranscriptEntry] = []
    @Published private(set) var liveCaption: LiveCaption?
    @Published private(set) var isMuted = false
    @Published private(set) var isSpeakerEnabled = true
    @Published private(set) var audioLevel = 0.04
    @Published private(set) var isUserSpeaking = false

    private let configuration: AppConfiguration
    private let networkSession: URLSession
    private let peerFactory = RTCPeerConnectionFactory()

    private var peerConnection: RTCPeerConnection?
    private var dataChannel: RTCDataChannel?
    private var microphoneTrack: RTCAudioTrack?
    private var remoteAudioTrack: RTCAudioTrack?
    private var recorder: ConversationAudioRecorder?
    private(set) var recordedAudioURL: URL?
    private var assistantDraft = ""
    private var userDraft = ""
    private var pendingOpeningMessage: String?
    private var pendingLanguage: PracticeLanguage = .english
    private var hasSentOpening = false
    private var responseHadAudio = false
    private var inputGateOpen = false
    private var isDisconnecting = false

    init(configuration: AppConfiguration = .current, session: URLSession = .shared) {
        self.configuration = configuration
        self.networkSession = session
        super.init()
    }

    func connect(scenario: Scenario, language: PracticeLanguage) async throws {
        guard !configuration.openAIAPIKey.isEmpty else { throw ConfigurationError.missingOpenAIKey }
        guard URL(string: "https://api.openai.com/v1/realtime/calls") != nil else {
            throw RealtimeProviderError.invalidEndpoint
        }

        guard await requestMicrophonePermission() else {
            throw RealtimeProviderError.microphoneDenied
        }

        await tearDown(markEnded: false)
        phase = .connecting
        transcript = []
        liveCaption = nil
        assistantDraft = ""
        userDraft = ""
        pendingOpeningMessage = scenario.firstMessage
        pendingLanguage = language
        hasSentOpening = false
        responseHadAudio = false
        inputGateOpen = false
        isMuted = false
        isUserSpeaking = false
        isDisconnecting = false
        audioLevel = 0.04
        recordedAudioURL = nil
        recorder = ConversationAudioRecorder()

        do {
            try configureAudioSession()
            let peer = try makePeerConnection()
            peerConnection = peer

            let audioSource = peerFactory.audioSource(with: RTCMediaConstraints(
                mandatoryConstraints: nil,
                optionalConstraints: [
                    "googEchoCancellation": "true",
                    "googAutoGainControl": "true",
                    "googNoiseSuppression": "true"
                ]
            ))
            let track = peerFactory.audioTrack(with: audioSource, trackId: "logos-microphone")
            track.isEnabled = false
            microphoneTrack = track
            if let recorder { track.add(recorder) }
            guard peer.add(track, streamIds: ["logos-session"]) != nil else {
                throw RealtimeProviderError.audioUnavailable
            }

            let channelConfiguration = RTCDataChannelConfiguration()
            channelConfiguration.isOrdered = true
            guard let channel = peer.dataChannel(forLabel: "oai-events", configuration: channelConfiguration) else {
                throw RealtimeProviderError.connectionFailed("The live event channel could not be created.")
            }
            channel.delegate = self
            dataChannel = channel

            let offer = try await createOffer(on: peer)
            try await setLocalDescription(offer, on: peer)
            let answerSDP = try await createOpenAISession(
                offerSDP: offer.sdp,
                scenario: scenario,
                language: language
            )
            try await setRemoteDescription(
                RTCSessionDescription(type: .answer, sdp: answerSDP),
                on: peer
            )
            try applyAudioRoute()
        } catch {
            await tearDown(markEnded: false)
            phase = .failed(error.localizedDescription)
            throw error
        }
    }

    func disconnect() async {
        await tearDown(markEnded: true)
    }

    func toggleMute() async throws {
        isMuted.toggle()
        updateMicrophoneState()
    }

    func toggleSpeaker() async throws {
        isSpeakerEnabled.toggle()
        do {
            try applyAudioRoute()
        } catch {
            isSpeakerEnabled.toggle()
            throw error
        }
    }

    private func makePeerConnection() throws -> RTCPeerConnection {
        let rtcConfiguration = RTCConfiguration()
        rtcConfiguration.sdpSemantics = .unifiedPlan
        rtcConfiguration.continualGatheringPolicy = .gatherContinually
        rtcConfiguration.audioJitterBufferFastAccelerate = true

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )
        guard let peer = peerFactory.peerConnection(
            with: rtcConfiguration,
            constraints: constraints,
            delegate: self
        ) else {
            throw RealtimeProviderError.connectionFailed("The realtime voice connection could not start.")
        }
        return peer
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.allowBluetoothHFP]
        )
        try session.setPreferredIOBufferDuration(0.02)
        try session.setActive(true)
        try applyAudioRoute()
    }

    private func applyAudioRoute() throws {
        try AVAudioSession.sharedInstance().overrideOutputAudioPort(isSpeakerEnabled ? .speaker : .none)
    }

    private func createOffer(on peer: RTCPeerConnection) async throws -> RTCSessionDescription {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true",
                "OfferToReceiveVideo": "false"
            ],
            optionalConstraints: nil
        )
        return try await withCheckedThrowingContinuation { continuation in
            peer.offer(for: constraints) { offer, error in
                if let offer {
                    continuation.resume(returning: offer)
                } else {
                    continuation.resume(throwing: error ?? RealtimeProviderError.invalidEndpoint)
                }
            }
        }
    }

    private func setLocalDescription(
        _ description: RTCSessionDescription,
        on peer: RTCPeerConnection
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            peer.setLocalDescription(description) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            }
        }
    }

    private func setRemoteDescription(
        _ description: RTCSessionDescription,
        on peer: RTCPeerConnection
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            peer.setRemoteDescription(description) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            }
        }
    }

    private func createOpenAISession(
        offerSDP: String,
        scenario: Scenario,
        language: PracticeLanguage
    ) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/realtime/calls") else {
            throw RealtimeProviderError.invalidEndpoint
        }

        let sessionJSON = try JSONSerialization.data(
            withJSONObject: realtimeSessionConfiguration(for: scenario, language: language)
        )
        let boundary = "logos-\(UUID().uuidString)"
        let body = multipartBody(
            boundary: boundary,
            sdp: Data(offerSDP.utf8),
            sessionJSON: sessionJSON
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(configuration.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await networkSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RealtimeProviderError.invalidEndpoint
        }
        guard (200..<300).contains(http.statusCode) else {
            let serverMessage = Self.openAIErrorMessage(from: data)
            throw RealtimeProviderError.connectionFailed(
                serverMessage ?? "OpenAI could not start the live conversation (\(http.statusCode))."
            )
        }
        guard let answer = String(data: data, encoding: .utf8), answer.contains("v=0") else {
            throw RealtimeProviderError.connectionFailed("OpenAI returned an invalid voice connection.")
        }
        return answer
    }

    private func realtimeSessionConfiguration(
        for scenario: Scenario,
        language: PracticeLanguage
    ) -> [String: Any] {
        [
            "type": "realtime",
            "model": configuration.realtimeModel,
            "instructions": """
            \(scenario.roleplayPrompt)

            # Required language
            Speak only in \(language.englishName). Understand the user in that language and keep every response, including numbers and dates, natural for a fluent \(language.englishName) speaker.
            """,
            "output_modalities": ["audio"],
            "max_output_tokens": 600,
            "audio": [
                "input": [
                    "transcription": [
                        "model": "gpt-4o-mini-transcribe",
                        "language": language.rawValue
                    ],
                    "noise_reduction": ["type": "near_field"],
                    "turn_detection": [
                        "type": "semantic_vad",
                        "eagerness": "low",
                        "create_response": true,
                        "interrupt_response": false
                    ]
                ],
                "output": ["voice": configuration.realtimeVoice]
            ]
        ]
    }

    private func multipartBody(boundary: String, sdp: Data, sessionJSON: Data) -> Data {
        var body = Data()
        func append(_ string: String) { body.append(Data(string.utf8)) }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"sdp\"\r\n")
        append("Content-Type: application/sdp\r\n\r\n")
        body.append(sdp)
        append("\r\n--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"session\"\r\n")
        append("Content-Type: application/json\r\n\r\n")
        body.append(sessionJSON)
        append("\r\n--\(boundary)--\r\n")
        return body
    }

    private func handleEventData(_ data: Data) {
        guard let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = event["type"] as? String else { return }

        switch type {
        case "input_audio_buffer.speech_started":
            isUserSpeaking = true
            userDraft = ""
            if inputGateOpen { setPhase(.listening) }

        case "input_audio_buffer.speech_stopped":
            isUserSpeaking = false
            closeInputGate()
            setPhase(.thinking)

        case "response.created":
            isUserSpeaking = false
            assistantDraft = ""
            responseHadAudio = false
            closeInputGate()
            setPhase(.thinking)

        case "output_audio_buffer.started":
            responseHadAudio = true
            closeInputGate()
            setPhase(.speaking)

        case "output_audio_buffer.stopped":
            openInputGate()

        case "conversation.item.input_audio_transcription.delta":
            if let delta = event["delta"] as? String {
                userDraft += delta
                publishCaption(userDraft, speaker: .user)
            }

        case "conversation.item.input_audio_transcription.completed":
            let completed = (event["transcript"] as? String) ?? userDraft
            appendTranscript(completed, speaker: .user)
            publishCaption(completed, speaker: .user)
            userDraft = ""

        case "response.output_audio_transcript.delta", "response.audio_transcript.delta":
            if let delta = event["delta"] as? String {
                assistantDraft += delta
                publishCaption(assistantDraft, speaker: .character)
            }

        case "response.output_audio_transcript.done", "response.audio_transcript.done":
            let completed = (event["transcript"] as? String) ?? assistantDraft
            appendTranscript(completed, speaker: .character)
            publishCaption(completed, speaker: .character)
            assistantDraft = ""

        case "response.done":
            guard !responseHadAudio else { break }
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(600))
                guard let self, !self.responseHadAudio, !self.isDisconnecting else { return }
                self.openInputGate()
            }

        case "error":
            let details = event["error"] as? [String: Any]
            setPhase(.failed((details?["message"] as? String) ?? "The live conversation was interrupted."))

        default:
            break
        }
    }

    private func sendOpeningIfReady() {
        guard !hasSentOpening,
              dataChannel?.readyState == .open,
              let opening = pendingOpeningMessage else { return }
        hasSentOpening = true
        pendingOpeningMessage = nil
        closeInputGate()
        setPhase(.thinking)

        let sent = sendEvent([
            "type": "response.create",
            "response": [
                "instructions": "Begin in character now. In \(pendingLanguage.englishName), naturally convey exactly the meaning of this opening and say nothing before it: \(opening)",
                "output_modalities": ["audio"]
            ]
        ])
        if !sent {
            setPhase(.failed("The live event channel closed before the conversation began."))
        }
    }

    @discardableResult
    private func sendEvent(_ payload: [String: Any]) -> Bool {
        guard let dataChannel,
              dataChannel.readyState == .open,
              let data = try? JSONSerialization.data(withJSONObject: payload) else { return false }
        return dataChannel.sendData(RTCDataBuffer(data: data, isBinary: false))
    }

    private func openInputGate() {
        guard !isDisconnecting else { return }
        inputGateOpen = true
        updateMicrophoneState()
        setPhase(.listening)
    }

    private func closeInputGate() {
        inputGateOpen = false
        updateMicrophoneState()
    }

    private func updateMicrophoneState() {
        microphoneTrack?.isEnabled = inputGateOpen && !isMuted && !isDisconnecting
        audioLevel = isMuted ? 0.02 : (phase == .speaking ? 0.72 : 0.04)
    }

    private func setPhase(_ newPhase: ConversationPhase) {
        phase = newPhase
        switch newPhase {
        case .speaking: audioLevel = 0.72
        case .thinking: audioLevel = 0.12
        default: audioLevel = isMuted ? 0.02 : 0.04
        }
    }

    private func appendTranscript(_ text: String?, speaker: Speaker) {
        guard let cleaned = text?.trimmingCharacters(in: .whitespacesAndNewlines), !cleaned.isEmpty else { return }
        guard transcript.last?.speaker != speaker || transcript.last?.text != cleaned else { return }
        transcript.append(TranscriptEntry(speaker: speaker, text: cleaned))
    }

    private func publishCaption(_ text: String?, speaker: Speaker) {
        guard let cleaned = text?.trimmingCharacters(in: .whitespacesAndNewlines), !cleaned.isEmpty else { return }
        liveCaption = LiveCaption(speaker: speaker, text: cleaned)
    }

    private func attachRemoteRecorder(to track: RTCAudioTrack) {
        guard track != microphoneTrack else { return }
        if let recorder {
            if let previous = remoteAudioTrack, previous !== track {
                previous.remove(recorder)
            }
            track.add(recorder)
        }
        remoteAudioTrack = track
    }

    private func tearDown(markEnded: Bool) async {
        isDisconnecting = true
        inputGateOpen = false
        isUserSpeaking = false
        microphoneTrack?.isEnabled = false
        if let recorder {
            microphoneTrack?.remove(recorder)
            remoteAudioTrack?.remove(recorder)
            recordedAudioURL = recorder.finish()
            self.recorder = nil
        }
        dataChannel?.delegate = nil
        dataChannel?.close()
        dataChannel = nil
        peerConnection?.delegate = nil
        peerConnection?.close()
        peerConnection = nil
        microphoneTrack = nil
        remoteAudioTrack = nil

        if !assistantDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appendTranscript(assistantDraft, speaker: .character)
            publishCaption(assistantDraft, speaker: .character)
            assistantDraft = ""
        }
        if !userDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appendTranscript(userDraft, speaker: .user)
            publishCaption(userDraft, speaker: .user)
            userDraft = ""
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if markEnded { setPhase(.ended) }
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    nonisolated private static func openAIErrorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = object["error"] as? [String: Any] else { return nil }
        return error["message"] as? String
    }
}

extension OpenAIRealtimeConversationProvider: RTCDataChannelDelegate {
    nonisolated func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        guard dataChannel.readyState == .open else { return }
        Task { @MainActor [weak self] in self?.sendOpeningIfReady() }
    }

    nonisolated func dataChannel(
        _ dataChannel: RTCDataChannel,
        didReceiveMessageWith buffer: RTCDataBuffer
    ) {
        Task { @MainActor [weak self] in self?.handleEventData(buffer.data) }
    }
}

extension OpenAIRealtimeConversationProvider: RTCPeerConnectionDelegate {
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        stream.audioTracks.forEach { $0.isEnabled = true }
        Task { @MainActor [weak self] in
            guard let self else { return }
            for track in stream.audioTracks {
                self.attachRemoteRecorder(to: track)
            }
        }
    }
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    nonisolated func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        guard newState == .failed else { return }
        Task { @MainActor [weak self] in
            guard self?.isDisconnecting == false else { return }
            self?.setPhase(.failed("The live voice connection was lost. Check your network and try again."))
        }
    }
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        dataChannel.delegate = self
        Task { @MainActor [weak self] in
            self?.dataChannel = dataChannel
            self?.sendOpeningIfReady()
        }
    }
    nonisolated func peerConnection(
        _ peerConnection: RTCPeerConnection,
        didAdd rtpReceiver: RTCRtpReceiver,
        streams mediaStreams: [RTCMediaStream]
    ) {
        rtpReceiver.track?.isEnabled = true
        Task { @MainActor [weak self] in
            if let track = rtpReceiver.track as? RTCAudioTrack {
                self?.attachRemoteRecorder(to: track)
            }
        }
    }
    nonisolated func peerConnection(
        _ peerConnection: RTCPeerConnection,
        didChange newState: RTCPeerConnectionState
    ) {
        guard newState == .failed else { return }
        Task { @MainActor [weak self] in
            guard self?.isDisconnecting == false else { return }
            self?.setPhase(.failed("The live voice connection was lost. Check your network and try again."))
        }
    }
}
