import Foundation

/// Manages C-SSRS questionnaire logic and navigation
///
/// Encapsulates the Columbia Suicide Severity Rating Scale workflow:
/// - Question sequencing (conditional logic based on Q2)
/// - Answer persistence
/// - Risk tier calculation from responses
final class CSSRSManager {
    
    // MARK: - State
    
    private(set) var currentQuestionIndex: Int = 0
    private(set) var answers: [Int: Bool] = [:]
    private var q2WasPositive: Bool = false
    
    // MARK: - Public API
    
    /// Reset to initial state
    func reset() {
        currentQuestionIndex = 0
        answers = [:]
        q2WasPositive = false
    }
    
    /// Get question text for current index
    func getCurrentQuestion() -> String {
        return CSSRQuestions.question(at: currentQuestionIndex)
    }
    
    /// Get badge for current index
    func getCurrentBadge() -> String {
        return CSSRQuestions.badge(at: currentQuestionIndex)
    }
    
    /// Get subtitle for current index
    func getCurrentSubtitle() -> String {
        return CSSRQuestions.subtitle(at: currentQuestionIndex)
    }
    
    /// Submit answer and advance to next question
    /// - Returns: True if more questions remain, false if complete
    func submitAnswer(_ answer: Bool) -> Bool {
        // Store answer
        answers[currentQuestionIndex] = answer
        
        // Track Q2 for conditional logic
        if currentQuestionIndex == 1 {
            q2WasPositive = answer
        }
        
        // Determine next question based on C-SSRS logic tree
        switch currentQuestionIndex {
        case 0: currentQuestionIndex = 1
        case 1: currentQuestionIndex = q2WasPositive ? 2 : 5
        case 2: currentQuestionIndex = 3
        case 3: currentQuestionIndex = 4
        case 4: currentQuestionIndex = 5
        case 5: return false // Complete
        default: return false
        }
        
        return true
    }
    
    /// Go back to previous question
    func goBack() {
        guard currentQuestionIndex > 0 else { return }
        
        if currentQuestionIndex == 5 {
            currentQuestionIndex = q2WasPositive ? 4 : 1
        } else {
            currentQuestionIndex -= 1
        }
    }
    
    /// Calculate risk tier based on all answers
    /// - Returns: RiskTier based on C-SSRS responses
    func calculateRiskTier() -> RiskTier {
        let q1 = answers[0] ?? false
        let q2 = answers[1] ?? false
        let q3 = answers[2] ?? false
        let q4 = answers[3] ?? false
        let q5 = answers[4] ?? false
        let q6 = answers[5] ?? false
        
        // RED: Q4 (Intent), Q5 (Plan), or Q6 (Recent Attempt)
        if q4 || q5 || q6 {
            return .crisis
        }
        
        // ORANGE: Q3 (Thoughts with Method)
        if q3 {
            return .highMonitoring
        }
        
        // YELLOW: Q1 (Wish Dead) or Q2 (Suicidal Thoughts)
        if q1 || q2 {
            return .moderate
        }
        
        // GREEN: All negative
        return .low
    }
    
    /// Apply answers to a CheckInRecord
    func applyAnswers(to record: CheckInRecord) {
        record.q1WishDead = answers[0] ?? false
        record.q2SuicidalThoughts = answers[1] ?? false
        record.q3ThoughtsWithMethod = answers[2] ?? false
        record.q4Intent = answers[3] ?? false
        record.q5Plan = answers[4] ?? false
        record.q6RecentAttempt = answers[5] ?? false
    }
}
