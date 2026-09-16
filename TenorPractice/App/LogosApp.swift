import SwiftUI

@main
struct LogosApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .tint(Brand.accent)
        }
    }
}

enum Brand {
    static let background = Color(red: 0.973, green: 0.951, blue: 0.906)
    static let card = Color(red: 0.992, green: 0.978, blue: 0.944)
    static let ink = Color(red: 0.105, green: 0.098, blue: 0.078)
    static let accent = Color(red: 0.67, green: 0.27, blue: 0.08)
    static let muted = Color(red: 0.36, green: 0.33, blue: 0.28)
    static let line = Color.black.opacity(0.09)
    static let practiceBackground = Color(red: 0.075, green: 0.086, blue: 0.078)
    static let practiceInk = Color(red: 0.96, green: 0.94, blue: 0.88)
    static let moss = Color(red: 0.22, green: 0.33, blue: 0.25)
    static let gold = Color(red: 0.72, green: 0.49, blue: 0.16)
}
