import SwiftUI

struct ConversationView: View {
    let scenario: Scenario
    let language: PracticeLanguage
    let sessionID: UUID
    let onCancel: () -> Void
    let onComplete: (ConversationResult) -> Void

    @StateObject private var provider = OpenAIRealtimeConversationProvider()
    @State private var startedAt = Date()
    @State private var isReflecting = false
    @State private var isFinishing = false
    @State private var errorMessage: String?

    private let evaluator = OpenAIEvaluationService()

    var body: some View {
        ZStack {
            Brand.practiceBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 10)
                portrait
                LiveCaptions(
                    caption: provider.liveCaption,
                    characterName: scenario.characterName,
                    phase: provider.phase,
                    language: language
                )
                .padding(.top, 12)
                presenceState
                Spacer(minLength: 10)
                controls
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            if isReflecting { reflectionOverlay }
        }
        .foregroundStyle(Brand.practiceInk)
        .task(id: sessionID) {
            startedAt = Date()
            do {
                try await provider.connect(scenario: scenario, language: language)
                try await Task.sleep(for: .seconds(scenario.durationMinutes * 60))
                guard !Task.isCancelled else { return }
                await finishWhenConversationSettles()
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button {
                Task {
                    await provider.disconnect()
                    onCancel()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.09), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(language.text("Leave conversation"))

            VStack(alignment: .leading, spacing: 2) {
                Text(language.text(scenario.title))
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                Text("\(scenario.characterName) · \(language.text(scenario.characterRole))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Brand.practiceInk.opacity(0.56))
                    .lineLimit(1)
            }

            Spacer()

            TimelineView(.periodic(from: startedAt, by: 1)) { context in
                SessionClock(
                    elapsed: max(0, context.date.timeIntervalSince(startedAt)),
                    duration: TimeInterval(scenario.durationMinutes * 60)
                )
            }

        }
        .padding(.top, 8)
    }

    private var portrait: some View {
        ZStack(alignment: .bottom) {
            CharacterPortrait(scenario: scenario, cornerRadius: 110)
                .frame(width: 238, height: 252)
                .overlay {
                    RoundedRectangle(cornerRadius: 110, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: scenario.theme.color.opacity(0.34), radius: 44, y: 18)

            if provider.phase == .speaking {
                HStack(spacing: 5) {
                    ForEach(0..<4, id: \.self) { index in
                        Capsule()
                            .fill(.white.opacity(0.9))
                            .frame(width: 4, height: CGFloat(8 + index % 2 * 7))
                    }
                }
                .padding(.horizontal, 15)
                .frame(height: 36)
                .background(.black.opacity(0.48), in: Capsule())
                .padding(.bottom, 18)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.25), value: provider.phase)
    }

    private var presenceState: some View {
        VStack(spacing: 9) {
            Text(language.text(provider.phase.label))
                .font(.system(size: 21, weight: .semibold, design: .serif))
                .contentTransition(.opacity)

            AudioPulse(level: provider.audioLevel, phase: provider.phase)
                .frame(height: 28)

            if case let .failed(message) = provider.phase {
                inlineError(message)
            } else if let errorMessage {
                inlineError(errorMessage)
            } else {
                Text(stateHint)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Brand.practiceInk.opacity(0.5))
            }
        }
        .padding(.top, 13)
    }

    private var stateHint: String {
        switch provider.phase {
        case .connecting: language.text("Making the room quiet…")
        case .speaking: language.format("Let %@ finish—or respond naturally", scenario.characterName)
        case .thinking: language.format("%@ is considering what you said", scenario.characterName)
        default: provider.isMuted ? language.text("Your microphone is muted") : language.text("Speak when you're ready")
        }
    }

    private var controls: some View {
        HStack(spacing: 28) {
            CallControl(
                icon: provider.isMuted ? "mic.slash.fill" : "mic.fill",
                label: language.text(provider.isMuted ? "Unmute" : "Mute"),
                isActive: provider.isMuted
            ) {
                Task {
                    do { try await provider.toggleMute() }
                    catch { errorMessage = error.localizedDescription }
                }
            }

            CallControl(
                icon: provider.isSpeakerEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                label: language.text(provider.isSpeakerEnabled ? "Speaker" : "Earpiece"),
                isActive: !provider.isSpeakerEnabled
            ) {
                Task {
                    do { try await provider.toggleSpeaker() }
                    catch { errorMessage = error.localizedDescription }
                }
            }

            CallControl(
                icon: "phone.down.fill",
                label: language.text("End"),
                tint: Color(red: 0.78, green: 0.16, blue: 0.13)
            ) {
                Task { await finishAndReflect() }
            }
            .disabled(
                provider.phase == .connecting ||
                provider.phase == .idle ||
                isFinishing
            )
        }
    }

    private var reflectionOverlay: some View {
        ZStack {
            Brand.practiceBackground.ignoresSafeArea()
            VStack(spacing: 22) {
                CharacterPortrait(scenario: scenario, cornerRadius: 38)
                    .frame(width: 78, height: 78)
                    .overlay { RoundedRectangle(cornerRadius: 38).stroke(.white.opacity(0.15)) }

                Text("Holding onto the moment…")
                    .font(.system(size: 27, weight: .bold, design: .rounded))

                Text(language.format("%@ is reflecting on what it felt like to talk with you.", scenario.characterName))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Brand.practiceInk.opacity(0.58))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 290)

                ProgressView()
                    .tint(Brand.practiceInk)
                    .padding(.top, 4)
            }
        }
        .transition(.opacity)
    }

    private func inlineError(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color(red: 0.97, green: 0.61, blue: 0.47))
            .multilineTextAlignment(.center)
            .padding(12)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
            .frame(maxWidth: 320)
    }

    private func finishAndReflect() async {
        guard !isFinishing else { return }
        isFinishing = true
        await provider.disconnect()
        let capturedTranscript = provider.transcript
        isReflecting = true
        errorMessage = nil

        do {
            let evaluation = try await evaluator.evaluate(
                scenario: scenario,
                language: language,
                transcript: capturedTranscript
            )
            onComplete(ConversationResult(
                scenario: scenario,
                language: language,
                transcript: capturedTranscript,
                evaluation: evaluation,
                conversationAudioURL: provider.recordedAudioURL
            ))
        } catch {
            isReflecting = false
            isFinishing = false
            errorMessage = error.localizedDescription
        }
    }

    private func finishWhenConversationSettles() async {
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline,
              provider.phase == .speaking || provider.phase == .thinking || provider.isUserSpeaking {
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
        await finishAndReflect()
    }
}

private struct CallControl: View {
    let icon: String
    let label: String
    var isActive = false
    var tint: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint == nil ? Brand.practiceInk : Color.white)
                    .frame(width: 58, height: 58)
                    .background(
                        tint ?? .white.opacity(isActive ? 0.2 : 0.09),
                        in: Circle()
                    )
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Brand.practiceInk.opacity(0.58))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct SessionClock: View {
    let elapsed: TimeInterval
    let duration: TimeInterval

    private var progress: Double { min(max(elapsed / duration, 0), 1) }
    private var remaining: Int { max(0, Int(duration - elapsed)) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Brand.practiceInk.opacity(0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
        }
        .frame(width: 40, height: 40)
        .accessibilityLabel("\(remaining) seconds remaining")
    }
}

private struct AudioPulse: View {
    let level: Double
    let phase: ConversationPhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12)) { timeline in
            HStack(alignment: .center, spacing: 4) {
                ForEach(0..<11, id: \.self) { index in
                    let wave = (sin(timeline.date.timeIntervalSinceReferenceDate * 4 + Double(index) * 0.75) + 1) / 2
                    let active = phase == .speaking || phase == .listening
                    Capsule()
                        .fill(Brand.practiceInk.opacity(active ? 0.62 : 0.2))
                        .frame(width: 3, height: active ? 5 + 17 * max(level, wave * 0.26) : 4)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct LiveCaptions: View {
    let caption: LiveCaption?
    let characterName: String
    let phase: ConversationPhase
    let language: PracticeLanguage

    var body: some View {
        VStack(spacing: 5) {
            Text(speakerLabel)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(speakerColor)

            ScrollViewReader { proxy in
                ScrollView {
                    Text(captionText)
                        .font(.system(size: 17, weight: .medium, design: .serif))
                        .foregroundStyle(Brand.practiceInk.opacity(caption == nil ? 0.42 : 0.92))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity)
                        .id("caption-bottom")
                }
                .scrollIndicators(.hidden)
                .onChange(of: caption?.text) { _, _ in
                    proxy.scrollTo("caption-bottom", anchor: .bottom)
                }
            }
            .frame(height: 62)
        }
        .frame(maxWidth: 330)
        .frame(height: 78)
        .accessibilityElement(children: .combine)
    }

    private var speakerLabel: String {
        guard let caption else { return language.text("LIVE CAPTIONS") }
        return caption.speaker == .user ? language.text("YOU") : characterName.uppercased()
    }

    private var speakerColor: Color {
        caption?.speaker == .user ? Brand.gold : Brand.practiceInk.opacity(0.54)
    }

    private var captionText: String {
        if let caption { return caption.text }
        return switch phase {
        case .connecting: language.text("Connecting…")
        case .thinking: "…"
        default: language.text("What you both say will appear here.")
        }
    }
}
