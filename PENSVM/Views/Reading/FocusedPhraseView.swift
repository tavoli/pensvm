import SwiftUI

struct FocusedPhraseView: View {
    let words: [AnnotatedWord]
    @EnvironmentObject var viewModel: AppViewModel
    @State private var selectedWord: AnnotatedWord?
    @State private var isTranslationRevealed: Bool = false

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

    @ViewBuilder
    private func wordInfoView(_ word: AnnotatedWord) -> some View {
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
        }
        .font(.custom("Palatino", size: 16))
    }
}
