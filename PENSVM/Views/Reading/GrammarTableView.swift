import SwiftUI

struct GrammarTableView: View {
    let block: ContentBlock
    @Binding var selectedWord: AnnotatedWord?

    private let fontSize: CGFloat = 16
    private let columnSpacing: CGFloat = 12
    private let rowSpacing: CGFloat = 4

    private var resolved: ResolvedTable {
        ResolvedTable(tableData: block.tableData!, words: block.words)
    }

    var body: some View {
        let table = resolved
        Grid(alignment: .leading, horizontalSpacing: columnSpacing, verticalSpacing: rowSpacing) {
            if !table.headers.isEmpty {
                headerRow(table)
            }
            ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                dataRow(row)
            }
        }
    }

    // MARK: - Header Row

    @ViewBuilder
    private func headerRow(_ table: ResolvedTable) -> some View {
        GridRow {
            Text("")
                .gridColumnAlignment(.trailing)

            if let paradigms = table.paradigms, paradigms.count * 2 == table.headers.count {
                ForEach(Array(table.headers.enumerated()), id: \.offset) { idx, header in
                    VStack(alignment: .leading, spacing: 0) {
                        if idx % 2 == 0 && idx / 2 < paradigms.count {
                            Text(paradigms[idx / 2])
                                .font(.custom("Palatino", size: 12).bold())
                                .foregroundColor(.black.opacity(0.5))
                        }
                        Text(header)
                            .font(.custom("Palatino", size: fontSize).italic())
                            .foregroundColor(.black.opacity(0.8))
                    }
                }
            } else {
                ForEach(Array(table.headers.enumerated()), id: \.offset) { _, header in
                    Text(header)
                        .font(.custom("Palatino", size: fontSize).italic())
                        .foregroundColor(.black.opacity(0.8))
                }
            }
        }
    }

    // MARK: - Data Row

    @ViewBuilder
    private func dataRow(_ row: ResolvedRow) -> some View {
        GridRow {
            HStack(spacing: 2) {
                if let prefix = row.numberPrefix {
                    Text(prefix)
                        .font(.custom("Palatino", size: fontSize).italic())
                        .foregroundColor(.black.opacity(0.6))
                }
                Text(row.label)
                    .font(.custom("Palatino", size: fontSize).italic())
                    .foregroundColor(.black.opacity(0.8))
            }
            .gridColumnAlignment(.trailing)

            ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cellWords in
                cellView(cellWords)
            }
        }
    }

    // MARK: - Cell View

    @ViewBuilder
    private func cellView(_ words: [CellWord]) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(words.enumerated()), id: \.offset) { idx, word in
                if idx > 0 {
                    Text(" ")
                        .font(.custom("Palatino", size: fontSize))
                }
                wordView(word)
            }
        }
    }

    @ViewBuilder
    private func wordView(_ word: CellWord) -> some View {
        let hasAnnotation = word.annotation?.hasAnnotations ?? false

        if let ending = word.ending {
            (Text(word.stem)
                .font(.custom("Palatino", size: fontSize))
                .foregroundColor(.black.opacity(0.8))
            + Text(ending)
                .font(.custom("Palatino", size: fontSize).bold())
                .foregroundColor(.black.opacity(0.8))
            )
            .contentShape(Rectangle())
            .anchorPreference(key: WordFrameKey.self, value: .bounds) { anchor in
                if let annotation = word.annotation, hasAnnotation {
                    return [annotation.id: anchor]
                }
                return [:]
            }
            .onTapGesture {
                if hasAnnotation, let annotation = word.annotation {
                    selectedWord = annotation
                }
            }
        } else {
            Text(word.stem)
                .font(.custom("Palatino", size: fontSize))
                .foregroundColor(.black.opacity(0.8))
                .contentShape(Rectangle())
                .anchorPreference(key: WordFrameKey.self, value: .bounds) { anchor in
                    if let annotation = word.annotation, hasAnnotation {
                        return [annotation.id: anchor]
                    }
                    return [:]
                }
                .onTapGesture {
                    if hasAnnotation, let annotation = word.annotation {
                        selectedWord = annotation
                    }
                }
        }
    }
}

// MARK: - Resolved Table Types (private to this file)

private struct CellWord {
    let stem: String
    let ending: String?
    let annotation: AnnotatedWord?
}

private struct ResolvedRow {
    let label: String
    let numberPrefix: String?
    let cells: [[CellWord]]
}

private struct ResolvedTable {
    let headers: [String]
    let paradigms: [String]?
    let rows: [ResolvedRow]

    init(tableData: GrammarTableData, words: [AnnotatedWord]) {
        self.headers = tableData.headers
        self.paradigms = tableData.paradigms

        var cursor = 0

        func normalize(_ s: String) -> String {
            var t = s
            if (t.hasPrefix("'") && t.hasSuffix("'")) || (t.hasPrefix("\u{2018}") && t.hasSuffix("\u{2019}")) {
                t = String(t.dropFirst().dropLast())
            }
            return t
        }

        func tryMatch(_ text: String) -> AnnotatedWord? {
            let clean = text.replacingOccurrences(of: "|", with: "")
            guard cursor < words.count else { return nil }
            let wordText = words[cursor].text.replacingOccurrences(of: "|", with: "")
            if normalize(wordText) == normalize(clean) {
                let matched = words[cursor]
                cursor += 1
                return matched
            }
            return nil
        }

        // Match headers
        for header in tableData.headers {
            _ = tryMatch(header)
        }

        // Match rows
        let paradigmList = tableData.paradigms ?? []
        let colsPerParadigm = paradigmList.isEmpty ? 0 : (tableData.rows.first?.cells.count ?? 0) / max(paradigmList.count, 1)

        var resolvedRows: [ResolvedRow] = []
        for (rowIdx, row) in tableData.rows.enumerated() {
            if let prefix = row.numberPrefix {
                _ = tryMatch(prefix)
            }
            _ = tryMatch(row.label)

            var resolvedCells: [[CellWord]] = []
            for (colIdx, cellStrings) in row.cells.enumerated() {
                // Paradigm marker in first row only, before first cell of each group
                if rowIdx == 0 && !paradigmList.isEmpty && colsPerParadigm > 0 {
                    if colIdx % colsPerParadigm == 0 {
                        let paradigmIdx = colIdx / colsPerParadigm
                        if paradigmIdx < paradigmList.count {
                            _ = tryMatch(paradigmList[paradigmIdx])
                        }
                    }
                }

                var cellWords: [CellWord] = []
                for word in cellStrings {
                    let annotation = tryMatch(word)
                    if let pipeIdx = word.firstIndex(of: "|") {
                        let stem = String(word[..<pipeIdx])
                        let ending = String(word[word.index(after: pipeIdx)...])
                        cellWords.append(CellWord(stem: stem, ending: ending.isEmpty ? nil : ending, annotation: annotation))
                    } else {
                        cellWords.append(CellWord(stem: word, ending: nil, annotation: annotation))
                    }
                }
                resolvedCells.append(cellWords)
            }

            resolvedRows.append(ResolvedRow(label: row.label, numberPrefix: row.numberPrefix, cells: resolvedCells))
        }

        self.rows = resolvedRows
    }
}
