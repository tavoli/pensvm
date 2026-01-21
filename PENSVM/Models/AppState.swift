import Foundation

enum AppState: Equatable {
    case dropZone
    case loading
    case exercise
    case summary
    case error(String)

    static func == (lhs: AppState, rhs: AppState) -> Bool {
        switch (lhs, rhs) {
        case (.dropZone, .dropZone),
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
