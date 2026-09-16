import SwiftUI

struct AppRootView: View {
    fileprivate enum Route {
        case onboarding
        case home
        case history
        case conversation(Scenario, PracticeLanguage, UUID)
        case results(ConversationResult, ResultsView.Origin)
    }

    @State private var route: Route = .onboarding
    @StateObject private var progression = ProgressionStore()
    @StateObject private var sessions = SessionStore()
    @StateObject private var languageStore = PracticeLanguageStore()

    var body: some View {
        ZStack {
            Brand.background.ignoresSafeArea()

            switch route {
            case .onboarding:
                OnboardingView(languageStore: languageStore) {
                    withAnimation(.easeInOut(duration: 0.3)) { route = .home }
                }
                .transition(.opacity)

            case .home:
                HomeView(
                    progression: progression,
                    languageStore: languageStore,
                    onSelect: { scenario in
                        withAnimation(.easeOut(duration: 0.2)) {
                            route = .conversation(scenario, languageStore.selected, UUID())
                        }
                    },
                    onOpenHistory: {
                        withAnimation(.easeInOut(duration: 0.22)) { route = .history }
                    }
                )
                .transition(.opacity)

            case .history:
                HistoryView(
                    sessions: sessions,
                    languageStore: languageStore,
                    onSelect: { result in
                        withAnimation(.easeInOut(duration: 0.22)) {
                            route = .results(result, .history)
                        }
                    },
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.22)) { route = .home }
                    }
                )
                .transition(.opacity)

            case let .conversation(scenario, language, sessionID):
                ConversationView(
                    scenario: scenario,
                    language: language,
                    sessionID: sessionID,
                    onCancel: { route = .home },
                    onComplete: { result in
                        let saved = sessions.save(result)
                        progression.record(saved)
                        route = .results(saved, .justFinished)
                    }
                )
                .transition(.opacity)

            case let .results(result, origin):
                ResultsView(
                    result: result,
                    origin: origin,
                    sessions: sessions,
                    onTryAgain: { route = .conversation(result.scenario, result.language, UUID()) },
                    onClose: { route = origin == .history ? .history : .home }
                )
                .transition(.move(edge: .bottom))
            }
        }
        .foregroundStyle(Brand.ink)
        .environment(\.locale, languageStore.selected.locale)
        .animation(.easeInOut(duration: 0.22), value: route.animationKey)
    }
}

private extension AppRootView.Route {
    var animationKey: String {
        switch self {
        case .onboarding: "onboarding"
        case .home: "home"
        case .history: "history"
        case let .conversation(_, _, id): "conversation-\(id)"
        case let .results(result, origin):
            "results-\(result.id)-\(origin == .history ? "history" : "live")"
        }
    }
}