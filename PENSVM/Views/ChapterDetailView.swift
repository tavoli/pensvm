import SwiftUI

struct ChapterDetailView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var exerciseCount: Int = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            if let chapter = viewModel.selectedChapter {
                Text("\(chapter.romanNumeral). \(chapter.title)")
                    .font(.custom("Palatino", size: 36))
                    .foregroundColor(.black)

                Text("\(chapter.totalPages) pages \(exerciseCount > 0 ? "• \(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")" : "")")
                    .font(.custom("Palatino", size: 18))
                    .foregroundColor(.black.opacity(0.6))

                Spacer()

                HStack(spacing: 24) {
                    Button(action: { viewModel.startReading() }) {
                        VStack(spacing: 8) {
                            Text("READ")
                                .font(.custom("Palatino", size: 18))
                            Text("[R]")
                                .font(.custom("Palatino", size: 12))
                                .foregroundColor(.black.opacity(0.4))
                        }
                        .frame(width: 120, height: 80)
                    }
                    .buttonStyle(MinimalButtonStyle())

                    Button(action: { viewModel.goToExercises() }) {
                        VStack(spacing: 8) {
                            Text("EXERCISES")
                                .font(.custom("Palatino", size: 18))
                            Text("[E]")
                                .font(.custom("Palatino", size: 12))
                                .foregroundColor(.black.opacity(0.4))
                        }
                        .frame(width: 120, height: 80)
                    }
                    .buttonStyle(MinimalButtonStyle())
                }
            } else {
                Text("No chapter selected")
                    .font(.custom("Palatino", size: 18))
                    .foregroundColor(.black.opacity(0.6))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onAppear {
            isFocused = true
            loadExerciseCount()
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "rR")) { _ in
            viewModel.startReading()
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "eE")) { _ in
            viewModel.goToExercises()
            return .handled
        }
    }

    private func loadExerciseCount() {
        guard let chapter = viewModel.selectedChapter else {
            exerciseCount = 0
            return
        }

        do {
            let exercises = try ExerciseStorageService.shared.listExercises()
            exerciseCount = exercises.filter { $0.chapterNumber == chapter.number }.count
        } catch {
            exerciseCount = 0
        }
    }
}
