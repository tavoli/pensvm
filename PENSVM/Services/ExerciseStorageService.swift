import Foundation

/// Manages exercise JSON storage and the exercise library index
/// Exercises are stored under their chapter directory: chapters/ch-{NN}/exercises/ex-{II}/
class ExerciseStorageService {
    static let shared = ExerciseStorageService()

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

    /// Library index file: ~/Library/Application Support/PENSVM/exercise-library.json
    var libraryIndexURL: URL {
        baseDirectory.appendingPathComponent("exercise-library.json")
    }

    private init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Directory Setup

    /// Creates base directories if they don't exist
    func ensureBaseDirectoriesExist() throws {
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

    // MARK: - Chapter & Exercise Directory

    /// Returns the directory for a specific chapter: chapters/ch-{NN}/
    func chapterDirectory(for chapterNumber: Int) -> URL {
        let paddedChapter = String(format: "%02d", chapterNumber)
        return chaptersDirectory.appendingPathComponent("ch-\(paddedChapter)")
    }

    /// Returns the exercises subdirectory for a chapter: chapters/ch-{NN}/exercises/
    func exercisesDirectory(for chapterNumber: Int) -> URL {
        chapterDirectory(for: chapterNumber).appendingPathComponent("exercises")
    }

    /// Returns the directory for a specific exercise: chapters/ch-{NN}/exercises/ex-{II}/
    func exerciseDirectory(for chapterNumber: Int, sequenceNumber: Int) -> URL {
        let paddedSequence = String(format: "%02d", sequenceNumber)
        return exercisesDirectory(for: chapterNumber).appendingPathComponent("ex-\(paddedSequence)")
    }

    /// Creates the exercise directory if needed (also creates parent directories)
    func ensureExerciseDirectoryExists(for chapterNumber: Int, sequenceNumber: Int) throws {
        let directory = exerciseDirectory(for: chapterNumber, sequenceNumber: sequenceNumber)
        try createDirectoryIfNeeded(at: directory)
    }

    // MARK: - Library Index

    /// Loads the library index, creating an empty one if it doesn't exist
    func loadLibraryIndex() throws -> ExerciseLibraryIndex {
        if !fileManager.fileExists(atPath: libraryIndexURL.path) {
            return ExerciseLibraryIndex(exercises: [])
        }

        do {
            let data = try Data(contentsOf: libraryIndexURL)
            return try decoder.decode(ExerciseLibraryIndex.self, from: data)
        } catch {
            throw StorageError.readError(error.localizedDescription)
        }
    }

    /// Saves the library index to disk
    func saveLibraryIndex(_ index: ExerciseLibraryIndex) throws {
        try ensureBaseDirectoriesExist()

        do {
            let data = try encoder.encode(index)
            try data.write(to: libraryIndexURL, options: .atomic)
        } catch {
            throw StorageError.writeError(error.localizedDescription)
        }
    }

    // MARK: - Sequence Number

    /// Returns the next available sequence number for a specific chapter
    func getNextSequenceNumber(for chapterNumber: Int) throws -> Int {
        let index = try loadLibraryIndex()
        let chapterExercises = index.exercises.filter { $0.chapterNumber == chapterNumber }
        if chapterExercises.isEmpty {
            return 1
        }
        let maxSequence = chapterExercises.map { $0.sequenceNumber }.max() ?? 0
        return maxSequence + 1
    }

    // MARK: - Exercise Operations

    /// Generates a filename for an exercise (e.g., "ch-06/exercises/ex-01/exercise.json")
    /// This path is relative to the chapters/ directory
    func filename(for exercise: StoredExercise) -> String {
        guard let chapterNumber = exercise.chapterNumber else {
            fatalError("Exercise must have a chapter number")
        }
        let paddedChapter = String(format: "%02d", chapterNumber)
        let paddedSequence = String(format: "%02d", exercise.sequenceNumber)
        return "ch-\(paddedChapter)/exercises/ex-\(paddedSequence)/exercise.json"
    }

    /// Returns the relative path for the source image
    func sourceAssetPath(for chapterNumber: Int, sequenceNumber: Int) -> String {
        let paddedChapter = String(format: "%02d", chapterNumber)
        let paddedSequence = String(format: "%02d", sequenceNumber)
        return "chapters/ch-\(paddedChapter)/exercises/ex-\(paddedSequence)/source.png"
    }

    /// Returns the absolute URL for the source image
    func sourceImageURL(for chapterNumber: Int, sequenceNumber: Int) -> URL {
        exerciseDirectory(for: chapterNumber, sequenceNumber: sequenceNumber).appendingPathComponent("source.png")
    }

    /// Saves an exercise to disk and updates the library index
    func saveExercise(_ exercise: StoredExercise) throws {
        guard let chapterNumber = exercise.chapterNumber else {
            throw StorageError.writeError("Exercise must have a chapter number")
        }

        try ensureBaseDirectoriesExist()
        try ensureExerciseDirectoryExists(for: chapterNumber, sequenceNumber: exercise.sequenceNumber)

        let fileName = filename(for: exercise)
        let fileURL = chaptersDirectory.appendingPathComponent(fileName)

        // Save exercise JSON
        do {
            let data = try encoder.encode(exercise)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw StorageError.writeError(error.localizedDescription)
        }

        // Update library index
        var index = try loadLibraryIndex()

        // Remove existing entry for this chapter and sequence number if it exists
        index.exercises.removeAll {
            $0.chapterNumber == chapterNumber && $0.sequenceNumber == exercise.sequenceNumber
        }

        // Add new reference
        let ref = ExerciseRef(
            id: exercise.id,
            sequenceNumber: exercise.sequenceNumber,
            chapterNumber: exercise.chapterNumber,
            exerciseType: exercise.exerciseType,
            file: fileName,
            importedAt: exercise.importedAt,
            sentenceCount: exercise.sentences.count,
            gapCount: exercise.totalGaps
        )
        index.exercises.append(ref)

        // Sort by chapter number, then sequence number
        index.exercises.sort {
            if $0.chapterNumber != $1.chapterNumber {
                return ($0.chapterNumber ?? 0) < ($1.chapterNumber ?? 0)
            }
            return $0.sequenceNumber < $1.sequenceNumber
        }

        try saveLibraryIndex(index)
    }

    /// Saves the source image for an exercise
    func saveSourceImage(_ imageData: Data, for chapterNumber: Int, sequenceNumber: Int) throws -> String {
        try ensureExerciseDirectoryExists(for: chapterNumber, sequenceNumber: sequenceNumber)

        let imageURL = sourceImageURL(for: chapterNumber, sequenceNumber: sequenceNumber)

        do {
            try imageData.write(to: imageURL, options: .atomic)
        } catch {
            throw StorageError.writeError(error.localizedDescription)
        }

        return sourceAssetPath(for: chapterNumber, sequenceNumber: sequenceNumber)
    }

    /// Loads an exercise by its chapter and sequence number
    func loadExercise(chapterNumber: Int, sequenceNumber: Int) throws -> StoredExercise? {
        let index = try loadLibraryIndex()

        guard let ref = index.exercises.first(where: {
            $0.chapterNumber == chapterNumber && $0.sequenceNumber == sequenceNumber
        }) else {
            return nil
        }

        let fileURL = chaptersDirectory.appendingPathComponent(ref.file)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw StorageError.fileNotFound
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(StoredExercise.self, from: data)
        } catch {
            throw StorageError.readError(error.localizedDescription)
        }
    }

    /// Loads all exercises for a specific chapter
    func loadExercises(for chapterNumber: Int) throws -> [StoredExercise] {
        let index = try loadLibraryIndex()
        let chapterRefs = index.exercises.filter { $0.chapterNumber == chapterNumber }
        var exercises: [StoredExercise] = []

        for ref in chapterRefs {
            let fileURL = chaptersDirectory.appendingPathComponent(ref.file)

            guard fileManager.fileExists(atPath: fileURL.path) else {
                continue
            }

            do {
                let data = try Data(contentsOf: fileURL)
                let exercise = try decoder.decode(StoredExercise.self, from: data)
                exercises.append(exercise)
            } catch {
                print("Warning: Could not load exercise \(ref.sequenceNumber) for chapter \(chapterNumber): \(error.localizedDescription)")
            }
        }

        return exercises.sorted { $0.sequenceNumber < $1.sequenceNumber }
    }

    /// Loads all exercises from disk
    func loadAllExercises() throws -> [StoredExercise] {
        let index = try loadLibraryIndex()
        var exercises: [StoredExercise] = []

        for ref in index.exercises {
            let fileURL = chaptersDirectory.appendingPathComponent(ref.file)

            guard fileManager.fileExists(atPath: fileURL.path) else {
                continue
            }

            do {
                let data = try Data(contentsOf: fileURL)
                let exercise = try decoder.decode(StoredExercise.self, from: data)
                exercises.append(exercise)
            } catch {
                print("Warning: Could not load exercise \(ref.sequenceNumber): \(error.localizedDescription)")
            }
        }

        return exercises.sorted {
            if $0.chapterNumber != $1.chapterNumber {
                return ($0.chapterNumber ?? 0) < ($1.chapterNumber ?? 0)
            }
            return $0.sequenceNumber < $1.sequenceNumber
        }
    }

    /// Deletes an exercise and its directory (including source image)
    func deleteExercise(chapterNumber: Int, sequenceNumber: Int) throws {
        var index = try loadLibraryIndex()

        guard let ref = index.exercises.first(where: {
            $0.chapterNumber == chapterNumber && $0.sequenceNumber == sequenceNumber
        }) else {
            return // Exercise doesn't exist, nothing to delete
        }

        // Remove the entire exercise directory (including exercise.json and source.png)
        let exerciseDir = exerciseDirectory(for: chapterNumber, sequenceNumber: sequenceNumber)
        if fileManager.fileExists(atPath: exerciseDir.path) {
            try fileManager.removeItem(at: exerciseDir)
        }

        // Remove from index
        index.exercises.removeAll {
            $0.chapterNumber == chapterNumber && $0.sequenceNumber == sequenceNumber
        }
        try saveLibraryIndex(index)
    }

    /// Deletes all exercises for a chapter
    func deleteExercises(for chapterNumber: Int) throws {
        var index = try loadLibraryIndex()

        // Remove the entire exercises directory for this chapter
        let exercisesDir = exercisesDirectory(for: chapterNumber)
        if fileManager.fileExists(atPath: exercisesDir.path) {
            try fileManager.removeItem(at: exercisesDir)
        }

        // Remove from index
        index.exercises.removeAll { $0.chapterNumber == chapterNumber }
        try saveLibraryIndex(index)
    }

    /// Checks if an exercise exists
    func exerciseExists(chapterNumber: Int, sequenceNumber: Int) throws -> Bool {
        let index = try loadLibraryIndex()
        return index.exercises.contains {
            $0.chapterNumber == chapterNumber && $0.sequenceNumber == sequenceNumber
        }
    }

    /// Returns the list of exercise references without loading full exercise data
    func listExercises() throws -> [ExerciseRef] {
        let index = try loadLibraryIndex()
        return index.exercises
    }

    /// Returns the list of exercise references for a specific chapter
    func listExercises(for chapterNumber: Int) throws -> [ExerciseRef] {
        let index = try loadLibraryIndex()
        return index.exercises.filter { $0.chapterNumber == chapterNumber }
    }

    /// Loads source image data for an exercise
    func loadSourceImage(for chapterNumber: Int, sequenceNumber: Int) -> Data? {
        let imageURL = sourceImageURL(for: chapterNumber, sequenceNumber: sequenceNumber)
        return try? Data(contentsOf: imageURL)
    }
}
