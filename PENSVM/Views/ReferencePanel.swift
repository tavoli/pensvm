import SwiftUI

struct ReferencePanel: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var selectedTab = 0
    @State private var selectedDeclension = 0

    // Declension data: (case, question, singular, plural)
    private let declensions: [[(String, String, String, String)]] = [
        // I (-ae) — feminine
        [
            ("Nom.", "Who?", "-a", "-ae"),
            ("Acc.", "What?", "-am", "-ās"),
            ("Gen.", "Whose?", "-ae", "-ārum"),
            ("Dat.", "To whom?", "-ae", "-īs"),
            ("Abl.", "With/From", "-ā", "-īs"),
            ("Loc.", "At/In (place)", "-ae", "-īs"),
        ],
        // II (-ī) — masculine/neuter
        [
            ("Nom.", "Who?", "-us / -um", "-ī / -a"),
            ("Acc.", "What?", "-um", "-ōs / -a"),
            ("Gen.", "Whose?", "-ī", "-ōrum"),
            ("Dat.", "To whom?", "-ō", "-īs"),
            ("Abl.", "With/From", "-ō", "-īs"),
            ("Loc.", "At/In (place)", "-ī", "-īs"),
        ],
        // III (-is) — m/f/n
        [
            ("Nom.", "Who?", "-/s/x", "-ēs / -a/-ia"),
            ("Acc.", "What?", "-em / -", "-ēs / -a/-ia"),
            ("Gen.", "Whose?", "-is", "-um / -ium"),
            ("Dat.", "To whom?", "-ī", "-ibus"),
            ("Abl.", "With/From", "-e / -ī", "-ibus"),
            ("Loc.", "At/In (place)", "-ī / -e", "-ibus"),
        ],
        // IV (-ūs) — masculine/neuter
        [
            ("Nom.", "Who?", "-us / -ū", "-ūs / -ua"),
            ("Acc.", "What?", "-um / -ū", "-ūs / -ua"),
            ("Gen.", "Whose?", "-ūs", "-uum"),
            ("Dat.", "To whom?", "-uī / -ū", "-ibus"),
            ("Abl.", "With/From", "-ū", "-ibus"),
            ("Loc.", "At/In (place)", "-ū", "-ibus"),
        ],
        // V (-ēī) — feminine
        [
            ("Nom.", "Who?", "-ēs", "-ēs"),
            ("Acc.", "What?", "-em", "-ēs"),
            ("Gen.", "Whose?", "-ēī / -eī", "-ērum"),
            ("Dat.", "To whom?", "-ēī / -eī", "-ēbus"),
            ("Abl.", "With/From", "-ē", "-ēbus"),
            ("Loc.", "At/In (place)", "-ē", "-ēbus"),
        ],
    ]

    private let declensionTabs = [
        "I (-ae)", "II (-ī)", "III (-is)", "IV (-ūs)", "V (-ēī)"
    ]

    private let verbEndings = [
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
                TabButton(title: "Nouns", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                TabButton(title: "Verbs", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                TabButton(title: "Pronouns", isSelected: selectedTab == 2) {
                    selectedTab = 2
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Content
            if selectedTab == 0 {
                declensionContent
            } else if selectedTab == 1 {
                verbsTable
            } else {
                pronounsTable
            }

            Spacer()
        }
        .frame(width: 520, height: 380)
        .background(Color.white)
        .overlay(
            Rectangle()
                .stroke(Color.black, lineWidth: 1)
        )
    }

    // MARK: - Declension Content

    private var declensionContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Declension sub-tabs
            HStack(spacing: 0) {
                ForEach(Array(declensionTabs.enumerated()), id: \.offset) { idx, title in
                    Button(action: { selectedDeclension = idx }) {
                        Text(title)
                            .font(.system(size: 11))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(selectedDeclension == idx ? Color.black : Color.clear)
                            .foregroundColor(selectedDeclension == idx ? .white : .black)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .overlay(
                        Rectangle()
                            .stroke(Color.black, lineWidth: 1)
                    )
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Table header
            HStack(spacing: 0) {
                Text("Case")
                    .frame(width: 60, alignment: .leading)
                Text("Question")
                    .frame(width: 120, alignment: .leading)
                Text("Singular")
                    .frame(width: 140, alignment: .leading)
                Text("Plural")
                    .frame(width: 140, alignment: .leading)
                Spacer()
            }
            .fontWeight(.medium)
            .padding(.vertical, 8)
            .padding(.horizontal)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.black),
                alignment: .bottom
            )

            // Data rows
            let rows = declensions[selectedDeclension]
            ForEach(rows, id: \.0) { cas, question, singular, plural in
                HStack(spacing: 0) {
                    Text(cas)
                        .frame(width: 60, alignment: .leading)
                    Text(question)
                        .foregroundColor(.black.opacity(0.6))
                        .frame(width: 120, alignment: .leading)
                    Text(singular)
                        .fontWeight(.medium)
                        .frame(width: 140, alignment: .leading)
                    Text(plural)
                        .fontWeight(.medium)
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

    // MARK: - Verbs Table

    private var verbsTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                Text("Form")
                    .frame(width: 90, alignment: .leading)
                Text("Meaning")
                    .frame(width: 140, alignment: .leading)
                Text("Singular")
                    .frame(width: 130, alignment: .leading)
                Text("Plural")
                    .frame(width: 140, alignment: .leading)
                Spacer()
            }
            .fontWeight(.medium)
            .padding(.vertical, 8)
            .padding(.horizontal)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.black),
                alignment: .bottom
            )

            ForEach(verbEndings, id: \.0) { form, meaning, singular, plural in
                HStack(spacing: 0) {
                    Text(form)
                        .frame(width: 90, alignment: .leading)
                    Text(meaning)
                        .foregroundColor(.black.opacity(0.6))
                        .frame(width: 140, alignment: .leading)
                    Text(singular)
                        .fontWeight(.medium)
                        .frame(width: 130, alignment: .leading)
                    Text(plural)
                        .fontWeight(.medium)
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
