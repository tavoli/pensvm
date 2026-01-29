import SwiftUI

@MainActor
class AppViewModel: ObservableObject {
    // MARK: - App State
    @Published var state: AppState = .home
    @Published var showReference: Bool = false
    @Published var focusedSentence: [AnnotatedWord]?
    @Published var focusedSentenceTranslation: String?
    @Published var isLoadingTranslation: Bool = false

    // MARK: - Chapter State
    @Published var selectedChapter: Chapter?
    @Published var currentPageIndex: Int = 0

    // MARK: - Reading State (for popover/prepared sentence)
    @Published var readingSelectedWord: AnnotatedWord?
    @Published var readingPreparedSentenceId: UUID?
    @Published var readingPreparedSentenceWords: [AnnotatedWord]?
    @Published var readingPageSentences: [(id: UUID, words: [AnnotatedWord])] = []
    @Published var readingPreparedSentenceIndex: Int?

    // MARK: - Exercise State
    @Published var exercise: Exercise?
    @Published var currentSentenceIndex: Int = 0
    @Published var isChecked: Bool = false
    @Published var startTime: Date?
    @Published var endTime: Date?

    // MARK: - Services
    private let chapterStorage = ChapterStorageService.shared
    private let exerciseStorage = ExerciseStorageService.shared
    private let sessionStorage = SessionStorageService.shared

    // MARK: - Computed Properties

    var currentSentence: Sentence? {
        guard let exercise = exercise,
              currentSentenceIndex < exercise.sentences.count else {
            return nil
        }
        return exercise.sentences[currentSentenceIndex]
    }

    var totalSentences: Int {
        exercise?.sentences.count ?? 0
    }

    var elapsedTime: String {
        guard let start = startTime else { return "0:00" }
        let end = endTime ?? Date()
        let elapsed = Int(end.timeIntervalSince(start))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var currentPage: Page? {
        guard let chapter = selectedChapter,
              currentPageIndex < chapter.pages.count else {
            return nil
        }
        return chapter.pages[currentPageIndex]
    }

    var totalPages: Int {
        selectedChapter?.pages.count ?? 0
    }

    // MARK: - Navigation Methods

    func goHome() {
        state = .home
        selectedChapter = nil
        currentPageIndex = 0
        resetExercise()
        sessionStorage.clearSession()
    }

    func goToChapterLibrary() {
        state = .chapterLibrary
    }

    func selectChapter(_ chapter: Chapter) {
        selectedChapter = chapter
        currentPageIndex = 0
        state = .chapterDetail
    }

    func startReading() {
        guard selectedChapter != nil else { return }
        currentPageIndex = 0
        state = .reading
    }

    func goToExercises() {
        state = .exerciseLibrary
    }

    func backToChapterDetail() {
        state = .chapterDetail
    }

    func backToChapterLibrary() {
        selectedChapter = nil
        state = .chapterLibrary
    }

    // MARK: - Reading Navigation

    func nextPage() {
        guard let chapter = selectedChapter else { return }
        if currentPageIndex < chapter.pages.count - 1 {
            currentPageIndex += 1
        }
    }

    func previousPage() {
        if currentPageIndex > 0 {
            currentPageIndex -= 1
        }
    }

    // MARK: - Exercise Methods

    func loadStoredExercise(sequenceNumber: Int) {
        state = .loading

        Task {
            do {
                // Find the exercise reference to get the chapter number
                let exercises = try exerciseStorage.listExercises()
                guard let ref = exercises.first(where: { $0.sequenceNumber == sequenceNumber }),
                      let chapterNumber = ref.chapterNumber else {
                    self.state = .error("Exercise not found")
                    return
                }

                guard let stored = try exerciseStorage.loadExercise(chapterNumber: chapterNumber, sequenceNumber: sequenceNumber) else {
                    self.state = .error("Exercise not found")
                    return
                }

                let exercise = convertToExercise(stored)
                self.exercise = exercise
                self.currentSentenceIndex = 0
                self.isChecked = false
                self.startTime = Date()
                self.endTime = nil
                self.state = .exercise
            } catch {
                self.state = .error(error.localizedDescription)
            }
        }
    }

    private func convertToExercise(_ stored: StoredExercise) -> Exercise {
        let sentences = stored.sentences.map { storedSentence -> Sentence in
            let parts = storedSentence.parts.map { storedPart -> SentencePart in
                switch storedPart.type {
                case .text:
                    return .text(storedPart.content ?? "")
                case .gap:
                    return .gap(Gap(
                        stem: storedPart.stem ?? "",
                        correctEnding: storedPart.correctEnding ?? "",
                        dictionaryForm: storedPart.dictionaryForm,
                        wordType: storedPart.wordType,
                        explanation: storedPart.explanation
                    ))
                }
            }
            return Sentence(id: storedSentence.id, parts: parts)
        }
        return Exercise(id: stored.id, sentences: sentences, createdAt: stored.importedAt)
    }

    func updateGapAnswer(sentenceIndex: Int, partIndex: Int, answer: String) {
        guard var exercise = exercise,
              sentenceIndex < exercise.sentences.count,
              partIndex < exercise.sentences[sentenceIndex].parts.count else {
            return
        }

        if case .gap(var gap) = exercise.sentences[sentenceIndex].parts[partIndex] {
            gap.userAnswer = answer
            exercise.sentences[sentenceIndex].parts[partIndex] = .gap(gap)
            self.exercise = exercise
        }
    }

    func checkAnswers() {
        isChecked = true
    }

    func nextSentence() {
        guard let exercise = exercise else { return }

        if currentSentenceIndex < exercise.sentences.count - 1 {
            currentSentenceIndex += 1
            isChecked = false
        } else {
            endTime = Date()
            state = .summary
        }
    }

    func handleEnter() {
        if isChecked {
            nextSentence()
        } else if currentSentence?.allGapsAnswered == true {
            checkAnswers()
        }
    }

    func toggleReference() {
        showReference.toggle()
    }

    func showFocusedSentence(_ words: [AnnotatedWord]) {
        focusedSentence = words
        focusedSentenceTranslation = nil
        isLoadingTranslation = true

        // Build Latin text from words
        let latinText = words.map { $0.text }.joined(separator: " ")
            .replacingOccurrences(of: " ,", with: ",")
            .replacingOccurrences(of: " .", with: ".")
            .replacingOccurrences(of: " :", with: ":")
            .replacingOccurrences(of: " ;", with: ";")
            .replacingOccurrences(of: " ?", with: "?")
            .replacingOccurrences(of: " !", with: "!")

        Task {
            do {
                print("🔤 Translating: \(latinText)")
                let translation = try await ClaudeCLIService().translateSentence(latinText)
                print("✅ Translation: \(translation)")
                self.focusedSentenceTranslation = translation
            } catch {
                print("❌ Translation error: \(error)")
                // Show error message in UI
                self.focusedSentenceTranslation = "Error: \(error.localizedDescription)"
            }
            self.isLoadingTranslation = false
        }
    }

    func closeFocusedPhrase() {
        focusedSentence = nil
        focusedSentenceTranslation = nil
        isLoadingTranslation = false
    }

    /// Clears reading popover and prepared sentence state. Returns true if something was cleared.
    func clearReadingActiveState() -> Bool {
        let hadState = readingSelectedWord != nil || readingPreparedSentenceId != nil
        readingSelectedWord = nil
        readingPreparedSentenceId = nil
        readingPreparedSentenceWords = nil
        readingPreparedSentenceIndex = nil
        return hadState
    }

    func openPreparedSentence() {
        if let words = readingPreparedSentenceWords {
            showFocusedSentence(words)
            readingPreparedSentenceId = nil
            readingPreparedSentenceWords = nil
            readingPreparedSentenceIndex = nil
        }
    }

    func prepareSentence(id: UUID, words: [AnnotatedWord], index: Int) {
        readingPreparedSentenceId = id
        readingPreparedSentenceWords = words
        readingPreparedSentenceIndex = index
    }

    func nextPreparedSentence() {
        guard !readingPageSentences.isEmpty else { return }

        if let currentIndex = readingPreparedSentenceIndex {
            let nextIndex = (currentIndex + 1) % readingPageSentences.count
            let sentence = readingPageSentences[nextIndex]
            prepareSentence(id: sentence.id, words: sentence.words, index: nextIndex)
        } else {
            // Start from first sentence
            let sentence = readingPageSentences[0]
            prepareSentence(id: sentence.id, words: sentence.words, index: 0)
        }
    }

    func previousPreparedSentence() {
        guard !readingPageSentences.isEmpty else { return }

        if let currentIndex = readingPreparedSentenceIndex {
            let prevIndex = currentIndex > 0 ? currentIndex - 1 : readingPageSentences.count - 1
            let sentence = readingPageSentences[prevIndex]
            prepareSentence(id: sentence.id, words: sentence.words, index: prevIndex)
        } else {
            // Start from last sentence
            let lastIndex = readingPageSentences.count - 1
            let sentence = readingPageSentences[lastIndex]
            prepareSentence(id: sentence.id, words: sentence.words, index: lastIndex)
        }
    }

    func reset() {
        if selectedChapter != nil {
            state = .chapterDetail
        } else {
            state = .exerciseLibrary
        }
        resetExercise()
    }

    private func resetExercise() {
        exercise = nil
        currentSentenceIndex = 0
        isChecked = false
        showReference = false
        focusedSentence = nil
        startTime = nil
        endTime = nil
    }

    func cancelLoading() {
        if selectedChapter != nil {
            state = .chapterDetail
        } else {
            state = .exerciseLibrary
        }
    }

    // MARK: - Session Persistence

    /// Saves the current session state to disk
    func saveSession() {
        let stateType: String
        switch state {
        case .home: stateType = "home"
        case .chapterLibrary: stateType = "chapterLibrary"
        case .chapterDetail: stateType = "chapterDetail"
        case .reading: stateType = "reading"
        case .exerciseLibrary: stateType = "exerciseLibrary"
        case .exercise: stateType = "exercise"
        case .summary: stateType = "summary"
        case .loading, .error: return  // Don't persist these states
        }

        // Collect gap answers from current exercise
        var gapAnswers: [String: String]?
        if let exercise = exercise {
            var answers: [String: String] = [:]
            for sentence in exercise.sentences {
                for part in sentence.parts {
                    if case .gap(let gap) = part, let answer = gap.userAnswer {
                        answers[gap.id.uuidString] = answer
                    }
                }
            }
            if !answers.isEmpty {
                gapAnswers = answers
            }
        }

        // Find exercise chapter and sequence number if in exercise
        var exerciseChapterNumber: Int?
        var exerciseSequenceNumber: Int?
        if let exercise = exercise {
            // Look up the exercise in storage to find its chapter and sequence
            if let exercises = try? exerciseStorage.listExercises(),
               let ref = exercises.first(where: { $0.id == exercise.id }) {
                exerciseChapterNumber = ref.chapterNumber
                exerciseSequenceNumber = ref.sequenceNumber
            }
        }

        let sessionState = SessionState(
            stateType: stateType,
            selectedChapterNumber: selectedChapter?.number,
            currentPageIndex: currentPageIndex,
            exerciseChapterNumber: exerciseChapterNumber,
            exerciseSequenceNumber: exerciseSequenceNumber,
            currentSentenceIndex: currentSentenceIndex,
            isChecked: isChecked,
            startTime: startTime,
            gapAnswers: gapAnswers
        )

        sessionStorage.saveSession(sessionState)
    }

    /// Restores the session state from disk
    func restoreSession() {
        guard let session = sessionStorage.loadSession() else {
            return
        }

        // Restore chapter if needed
        if let chapterNumber = session.selectedChapterNumber {
            if let chapter = try? chapterStorage.loadChapter(number: chapterNumber) {
                selectedChapter = chapter
            }
        }

        // Restore page index
        if let pageIndex = session.currentPageIndex {
            currentPageIndex = pageIndex
        }

        // Restore state
        switch session.stateType {
        case "home":
            state = .home
        case "chapterLibrary":
            state = .chapterLibrary
        case "chapterDetail":
            state = .chapterDetail
        case "reading":
            state = .reading
        case "exerciseLibrary":
            state = .exerciseLibrary
        case "exercise":
            // Need to restore the exercise with answers
            restoreExerciseSession(session)
        case "summary":
            // Restore exercise for summary display
            restoreExerciseSession(session)
            state = .summary
        default:
            state = .home
        }
    }

    private func restoreExerciseSession(_ session: SessionState) {
        guard let chapterNumber = session.exerciseChapterNumber,
              let sequenceNumber = session.exerciseSequenceNumber else {
            state = .exerciseLibrary
            return
        }

        // Load the exercise
        guard let stored = try? exerciseStorage.loadExercise(chapterNumber: chapterNumber, sequenceNumber: sequenceNumber) else {
            state = .exerciseLibrary
            return
        }

        var exercise = convertToExercise(stored)

        // Restore gap answers
        if let gapAnswers = session.gapAnswers {
            for sentenceIndex in exercise.sentences.indices {
                for partIndex in exercise.sentences[sentenceIndex].parts.indices {
                    if case .gap(var gap) = exercise.sentences[sentenceIndex].parts[partIndex] {
                        if let answer = gapAnswers[gap.id.uuidString] {
                            gap.userAnswer = answer
                            exercise.sentences[sentenceIndex].parts[partIndex] = .gap(gap)
                        }
                    }
                }
            }
        }

        self.exercise = exercise
        self.currentSentenceIndex = session.currentSentenceIndex ?? 0
        self.isChecked = session.isChecked ?? false
        self.startTime = session.startTime
        self.state = .exercise
    }
}
