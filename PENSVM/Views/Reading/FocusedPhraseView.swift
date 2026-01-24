import SwiftUI

struct FocusedPhraseView: View {
    let words: [AnnotatedWord]
    @EnvironmentObject var viewModel: AppViewModel
    @State private var selectedWord: AnnotatedWord?

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

            // Bottom info panel
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
                .padding(16)
                .frame(height: 50)
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
