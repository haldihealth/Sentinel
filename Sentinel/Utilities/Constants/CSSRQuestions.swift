import Foundation

/// Constants container for C-SSRS questions and other app constants
enum CSSRQuestions {
    // MARK: - C-SSRS Screening Questions
    
    static let questions: [String] = [
        "In the past 24 hours, have you wished you were dead or wished you could go to sleep and not wake up?",
        "In the past 24 hours, have you had any actual thoughts of killing yourself?",
        "Have you been thinking about how you might kill yourself?",
        "Have you had these thoughts and had some intention of acting on them?",
        "Have you started to work out or worked out the details of how to kill yourself? Do you intend to carry out this plan?",
        "Have you done anything, started to do anything, or prepared to do anything to end your life?"
    ]
    
    static let badges: [String] = [
        "C-SSRS PROTOCOL",
        "C-SSRS PROTOCOL",
        "METHOD ASSESSMENT",
        "INTENT ASSESSMENT",
        "PLAN ASSESSMENT",
        "BEHAVIOR ASSESSMENT"
    ]
    
    static let subtitles: [String] = [
        "This includes any fleeting thoughts or passive wishes about not being here.",
        "This would include any thoughts you've had about ending your life.",
        "Describe any thoughts or plans you've had regarding specific methods...",
        "Describe any thoughts regarding intent...",
        "Describe any details regarding the plan...",
        "Describe any actions or preparations..."
    ]
    
    // MARK: - Helper Methods
    
    static func question(at index: Int) -> String {
        guard index >= 0 && index < questions.count else {
            return ""
        }
        return questions[index]
    }
    
    static func subtitle(at index: Int) -> String {
        guard index >= 0 && index < subtitles.count else {
            return ""
        }
        return subtitles[index]
    }
    
    static func badge(at index: Int) -> String {
        guard index >= 0 && index < badges.count else {
            return "C-SSRS PROTOCOL"
        }
        return badges[index]
    }
}
