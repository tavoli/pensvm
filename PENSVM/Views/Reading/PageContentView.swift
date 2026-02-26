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
    @State private var hoverTimer: Timer?
    @State private var cachedSentences: [UUID: [ReadingSentence]] = [:]  // block.id -> sentences
    @State private var currentlyHoveredSentence: ReadingSentence?  // Track current hover for restart

    // Convenience accessors to viewModel state
    private var selectedWord: AnnotatedWord? {
        get { viewModel.readingSelectedWord }
        nonmutating set { viewModel.readingSelectedWord = newValue }
    }

    private var preparedSentenceId: UUID? {
        get { viewModel.readingPreparedSentenceId }
        nonmutating set { viewModel.readingPreparedSentenceId = newValue }
    }

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
        .overlayPreferenceValue(WordFrameKey.self) { anchors in
            GeometryReader { geo in
                if let word = selectedWord, let anchor = anchors[word.id] {
                    let frame = geo[anchor]
                    if word.isPolysemous {
                        WordDiscriminationPopover(
                            word: word,
                            wordFrame: frame,
                            containerSize: geo.size,
                            keySelection: Binding(
                                get: { viewModel.readingDiscriminationSelection },
                                set: { viewModel.readingDiscriminationSelection = $0 }
                            ),
                            onDismiss: { viewModel.readingSelectedWord = nil }
                        )
                        .id(word.id)
                    } else {
                        WordTooltip(word: word, wordFrame: frame, containerSize: geo.size) {
                            viewModel.readingSelectedWord = nil
                        }
                    }
                }
            }
        }
        .onAppear {
            registerSentencesWithViewModel()
        }
        .onChange(of: page.id) { _ in
            registerSentencesWithViewModel()
        }
        .onChange(of: viewModel.readingPreparedSentenceId) { newValue in
            // When state is cleared (e.g., by ESC) and still hovering, restart timer
            if newValue == nil, let sentence = currentlyHoveredSentence {
                startHoverTimer(for: sentence)
            }
        }
    }

    private func registerSentencesWithViewModel() {
        var allSentences: [(id: UUID, words: [AnnotatedWord])] = []
        for block in filteredContent {
            // Grammar-table blocks don't participate in sentence navigation
            if block.style == "grammar-table" { continue }
            let sentences = getSentences(for: block)
            for sentence in sentences {
                allSentences.append((id: sentence.id, words: sentence.words))
            }
        }
        // Only register if this is the main view (no column filter) or left column
        if column == nil || column == "left" {
            viewModel.readingPageSentences = allSentences
        } else if column == "right" {
            // Append right column sentences
            viewModel.readingPageSentences.append(contentsOf: allSentences)
        }
    }

    @ViewBuilder
    private func contentBlock(_ block: ContentBlock) -> some View {
        switch block.type {
        case .text:
            if block.tableData != nil {
                // Structured grammar table
                GrammarTableView(
                    block: block,
                    selectedWord: Binding(
                        get: { viewModel.readingSelectedWord },
                        set: { viewModel.readingSelectedWord = $0 }
                    )
                )
                .padding(.leading, textIndent(for: block))
                .padding(.vertical, 2)
            } else if !block.words.isEmpty {
                // Render annotated words as tappable elements
                annotatedTextView(words: block.words, block: block)
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
            return 22
        case "grammar-subtitle", "grammar", "grammar-label":
            return 18
        default:
            return 20
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
            currentlyHoveredSentence = sentence
            startHoverTimer(for: sentence)
        } else {
            currentlyHoveredSentence = nil
            hoverTimer?.invalidate()
            hoverTimer = nil
        }
    }

    private func startHoverTimer(for sentence: ReadingSentence) {
        hoverTimer?.invalidate()
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            DispatchQueue.main.async {
                let index = viewModel.readingPageSentences.firstIndex { $0.id == sentence.id } ?? 0
                viewModel.prepareSentence(id: sentence.id, words: sentence.words, index: index)
            }
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
            // Grammar prose: each sentence on its own line
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
            WrappingHStack(alignment: .leading, spacing: 0, lineSpacing: 6) {
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
            .overlay(alignment: .topTrailing) {
                if isPrepared, let label = word.caseLabel {
                    Text(label)
                        .font(.custom("Palatino", size: 9).weight(.semibold))
                        .foregroundColor(Self.caseColor(for: label))
                        .offset(y: -4)
                        .transition(.opacity.combined(with: .scale(scale: 0.3, anchor: .bottomLeading)))
                }
            }
            .animation(.easeOut(duration: 0.3), value: isPrepared)
            .contentShape(Rectangle())
            .anchorPreference(key: WordFrameKey.self, value: .bounds) { anchor in
                hasAnnotation ? [word.id: anchor] : [:]
            }
            .onHover { isHovering in
                handleSentenceHover(isHovering: isHovering, sentence: sentence)
            }
            .onTapGesture {
                if hasAnnotation {
                    selectedWord = word
                }
            }
    }

    private static func caseColor(for label: String) -> Color {
        switch label {
        case "N":  return Color(red: 0.0, green: 0.25, blue: 0.85)  // bold blue — subject
        case "Ac": return Color(red: 0.85, green: 0.4, blue: 0.0)   // bold orange — direct object
        case "G":  return Color(red: 0.55, green: 0.1, blue: 0.7)   // bold purple — possession
        case "D":  return Color(red: 0.0, green: 0.55, blue: 0.55)  // bold teal — indirect object
        case "Ab": return Color(red: 0.8, green: 0.1, blue: 0.15)   // bold red — from/by/with
        case "V":  return Color(red: 0.1, green: 0.6, blue: 0.1)    // bold green — address
        case "Lc": return Color.black.opacity(0.6)                   // dark gray — place
        default:   return Color.black.opacity(0.45)
        }
    }

}

// MARK: - Word Annotation Popover
// Compact popover: word, lemma - gloss, pos + form

// MARK: - Word Frame Preference Key

struct WordFrameKey: PreferenceKey {
    static var defaultValue: [UUID: Anchor<CGRect>] = [:]
    static func reduce(value: inout [UUID: Anchor<CGRect>], nextValue: () -> [UUID: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Custom Word Tooltip

struct WordTooltip: View {
    let word: AnnotatedWord
    let wordFrame: CGRect
    let containerSize: CGSize
    let onDismiss: () -> Void

    @State private var tooltipSize: CGSize = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Header: dictionary citation · part of speech
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                if let citation = word.dictionaryCitation {
                    Text(citation)
                        .font(.custom("Palatino", size: 15).bold())
                        .foregroundColor(.black)
                } else {
                    Text(word.lemma ?? word.text)
                        .font(.custom("Palatino", size: 15).bold())
                        .foregroundColor(.black)
                }
                if let posText = word.expandedPos {
                    Text(" · ")
                        .font(.custom("Palatino", size: 11))
                        .foregroundColor(.black.opacity(0.2))
                    Text(posText)
                        .font(.custom("Palatino", size: 11))
                        .foregroundColor(.black.opacity(0.4))
                }
                if word.irregular {
                    Text(" · ")
                        .font(.custom("Palatino", size: 11))
                        .foregroundColor(.black.opacity(0.2))
                    Text("irreg.")
                        .font(.custom("Palatino", size: 11))
                        .foregroundColor(.black.opacity(0.4))
                }
            }

            // Form + gender
            if let formText = word.expandedForm {
                HStack(spacing: 0) {
                    Text(formText)
                        .font(.custom("Palatino", size: 11))
                        .foregroundColor(.black.opacity(0.4))
                    if let g = word.expandedGender {
                        Text(" \(g)")
                            .font(.custom("Palatino", size: 11))
                            .foregroundColor(.black.opacity(0.4))
                    }
                }
            }

            // Gloss
            if let gloss = word.gloss {
                Text(gloss)
                    .font(.custom("Palatino", size: 13))
                    .foregroundColor(.black.opacity(0.5))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            GeometryReader { geo in
                Color(white: 0.98)
                    .onAppear { tooltipSize = geo.size }
                    .onChange(of: geo.size) { tooltipSize = $0 }
            }
        )
        .cornerRadius(4)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
        .position(
            x: {
                let halfW = tooltipSize.width / 2
                let margin: CGFloat = 4
                let idealX = wordFrame.midX
                // Clamp so tooltip stays within container bounds
                return min(max(idealX, halfW + margin), containerSize.width - halfW - margin)
            }(),
            y: {
                let aboveY = wordFrame.minY - tooltipSize.height / 2 - 4
                if aboveY - tooltipSize.height / 2 < 0 {
                    return wordFrame.maxY + tooltipSize.height / 2 + 4
                }
                return aboveY
            }()
        )
        .onTapGesture {
            onDismiss()
        }
    }
}

// MARK: - Word Discrimination Popover

struct WordDiscriminationPopover: View {
    let word: AnnotatedWord
    let wordFrame: CGRect
    let containerSize: CGSize
    @Binding var keySelection: Int?
    let onDismiss: () -> Void

    @State private var options: [String] = []
    @State private var selectedIndex: Int?
    @State private var isResolved: Bool = false
    @State private var popoverSize: CGSize = .zero

    private var correctGloss: String { word.gloss ?? "" }
    private var pickedCorrectly: Bool {
        guard let idx = selectedIndex, idx < options.count else { return false }
        return options[idx] == correctGloss
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header: citation + POS
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                if let citation = word.dictionaryCitation {
                    Text(citation)
                        .font(.custom("Palatino", size: 15).bold())
                        .foregroundColor(.black)
                } else {
                    Text(word.lemma ?? word.text)
                        .font(.custom("Palatino", size: 15).bold())
                        .foregroundColor(.black)
                }
                if let posText = word.expandedPos {
                    Text(" · ")
                        .font(.custom("Palatino", size: 11))
                        .foregroundColor(.black.opacity(0.2))
                    Text(posText)
                        .font(.custom("Palatino", size: 11))
                        .foregroundColor(.black.opacity(0.4))
                }
                if word.irregular {
                    Text(" · ")
                        .font(.custom("Palatino", size: 11))
                        .foregroundColor(.black.opacity(0.2))
                    Text("irreg.")
                        .font(.custom("Palatino", size: 11))
                        .foregroundColor(.black.opacity(0.4))
                }
            }

            // Options — horizontal flow
            HStack(spacing: 6) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    optionChip(index: index, gloss: option)
                }
            }

            // Post-resolution: word info + explanation
            if isResolved {
                Rectangle()
                    .fill(Color.black.opacity(0.15))
                    .frame(height: 1)
                    .padding(.top, 2)

                HStack(spacing: 0) {
                    if let lemma = word.lemma {
                        Text(lemma)
                            .font(.custom("Palatino", size: 12))
                            .italic()
                            .foregroundColor(.black.opacity(0.6))
                    }
                    if let formText = word.expandedForm {
                        Text(" · \(formText)")
                            .font(.custom("Palatino", size: 11))
                            .foregroundColor(.black.opacity(0.4))
                    }
                }

                if !pickedCorrectly, let explanation = word.explanation {
                    Text(explanation)
                        .font(.custom("Palatino", size: 12))
                        .foregroundColor(.black.opacity(0.5))
                        .italic()
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 280, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .fixedSize()
        .background(
            GeometryReader { geo in
                Color(white: 0.98)
                    .onAppear { popoverSize = geo.size }
                    .onChange(of: geo.size) { popoverSize = $0 }
            }
        )
        .cornerRadius(4)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
        .position(
            x: {
                let halfW = popoverSize.width / 2
                let margin: CGFloat = 4
                let idealX = wordFrame.midX
                return min(max(idealX, halfW + margin), containerSize.width - halfW - margin)
            }(),
            y: {
                // Prefer below the word so the sentence context above stays visible
                let belowY = wordFrame.maxY + popoverSize.height / 2 + 4
                if belowY + popoverSize.height / 2 > containerSize.height {
                    // Fall back to above if no room below
                    return wordFrame.minY - popoverSize.height / 2 - 4
                }
                return belowY
            }()
        )
        .onAppear {
            var allOptions = [correctGloss] + word.alternativeGlosses
            allOptions.shuffle()
            options = allOptions
        }
        .onChange(of: keySelection) { newValue in
            guard let pick = newValue, !isResolved else { return }
            let index = pick - 1
            if index >= 0 && index < options.count {
                resolve(index: index)
            }
            keySelection = nil
        }
        .onTapGesture {
            if isResolved {
                onDismiss()
            }
        }
    }

    @ViewBuilder
    private func optionChip(index: Int, gloss: String) -> some View {
        let isCorrect = gloss == correctGloss
        let isSelected = selectedIndex == index
        let showGreen = isResolved && isCorrect
        let showWrong = isResolved && isSelected && !isCorrect

        HStack(spacing: 3) {
            Text("\(index + 1)")
                .font(.custom("Palatino", size: 11).bold())
                .foregroundColor(showWrong ? .black.opacity(0.2) : .black.opacity(0.4))

            Text(gloss)
                .font(.custom("Palatino", size: 13))
                .strikethrough(showWrong)
                .foregroundColor(showWrong ? .black.opacity(0.3) : .black)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(showGreen ? Color(red: 0, green: 1, blue: 0) : Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(showWrong ? Color.black.opacity(0.3) : Color.black, lineWidth: 1)
        )
        .cornerRadius(3)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isResolved {
                resolve(index: index)
            }
        }
    }

    private func resolve(index: Int) {
        selectedIndex = index
        isResolved = true
    }
}

// MARK: - Wrapping HStack for Flow Layout

struct WrappingHStack: Layout {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = 0
    var lineSpacing: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing, lineSpacing: lineSpacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing, lineSpacing: lineSpacing)

        for (index, subview) in subviews.enumerated() {
            let point = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in containerWidth: CGFloat, subviews: Subviews, spacing: CGFloat, lineSpacing: CGFloat = 0) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                // Check if we need to wrap to next line
                if x + size.width > containerWidth && x > 0 {
                    x = 0
                    y += lineHeight + (lineSpacing > 0 ? lineSpacing : spacing)
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
