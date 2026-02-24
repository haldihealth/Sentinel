import Foundation

/// Centralized risk calculation logic for all C-SSRS assessments
///
/// Single source of truth for determining risk tiers from C-SSRS responses.
/// Consolidates duplicate logic from CheckInViewModel, PromptBuilder, and fallback handlers.
struct RiskCalculator {
    
    // MARK: - Primary Risk Calculation
    
    /// Calculate risk tier from C-SSRS responses (Deterministic)
    /// - Parameters:
    ///   - record: CheckInRecord with C-SSRS answers
    /// - Returns: Calculated RiskTier
    static func calculateRiskTier(from record: CheckInRecord) -> RiskTier {
        // TIER 1: CRISIS (RED) - Immediate Safety Concern
        // Q4 (Intent) or Q5 (Plan) = automatic crisis tier
        if record.q4Intent == true || record.q5Plan == true {
            return .crisis
        }
        
        // TIER 2: HIGH MONITORING (ORANGE)
        // Q6 (Recent Attempt) triggers high monitoring
        if record.q6RecentAttempt == true {
            return .highMonitoring
        }
        
        // TIER 3: MODERATE (YELLOW)
        // Q3 (Method), Q2 (Thoughts), or Q1 (Wish Dead)
        if record.q3ThoughtsWithMethod == true || 
           record.q2SuicidalThoughts == true || 
           record.q1WishDead == true {
            return .moderate
        }
        
        // TIER 4: LOW (GREEN) - Base Case
        return .low
    }
    
    // MARK: - MAX Risk Selection
    


    /// Determines final risk tier, source, and explanation
    /// - Parameters:
    ///   - cssrsRisk: risk from CSSR
    ///   - aiRisk: risk from AI
    ///   - aiExplanation: explanation from AI (if any)
    /// - Returns: Tuple of (finalTier, source, explanation)
    static func determineRiskSource(
        cssrsRisk: RiskTier,
        aiRisk: RiskTier,
        aiExplanation: String?
    ) -> (tier: RiskTier, source: String, explanation: String) {
        if cssrsRisk >= aiRisk {
            // CSSR is the dominant factor (or equal, so we default to CSSR explanation)
            return (cssrsRisk, "CSSR", "This was the minimum risk tier based on Columbia screening questions.")
        } else {
            // AI is pushing the risk higher
            let explanation = aiExplanation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "MedGemma identified elevated risk factors."
            // Ensure explanation is concise (1-2 sentences)
            // Implementation note: The prompt already asks for 1 sentence. Use as is.
            return (aiRisk, "MedGemma", explanation)
        }
    }
    
    // MARK: - Compact C-SSRS Summary
    
    /// Creates a compact string summary of C-SSRS responses for logging/prompts
    /// - Parameter record: CheckInRecord with C-SSRS answers
    /// - Returns: Comma-separated list of positive responses (e.g., "Q1+, Q3+")
    static func buildCompactCSSRS(_ record: CheckInRecord) -> String {
        var flags: [String] = []
        if record.q1WishDead == true { flags.append("Q1+") }
        if record.q2SuicidalThoughts == true { flags.append("Q2+") }
        if record.q3ThoughtsWithMethod == true { flags.append("Q3+") }
        if record.q4Intent == true { flags.append("Q4+CRISIS") }
        if record.q5Plan == true { flags.append("Q5+CRISIS") }
        if record.q6RecentAttempt == true { flags.append("Q6+") }
        return flags.isEmpty ? "All negative" : flags.joined(separator: ", ")
    }
}
