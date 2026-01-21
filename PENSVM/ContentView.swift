import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: ExerciseViewModel
    @State private var isFullScreen = false

    var body: some View {
        VStack(spacing: 0) {
            // Title bar area
            HStack {
                Text("PENSVM")
                    .font(.custom("Palatino", size: 16))
                    .foregroundColor(.black)
                Spacer()
                if case .exercise = viewModel.state {
                    Text("\(viewModel.currentSentenceIndex + 1) / \(viewModel.totalSentences)")
                        .font(.custom("Palatino", size: 16))
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, 16)
            .padding(.leading, isFullScreen ? 0 : 60) // Space for traffic lights when not fullscreen
            .frame(height: 38)
            .background(Color.white)

            // Content
            ZStack {
                Color.white

                switch viewModel.state {
                case .dropZone:
                    DropZoneView()
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
    }
}

struct ErrorView: View {
    let message: String
    @EnvironmentObject var viewModel: ExerciseViewModel

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
