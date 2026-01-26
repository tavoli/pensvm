import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var isFullScreen = false

    var body: some View {
        VStack(spacing: 0) {
            // Title bar area
            HStack {
                if viewModel.state != .home {
                    Button(action: handleBack) {
                        Text("< Back")
                            .font(.custom("Palatino", size: 14))
                            .foregroundColor(.black)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Spacer()

                Text("PENSVM")
                    .font(.custom("Palatino", size: 16))
                    .foregroundColor(.black)

                Spacer()

                if case .exercise = viewModel.state {
                    Text("\(viewModel.currentSentenceIndex + 1) / \(viewModel.totalSentences)")
                        .font(.custom("Palatino", size: 16))
                        .foregroundColor(.black)
                } else if case .reading = viewModel.state {
                    Text("\(viewModel.currentPageIndex + 1) / \(viewModel.totalPages)")
                        .font(.custom("Palatino", size: 16))
                        .foregroundColor(.black)
                        .padding(.trailing, 16)

                    Button(action: { viewModel.goToExercises() }) {
                        Text("Exercises")
                            .font(.custom("Palatino", size: 14))
                    }
                    .buttonStyle(MinimalButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.leading, isFullScreen ? 0 : 60)
            .frame(height: 38)
            .background(Color.white)

            // Content
            ZStack {
                Color.white

                switch viewModel.state {
                case .home:
                    HomeView()
                case .chapterLibrary:
                    ChapterLibraryView()
                case .chapterDetail:
                    ChapterDetailView()
                case .reading:
                    ReadingView()
                case .exerciseLibrary:
                    ExerciseLibraryView()
                case .loading:
                    LoadingView()
                case .exercise:
                    ExerciseView()
                case .summary:
                    SummaryView()
                case .error(let message):
                    ErrorView(message: message)
                }

                if viewModel.showReference {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ReferencePanel()
                                .padding(16)
                        }
                    }
                }

                if let sentence = viewModel.focusedSentence {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            viewModel.closeFocusedPhrase()
                        }

                    FocusedPhraseView(words: sentence)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .ignoresSafeArea()
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { _ in
            isFullScreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification)) { _ in
            isFullScreen = false
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(characters: CharacterSet(charactersIn: "?")) { _ in
            viewModel.toggleReference()
            return .handled
        }
        .onKeyPress(.escape) {
            handleEscape()
            return .handled
        }
        .onKeyPress(.delete) {
            handleBack()
            return .handled
        }
    }

    private func handleBack() {
        switch viewModel.state {
        case .chapterLibrary:
            viewModel.goHome()
        case .chapterDetail:
            viewModel.backToChapterLibrary()
        case .reading:
            viewModel.backToChapterDetail()
        case .exerciseLibrary:
            if viewModel.selectedChapter != nil {
                viewModel.backToChapterDetail()
            } else {
                viewModel.goToChapterLibrary()
            }
        case .exercise, .summary:
            viewModel.reset()
        case .error:
            viewModel.reset()
        default:
            break
        }
    }

    private func handleEscape() {
        if viewModel.focusedSentence != nil {
            viewModel.closeFocusedPhrase()
        } else if viewModel.clearReadingActiveState() {
            // Cleared popover or prepared sentence state
        } else if viewModel.showReference {
            viewModel.showReference = false
        } else if case .reading = viewModel.state {
            // Do nothing - don't exit reading view with Escape
        } else {
            handleBack()
        }
    }
}

struct ErrorView: View {
    let message: String
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text(message)
                .foregroundColor(.black)

            Button("Try Again") {
                viewModel.reset()
            }
            .buttonStyle(MinimalButtonStyle())
        }
    }
}
