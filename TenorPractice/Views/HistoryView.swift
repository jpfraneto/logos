import SwiftUI

struct HistoryView: View {
    @ObservedObject var sessions: SessionStore
    @ObservedObject var languageStore: PracticeLanguageStore
    let onSelect: (ConversationResult) -> Void
    let onBack: () -> Void

    var body: some View {
        ZStack {
            PaperBackground(dimmed: true)

            VStack(spacing: 0) {
                masthead
                if sessions.sessions.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
        }
    }

    private var masthead: some View {
        HStack {
            BackButton(action: onBack)

            Spacer()

            VStack(spacing: 2) {
                Text(languageStore.selected.text("Your dialogues"))
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                if !sessions.sessions.isEmpty {
                    Text(sessionCount)
                        .font(.system(size: 12, weight: .medium, design: .serif))
                        .foregroundStyle(Brand.accent)
                }
            }

            Spacer()
            Color.clear.frame(width: 42, height: 42)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var sessionCount: String {
        let count = sessions.sessions.count
        return count == 1
            ? languageStore.selected.text("1 dialogue")
            : languageStore.selected.format("%d dialogues", count)
    }

    private var list: some View {
        List {
            ForEach(sessions.sessions) { session in
                Button {
                    onSelect(sessions.result(for: session))
                } label: {
                    HistorySessionRow(session: session, language: languageStore.selected)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .onDelete { indexSet in
                indexSet.map { sessions.sessions[$0] }.forEach(sessions.delete)
            }
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "building.columns")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Brand.accent)
            Text(languageStore.selected.text("Completed conversations will appear here."))
                .font(.system(size: 18, design: .serif))
                .foregroundStyle(Brand.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HistorySessionRow: View {
    let session: SavedSession
    let language: PracticeLanguage

    var body: some View {
        HStack(spacing: 14) {
            CharacterPortrait(scenario: session.displayScenario, cornerRadius: 16)
                .frame(width: 68, height: 68)

            VStack(alignment: .leading, spacing: 5) {
                Text(language.text(session.scenarioTitle))
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .lineLimit(2)
                Text("\(session.characterName) · \(session.createdAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Brand.muted)
                Text(session.evaluation.retryFocus)
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(Brand.muted)
                    .lineLimit(2)
                    .lineSpacing(2)
            }

            Spacer(minLength: 6)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Brand.accent)
        }
        .padding(12)
        .background(Brand.card.opacity(0.86), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(Brand.accent.opacity(0.1)) }
    }
}