import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @EnvironmentObject var viewModel: ExerciseViewModel
    @State private var isHovering = false

    var body: some View {
        ZStack {
            Color(isHovering ? .green : .white)

            Text("Drop PENSVM A exercise")
                .font(.custom("Palatino", size: 22))
                .foregroundColor(.black)

            VStack {
                Spacer()

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
        .onTapGesture {
            viewModel.openFilePicker()
        }
        .onDrop(of: [.fileURL, .image], isTargeted: $isHovering) { providers in
            viewModel.handleDrop(providers: providers)
        }
    }
}
