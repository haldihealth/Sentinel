import Foundation

/// Type of healthcare provider or contact who can receive clinical reports
///
/// Used by PromptBuilder to tailor SBAR messages for different audiences.
enum RecipientType: String, Codable {
    case primaryCare = "Primary Care Provider"
    case mentalHealth = "Mental Health Provider"
    case emergencyServices = "Emergency Services"
    case caregiver = "Caregiver"
}
