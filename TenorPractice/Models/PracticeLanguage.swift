import Combine
import Foundation

enum PracticeLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .english: "English"
        case .spanish: "Español"
        case .french: "Français"
        case .german: "Deutsch"
        case .italian: "Italiano"
        case .portuguese: "Português"
        }
    }

    var englishName: String {
        switch self {
        case .english: "English"
        case .spanish: "Spanish"
        case .french: "French"
        case .german: "German"
        case .italian: "Italian"
        case .portuguese: "Portuguese"
        }
    }

    var shortCode: String { rawValue.uppercased() }

    var locale: Locale { Locale(identifier: rawValue) }

    func text(_ key: String) -> String {
        guard
            let path = Bundle.main.path(forResource: rawValue, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else { return key }

        return NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
    }

    func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: locale, arguments: arguments)
    }
}

@MainActor
final class PracticeLanguageStore: ObservableObject {
    @Published var selected: PracticeLanguage {
        didSet { defaults.set(selected.rawValue, forKey: Self.storageKey) }
    }

    private let defaults: UserDefaults
    private static let storageKey = "logos.practice-language"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.string(forKey: Self.storageKey)
        selected = PracticeLanguage(rawValue: saved ?? "") ?? .english
    }
}
