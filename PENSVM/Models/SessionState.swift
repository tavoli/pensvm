import Foundation

/// Captures the user's current session state for persistence across app launches
struct SessionState: Codable {
    // Current view state
    var stateType: String  // "home", "chapterLibrary", "chapterDetail", "reading", "exerciseLibrary", "exercise", "summary"

    // Chapter context
    var selectedChapterNumber: Int?
    var currentPageIndex: Int?

    // Exercise context
    var exerciseChapterNumber: Int?
    var exerciseSequenceNumber: Int?
    var currentSentenceIndex: Int?
    var isChecked: Bool?
    var startTime: Date?
    var gapAnswers: [String: String]?  // Gap ID string -> user answer
}
