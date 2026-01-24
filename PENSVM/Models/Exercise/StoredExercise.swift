import Foundation

// MARK: - Stored Exercise

/// A persistable exercise with metadata for storage
struct StoredExercise: Identifiable, Codable {
    let id: UUID
    let sequenceNumber: Int           // 001, 002, etc.
    let chapterNumber: Int?           // From image or null if unknown
    let exerciseType: String          // "PENSVM A", "PENSVM B", etc.
    var sentences: [StoredSentence]
    let sourceAssetPath: String?      // Relative path to source image
    let importedAt: Date

    init(
        id: UUID = UUID(),
        sequenceNumber: Int,
        chapterNumber: Int? = nil,
        exerciseType: String = "PENSVM A",
        sentences: [StoredSentence],
        sourceAssetPath: String? = nil,
        importedAt: Date = Date()
    ) {
        self.id = id
        self.sequenceNumber = sequenceNumber
        self.chapterNumber = chapterNumber
        self.exerciseType = exerciseType
        self.sentences = sentences
        self.sourceAssetPath = sourceAssetPath
        self.importedAt = importedAt
    }

    var totalGaps: Int {
        sentences.reduce(0) { $0 + $1.gapCount }
    }

    /// Display title for UI
    var displayTitle: String {
        if let chapter = chapterNumber {
            return "Chapter \(chapter) - \(exerciseType)"
        }
        return "\(exerciseType) #\(sequenceNumber)"
    }
}

// MARK: - Stored Sentence

struct StoredSentence: Identifiable, Codable {
    let id: UUID
    let parts: [StoredSentencePart]

    init(id: UUID = UUID(), parts: [StoredSentencePart]) {
        self.id = id
        self.parts = parts
    }

    var gapCount: Int {
        parts.filter { $0.type == .gap }.count
    }
}

// MARK: - Stored Sentence Part

struct StoredSentencePart: Identifiable, Codable {
    let id: UUID
    let type: PartType
    let content: String?          // For text parts
    let stem: String?             // For gap parts
    let correctEnding: String?    // For gap parts
    let dictionaryForm: String?   // For gap parts
    let wordType: String?         // For gap parts

    enum PartType: String, Codable {
        case text
        case gap
    }

    // Text part initializer
    init(id: UUID = UUID(), content: String) {
        self.id = id
        self.type = .text
        self.content = content
        self.stem = nil
        self.correctEnding = nil
        self.dictionaryForm = nil
        self.wordType = nil
    }

    // Gap part initializer
    init(
        id: UUID = UUID(),
        stem: String,
        correctEnding: String,
        dictionaryForm: String? = nil,
        wordType: String? = nil
    ) {
        self.id = id
        self.type = .gap
        self.content = nil
        self.stem = stem
        self.correctEnding = correctEnding
        self.dictionaryForm = dictionaryForm
        self.wordType = wordType
    }

    // Full initializer for decoding
    init(
        id: UUID = UUID(),
        type: PartType,
        content: String? = nil,
        stem: String? = nil,
        correctEnding: String? = nil,
        dictionaryForm: String? = nil,
        wordType: String? = nil
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.stem = stem
        self.correctEnding = correctEnding
        self.dictionaryForm = dictionaryForm
        self.wordType = wordType
    }
}
