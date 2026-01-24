import SwiftUI

// Represents a sentence within a reading block
struct ReadingSentence: Identifiable {
    let id: UUID
    let words: [AnnotatedWord]
    let blockStyle: String?
}

struct PageContentView: View {
    let page: Page
    var column: String? = nil  // nil means show all content (backward compatible)

    @EnvironmentObject var viewModel: AppViewModel
    @State private var selectedWord: AnnotatedWord?
    @State private var preparedSentenceId: UUID?
    @State private var hoverTimer: Timer?
    @State private var cachedSentences: [UUID: [ReadingSentence]] = [:]  // block.id -> sentences

    private var baseDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("PENSVM")
    }

    // Filter content by column if specified
    private var filteredContent: [ContentBlock] {
        guard let col = column else {
            return page.content  // No filter, show all
        }
        return page.content.filter { $0.resolvedColumn == col }
    }

    // Show line numbers only in left column (or when no column filter)
    private var shouldShowLineNumbers: Bool {
        column == nil || column == "left"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if shouldShowLineNumbers, let lineStart = page.lineStart {
                Text("Lines \(lineStart)–\(page.lineEnd ?? lineStart)")
                    .font(.custom("Palatino", size: 12))
                    .foregroundColor(.black.opacity(0.4))
            }

            ForEach(filteredContent) { block in
                contentBlock(block)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.white)
        .popover(item: $selectedWord) { word in
            WordAnnotationPopover(word: word)
        }
    }

    @ViewBuilder
    private func contentBlock(_ block: ContentBlock) -> some View {
        switch block.type {
        case .text:
            let words = block.words
            if !words.isEmpty {
                // Render annotated words as tappable elements
                annotatedTextView(words: words, block: block)
                    .padding(.top, topPadding(for: block))
            } else if let paragraph = block.paragraph {
                // Fallback: render plain paragraph text (no hover/focus for non-annotated text)
                Text(paragraph)
                    .font(.custom("Palatino", size: textSize(for: block)).weight(isBold(for: block) ? .bold : .regular))
                    .italic(isItalic(for: block))
                    .foregroundColor(textColor(for: block))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, textIndent(for: block))
                    .padding(.top, topPadding(for: block))
                    .padding(.vertical, isGrammarStyle(block.style) ? 2 : 0)
            }
        case .image:
            if let assetPath = block.assetPath {
                let imageURL = baseDirectory.appendingPathComponent(assetPath)
                if let nsImage = NSImage(contentsOf: imageURL) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else {
                    placeholderImage(block.description)
                }
            } else {
                placeholderImage(block.description)
            }
        }
    }

    // MARK: - Grammar Style Helpers

    private func textSize(for block: ContentBlock) -> CGFloat {
        switch block.style {
        case "grammar-title":
            return 20
        case "grammar-subtitle", "grammar", "grammar-label":
            return 16
        default:
            return 18
        }
    }

    private func textColor(for block: ContentBlock) -> Color {
        switch block.style {
        case "grammar-title":
            return Color(red: 0.8, green: 0.4, blue: 0)  // Orange #CC6600
        case "grammar":
            return .black.opacity(0.8)
        default:
            return .black
        }
    }

    private func isGrammarStyle(_ style: String?) -> Bool {
        guard let style = style else { return false }
        return style.hasPrefix("grammar")
    }

    private func textIndent(for block: ContentBlock) -> CGFloat {
        switch block.style {
        case "grammar", "grammar-label":
            return 16
        default:
            return 0
        }
    }

    private func topPadding(for block: ContentBlock) -> CGFloat {
        switch block.style {
        case "grammar-title":
            return 24
        default:
            return 0
        }
    }

    private func isBold(for block: ContentBlock) -> Bool {
        switch block.style {
        case "grammar-title", "grammar-label":
            return true
        default:
            return false
        }
    }

    private func isItalic(for block: ContentBlock) -> Bool {
        switch block.style {
        case "grammar-subtitle", "italic":
            return true
        default:
            return false
        }
    }

    private func placeholderImage(_ description: String?) -> some View {
        VStack {
            Text("[Image]")
                .font(.custom("Palatino", size: 14))
                .foregroundColor(.black.opacity(0.4))
            if let desc = description {
                Text(desc)
                    .font(.custom("Palatino", size: 12))
                    .foregroundColor(.black.opacity(0.3))
            }
        }
        .frame(width: 200, height: 100)
        .overlay(
            Rectangle()
                .stroke(Color.black.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Sentence Splitting

    private func getSentences(for block: ContentBlock) -> [ReadingSentence] {
        if let cached = cachedSentences[block.id] {
            return cached
        }
        let sentences = splitIntoSentences(words: block.words, style: block.style)
        DispatchQueue.main.async {
            cachedSentences[block.id] = sentences
        }
        return sentences
    }

    private func splitIntoSentences(words: [AnnotatedWord], style: String?) -> [ReadingSentence] {
        var sentences: [ReadingSentence] = []
        var currentWords: [AnnotatedWord] = []

        // Grammar blocks: only split on periods (semicolons stay within the line)
        // Regular text: split on all sentence-ending punctuation
        let sentenceEnders: Set<String> = style == "grammar"
            ? ["."]
            : [".", "?", "!", ";"]

        for word in words {
            currentWords.append(word)
            // Check if this word ends a sentence
            if sentenceEnders.contains(word.text) {
                sentences.append(ReadingSentence(id: UUID(), words: currentWords, blockStyle: style))
                currentWords = []
            }
        }

        // Add remaining words as final sentence
        if !currentWords.isEmpty {
            sentences.append(ReadingSentence(id: UUID(), words: currentWords, blockStyle: style))
        }

        return sentences
    }

    // MARK: - Focused Phrase Handling

    private func handleSentenceHover(isHovering: Bool, sentence: ReadingSentence) {
        if isHovering {
            // Start 3-second timer to prepare sentence
            hoverTimer?.invalidate()
            hoverTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
                DispatchQueue.main.async {
                    preparedSentenceId = sentence.id
                }
            }
        } else {
            // Cancel timer and clear prepared state
            hoverTimer?.invalidate()
            hoverTimer = nil
            preparedSentenceId = nil
        }
    }

    private func handleSentenceTap(sentence: ReadingSentence) {
        if preparedSentenceId == sentence.id {
            viewModel.showFocusedSentence(sentence.words)
            preparedSentenceId = nil
        }
    }

    // MARK: - Annotated Word Rendering

    @ViewBuilder
    private func annotatedTextView(words: [AnnotatedWord], block: ContentBlock) -> some View {
        let sentences = getSentences(for: block)

        if block.style == "grammar" {
            // Grammar content: each sentence on its own line
            VStack(alignment: .leading, spacing: 2) {
                ForEach(sentences) { sentence in
                    WrappingHStack(alignment: .leading, spacing: 0) {
                        ForEach(sentence.words) { word in
                            wordView(word, sentence: sentence, block: block)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, textIndent(for: block))
            .padding(.vertical, 2)
        } else {
            // Regular text: all sentences flow together
            WrappingHStack(alignment: .leading, spacing: 0) {
                ForEach(sentences) { sentence in
                    ForEach(sentence.words) { word in
                        wordView(word, sentence: sentence, block: block)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, textIndent(for: block))
            .padding(.vertical, isGrammarStyle(block.style) ? 2 : 0)
        }
    }

    @ViewBuilder
    private func wordView(_ word: AnnotatedWord, sentence: ReadingSentence, block: ContentBlock) -> some View {
        let hasAnnotation = word.hasAnnotations
        let isPunctuation = !hasAnnotation && word.text.count <= 2
        let displayText = isPunctuation ? word.text : " " + word.text
        let isPrepared = preparedSentenceId == sentence.id

        Text(displayText)
            .font(.custom("Palatino", size: textSize(for: block)).weight(isBold(for: block) ? .bold : .regular))
            .italic(isItalic(for: block))
            .foregroundColor(textColor(for: block))
            .background(isPrepared ? Color.black.opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
            .onHover { isHovering in
                handleSentenceHover(isHovering: isHovering, sentence: sentence)
            }
            .onTapGesture {
                if isPrepared {
                    viewModel.showFocusedSentence(sentence.words)
                    preparedSentenceId = nil
                } else if hasAnnotation {
                    selectedWord = word
                }
            }
    }

}

// MARK: - Word Annotation Popover
// Compact popover: word, lemma - gloss, pos + form

struct WordAnnotationPopover: View {
    let word: AnnotatedWord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header: word + part of speech
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(word.text)
                    .font(.custom("Palatino", size: 20))
                    .foregroundColor(.black)
                if let posText = word.expandedPos {
                    Text(posText)
                        .font(.custom("Palatino", size: 12))
                        .foregroundColor(.black.opacity(0.5))
                }
            }

            // Lemma - gloss
            if word.lemma != nil || word.gloss != nil {
                HStack(spacing: 0) {
                    if let lemma = word.lemma {
                        Text(lemma)
                            .font(.custom("Palatino", size: 14))
                            .italic()
                            .foregroundColor(.black)
                    }
                    if let gloss = word.gloss {
                        Text(word.lemma != nil ? " - \(gloss)" : gloss)
                            .font(.custom("Palatino", size: 14))
                            .foregroundColor(.black.opacity(0.6))
                    }
                }
            }

            // Form only (pos moved to header)
            if let formText = word.expandedForm {
                Text(formText)
                    .font(.custom("Palatino", size: 12))
                    .foregroundColor(.black.opacity(0.5))
            }
        }
        .padding(10)
        .background(Color.white)
        .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
    }
}

// MARK: - Wrapping HStack for Flow Layout

struct WrappingHStack: Layout {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)

        for (index, subview) in subviews.enumerated() {
            let point = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in containerWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                // Check if we need to wrap to next line
                if x + size.width > containerWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width
            }

            self.size = CGSize(width: containerWidth, height: y + lineHeight)
        }
    }
}

extension Text {
    func italic(_ isItalic: Bool) -> Text {
        if isItalic {
            return self.italic()
        }
        return self
    }
}
