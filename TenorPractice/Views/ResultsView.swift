import SwiftUI

struct ResultsView: View {
    enum Origin {
        case justFinished
        case history
    }

    let result: ConversationResult
    let origin: Origin
    @ObservedObject var sessions: SessionStore
    let onTryAgain: () -> Void
    let onClose: () -> Void

    @StateObject private var reflectionAudio = AudioPlaybackController()
    @StateObject private var conversationAudio = AudioPlaybackController()
    @State private var showReflectionText = false
    @State private var showConversation = false

    private var language: PracticeLanguage { result.language }

    var body: some View {
        ZStack {
            PaperBackground(dimmed: true)

            VStack(spacing: 0) {
                if origin == .history { historyChrome }

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        header
                        playerCard
                        turningPoint
                        resultRow
                        retryCard
                        if origin == .history { conversationDisclosure }
                        actions
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, origin == .history ? 10 : 20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
        }
        .task(id: result.id) {
            showReflectionText = false
            showConversation = false
            reflectionAudio.reset()
            conversationAudio.reset()
            if let url = result.conversationAudioURL {
                conversationAudio.load(url: url)
            }

            let cached = sessions.reflectionAudioURL(for: result.id)
            if FileManager.default.fileExists(atPath: cached.path) {
                reflectionAudio.load(url: cached)
                if origin == .justFinished { reflectionAudio.togglePlayback() }
            } else if let data = await reflectionAudio.prepare(
                text: result.evaluation.characterReflection,
                language: language,
                autoplay: origin == .justFinished
            ) {
                sessions.saveReflectionAudio(data, for: result.id)
            }
        }
        .onChange(of: reflectionAudio.isPlaying) { _, playing in
            if playing { conversationAudio.pause() }
        }
        .onChange(of: conversationAudio.isPlaying) { _, playing in
            if playing { reflectionAudio.pause() }
        }
        .onDisappear {
            reflectionAudio.pause()
            conversationAudio.pause()
        }
    }

    private var historyChrome: some View {
        HStack {
            BackButton(action: onClose)
            Spacer()
            Text(formattedDate)
                .font(.system(size: 13, weight: .medium, design: .serif))
                .foregroundStyle(Brand.muted)
            Spacer()
            Color.clear.frame(width: 42, height: 42)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var header: some View {
        HStack(spacing: 14) {
            CharacterPortrait(scenario: result.scenario, cornerRadius: 30)
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .overlay { Circle().stroke(Brand.accent.opacity(0.14), lineWidth: 1) }

            VStack(alignment: .leading, spacing: 3) {
                Text(language.format("How %@ experienced it", result.scenario.characterName).uppercased(with: language.locale))
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Brand.accent.opacity(0.85))
                Text("Listen before looking at the score")
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundStyle(Brand.ink.opacity(0.78))
            }
        }
    }


    private var playerCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                Button(action: reflectionAudio.togglePlayback) {
                    ZStack {
                        Circle().fill(Brand.accent)
                        if reflectionAudio.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: reflectionAudio.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .offset(x: reflectionAudio.isPlaying ? 0 : 1)
                        }
                    }
                    .frame(width: 54, height: 54)
                }
                .buttonStyle(.plain)
                .disabled(!reflectionAudio.isReady && !reflectionAudio.isLoading)
                .accessibilityLabel(
                    language.format(
                        reflectionAudio.isPlaying ? "Pause %@'s reflection" : "Play %@'s reflection",
                        result.scenario.characterName
                    )
                )

                VStack(spacing: 8) {
                    Slider(
                        value: Binding(get: { reflectionAudio.currentTime }, set: reflectionAudio.seek),
                        in: 0...max(reflectionAudio.duration, 0.1)
                    )
                    .tint(Brand.accent)
                    .disabled(!reflectionAudio.isReady)

                    HStack {
                        Text(formatTime(reflectionAudio.currentTime))
                        Spacer()
                        Text(
                            reflectionAudio.isLoading
                                ? language.format("%@ is reflecting…", result.scenario.characterName)
                                : formatTime(reflectionAudio.duration)
                        )
                    }
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Brand.muted)
                }
            }

            Button {
                withAnimation(.easeOut(duration: 0.2)) { showReflectionText.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text(language.text(showReflectionText ? "Hide written reflection" : "Read written reflection"))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .rotationEffect(.degrees(showReflectionText ? 90 : 0))
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Brand.accent)
            }
            .buttonStyle(.plain)

            if showReflectionText {
                Text(result.evaluation.characterReflection)
                    .font(.system(size: 17, design: .serif))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let error = reflectionAudio.errorMessage {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Brand.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Brand.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 14, y: 6)
    }

    private var turningPoint: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("The moment I shifted")
                .textCase(.uppercase)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(Brand.accent.opacity(0.8))
            Text(result.evaluation.turningPoint)
                .font(.system(size: 21, weight: .regular, design: .serif))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var resultRow: some View {
        VStack(spacing: 16) {
            Rectangle().fill(Brand.line).frame(height: 1)

            HStack(spacing: 14) {
                Image(systemName: "laurel.leading")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Brand.accent)
                    .frame(width: 36, height: 36)
                    .overlay { Circle().stroke(Brand.accent.opacity(0.22), lineWidth: 1) }

                Text(result.evaluation.resultLabel)
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .lineLimit(2)

                Spacer(minLength: 8)

                Text("+\(result.xpEarned) XP")
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(Brand.accent)
            }

            Rectangle().fill(Brand.line).frame(height: 1)
        }
    }

    private var retryCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "lightbulb")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Brand.accent)
                .frame(width: 48, height: 48)
                .overlay { Circle().stroke(Brand.accent.opacity(0.28), lineWidth: 1) }

            VStack(alignment: .leading, spacing: 6) {
                Text("Try one change")
                    .textCase(.uppercase)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.3)
                    .foregroundStyle(Brand.accent)
                Text(result.evaluation.retryFocus)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private var conversationDisclosure: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { showConversation.toggle() }
            } label: {
                HStack {
                    Text(language.text("The conversation"))
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .rotationEffect(.degrees(showConversation ? 90 : 0))
                }
                .foregroundStyle(Brand.accent)
            }
            .buttonStyle(.plain)

            if showConversation {
                if result.conversationAudioURL != nil {
                    AudioPlayerBar(
                        audio: conversationAudio,
                        playLabel: language.text("Play the conversation"),
                        pauseLabel: language.text("Pause the conversation")
                    )
                }

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(result.transcript) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.speaker == .user
                                 ? language.text("YOU")
                                 : result.scenario.characterName.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.3)
                                .foregroundStyle(entry.speaker == .user ? Brand.accent : Brand.muted)
                            Text(entry.text)
                                .font(.system(size: 16, design: .serif))
                                .lineSpacing(3)
                        }
                    }
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            PrimaryButton(title: "Practice again", action: onTryAgain)
            if origin == .justFinished {
                Button("Choose another conversation", action: onClose)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(Brand.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
        }
        .padding(.top, 4)
    }

    private var formattedDate: String {
        result.createdAt.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let seconds = max(0, Int(time.rounded()))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}