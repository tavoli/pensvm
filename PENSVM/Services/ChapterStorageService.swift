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

    /// Default book slug for LLPSI
    static let defaultBookSlug = "llpsi"

    /// Base directory: ~/Library/Application Support/PENSVM/
    var baseDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("PENSVM")
    }

    /// Books directory: ~/Library/Application Support/PENSVM/books/
    var booksDirectory: URL {
        baseDirectory.appendingPathComponent("books")
    }

    /// Chapters directory for a specific book.
    /// All books use: ~/Library/Application Support/PENSVM/books/<slug>/chapters/
    func chaptersDirectory(bookSlug: String) -> URL {
        return booksDirectory.appendingPathComponent(bookSlug).appendingPathComponent("chapters")
    }

    /// Backward-compatible chaptersDirectory (defaults to LLPSI)
    var chaptersDirectory: URL {
        chaptersDirectory(bookSlug: Self.defaultBookSlug)
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
        try createDirectoryIfNeeded(at: booksDirectory)
    }

    func ensureBookDirectoriesExist(bookSlug: String) throws {
        try createDirectoryIfNeeded(at: baseDirectory)
        try createDirectoryIfNeeded(at: booksDirectory)
        try createDirectoryIfNeeded(at: chaptersDirectory(bookSlug: bookSlug))
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

    // MARK: - Migration

    /// Migrates library.json from old format (chapters at root) to new format (books array),
    /// and moves LLPSI chapters from legacy path (chapters/) to books/llpsi/chapters/.
    func migrateIfNeeded() throws {
        guard fileManager.fileExists(atPath: libraryIndexURL.path) else { return }

        // Try to read raw JSON to check if index format migration is needed
        let data = try Data(contentsOf: libraryIndexURL)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        // If has "chapters" key at root (old format), decode and re-save in new format
        if json["books"] == nil, json["chapters"] != nil {
            let index = try decoder.decode(LibraryIndex.self, from: data)
            try saveLibraryIndex(index)
            print("Migration complete: library.json updated to books[] format")
        }

        // Migrate LLPSI chapters from legacy path to books/llpsi/chapters/
        let legacyDir = baseDirectory.appendingPathComponent("chapters")
        let newDir = chaptersDirectory(bookSlug: Self.defaultBookSlug)

        guard fileManager.fileExists(atPath: legacyDir.path) else { return }

        try createDirectoryIfNeeded(at: newDir)

        let contents = try fileManager.contentsOfDirectory(atPath: legacyDir.path)
        let chapterDirs = contents.filter { $0.hasPrefix("ch-") }

        guard !chapterDirs.isEmpty else {
            // Nothing to migrate, clean up empty legacy dir
            try? fileManager.removeItem(at: legacyDir)
            return
        }

        for dir in chapterDirs {
            let src = legacyDir.appendingPathComponent(dir)
            let dst = newDir.appendingPathComponent(dir)
            if !fileManager.fileExists(atPath: dst.path) {
                try fileManager.moveItem(at: src, to: dst)
            }
        }

        // Remove legacy directory if empty (ignoring .DS_Store)
        let remaining = try fileManager.contentsOfDirectory(atPath: legacyDir.path)
            .filter { $0 != ".DS_Store" }
        if remaining.isEmpty {
            try? fileManager.removeItem(at: legacyDir)
        }

        print("Migration complete: LLPSI chapters moved to books/llpsi/chapters/")
    }

    // MARK: - Chapter Directory

    /// Returns the directory for a specific chapter within a book
    func chapterDirectory(for chapterNumber: Int, bookSlug: String = defaultBookSlug) -> URL {
        let paddedNumber = String(format: "%02d", chapterNumber)
        return chaptersDirectory(bookSlug: bookSlug).appendingPathComponent("ch-\(paddedNumber)")
    }

    /// Creates the chapter directory if needed
    func ensureChapterDirectoryExists(for chapterNumber: Int, bookSlug: String = defaultBookSlug) throws {
        let directory = chapterDirectory(for: chapterNumber, bookSlug: bookSlug)
        try createDirectoryIfNeeded(at: directory)
    }

    // MARK: - Library Index

    /// Loads the library index, creating an empty one if it doesn't exist
    func loadLibraryIndex() throws -> LibraryIndex {
        if !fileManager.fileExists(atPath: libraryIndexURL.path) {
            return LibraryIndex(books: [])
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
        try createDirectoryIfNeeded(at: baseDirectory)

        do {
            let data = try encoder.encode(index)
            try data.write(to: libraryIndexURL, options: .atomic)
        } catch {
            throw StorageError.writeError(error.localizedDescription)
        }
    }

    // MARK: - Book Operations

    /// Returns all books from the library index
    func loadBooks() throws -> [BookLibraryEntry] {
        let index = try loadLibraryIndex()
        return index.books
    }

    /// Creates a new book entry in the library index
    func createBook(slug: String, title: String, author: String?, hasExercises: Bool, hasMarginImages: Bool) throws {
        var index = try loadLibraryIndex()

        // Don't create if already exists
        guard !index.books.contains(where: { $0.slug == slug }) else { return }

        let book = BookLibraryEntry(
            slug: slug,
            title: title,
            author: author,
            hasExercises: hasExercises,
            hasMarginImages: hasMarginImages,
            chapters: []
        )
        index.books.append(book)
        try saveLibraryIndex(index)
        try ensureBookDirectoriesExist(bookSlug: slug)
    }

    // MARK: - Chapter Operations

    /// Generates a filename for a chapter (e.g., "ch-06/chapter.json")
    func filename(for chapter: Chapter) -> String {
        let paddedNumber = String(format: "%02d", chapter.number)
        return "ch-\(paddedNumber)/chapter.json"
    }

    /// Saves a chapter to disk and updates the library index
    func saveChapter(_ chapter: Chapter, bookSlug: String = defaultBookSlug) throws {
        try ensureBookDirectoriesExist(bookSlug: bookSlug)
        try ensureChapterDirectoryExists(for: chapter.number, bookSlug: bookSlug)

        let fileName = filename(for: chapter)
        let fileURL = chaptersDirectory(bookSlug: bookSlug).appendingPathComponent(fileName)

        // Save chapter JSON
        do {
            let data = try encoder.encode(chapter)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw StorageError.writeError(error.localizedDescription)
        }

        // Update library index
        var index = try loadLibraryIndex()

        // Find or create book entry
        if let bookIndex = index.books.firstIndex(where: { $0.slug == bookSlug }) {
            // Remove existing entry for this chapter number if it exists
            index.books[bookIndex].chapters.removeAll { $0.number == chapter.number }

            // Add new entry
            let ref = ChapterRef(number: chapter.number, title: chapter.title, file: fileName)
            index.books[bookIndex].chapters.append(ref)

            // Sort by chapter number
            index.books[bookIndex].chapters.sort { $0.number < $1.number }
        } else {
            // Create default book entry (for backward compatibility)
            let ref = ChapterRef(number: chapter.number, title: chapter.title, file: fileName)
            let book = BookLibraryEntry(
                slug: bookSlug,
                title: bookSlug == Self.defaultBookSlug ? "Lingua Latina per se Illustrata" : bookSlug,
                author: bookSlug == Self.defaultBookSlug ? "Hans Ørberg" : nil,
                hasExercises: bookSlug == Self.defaultBookSlug,
                hasMarginImages: bookSlug == Self.defaultBookSlug,
                chapters: [ref]
            )
            index.books.append(book)
        }

        try saveLibraryIndex(index)
    }

    /// Loads a chapter by its number from a specific book
    func loadChapter(number: Int, bookSlug: String = defaultBookSlug) throws -> Chapter? {
        let index = try loadLibraryIndex()

        guard let book = index.book(slug: bookSlug),
              let ref = book.chapters.first(where: { $0.number == number }) else {
            return nil
        }

        let fileURL = chaptersDirectory(bookSlug: bookSlug).appendingPathComponent(ref.file)

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

    /// Loads all chapters from disk for a specific book
    func loadAllChapters(bookSlug: String = defaultBookSlug) throws -> [Chapter] {
        let index = try loadLibraryIndex()

        guard let book = index.book(slug: bookSlug) else {
            return []
        }

        var chapters: [Chapter] = []
        let chapsDir = chaptersDirectory(bookSlug: bookSlug)

        for ref in book.chapters {
            let fileURL = chapsDir.appendingPathComponent(ref.file)

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
    func deleteChapter(number: Int, bookSlug: String = defaultBookSlug) throws {
        var index = try loadLibraryIndex()

        guard let bookIndex = index.books.firstIndex(where: { $0.slug == bookSlug }) else {
            return
        }

        // Remove the entire chapter directory (including chapter.json and all assets)
        let chapterDir = chapterDirectory(for: number, bookSlug: bookSlug)
        if fileManager.fileExists(atPath: chapterDir.path) {
            try fileManager.removeItem(at: chapterDir)
        }

        // Remove from index
        index.books[bookIndex].chapters.removeAll { $0.number == number }
        try saveLibraryIndex(index)
    }

    /// Checks if a chapter exists
    func chapterExists(number: Int, bookSlug: String = defaultBookSlug) throws -> Bool {
        let index = try loadLibraryIndex()
        guard let book = index.book(slug: bookSlug) else { return false }
        return book.chapters.contains { $0.number == number }
    }

    /// Returns the list of chapter references without loading full chapter data
    func listChapters(bookSlug: String = defaultBookSlug) throws -> [ChapterRef] {
        let index = try loadLibraryIndex()
        return index.book(slug: bookSlug)?.chapters ?? []
    }
}
