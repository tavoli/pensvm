import SwiftUI

struct ReferencePanel: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var selectedTab = 0

    private let references = [
        ("Nominative", "Who? (subject)", "-a, -us, -um", "-ae, -ī, -a"),
        ("Accusative", "What? / To (place)", "-am, -um", "-ās, -ōs, -a"),
        ("Genitive", "Whose? / Of what?", "-ae, -ī", "-ārum, -ōrum"),
        ("Dative", "To whom? / For?", "-ae, -ō", "-īs"),
        ("Ablative", "With / From (place)", "-ā, -ō", "-īs"),
        ("Locative", "At/In (place)", "-ae, -ī", "-īs"),
        ("Imperative", "Command", "-ā, -ē, -e, -ī", "-āte, -ēte, -ite, -īte"),
        ("Indicative", "Fact (he/she does)", "-at, -et, -it", "-ant, -ent, -unt, -iunt"),
    ]

    // Pronoun: is, ea, id (he, she, it)
    private let pronounsIsEaId = [
        ("Nom.", "is", "ea", "id", "eī", "eae", "ea"),
        ("Acc.", "eum", "eam", "id", "eōs", "eās", "ea"),
        ("Gen.", "eius", "eius", "eius", "eōrum", "eārum", "eōrum"),
        ("Dat.", "eī", "eī", "eī", "eīs", "eīs", "eīs"),
        ("Abl.", "eō", "eā", "eō", "eīs", "eīs", "eīs"),
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

            // Tab bar
            HStack(spacing: 0) {
                TabButton(title: "Nouns/Adjectives", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                TabButton(title: "Pronouns", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Content
            if selectedTab == 0 {
                endingsTable
            } else {
                pronounsTable
            }

            Spacer()
        }
        .frame(width: 520, height: 360)
        .background(Color.white)
        .overlay(
            Rectangle()
                .stroke(Color.black, lineWidth: 1)
        )
    }

    private var endingsTable: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                Spacer()
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
                    Spacer()
                }
                .padding(.vertical, 6)
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundColor(.black)
    }

    private var pronounsTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            Text("is, ea, id — he, she, it")
                .fontWeight(.medium)
                .padding(.vertical, 8)
                .padding(.horizontal)

            // Header row
            HStack(spacing: 0) {
                Text("")
                    .frame(width: 50, alignment: .leading)
                Text("M")
                    .frame(width: 55, alignment: .leading)
                Text("F")
                    .frame(width: 55, alignment: .leading)
                Text("N")
                    .frame(width: 55, alignment: .leading)
                Text("M")
                    .frame(width: 65, alignment: .leading)
                Text("F")
                    .frame(width: 65, alignment: .leading)
                Text("N")
                    .frame(width: 65, alignment: .leading)
                Spacer()
            }
            .fontWeight(.medium)
            .padding(.vertical, 4)
            .padding(.horizontal)

            // Singular/Plural labels
            HStack(spacing: 0) {
                Text("")
                    .frame(width: 50, alignment: .leading)
                Text("Singular")
                    .frame(width: 165, alignment: .leading)
                Text("Plural")
                    .frame(width: 195, alignment: .leading)
                Spacer()
            }
            .font(.caption)
            .foregroundColor(.black.opacity(0.6))
            .padding(.horizontal)
            .padding(.bottom, 4)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.black),
                alignment: .bottom
            )

            // Pronoun rows
            ForEach(pronounsIsEaId, id: \.0) { cas, ms, fs, ns, mp, fp, np in
                HStack(spacing: 0) {
                    Text(cas)
                        .frame(width: 50, alignment: .leading)
                    Text(ms)
                        .frame(width: 55, alignment: .leading)
                    Text(fs)
                        .frame(width: 55, alignment: .leading)
                    Text(ns)
                        .frame(width: 55, alignment: .leading)
                    Text(mp)
                        .frame(width: 65, alignment: .leading)
                    Text(fp)
                        .frame(width: 65, alignment: .leading)
                    Text(np)
                        .frame(width: 65, alignment: .leading)
                    Spacer()
                }
                .padding(.vertical, 6)
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundColor(.black)
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.black : Color.clear)
                .foregroundColor(isSelected ? .white : .black)
        }
        .buttonStyle(PlainButtonStyle())
        .overlay(
            Rectangle()
                .stroke(Color.black, lineWidth: 1)
        )
    }
}
