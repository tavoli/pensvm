import Foundation

enum StorageError: LocalizedError {
    case directoryCreationFailed
    case encodingFailed
    case decodingFailed
    case fileNotFound
    case writeError(String)
    case readError(String)

    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed:
            return "Could not create storage directory."
        case .encodingFailed:
            return "Could not encode data."
        case .decodingFailed:
            return "Could not decode data."
        case .fileNotFound:
            return "File not found."
        case .writeError(let message):
            return "Write error: \(message)"
        case .readError(let message):
            return "Read error: \(message)"
        }
    }
}

/// Manages chapter JSON storage and the library index
class ChapterStorageService {
    static let shared = ChapterStorageService()

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Base directory: ~/Library/Application Support/PENSVM/
    var baseDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("PENSVM")
    }

    /// Chapters directory: ~/Library/Application Support/PENSVM/chapters/
    var chaptersDirectory: URL {
        baseDirectory.appendingPathComponent("chapters")
    }

    /// Library index file: ~/Library/Application Support/PENSVM/library.json
    var libraryIndexURL: URL {
        baseDirectory.appendingPathComponent("library.json")
    }

    private init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Directory Setup

    /// Creates necessary directories if they don't exist
    func ensureDirectoriesExist() throws {
        try createDirectoryIfNeeded(at: baseDirectory)
        try createDirectoryIfNeeded(at: chaptersDirectory)
    }

    private func createDirectoryIfNeeded(at url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                throw StorageError.directoryCreationFailed
            }
        }
    }

    // MARK: - Chapter Directory

    /// Returns the directory for a specific chapter: chapters/ch-{NN}/
    func chapterDirectory(for chapterNumber: Int) -> URL {
        let paddedNumber = String(format: "%02d", chapterNumber)
        return chaptersDirectory.appendingPathComponent("ch-\(paddedNumber)")
    }

    /// Creates the chapter directory if needed
    func ensureChapterDirectoryExists(for chapterNumber: Int) throws {
        let directory = chapterDirectory(for: chapterNumber)
        try createDirectoryIfNeeded(at: directory)
    }

    // MARK: - Library Index

    /// Loads the library index, creating an empty one if it doesn't exist
    func loadLibraryIndex() throws -> LibraryIndex {
        if !fileManager.fileExists(atPath: libraryIndexURL.path) {
            return LibraryIndex(chapters: [])
        }

        do {
            let data = try Data(contentsOf: libraryIndexURL)
            return try decoder.decode(LibraryIndex.self, from: data)
        } catch {
            throw StorageError.readError(error.localizedDescription)
        }
    }

    /// Saves the library index to disk
    func saveLibraryIndex(_ index: LibraryIndex) throws {
        try ensureDirectoriesExist()

        do {
            let data = try encoder.encode(index)
            try data.write(to: libraryIndexURL, options: .atomic)
        } catch {
            throw StorageError.writeError(error.localizedDescription)
        }
    }

    // MARK: - Chapter Operations

    /// Generates a filename for a chapter (e.g., "ch-06/chapter.json")
    func filename(for chapter: Chapter) -> String {
        let paddedNumber = String(format: "%02d", chapter.number)
        return "ch-\(paddedNumber)/chapter.json"
    }

    /// Saves a chapter to disk and updates the library index
    func saveChapter(_ chapter: Chapter) throws {
        try ensureDirectoriesExist()
        try ensureChapterDirectoryExists(for: chapter.number)

        let fileName = filename(for: chapter)
        let fileURL = chaptersDirectory.appendingPathComponent(fileName)

        // Save chapter JSON
        do {
            let data = try encoder.encode(chapter)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw StorageError.writeError(error.localizedDescription)
        }

        // Update library index
        var index = try loadLibraryIndex()

        // Remove existing entry for this chapter number if it exists
        index.chapters.removeAll { $0.number == chapter.number }

        // Add new entry
        let ref = ChapterRef(number: chapter.number, title: chapter.title, file: fileName)
        index.chapters.append(ref)

        // Sort by chapter number
        index.chapters.sort { $0.number < $1.number }

        try saveLibraryIndex(index)
    }

    /// Loads a chapter by its number
    func loadChapter(number: Int) throws -> Chapter? {
        let index = try loadLibraryIndex()

        guard let ref = index.chapters.first(where: { $0.number == number }) else {
            return nil
        }

        let fileURL = chaptersDirectory.appendingPathComponent(ref.file)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw StorageError.fileNotFound
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(Chapter.self, from: data)
        } catch {
            throw StorageError.readError(error.localizedDescription)
        }
    }

    /// Loads all chapters from disk
    func loadAllChapters() throws -> [Chapter] {
        let index = try loadLibraryIndex()
        var chapters: [Chapter] = []

        for ref in index.chapters {
            let fileURL = chaptersDirectory.appendingPathComponent(ref.file)

            guard fileManager.fileExists(atPath: fileURL.path) else {
                continue
            }

            do {
                let data = try Data(contentsOf: fileURL)
                let chapter = try decoder.decode(Chapter.self, from: data)
                chapters.append(chapter)
            } catch {
                // Skip corrupted files, log error
                print("Warning: Could not load chapter \(ref.number): \(error.localizedDescription)")
            }
        }

        return chapters.sorted { $0.number < $1.number }
    }

    /// Deletes a chapter and its directory (including assets)
    func deleteChapter(number: Int) throws {
        var index = try loadLibraryIndex()

        guard let ref = index.chapters.first(where: { $0.number == number }) else {
            return // Chapter doesn't exist, nothing to delete
        }

        // Remove the entire chapter directory (including chapter.json and all assets)
        let chapterDir = chapterDirectory(for: number)
        if fileManager.fileExists(atPath: chapterDir.path) {
            try fileManager.removeItem(at: chapterDir)
        }

        // Remove from index
        index.chapters.removeAll { $0.number == number }
        try saveLibraryIndex(index)
    }

    /// Checks if a chapter exists
    func chapterExists(number: Int) throws -> Bool {
        let index = try loadLibraryIndex()
        return index.chapters.contains { $0.number == number }
    }

    /// Returns the list of chapter references without loading full chapter data
    func listChapters() throws -> [ChapterRef] {
        let index = try loadLibraryIndex()
        return index.chapters
    }
}
