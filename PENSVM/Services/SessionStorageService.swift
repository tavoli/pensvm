import Foundation

/// Manages session state persistence for restoring user's place on app relaunch
class SessionStorageService {
    static let shared = SessionStorageService()

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Base directory: ~/Library/Application Support/PENSVM/
    var baseDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("PENSVM")
    }

    /// Session file: ~/Library/Application Support/PENSVM/session.json
    var sessionFileURL: URL {
        baseDirectory.appendingPathComponent("session.json")
    }

    private init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Directory Setup

    private func ensureDirectoryExists() throws {
        if !fileManager.fileExists(atPath: baseDirectory.path) {
            try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Session Operations

    /// Saves the current session state to disk
    func saveSession(_ state: SessionState) {
        do {
            try ensureDirectoryExists()
            let data = try encoder.encode(state)
            try data.write(to: sessionFileURL, options: .atomic)
        } catch {
            print("Warning: Could not save session: \(error.localizedDescription)")
        }
    }

    /// Loads the saved session state, if any
    func loadSession() -> SessionState? {
        guard fileManager.fileExists(atPath: sessionFileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: sessionFileURL)
            return try decoder.decode(SessionState.self, from: data)
        } catch {
            print("Warning: Could not load session: \(error.localizedDescription)")
            return nil
        }
    }

    /// Clears the saved session
    func clearSession() {
        do {
            if fileManager.fileExists(atPath: sessionFileURL.path) {
                try fileManager.removeItem(at: sessionFileURL)
            }
        } catch {
            print("Warning: Could not clear session: \(error.localizedDescription)")
        }
    }
}
