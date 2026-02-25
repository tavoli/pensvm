import SwiftUI

struct FocusedPhraseView: View {
    let words: [AnnotatedWord]
    @EnvironmentObject var viewModel: AppViewModel
    @State private var selectedWord: AnnotatedWord?
    @State private var isTranslationRevealed: Bool = false
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
            // Phrase area - centered vertically, text flows naturally
            VStack {
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

                Spacer()
            }
            .frame(maxWidth: .infinity)

            // Bottom info panel - two rows
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 1)

                // Row 1: Translation + Close button
                HStack(alignment: .center) {
                    translationBar

                    Spacer()

                    Button("Close") {
                        viewModel.closeFocusedPhrase()
                    }
                    .buttonStyle(MinimalButtonStyle())
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Rectangle()
                    .fill(Color.black.opacity(0.1))
                    .frame(height: 1)

                // Row 2: Word info
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
            selectPreviousWord()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            selectNextWord()
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "1234")) { keyPress in
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
    private var translationBar: some View {
        if viewModel.isLoadingTranslation {
            // Loading state
            Text("Translating...")
                .font(.custom("Palatino", size: 14))
                .foregroundColor(.black.opacity(0.4))
                .italic()
        } else if let translation = viewModel.focusedSentenceTranslation {
            if translation.hasPrefix("Error:") {
                // Error: show directly without spoiler
                Text(translation)
                    .font(.custom("Palatino", size: 14))
                    .foregroundColor(.red.opacity(0.7))
            } else if isTranslationRevealed {
                // Revealed: show translation text
                Text(translation)
                    .font(.custom("Palatino", size: 14))
                    .foregroundColor(.black.opacity(0.6))
                    .onTapGesture {
                        isTranslationRevealed = false
                    }
            } else {
                // Hidden: black spoiler bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black)
                    .frame(width: max(CGFloat(translation.count) * 7, 100), height: 20)
                    .onTapGesture {
                        isTranslationRevealed = true
                    }
            }
        } else {
            // No translation available
            Text("Translation unavailable")
                .font(.custom("Palatino", size: 14))
                .foregroundColor(.black.opacity(0.3))
                .italic()
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
                Text(word.text)
                    .font(.custom("Palatino", size: 16).bold())
                    .foregroundColor(.black)

                if let pos = word.expandedPos {
                    Text(pos)
                        .font(.custom("Palatino", size: 13))
                        .foregroundColor(.black.opacity(0.4))
                }

                Text("·")
                    .foregroundColor(.black.opacity(0.3))

                ForEach(Array(discriminationOptions.enumerated()), id: \.offset) { index, option in
                    let isCorrect = option == (word.gloss ?? "")

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
                // Word
                Text(word.text)
                    .font(.custom("Palatino", size: 16))
                    .foregroundColor(.black)

                // Part of speech
                if let pos = word.expandedPos {
                    Text(" · ")
                        .foregroundColor(.black.opacity(0.3))
                    Text(pos)
                        .foregroundColor(.black.opacity(0.6))
                }

                // Lemma — gloss
                if word.lemma != nil || word.gloss != nil {
                    Text(" · ")
                        .foregroundColor(.black.opacity(0.3))
                    if let lemma = word.lemma {
                        Text(lemma)
                            .italic()
                            .foregroundColor(.black)
                    }
                    if let gloss = word.gloss {
                        Text(word.lemma != nil ? " — \(gloss)" : gloss)
                            .foregroundColor(.black.opacity(0.6))
                    }
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
