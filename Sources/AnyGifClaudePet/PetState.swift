import Foundation

/// All possible states for the desktop pet.
enum PetState: String, CaseIterable {
    case idle
    case thinking
    case working
    case happy
    case sad
    case celebrating
    case sleeping

    /// States that auto-return to idle after a delay.
    var autoReturnDelay: TimeInterval? {
        switch self {
        case .happy, .sad, .celebrating:
            return 3.0
        default:
            return nil
        }
    }
}
