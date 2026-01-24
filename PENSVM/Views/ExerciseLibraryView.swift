import SwiftUI

struct ExerciseLibraryView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var exercises: [ExerciseRef] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var filteredExercises: [ExerciseRef] {
        if let chapter = viewModel.selectedChapter {
            return exercises.filter { $0.chapterNumber == chapter.number }
        }
        return exercises
    }

    private var headerText: String {
        if let chapter = viewModel.selectedChapter {
            return "Exercises for Chapter \(chapter.number)"
        }
        return "All Exercises"
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if filteredExercises.isEmpty {
                emptyView
            } else {
                exerciseList
            }
        }
        .onAppear {
            loadExercises()
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            Text("Loading exercises...")
                .font(.custom("Palatino", size: 18))
                .foregroundColor(.black)
            Spacer()
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Text(message)
                .font(.custom("Palatino", size: 18))
                .foregroundColor(.black)
            Button("Retry") {
                loadExercises()
            }
            .buttonStyle(MinimalButtonStyle())
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            if viewModel.selectedChapter != nil {
                Text("No exercises for this chapter")
                    .font(.custom("Palatino", size: 22))
                    .foregroundColor(.black)
                Text("Use /import-exercise to add exercises")
                    .font(.custom("Palatino", size: 16))
                    .foregroundColor(.black.opacity(0.6))
            } else {
                Text("No exercises imported")
                    .font(.custom("Palatino", size: 22))
                    .foregroundColor(.black)
                Text("Use /import-exercise to add exercises")
                    .font(.custom("Palatino", size: 16))
                    .foregroundColor(.black.opacity(0.6))
            }
            Spacer()

            VStack {
                HStack {
                    Spacer()
                    Button("?") {
                        viewModel.toggleReference()
                    }
                    .buttonStyle(MinimalButtonStyle())
                }
                .padding()
            }
        }
    }

    private var exerciseList: some View {
        VStack(spacing: 0) {
            Text(headerText)
                .font(.custom("Palatino", size: 14))
                .foregroundColor(.black.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.white)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(filteredExercises) { exercise in
                        ExerciseRow(exercise: exercise) {
                            selectExercise(exercise)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
        }
    }

    private func loadExercises() {
        isLoading = true
        errorMessage = nil

        do {
            exercises = try ExerciseStorageService.shared.listExercises()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func selectExercise(_ ref: ExerciseRef) {
        viewModel.loadStoredExercise(sequenceNumber: ref.sequenceNumber)
    }
}

struct ExerciseRow: View {
    let exercise: ExerciseRef
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.displayTitle)
                        .font(.custom("Palatino", size: 18))
                        .foregroundColor(.black)
                    Text(exercise.displaySubtitle)
                        .font(.custom("Palatino", size: 14))
                        .foregroundColor(.black.opacity(0.6))
                }
                Spacer()
                Text("#\(exercise.sequenceNumber)")
                    .font(.custom("Palatino", size: 14))
                    .foregroundColor(.black.opacity(0.4))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.white)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.black.opacity(0.1)),
            alignment: .bottom
        )
    }
}
