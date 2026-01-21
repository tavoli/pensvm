import SwiftUI

@main
struct PENSVMApp: App {
    @StateObject private var viewModel = ExerciseViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 800, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Image...") {
                    viewModel.openFilePicker()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}
