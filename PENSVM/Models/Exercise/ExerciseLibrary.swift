import Foundation

// MARK: - Exercise Library Index

/// Index of all imported exercises
struct ExerciseLibraryIndex: Codable {
    var exercises: [ExerciseRef]

    init(exercises: [ExerciseRef] = []) {
        self.exercises = exercises
    }
}

// MARK: - Exercise Reference

/// Lightweight reference to an exercise for library listing
struct ExerciseRef: Codable, Identifiable {
    let id: UUID
    let sequenceNumber: Int
    let chapterNumber: Int?
    let exerciseType: String
    let file: String
    let importedAt: Date
    let sentenceCount: Int
    let gapCount: Int

    init(
        id: UUID = UUID(),
        sequenceNumber: Int,
        chapterNumber: Int? = nil,
        exerciseType: String,
        file: String,
        importedAt: Date = Date(),
        sentenceCount: Int,
        gapCount: Int
    ) {
        self.id = id
        self.sequenceNumber = sequenceNumber
        self.chapterNumber = chapterNumber
        self.exerciseType = exerciseType
        self.file = file
        self.importedAt = importedAt
        self.sentenceCount = sentenceCount
        self.gapCount = gapCount
    }

    /// Display title for UI
    var displayTitle: String {
        if let chapter = chapterNumber {
            return "Chapter \(chapter) - \(exerciseType)"
        }
        return "\(exerciseType) #\(sequenceNumber)"
    }

    /// Subtitle with stats
    var displaySubtitle: String {
        "\(sentenceCount) sentences, \(gapCount) gaps"
    }
}
