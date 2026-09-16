import Combine
import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [SavedSession] = []

    private let fileManager: FileManager
    private let directory: URL
    private let indexURL: URL

    init(directory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let directory {
            self.directory = directory
        } else {
            let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.directory = support.appendingPathComponent("LogosSessions", isDirectory: true)
        }
        indexURL = self.directory.appendingPathComponent("index.json")
        try? fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
        load()
    }

    func result(for session: SavedSession) -> ConversationResult {
        session.conversationResult(audioURL: audioURL(for: session.id))
    }

    func audioURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).m4a")
    }

    func reflectionAudioURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString)-reflection.mp3")
    }

    func saveReflectionAudio(_ data: Data, for id: UUID) {
        try? data.write(to: reflectionAudioURL(for: id), options: .atomic)
    }

    @discardableResult
    func save(_ result: ConversationResult) -> ConversationResult {
        var storedAudioURL: URL?
        if let source = result.conversationAudioURL {
            let destination = audioURL(for: result.id)
            try? fileManager.removeItem(at: destination)
            do {
                try fileManager.copyItem(at: source, to: destination)
                if fileManager.fileExists(atPath: destination.path),
                   let size = try? fileManager.attributesOfItem(atPath: destination.path)[.size] as? NSNumber,
                   size.intValue > 800 {
                    storedAudioURL = destination
                } else {
                    try? fileManager.removeItem(at: destination)
                }
            } catch {
                storedAudioURL = nil
            }
        }

        let record = SavedSession(result: result, hasConversationAudio: storedAudioURL != nil)
        sessions.removeAll { $0.id == record.id }
        sessions.insert(record, at: 0)
        persist()
        return result.withConversationAudioURL(storedAudioURL)
    }

    func delete(_ session: SavedSession) {
        sessions.removeAll { $0.id == session.id }
        try? fileManager.removeItem(at: audioURL(for: session.id))
        try? fileManager.removeItem(at: reflectionAudioURL(for: session.id))
        persist()
    }

    private func load() {
        guard
            let data = try? Data(contentsOf: indexURL),
            let saved = try? JSONDecoder().decode([SavedSession].self, from: data)
        else {
            sessions = []
            return
        }
        sessions = saved.sorted { $0.createdAt > $1.createdAt }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}