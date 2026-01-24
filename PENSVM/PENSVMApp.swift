import SwiftUI
import Combine

@main
struct PENSVMApp: App {
    @StateObject private var viewModel = AppViewModel()

    init() {
        // Register for app termination to save session
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Note: We can't access viewModel here directly since it's not initialized yet
            // The save will be handled by the SessionSaver view modifier
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onAppear {
                    viewModel.restoreSession()
                }
                .modifier(SessionSaver(viewModel: viewModel))
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 800, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

/// View modifier that saves session on relevant state changes and app termination
struct SessionSaver: ViewModifier {
    @ObservedObject var viewModel: AppViewModel
    @State private var cancellables = Set<AnyCancellable>()

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                viewModel.saveSession()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
                viewModel.saveSession()
            }
            .onChange(of: viewModel.state) { _, _ in
                viewModel.saveSession()
            }
            .onChange(of: viewModel.currentPageIndex) { _, _ in
                viewModel.saveSession()
            }
            .onChange(of: viewModel.currentSentenceIndex) { _, _ in
                viewModel.saveSession()
            }
            .onChange(of: viewModel.isChecked) { _, _ in
                viewModel.saveSession()
            }
    }
}
