import SwiftUI

struct HomeView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("PENSVM")
                .font(.custom("Palatino", size: 48))
                .foregroundColor(.black)

            Text("Latin exercises from Lingua Latina")
                .font(.custom("Palatino", size: 18))
                .foregroundColor(.black.opacity(0.6))

            Spacer()

            Button("Enter Library") {
                viewModel.goToChapterLibrary()
            }
            .buttonStyle(MinimalButtonStyle())
            .font(.custom("Palatino", size: 18))

            Text("Press Enter to continue")
                .font(.custom("Palatino", size: 14))
                .foregroundColor(.black.opacity(0.4))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onAppear { isFocused = true }
        .onKeyPress(.return) {
            viewModel.goToChapterLibrary()
            return .handled
        }
    }
}
