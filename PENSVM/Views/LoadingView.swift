import SwiftUI

struct LoadingView: View {
    @EnvironmentObject var viewModel: ExerciseViewModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Processing...")
                .foregroundColor(.black)

            Button("Cancel") {
                viewModel.cancelLoading()
            }
            .buttonStyle(MinimalButtonStyle())

            Spacer()
        }
    }
}
