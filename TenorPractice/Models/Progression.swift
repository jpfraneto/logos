import Foundation

struct ProgressionSnapshot: Codable, Equatable, Sendable {
    var totalXP: Int
    var completionDates: [Date]
    var skillScoreSums: [String: Int]
    var skillScoreCounts: [String: Int]
    var scenarioCompletions: [String: Int]

    static let empty = ProgressionSnapshot(
        totalXP: 0,
        completionDates: [],
        skillScoreSums: [:],
        skillScoreCounts: [:],
        scenarioCompletions: [:]
    )

    var completedConversations: Int { completionDates.count }

    var skillScores: [String: Int] {
        skillScoreSums.reduce(into: [:]) { result, item in
            let count = max(skillScoreCounts[item.key] ?? 0, 1)
            result[item.key] = Int((Double(item.value) / Double(count)).rounded())
        }
    }

    var currentStreak: Int {
        guard !completionDates.isEmpty else { return 0 }
        let calendar = Calendar.current
        let practicedDays = Set(completionDates.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        guard practicedDays.contains(today) || practicedDays.contains(yesterday) else { return 0 }

        var cursor = practicedDays.contains(today) ? today : yesterday
        var streak = 0
        while practicedDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    var weakestSkill: String? {
        skillScores.min(by: { $0.value < $1.value })?.key
    }
}
