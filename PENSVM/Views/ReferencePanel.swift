import SwiftUI

struct ReferencePanel: View {
    @EnvironmentObject var viewModel: ExerciseViewModel

    private let references = [
        ("Accusative", "Who/What? (object)", "-am, -um", "-ās, -ōs, -a"),
        ("Ablative", "Where? / With whom?", "-ā, -ō", "-īs"),
        ("Imperative", "Command", "-ā, -ē, -e, -ī", "-āte, -ēte, -ite, -īte"),
        ("Indicative", "Fact (he/she does)", "-at, -et, -it", "-ant, -ent, -unt, -iunt"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Reference")
                    .foregroundColor(.black)
                Spacer()
                Button("Close") {
                    viewModel.toggleReference()
                }
                .buttonStyle(MinimalButtonStyle())
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.black),
                alignment: .bottom
            )

            // Table
            VStack(spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    Text("Concept")
                        .frame(width: 90, alignment: .leading)
                    Text("Question")
                        .frame(width: 140, alignment: .leading)
                    Text("Singular")
                        .frame(width: 100, alignment: .leading)
                    Text("Plural")
                        .frame(width: 140, alignment: .leading)
                }
                .fontWeight(.medium)
                .padding(.vertical, 8)
                .padding(.horizontal)
                .background(Color.white)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.black),
                    alignment: .bottom
                )

                // Data rows
                ForEach(references, id: \.0) { concept, question, singular, plural in
                    HStack(spacing: 0) {
                        Text(concept)
                            .frame(width: 90, alignment: .leading)
                        Text(question)
                            .frame(width: 140, alignment: .leading)
                        Text(singular)
                            .frame(width: 100, alignment: .leading)
                        Text(plural)
                            .frame(width: 140, alignment: .leading)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal)
                }
            }
            .foregroundColor(.black)

            Spacer()
        }
        .frame(width: 520, height: 280)
        .background(Color.white)
        .overlay(
            Rectangle()
                .stroke(Color.black, lineWidth: 1)
        )
    }
}
