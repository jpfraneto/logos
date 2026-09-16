import SwiftUI

struct HomeView: View {
    @ObservedObject var progression: ProgressionStore
    @ObservedObject var languageStore: PracticeLanguageStore
    let onSelect: (Scenario) -> Void
    let onOpenHistory: () -> Void

    var body: some View {
        ZStack {
            PaperBackground(dimmed: true)

            ScrollView {
                LazyVStack(spacing: 0) {
                    masthead
                    conversations
                }
                .padding(.bottom, 38)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var masthead: some View {
        HStack {
            Button(action: onOpenHistory) {
                Image(systemName: "building.columns")
                    .font(.system(size: 16, weight: .regular))
                    .frame(width: 42, height: 42)
                    .overlay { Circle().stroke(Brand.accent.opacity(0.25)) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(languageStore.selected.text("Your dialogues"))

            Spacer()

            VStack(spacing: 2) {
                LogosWordmark(compact: true)
                Text(progressSummary)
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundStyle(Brand.accent)
            }

            Spacer()

            PracticeLanguageMenu(languageStore: languageStore)
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
    }

    private var progressSummary: String {
        let count = progression.snapshot.completedConversations
        guard count > 0 else { return languageStore.selected.text("Your first dialogue") }
        let dialogue = count == 1
            ? languageStore.selected.text("1 dialogue")
            : languageStore.selected.format("%d dialogues", count)
        if progression.snapshot.currentStreak >= 2 {
            return languageStore.selected.format("%@ · %d-day streak", dialogue, progression.snapshot.currentStreak)
        }
        return languageStore.selected.format("%@ · %d XP earned", dialogue, progression.snapshot.totalXP)
    }

    private var conversations: some View {
        VStack(spacing: 12) {
            ForEach(Scenario.library) { scenario in
                ConversationListRow(
                    scenario: scenario,
                    language: languageStore.selected,
                    completionCount: progression.snapshot.scenarioCompletions[scenario.id, default: 0],
                    action: { onSelect(scenario) }
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
    }
}

private struct ConversationListRow: View {
    let scenario: Scenario
    let language: PracticeLanguage
    let completionCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                CharacterPortrait(scenario: scenario, cornerRadius: 16)
                    .frame(width: 78, height: 78)

                VStack(alignment: .leading, spacing: 6) {
                    Text(language.text(scenario.title))
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(language.text(scenario.cardDescription))
                        .font(.system(size: 14, design: .serif).italic())
                        .foregroundStyle(Brand.muted)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Text("\(scenario.characterName) · \(scenario.durationMinutes) \(language.text("min"))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Brand.muted)
                        if completionCount > 0 {
                            Text(completionCount == 1
                                 ? language.text("PRACTICED ONCE")
                                 : language.format("PRACTICED %d TIMES", completionCount))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Brand.accent)
                        }
                    }
                    .padding(.top, 2)
                }

                Spacer(minLength: 4)
            }
            .padding(14)
            .background(Brand.card.opacity(0.86), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 20).stroke(Brand.accent.opacity(0.1)) }
        }
        .buttonStyle(.plain)
    }
}