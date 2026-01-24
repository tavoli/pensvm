import Foundation

// MARK: - Library Index

struct LibraryIndex: Codable {
    var chapters: [ChapterRef]
}

struct ChapterRef: Codable {
    let number: Int
    let title: String
    let file: String
}

// MARK: - Chapter

struct Chapter: Identifiable, Codable {
    let id: UUID
    let number: Int
    let title: String
    var pages: [Page]
    let importedAt: Date

    init(id: UUID = UUID(), number: Int, title: String, pages: [Page], importedAt: Date = Date()) {
        self.id = id
        self.number = number
        self.title = title
        self.pages = pages
        self.importedAt = importedAt
    }

    var totalPages: Int { pages.count }

    var romanNumeral: String {
        let numerals = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
                       "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX"]
        return number < numerals.count ? numerals[number] : "\(number)"
    }
}

// MARK: - Page

struct Page: Identifiable, Codable {
    let id: UUID
    let index: Int
    let lineStart: Int?
    let lineEnd: Int?
    var content: [ContentBlock]
    var assetPath: String?        // relative path to stored page image (e.g., "assets/06/page-0.png")

    // Dual margin support (new)
    var leftMarginAssetPath: String?   // Left margin (if present)
    var rightMarginAssetPath: String?  // Right margin (if present)

    // Legacy single-margin fields (for backward compatibility)
    var marginAssetPath: String?  // cropped margin strip (e.g., "assets/06/margin-0.png")
    var marginSide: String?       // "left" or "right" - which side the margin appears on

    init(id: UUID = UUID(), index: Int, lineStart: Int? = nil, lineEnd: Int? = nil, content: [ContentBlock], assetPath: String? = nil, leftMarginAssetPath: String? = nil, rightMarginAssetPath: String? = nil, marginAssetPath: String? = nil, marginSide: String? = nil) {
        self.id = id
        self.index = index
        self.lineStart = lineStart
        self.lineEnd = lineEnd
        self.content = content
        self.assetPath = assetPath
        self.leftMarginAssetPath = leftMarginAssetPath
        self.rightMarginAssetPath = rightMarginAssetPath
        self.marginAssetPath = marginAssetPath
        self.marginSide = marginSide
    }

    // Computed properties for backward compatibility
    // If new fields are not set, fall back to legacy fields
    var resolvedLeftMarginAssetPath: String? {
        if leftMarginAssetPath != nil { return leftMarginAssetPath }
        if marginSide == "left" { return marginAssetPath }
        return nil
    }

    var resolvedRightMarginAssetPath: String? {
        if rightMarginAssetPath != nil { return rightMarginAssetPath }
        if marginSide == "right" { return marginAssetPath }
        return nil
    }

    var hasLeftMargin: Bool { resolvedLeftMarginAssetPath != nil }
    var hasRightMargin: Bool { resolvedRightMarginAssetPath != nil }
    var hasBothMargins: Bool { hasLeftMargin && hasRightMargin }
}

// MARK: - Annotated Word (for word-level grammatical annotations)
// Simplified TOON format: t=text, l=lemma, g=gloss, f=form

struct AnnotatedWord: Identifiable {
    let id: UUID
    let text: String              // The word as it appears (e.g., "viā")
    let lemma: String?            // Dictionary form (e.g., "via") - nil if same as text
    let gloss: String?            // English translation (e.g., "road")
    let form: String?             // Abbreviated morphology (e.g., "abl.s")
    let pos: String?              // Part of speech (e.g., "n", "v", "adj")

    init(id: UUID = UUID(), text: String, lemma: String? = nil, gloss: String? = nil, form: String? = nil, pos: String? = nil) {
        self.id = id
        self.text = text
        self.lemma = lemma
        self.gloss = gloss
        self.form = form
        self.pos = pos
    }

    /// Returns true if this word has any grammatical annotations
    var hasAnnotations: Bool {
        lemma != nil || gloss != nil || form != nil || pos != nil
    }

    /// Returns the expanded form for display (e.g., "abl.s" -> "ablative sing.")
    var expandedForm: String? {
        ToonParser.expandForm(form)
    }

    /// Returns expanded part of speech (e.g., "v" -> "verb")
    var expandedPos: String? {
        ToonParser.expandPos(pos)
    }
}

// MARK: - Content Block (text paragraph or inline image)

struct ContentBlock: Identifiable, Codable {
    let id: UUID
    let type: ContentType
    let paragraph: String?       // text content (nil for images)
    let style: String?           // "italic" for quoted text
    let assetPath: String?       // relative path for inline images (e.g., "assets/06/inline-0-0.png")
    let description: String?     // alt text for images
    var column: String?          // "left", "right", or nil (defaults to right for backward compatibility)
    var toon: String?            // TOON format word annotations (parsed on-demand)

    enum ContentType: String, Codable {
        case text
        case image
    }

    // Text content initializer
    init(id: UUID = UUID(), paragraph: String, style: String? = nil, column: String? = nil, toon: String? = nil) {
        self.id = id
        self.type = .text
        self.paragraph = paragraph
        self.style = style
        self.assetPath = nil
        self.description = nil
        self.column = column
        self.toon = toon
    }

    // Image content initializer
    init(id: UUID = UUID(), description: String, assetPath: String, column: String? = nil) {
        self.id = id
        self.type = .image
        self.paragraph = nil
        self.style = nil
        self.assetPath = assetPath
        self.description = description
        self.column = column
        self.toon = nil
    }

    // Full initializer (for decoding)
    init(id: UUID = UUID(), type: ContentType, paragraph: String? = nil, style: String? = nil, assetPath: String? = nil, description: String? = nil, column: String? = nil, toon: String? = nil) {
        self.id = id
        self.type = type
        self.paragraph = paragraph
        self.style = style
        self.assetPath = assetPath
        self.description = description
        self.column = column
        self.toon = toon
    }

    // For backward compatibility, nil column means "right" (default)
    var resolvedColumn: String {
        column ?? "right"
    }

    /// Parse TOON string into AnnotatedWord array (computed on-demand)
    var words: [AnnotatedWord] {
        ToonParser.parse(toon)
    }

    /// Returns true if this block has word-level annotations
    var hasWordAnnotations: Bool {
        guard let toon = toon, !toon.isEmpty else { return false }
        let words = self.words
        return !words.isEmpty && words.contains { $0.hasAnnotations }
    }
}

