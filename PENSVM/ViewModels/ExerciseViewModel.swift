import SwiftUI
import AppKit

@MainActor
class ExerciseViewModel: ObservableObject {
    @Published var state: AppState = .dropZone
    @Published var exercise: Exercise?
    @Published var currentSentenceIndex: Int = 0
    @Published var isChecked: Bool = false
    @Published var showReference: Bool = false
    @Published var startTime: Date?
    @Published var endTime: Date?

    private let claudeService = ClaudeCLIService()

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

    func processImage(_ data: Data) {
        state = .loading

        Task {
            do {
                let result = try await claudeService.parseExercise(from: data)
                self.exercise = result
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
        } else {
            checkAnswers()
        }
    }

    func toggleReference() {
        showReference.toggle()
    }

    func reset() {
        state = .dropZone
        exercise = nil
        currentSentenceIndex = 0
        isChecked = false
        showReference = false
        startTime = nil
        endTime = nil
    }

    func cancelLoading() {
        reset()
    }

    func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            loadImage(from: url)
        }
    }

    func loadImage(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            processImage(data)
        } catch {
            state = .error("Could not read image file.")
        }
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        if provider.hasItemConformingToTypeIdentifier("public.file-url") {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                DispatchQueue.main.async {
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        self.loadImage(from: url)
                    } else if let url = item as? URL {
                        self.loadImage(from: url)
                    }
                }
            }
            return true
        }

        if provider.hasItemConformingToTypeIdentifier("public.image") {
            provider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, error in
                DispatchQueue.main.async {
                    if let data = data {
                        self.processImage(data)
                    }
                }
            }
            return true
        }

        return false
    }
}
