import SwiftUI

struct OnboardingView: View {
    @ObservedObject var languageStore: PracticeLanguageStore
    let onFinish: () -> Void

    @State private var page = 0
    private let pageCount = 4

    var body: some View {
        ZStack {
            PaperBackground()

            VStack(spacing: 0) {
                ZStack {
                    if page > 0 {
                        Text("\(page + 1) / \(pageCount)")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Brand.accent)
                    }

                    HStack {
                        Spacer()
                        PracticeLanguageMenu(languageStore: languageStore)
                    }
                }
                .frame(height: 30)
                .padding(.horizontal, 28)

                TabView(selection: $page) {
                    welcome.tag(0)
                    simulation.tag(1)
                    mirror.tag(2)
                    repeatPractice.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                footer
            }
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .foregroundStyle(Brand.ink)
    }

    private var welcome: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 54)
            LogosWordmark()
            Text("PRACTICE THE CONVERSATIONS\nTHAT MATTER.")
                .font(.system(size: 12, weight: .semibold))
                .tracking(2.2)
                .multilineTextAlignment(.center)
            Rectangle().fill(Brand.accent).frame(width: 35, height: 1)
            Spacer()
            Text("A quiet place to become more yourself\nin difficult conversations.")
                .font(.system(size: 18, weight: .regular, design: .serif))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.bottom, 26)
        }
        .padding(.horizontal, 34)
    }

    private var simulation: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 16)
            onboardingTitle("Step into real\nconversations.")
            Text("Practice with characters who react like people—with their own perspective, emotions, and goals.")
                .font(.system(size: 17, design: .serif))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)

            ZStack(alignment: .leading) {
                CharacterPortrait(scenario: Scenario.library[0], cornerRadius: 130)
                    .frame(width: 260, height: 300)
                    .offset(x: 34)
                Text("I’m not sure\nthat’s the right move.")
                    .font(.system(size: 17, weight: .regular, design: .serif).italic())
                    .lineSpacing(4)
                    .padding(18)
                    .background(Brand.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
                    .offset(x: -20, y: 42)
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
    }

    private var mirror: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 16)
            onboardingTitle("See how you land.")
            Text("After the conversation, hear what it was like to be on the other side of you.")
                .font(.system(size: 17, design: .serif))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 28)

            VStack(alignment: .leading, spacing: 18) {
                Text("“")
                    .font(.system(size: 52, weight: .bold, design: .serif))
                    .foregroundStyle(Brand.accent)
                    .frame(height: 32)
                Text("I understood what you wanted. When you named the impact plainly, I started seeing your case.")
                    .font(.system(size: 23, design: .serif))
                    .lineSpacing(5)
                Text("— AN EXAMPLE REFLECTION")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.7)
                    .foregroundStyle(Brand.muted)
            }
            .padding(25)
            .background(Brand.card.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(Brand.accent.opacity(0.15)) }
            .shadow(color: .black.opacity(0.1), radius: 18, y: 8)
            .padding(.horizontal, 22)
            Spacer(minLength: 8)
        }
    }

    private var repeatPractice: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 16)
            onboardingTitle("Try again.\nNotice what changes.")
            Text("Insight becomes useful when you can immediately test a different approach.")
                .font(.system(size: 17, design: .serif))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 30)

            VStack(spacing: 0) {
                processRow(number: "I", title: "Choose", detail: "Enter one real situation")
                processRow(number: "II", title: "Practice", detail: "Speak naturally, in the moment")
                processRow(number: "III", title: "Reflect", detail: "Hear how you were experienced")
                processRow(number: "IV", title: "Practice again", detail: "Try one meaningful change", showLine: false)
            }
            .padding(.horizontal, 18)
            .background(Brand.card.opacity(0.82), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 24).stroke(Brand.accent.opacity(0.12)) }
            .padding(.horizontal, 22)
            Spacer(minLength: 8)
        }
    }

    private func onboardingTitle(_ title: String) -> some View {
        VStack(spacing: 17) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 37, weight: .semibold, design: .serif))
                .multilineTextAlignment(.center)
                .lineSpacing(-2)
            Rectangle().fill(Brand.accent).frame(width: 36, height: 1)
        }
    }

    private func processRow(number: String, title: String, detail: String, showLine: Bool = true) -> some View {
        HStack(spacing: 17) {
            Text(number)
                .font(.system(size: 23, weight: .regular, design: .serif))
                .foregroundStyle(Brand.accent)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey(title)).font(.system(size: 19, weight: .semibold, design: .serif))
                Text(LocalizedStringKey(detail)).font(.system(size: 13)).foregroundStyle(Brand.muted)
            }
            Spacer()
        }
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            if showLine { Rectangle().fill(Brand.line).frame(height: 1).padding(.leading, 49) }
        }
    }

    private var footer: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Circle()
                        .fill(index == page ? Brand.accent : Brand.ink.opacity(0.18))
                        .frame(width: 8, height: 8)
                }
            }

            if page == pageCount - 1 {
                PrimaryButton(title: "Let’s begin", action: onFinish)
                    .padding(.horizontal, 28)
            } else {
                HStack {
                    if page > 0 {
                        Button("Back") { withAnimation { page -= 1 } }
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                    }
                    Spacer()
                    Button {
                        withAnimation { page += 1 }
                    } label: {
                        HStack(spacing: 9) {
                            Text(LocalizedStringKey(page == 0 ? "Enter Logos" : "Next"))
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundStyle(Brand.accent)
                    }
                }
                .padding(.horizontal, 30)
                .frame(height: 56)
            }
        }
        .frame(minHeight: 94)
    }
}
