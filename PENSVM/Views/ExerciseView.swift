import SwiftUI

struct ExerciseView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @FocusState private var focusedGapIndex: Int?
    @FocusState private var isViewFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if let sentence = viewModel.currentSentence {
                SentenceView(
                    sentence: sentence,
                    sentenceIndex: viewModel.currentSentenceIndex,
                    isChecked: viewModel.isChecked,
                    focusedGapIndex: $focusedGapIndex
                )
                .padding()
            }

            Spacer()

            // Footer
            HStack {
                if viewModel.isChecked {
                    Text("Enter: next sentence")
                } else {
                    Text("Tab: next  |  Enter: check  |  ?: reference")
                }
            }
            .foregroundColor(.black)
            .padding()
            .frame(maxWidth: .infinity)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.black),
                alignment: .top
            )
        }
        .focusable(viewModel.isChecked)
        .focusEffectDisabled()
        .focused($isViewFocused)
        .onAppear {
            // Delay focus to ensure view hierarchy is ready (especially on session restore)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if !viewModel.isChecked {
                    focusedGapIndex = 0
                }
            }
        }
        .onChange(of: viewModel.currentSentenceIndex) { _, _ in
            focusedGapIndex = 0
        }
        .onChange(of: viewModel.isChecked) { _, isChecked in
            if isChecked {
                focusedGapIndex = nil
                DispatchQueue.main.async {
                    isViewFocused = true
                }
            } else {
                DispatchQueue.main.async {
                    focusedGapIndex = 0
                }
            }
        }
        .onKeyPress(.tab, phases: .down) { keyPress in
            guard !viewModel.isChecked,
                  let sentence = viewModel.currentSentence else { return .ignored }
            let gapCount = sentence.gaps.count
            guard gapCount > 0 else { return .ignored }

            if keyPress.modifiers.contains(.shift) {
                let current = focusedGapIndex ?? 1
                focusedGapIndex = max(current - 1, 0)
            } else {
                let current = focusedGapIndex ?? -1
                focusedGapIndex = min(current + 1, gapCount - 1)
            }
            return .handled
        }
        .onKeyPress(.return) {
            viewModel.handleEnter()
            return .handled
        }
    }
}

struct SentenceView: View {
    let sentence: Sentence
    let sentenceIndex: Int
    let isChecked: Bool
    var focusedGapIndex: FocusState<Int?>.Binding

    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(spacing: 4) {
                ForEach(Array(sentence.parts.enumerated()), id: \.offset) { partIndex, part in
                    switch part {
                    case .text(let content):
                        Text(content)
                            .font(.custom("Palatino", size: 22))
                            .foregroundColor(.black)

                    case .gap(let gap):
                        GapView(
                            gap: gap,
                            sentenceIndex: sentenceIndex,
                            partIndex: partIndex,
                            gapNumber: gapNumber(for: partIndex),
                            isChecked: isChecked,
                            focusedGapIndex: focusedGapIndex
                        )
                    }
                }
            }
        }
    }

    private func gapNumber(for partIndex: Int) -> Int {
        var count = 0
        for (index, part) in sentence.parts.enumerated() {
            if case .gap = part {
                if index == partIndex {
                    return count
                }
                count += 1
            }
        }
        return 0
    }
}

struct GapView: View {
    let gap: Gap
    let sentenceIndex: Int
    let partIndex: Int
    let gapNumber: Int
    let isChecked: Bool
    var focusedGapIndex: FocusState<Int?>.Binding

    @EnvironmentObject var viewModel: AppViewModel
    @State private var text: String = ""
    @State private var showingDictionary: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            Text(gap.stem)
                .font(.custom("Palatino", size: 22))
                .foregroundColor(.black)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .onTapGesture {
                    if gap.dictionaryForm != nil {
                        showingDictionary = true
                    }
                }
                .popover(isPresented: $showingDictionary, arrowEdge: .bottom) {
                    if let _ = gap.dictionaryForm {
                        Text(dictionaryHeadword(gap: gap))
                            .font(.custom("Palatino", size: 18))
                            .fontWeight(.medium)
                            .padding(8)
                    }
                }

            if isChecked {
                Text(gap.userAnswer ?? "")
                    .font(.custom("Palatino", size: 22))
                    .frame(minWidth: 40)
                    .foregroundColor(gap.isCorrect == true ? .green : .black)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(gap.isCorrect == true ? .green : .black),
                        alignment: .bottom
                    )
                    .overlay(alignment: .topLeading) {
                        if gap.isCorrect == false {
                            let showBelow = gapNumber % 2 == 0
                            VStack(alignment: .leading, spacing: 2) {
                                if !showBelow, let explanation = gap.explanation {
                                    Text(explanation)
                                        .font(.custom("Palatino", size: 14))
                                        .foregroundColor(.gray)
                                        .italic()
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                Text("(\(gap.correctEnding))")
                                    .font(.custom("Palatino", size: 16))
                                    .foregroundColor(.black)
                                if showBelow, let explanation = gap.explanation {
                                    Text(explanation)
                                        .font(.custom("Palatino", size: 14))
                                        .foregroundColor(.gray)
                                        .italic()
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                            }
                            .offset(y: showBelow ? 26 : -52)
                        }
                    }
            } else {
                TextField("", text: $text)
                    .font(.custom("Palatino", size: 22))
                    .textFieldStyle(.plain)
                    .frame(minWidth: 40)
                    .foregroundColor(.black)
                    .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.black),
                    alignment: .bottom
                )
                .focused(focusedGapIndex, equals: gapNumber)
                .onChange(of: text) { _, newValue in
                    viewModel.updateGapAnswer(
                        sentenceIndex: sentenceIndex,
                        partIndex: partIndex,
                        answer: newValue
                    )
                }
                .onAppear {
                    text = gap.userAnswer ?? ""
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    /// Format dictionary headword: "insula, insulae, f." for nouns with data,
    /// falls back to nominative + generic genitive ending for older exercises
    private func dictionaryHeadword(gap: Gap) -> String {
        guard let dictForm = gap.dictionaryForm else { return gap.stem }

        // Full citation if we have genitive and gender
        if let gen = gap.genitiveForm {
            if let g = gap.gender {
                return "\(dictForm), \(gen), \(g)."
            }
            return "\(dictForm), \(gen)"
        }

        // Fallback: generic genitive ending from declension
        if let wt = gap.wordType?.lowercased() {
            let genitiveEndings: [(String, String)] = [
                ("1st decl", "-ae"),
                ("2nd decl", "-ī"),
                ("3rd decl", "-is"),
                ("4th decl", "-ūs"),
                ("5th decl", "-ēī"),
            ]
            for (declPattern, genEnding) in genitiveEndings {
                if wt.contains(declPattern) {
                    return "\(dictForm), \(genEnding)"
                }
            }
        }

        return dictForm
    }
}

// Simple flow layout for wrapping text and gaps
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return (CGSize(width: maxX, height: currentY + lineHeight), positions)
    }
}
