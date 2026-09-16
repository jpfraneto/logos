import Combine
import Foundation

@MainActor
final class ProgressionStore: ObservableObject {
    @Published private(set) var snapshot: ProgressionSnapshot

    private let defaults: UserDefaults
    // v2 intentionally starts clean. v1 contained prototype seed data that did
    // not represent the user's actual practice history.
    private let storageKey = "logos.progression.v2"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(ProgressionSnapshot.self, from: data) {
            snapshot = saved
        } else {
            snapshot = .empty
        }
    }

    var recommendations: [Scenario] {
        let focusedIDs: [String]
        switch snapshot.weakestSkill {
        case "Conflict":
            focusedIDs = ["give-difficult-feedback", "disagree-with-manager", "performance-conversation"]
        case "Confidence":
            focusedIDs = ["push-back-deadline", "ask-for-a-promotion", "deliver-bad-news"]
        case "Listening":
            focusedIDs = ["angry-customer", "resolve-team-tension", "set-a-boundary"]
        default:
            focusedIDs = Scenario.recommendedIDs
        }
        return focusedIDs.compactMap(Scenario.find)
    }

    func record(_ result: ConversationResult) {
        snapshot.totalXP += result.xpEarned
        snapshot.completionDates.append(Date())
        snapshot.scenarioCompletions[result.scenario.id, default: 0] += 1

        for dimension in result.evaluation.dimensions {
            snapshot.skillScoreSums[dimension.name, default: 0] += dimension.score
            snapshot.skillScoreCounts[dimension.name, default: 0] += 1
        }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
