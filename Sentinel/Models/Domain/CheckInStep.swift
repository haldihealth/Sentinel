import Foundation

/// Represents the current step in the Daily Check-In flow
enum CheckInStep: Equatable, Sendable {
    /// Multimodal recording (camera + audio)
    case multimodal
    
    /// C-SSRS questionnaire at specific question index
    case cssrs(questionIndex: Int)
}
