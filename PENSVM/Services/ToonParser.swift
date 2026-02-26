import Foundation

/// TOON (Token-Oriented Object Notation) parser for word annotations
/// Format: words[N]{field1,field2,...}:\nvalue1,value2,...\n...
///
/// Fields:
/// - t: text (word as it appears)
/// - l: lemma (dictionary form, empty if same as text)
/// - g: gloss (English translation)
/// - f: form (abbreviated morphology: "abl.s", "pres.3pl", etc.)
/// - p: part of speech (e.g., "n", "v", "adj")
/// - gn: genitive singular (e.g., "viae", "servī")
/// - gd: gender (e.g., "f", "m", "n")
/// - ir: irregular declension (1 = irregular, empty = regular)
struct ToonParser {

    /// Parse a TOON string into an array of AnnotatedWord
    static func parse(_ toon: String?, glossNotes: [String: String]? = nil) -> [AnnotatedWord] {
        guard let toon = toon, !toon.isEmpty else { return [] }

        let lines = toon.components(separatedBy: "\n")
        guard lines.count > 1 else { return [] }

        // Parse header: words[N]{t,l,g,f}:
        let header = lines[0]
        guard let fields = parseHeader(header) else { return [] }

        // Parse data rows
        var words: [AnnotatedWord] = []
        var wordIndex = 0
        for i in 1..<lines.count {
            let line = lines[i]
            if line.isEmpty { continue }

            let explanation = glossNotes?[String(wordIndex)]
            if let word = parseRow(line, fields: fields, explanation: explanation) {
                words.append(word)
            }
            wordIndex += 1
        }

        return words
    }

    /// Parse header to extract field names
    /// Format: words[N]{t,l,g,f}:
    private static func parseHeader(_ header: String) -> [String]? {
        // Find the fields between { and }
        guard let openBrace = header.firstIndex(of: "{"),
              let closeBrace = header.firstIndex(of: "}") else {
            return nil
        }

        let fieldsStr = header[header.index(after: openBrace)..<closeBrace]
        return fieldsStr.components(separatedBy: ",")
    }

    /// Parse a single CSV row into an AnnotatedWord
    private static func parseRow(_ line: String, fields: [String], explanation: String? = nil) -> AnnotatedWord? {
        let values = parseCSVLine(line)
        guard values.count >= 1 else { return nil }

        var text: String = ""
        var lemma: String?
        var gloss: String?
        var form: String?
        var pos: String?
        var genitiveForm: String?
        var gender: String?
        var irregular: Bool = false
        var alternativeGlosses: [String] = []

        for (index, field) in fields.enumerated() {
            guard index < values.count else { break }
            let value = values[index]

            switch field {
            case "t":
                text = value
            case "l":
                lemma = value.isEmpty ? nil : value
            case "g":
                if value.isEmpty {
                    gloss = nil
                } else if value.contains("|") {
                    let parts = value.components(separatedBy: "|")
                    gloss = parts[0]
                    alternativeGlosses = Array(parts.dropFirst())
                } else {
                    gloss = value
                }
            case "f":
                form = value.isEmpty ? nil : value
            case "p":
                pos = value.isEmpty ? nil : value
            case "gn":
                genitiveForm = value.isEmpty ? nil : value
            case "gd":
                gender = value.isEmpty ? nil : value
            case "ir":
                irregular = value == "1"
            default:
                break
            }
        }

        guard !text.isEmpty else { return nil }

        return AnnotatedWord(
            text: text,
            lemma: lemma,
            gloss: gloss,
            form: form,
            pos: pos,
            genitiveForm: genitiveForm,
            gender: gender,
            irregular: irregular,
            alternativeGlosses: alternativeGlosses,
            explanation: explanation
        )
    }

    /// Parse a CSV line, handling commas and potential escaping
    private static func parseCSVLine(_ line: String) -> [String] {
        var values: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                values.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        values.append(current)

        return values
    }

    // MARK: - Expansion (for display)

    /// Expand abbreviated form to full morphology
    /// e.g., "abl.s" -> "ablative sing."
    static func expandForm(_ form: String?) -> String? {
        guard let form = form, !form.isEmpty else { return nil }

        let parts = form.components(separatedBy: ".")
        var expanded: [String] = []

        for part in parts {
            if let full = abbreviations[part] {
                expanded.append(full)
            } else {
                expanded.append(part)
            }
        }

        return expanded.joined(separator: " ")
    }

    /// Expand abbreviated part of speech
    /// e.g., "v" -> "verb"
    static func expandPos(_ pos: String?) -> String? {
        guard let pos = pos, !pos.isEmpty else { return nil }
        return posAbbreviations[pos] ?? pos
    }

    private static let posAbbreviations: [String: String] = [
        "n": "noun",
        "v": "verb",
        "adj": "adjective",
        "adv": "adverb",
        "prep": "preposition",
        "conj": "conjunction",
        "pron": "pronoun",
        "num": "numeral",
        "interj": "interjection",
        "part": "particle"
    ]

    private static let abbreviations: [String: String] = [
        // Cases
        "nom": "nominative",
        "gen": "genitive",
        "dat": "dative",
        "acc": "accusative",
        "abl": "ablative",
        "voc": "vocative",
        "loc": "locative",

        // Number
        "s": "sing.",
        "pl": "plural",

        // Gender
        "m": "masc.",
        "f": "fem.",
        "n": "neut.",

        // Person + Number (combined for verbs)
        "1s": "1st sing.",
        "2s": "2nd sing.",
        "3s": "3rd sing.",
        "1pl": "1st plural",
        "2pl": "2nd plural",
        "3pl": "3rd plural",

        // Person (standalone)
        "1": "1st",
        "2": "2nd",
        "3": "3rd",

        // Infinitive
        "inf": "infinitive"
    ]
}
