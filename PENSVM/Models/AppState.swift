import Foundation

enum AppState: Equatable {
    case home              // Landing screen
    case chapterLibrary    // List of all chapters
    case chapterDetail     // Single chapter with Read/Exercises options
    case reading           // Display chapter pages
    case exerciseLibrary   // List exercises (filtered by chapter when selected)
    case loading           // Processing state
    case exercise          // Main practice interface
    case summary           // Results screen
    case error(String)     // Error state

    static func == (lhs: AppState, rhs: AppState) -> Bool {
        switch (lhs, rhs) {
        case (.home, .home),
             (.chapterLibrary, .chapterLibrary),
             (.chapterDetail, .chapterDetail),
             (.reading, .reading),
             (.exerciseLibrary, .exerciseLibrary),
             (.loading, .loading),
             (.exercise, .exercise),
             (.summary, .summary):
            return true
        case (.error(let lhsMsg), .error(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}
