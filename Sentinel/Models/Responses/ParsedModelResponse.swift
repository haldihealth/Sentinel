import Foundation

/// Parsed response format for JSON output from MedGemma
///
/// Used by both MedGemmaParser and MedGemmaFallback to ensure
/// consistent encoding/decoding of model responses.
struct ParsedModelResponse: Codable {
    let riskTier: String
    let reasoning: String

    // Optional fields for backwards compatibility with full schema
    let riskScore: Double?
    let keyDeviations: [String]?
    let safetyPlanItem: Int?
    let action: String?

    init(
        riskTier: String,
        reasoning: String,
        riskScore: Double? = nil,
        keyDeviations: [String]? = nil,
        safetyPlanItem: Int? = nil,
        action: String? = nil
    ) {
        self.riskTier = riskTier
        self.reasoning = reasoning
        self.riskScore = riskScore
        self.keyDeviations = keyDeviations
        self.safetyPlanItem = safetyPlanItem
        self.action = action
    }
}
