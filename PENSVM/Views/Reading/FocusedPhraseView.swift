import SwiftUI

struct FocusedPhraseView: View {
    let words: [AnnotatedWord]
    @EnvironmentObject var viewModel: AppViewModel
    @State private var selectedWord: AnnotatedWord?
    @State private var translationText: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var discriminationOptions: [String] = []
    @State private var discriminationSelected: Int?
    @State private var discriminationResolved: Bool = false

    private var annotatedWords: [AnnotatedWord] {
        words.filter { $0.hasAnnotations }
    }

    private func selectPreviousWord() {
        guard !annotatedWords.isEmpty else { return }
        if let current = selectedWord,
           let currentIndex = annotatedWords.firstIndex(where: { $0.id == current.id }) {
            let newIndex = currentIndex > 0 ? currentIndex - 1 : annotatedWords.count - 1
            selectedWord = annotatedWords[newIndex]
        } else {
            selectedWord = annotatedWords.last
        }
    }

    private func selectNextWord() {
        guard !annotatedWords.isEmpty else { return }
        if let current = selectedWord,
           let currentIndex = annotatedWords.firstIndex(where: { $0.id == current.id }) {
            let newIndex = currentIndex < annotatedWords.count - 1 ? currentIndex + 1 : 0
            selectedWord = annotatedWords[newIndex]
        } else {
            selectedWord = annotatedWords.first
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content area - sentence + inline translation
            VStack(spacing: 32) {
                Spacer()

                if words.isEmpty {
                    Text("No content")
                        .font(.custom("Palatino", size: 28))
                        .foregroundColor(.black.opacity(0.4))
                } else {
                    // Tappable words - centered horizontally
                    HStack {
                        Spacer()
                        WrappingHStack(alignment: .center, spacing: 0) {
                            ForEach(words) { word in
                                wordView(word)
                            }
                        }
                        .frame(maxWidth: 720)
                        Spacer()
                    }
                }

                // Inline translation area
                translationArea

                Spacer()
            }
            .frame(maxWidth: .infinity)

            // Bottom bar - single row: word info + Close
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 1)

                HStack(alignment: .center) {
                    if let word = selectedWord {
                        wordInfoView(word)
                    } else {
                        Text("Tap a word to see its details")
                            .font(.custom("Palatino", size: 14))
                            .foregroundColor(.black.opacity(0.4))
                            .italic()
                    }

                    Spacer()

                    Button("Close") {
                        viewModel.closeFocusedPhrase()
                    }
                    .buttonStyle(MinimalButtonStyle())
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) {
            guard !isTextFieldFocused else { return .ignored }
            selectPreviousWord()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            guard !isTextFieldFocused else { return .ignored }
            selectNextWord()
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "1234")) { keyPress in
            guard !isTextFieldFocused else { return .ignored }
            if let word = selectedWord, word.isPolysemous, !discriminationResolved {
                if let digit = Int(String(keyPress.characters)) {
                    let index = digit - 1
                    if index >= 0 && index < discriminationOptions.count {
                        discriminationSelected = index
                        discriminationResolved = true
                    }
                }
                return .handled
            }
            return .ignored
        }
        .onChange(of: selectedWord?.id) { _ in
            resetDiscrimination()
        }
        .onChange(of: viewModel.focusedSentence?.first?.id) { _ in
            translationText = ""
            isTextFieldFocused = false
        }
    }

    @ViewBuilder
    private func wordView(_ word: AnnotatedWord) -> some View {
        let hasAnnotation = word.hasAnnotations
        let isPunctuation = !hasAnnotation && word.text.count <= 2
        let displayText = isPunctuation ? word.text : " " + word.text
        let isSelected = selectedWord?.id == word.id

        Text(displayText)
            .font(.custom("Palatino", size: 28))
            .foregroundColor(.black)
            .overlay(alignment: .bottom) {
                if isSelected {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 1)
                        .offset(y: -2)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if hasAnnotation {
                    selectedWord = word
                }
            }
    }

    @ViewBuilder
    private var translationArea: some View {
        VStack(spacing: 16) {
            switch viewModel.translationState {
            case .writing:
                VStack(spacing: 4) {
                    TextField("Write your translation...", text: $translationText)
                        .font(.custom("Palatino", size: 24))
                        .foregroundColor(.black)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.center)
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            if !translationText.trimmingCharacters(in: .whitespaces).isEmpty {
                                viewModel.submitTranslation(userText: translationText)
                            }
                        }

                    Rectangle()
                        .fill(Color.black.opacity(0.15))
                        .frame(maxWidth: 480, maxHeight: 1)

                    Text("Return to submit")
                        .font(.custom("Palatino", size: 12))
                        .foregroundColor(.black.opacity(0.15))
                }

            case .loading:
                Text("Checking...")
                    .font(.custom("Palatino", size: 24))
                    .foregroundColor(.black.opacity(0.2))
                    .italic()

            case .reviewed:
                if let feedback = viewModel.translationFeedback {
                    VStack(spacing: 16) {
                        // User's translation
                        Text(translationText)
                            .font(.custom("Palatino", size: 24))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)

                        // Rating
                        Text(feedback.rating)
                            .font(.custom("Palatino", size: 14).bold())
                            .foregroundColor(ratingColor(feedback.rating))

                        // Divider + reference
                        VStack(spacing: 12) {
                            Rectangle()
                                .fill(Color.black.opacity(0.07))
                                .frame(maxWidth: 480, maxHeight: 1)

                            Text(feedback.referenceTranslation)
                                .font(.custom("Palatino", size: 16))
                                .foregroundColor(.black.opacity(0.4))
                                .italic()
                                .multilineTextAlignment(.center)

                            // Notes
                            if !feedback.notes.isEmpty {
                                ForEach(feedback.notes, id: \.self) { note in
                                    Text(note)
                                        .font(.custom("Palatino", size: 13))
                                        .foregroundColor(.black.opacity(0.25))
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }

                        // Try again
                        Text("Try again")
                            .font(.custom("Palatino", size: 13))
                            .foregroundColor(.black.opacity(0.4))
                            .underline()
                            .onTapGesture {
                                translationText = ""
                                viewModel.retryTranslation()
                            }
                    }
                }
            }
        }
        .frame(maxWidth: 720)
    }

    private func ratingColor(_ rating: String) -> Color {
        switch rating {
        case "excellent": return Color(red: 0, green: 0.6, blue: 0)
        case "good": return .black
        case "needs work": return Color(red: 0.8, green: 0, blue: 0)
        case "error": return .red.opacity(0.7)
        default: return .black
        }
    }

    private func resetDiscrimination() {
        if let word = selectedWord, word.isPolysemous {
            var allOptions = [word.gloss ?? ""] + word.alternativeGlosses
            allOptions.shuffle()
            discriminationOptions = allOptions
        } else {
            discriminationOptions = []
        }
        discriminationSelected = nil
        discriminationResolved = false
    }

    @ViewBuilder
    private func wordInfoView(_ word: AnnotatedWord) -> some View {
        if word.isPolysemous && !discriminationResolved {
            // Inline discrimination: show options horizontally
            HStack(spacing: 8) {
                if let citation = word.dictionaryCitation {
                    Text(citation)
                        .font(.custom("Palatino", size: 16).bold())
                        .foregroundColor(.black)
                } else {
                    Text(word.lemma ?? word.text)
                        .font(.custom("Palatino", size: 16).bold())
                        .foregroundColor(.black)
                }

                if let pos = word.expandedPos {
                    Text(pos)
                        .font(.custom("Palatino", size: 13))
                        .foregroundColor(.black.opacity(0.4))
                }

                if word.irregular {
                    Text("irreg.")
                        .font(.custom("Palatino", size: 13))
                        .foregroundColor(.black.opacity(0.4))
                }

                Text("·")
                    .foregroundColor(.black.opacity(0.3))

                ForEach(Array(discriminationOptions.enumerated()), id: \.offset) { index, option in
                    HStack(spacing: 4) {
                        Text("\(index + 1)")
                            .font(.custom("Palatino", size: 12).bold())
                            .foregroundColor(.black.opacity(0.5))
                        Text(option)
                            .font(.custom("Palatino", size: 14))
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.black, lineWidth: 1)
                    )
                    .cornerRadius(3)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        discriminationSelected = index
                        discriminationResolved = true
                    }
                }
            }
            .font(.custom("Palatino", size: 16))
        } else {
            // Standard word info (also shown after discrimination resolves)
            HStack(spacing: 0) {
                // Dictionary citation or lemma
                if let citation = word.dictionaryCitation {
                    Text(citation)
                        .font(.custom("Palatino", size: 16))
                        .foregroundColor(.black)
                } else {
                    Text(word.lemma ?? word.text)
                        .font(.custom("Palatino", size: 16))
                        .foregroundColor(.black)
                }

                // Part of speech
                if let pos = word.expandedPos {
                    Text(" · ")
                        .foregroundColor(.black.opacity(0.3))
                    Text(pos)
                        .foregroundColor(.black.opacity(0.6))
                }

                // Irregular marker
                if word.irregular {
                    Text(" · ")
                        .foregroundColor(.black.opacity(0.3))
                    Text("irreg.")
                        .foregroundColor(.black.opacity(0.6))
                }

                // Gloss
                if let gloss = word.gloss {
                    Text(" · ")
                        .foregroundColor(.black.opacity(0.3))
                    Text(gloss)
                        .foregroundColor(.black.opacity(0.6))
                }

                // Form
                if let form = word.expandedForm {
                    Text(" · ")
                        .foregroundColor(.black.opacity(0.3))
                    Text(form)
                        .foregroundColor(.black.opacity(0.6))
                }

                // Show result indicator after discrimination
                if word.isPolysemous && discriminationResolved {
                    if let selected = discriminationSelected,
                       selected < discriminationOptions.count {
                        let pickedCorrectly = discriminationOptions[selected] == (word.gloss ?? "")
                        Text(pickedCorrectly ? " · correct" : " · \(discriminationOptions[selected])")
                            .foregroundColor(pickedCorrectly ? Color(red: 0, green: 0.6, blue: 0) : .black.opacity(0.4))
                    }
                }
            }
            .font(.custom("Palatino", size: 16))
        }
    }
}
