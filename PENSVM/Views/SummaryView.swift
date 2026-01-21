import SwiftUI

struct SummaryView: View {
    @EnvironmentObject var viewModel: ExerciseViewModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Exercise Complete")
                .font(.custom("Palatino", size: 28))
                .foregroundColor(.black)

            if let exercise = viewModel.exercise {
                Text("\(exercise.percentageCorrect)%")
                    .font(.custom("Palatino", size: 48))
                    .foregroundColor(.black)

                Text("\(exercise.correctCount) of \(exercise.totalGaps) correct")
                    .font(.custom("Palatino", size: 18))
                    .foregroundColor(.black)
            }

            Text("Time: \(viewModel.elapsedTime)")
                .font(.custom("Palatino", size: 18))
                .foregroundColor(.black)

            VStack(spacing: 12) {
                Button("New Exercise") {
                    viewModel.reset()
                }
                .buttonStyle(MinimalButtonStyle())

                Button("Review Errors") {
                    // TODO: Review errors
                }
                .buttonStyle(MinimalButtonStyle())
            }
            .padding(.top, 20)

            Spacer()
        }
    }
}
