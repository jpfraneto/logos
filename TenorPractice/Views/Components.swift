import SwiftUI

struct PaperBackground: View {
    var dimmed = false

    var body: some View {
        ZStack {
            Brand.background
            Image("LogosPaperBackground")
                .resizable()
                .scaledToFill()
                .opacity(dimmed ? 0.24 : 0.58)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct LogosWordmark: View {
    var compact = false

    var body: some View {
        Text("LOGOS")
            .font(.system(size: compact ? 22 : 42, weight: .regular, design: .serif))
            .tracking(compact ? 5 : 8)
            .accessibilityAddTraits(.isHeader)
    }
}

struct OrnamentalDivider: View {
    var body: some View {
        HStack(spacing: 14) {
            Rectangle().fill(Brand.accent.opacity(0.35)).frame(height: 1)
            Image(systemName: "laurel.leading")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(Brand.accent)
            Rectangle().fill(Brand.accent.opacity(0.35)).frame(height: 1)
        }
    }
}

struct PrimaryButton: View {
    let title: String
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading { ProgressView().tint(.white) }
                Text(LocalizedStringKey(title))
                    .font(.system(size: 18, weight: .semibold, design: .serif))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .foregroundStyle(.white)
            .background(Brand.accent, in: Capsule())
            .shadow(color: Brand.accent.opacity(0.2), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

struct CharacterPortrait: View {
    let scenario: Scenario
    var cornerRadius: CGFloat = 28

    var body: some View {
        Group {
            if let portraitName = scenario.portraitName {
                Image(portraitName)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    scenario.theme.color
                    Text(String(scenario.characterName.prefix(1)))
                        .font(.system(size: 52, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityLabel("\(scenario.characterName), \(scenario.characterRole)")
    }
}

struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .bold))
                .frame(width: 42, height: 42)
                .background(.white, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Back"))
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(LocalizedStringKey(text))
            .textCase(.uppercase)
            .font(.system(size: 12, weight: .black))
            .tracking(1.3)
            .foregroundStyle(Brand.muted)
    }
}

struct AudioPlayerBar: View {
    @ObservedObject var audio: AudioPlaybackController
    let playLabel: String
    let pauseLabel: String
    var loadingLabel: String?

    var body: some View {
        HStack(spacing: 14) {
            Button(action: audio.togglePlayback) {
                ZStack {
                    Circle().fill(Brand.accent)
                    if audio.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: audio.isPlaying ? 0 : 1)
                    }
                }
                .frame(width: 50, height: 50)
            }
            .buttonStyle(.plain)
            .disabled(!audio.isReady && !audio.isLoading)
            .accessibilityLabel(audio.isPlaying ? pauseLabel : playLabel)

            VStack(spacing: 5) {
                Slider(
                    value: Binding(get: { audio.currentTime }, set: audio.seek),
                    in: 0...max(audio.duration, 0.1)
                )
                .tint(Brand.accent)
                .disabled(!audio.isReady)

                HStack {
                    Text(format(audio.currentTime))
                    Spacer()
                    Text(audio.isLoading ? (loadingLabel ?? "…") : format(audio.duration))
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Brand.muted)
            }
        }
        .padding(14)
        .background(Brand.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func format(_ time: TimeInterval) -> String {
        let seconds = max(0, Int(time.rounded()))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct PracticeLanguageMenu: View {
    @ObservedObject var languageStore: PracticeLanguageStore

    var body: some View {
        Menu {
            Picker("Practice language", selection: $languageStore.selected) {
                ForEach(PracticeLanguage.allCases) { language in
                    Text(language.nativeName).tag(language)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                Text(languageStore.selected.shortCode)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .font(.system(size: 14, weight: .semibold))
            .frame(width: 52, height: 42)
            .overlay { Capsule().stroke(Brand.accent.opacity(0.25)) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(languageStore.selected.format("Practice language: %@", languageStore.selected.nativeName))
    }
}

extension Scenario.Theme {
    var color: Color {
        switch self {
        case .terracotta: Color(red: 0.66, green: 0.27, blue: 0.16)
        case .amber: Color(red: 0.68, green: 0.44, blue: 0.15)
        case .teal: Color(red: 0.14, green: 0.35, blue: 0.35)
        case .plum: Color(red: 0.39, green: 0.24, blue: 0.36)
        case .olive: Color(red: 0.35, green: 0.39, blue: 0.20)
        case .slate: Color(red: 0.28, green: 0.32, blue: 0.36)
        }
    }
}
