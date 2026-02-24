import Foundation

struct Exercise: Identifiable {
    let id: UUID
    var sentences: [Sentence]
    let createdAt: Date

    init(id: UUID = UUID(), sentences: [Sentence], createdAt: Date = Date()) {
        self.id = id
        self.sentences = sentences
        self.createdAt = createdAt
    }

    var totalGaps: Int {
        sentences.reduce(0) { $0 + $1.gaps.count }
    }

    var correctCount: Int {
        sentences.reduce(0) { total, sentence in
            total + sentence.gaps.filter { $0.isCorrect == true }.count
        }
    }

    var incorrectCount: Int {
        totalGaps - correctCount
    }

    var percentageCorrect: Int {
        guard totalGaps > 0 else { return 0 }
        return Int((Double(correctCount) / Double(totalGaps)) * 100)
    }
}

struct Sentence: Identifiable {
    let id: UUID
    var parts: [SentencePart]

    init(id: UUID = UUID(), parts: [SentencePart]) {
        self.id = id
        self.parts = parts
    }

    var gaps: [Gap] {
        parts.compactMap { part in
            if case .gap(let gap) = part {
                return gap
            }
            return nil
        }
    }

    var gapIndices: [Int] {
        parts.enumerated().compactMap { index, part in
            if case .gap = part {
                return index
            }
            return nil
        }
    }

    var allGapsAnswered: Bool {
        gaps.allSatisfy { $0.userAnswer != nil && !$0.userAnswer!.isEmpty }
    }
}

enum SentencePart: Identifiable {
    case text(String)
    case gap(Gap)

    var id: String {
        switch self {
        case .text(let content):
            return "text-\(content.hashValue)"
        case .gap(let gap):
            return gap.id.uuidString
        }
    }
}

struct Gap: Identifiable {
    let id: UUID
    let stem: String
    let correctEnding: String
    let dictionaryForm: String?
    let wordType: String?
    let explanation: String?  // Why this ending is correct (context-based)
    let genitiveForm: String?
    let gender: String?       // "f", "m", or "n"
    var userAnswer: String?

    init(id: UUID = UUID(), stem: String, correctEnding: String, dictionaryForm: String? = nil, wordType: String? = nil, explanation: String? = nil, genitiveForm: String? = nil, gender: String? = nil, userAnswer: String? = nil) {
        self.id = id
        self.stem = stem
        self.correctEnding = correctEnding
        self.dictionaryForm = dictionaryForm
        self.wordType = wordType
        self.explanation = explanation
        self.genitiveForm = genitiveForm
        self.gender = gender
        self.userAnswer = userAnswer
    }

    var isCorrect: Bool? {
        guard let answer = userAnswer, !answer.isEmpty else { return nil }
        return normalizeForComparison(answer) == normalizeForComparison(correctEnding)
    }

    private func normalizeForComparison(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces).lowercased()
        // Normalize macrons: ā→a, ē→e, ī→i, ō→o, ū→u
        let macronMap: [Character: Character] = [
            "ā": "a", "ē": "e", "ī": "i", "ō": "o", "ū": "u",
            "Ā": "a", "Ē": "e", "Ī": "i", "Ō": "o", "Ū": "u"
        ]
        return String(trimmed.map { macronMap[$0] ?? $0 })
    }
}
