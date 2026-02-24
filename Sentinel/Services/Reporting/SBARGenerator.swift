import Foundation

/// Generates SBAR (Situation, Background, Assessment, Recommendation) reports
///
/// Extracted from MedGemmaEngine to be reusable across the app.
/// Provides template-based clinical reporting when LLM is unavailable.
struct SBARGenerator {
    
    /// Generate a template-based SBAR report
    /// - Parameters:
    ///   - record: CheckInRecord with C-SSRS data
    ///   - healthData: Current health metrics
    ///   - profile: User profile information
    ///   - riskTier: Calculated risk tier
    ///   - recipient: Target recipient (primary care, mental health, etc.)
    /// - Returns: Formatted SBAR report string
    static func generate(
        record: CheckInRecord?,
        healthData: HealthData?,
        profile: UserProfile?,
        riskTier: RiskTier,
        recipient: RecipientType = .primaryCare
    ) -> String {
        let name = profile?.preferredName ?? "Veteran"
        let date = Date().formatted(date: .abbreviated, time: .shortened)
        
        // SITUATION: Current risk state
        let situation = buildSituation(name: name, riskTier: riskTier)
        
        // BACKGROUND: Data summary
        let background = buildBackground(record: record, healthData: healthData, date: date)
        
        // ASSESSMENT: Clinical interpretation
        let assessment = buildAssessment(riskTier: riskTier)
        
        // RECOMMENDATION: Next steps
        let recommendation = buildRecommendation(riskTier: riskTier, recipient: recipient)
        
        return """
        SITUATION:
        \(situation)
        
        BACKGROUND:
        \(background)
        
        ASSESSMENT:
        \(assessment)
        
        RECOMMENDATION:
        \(recommendation)
        """
    }
    
    // MARK: - SBAR Component Builders
    
    private static func buildSituation(name: String, riskTier: RiskTier) -> String {
        switch riskTier {
        case .crisis:
            return "Patient \(name) is presenting with CRISIS-level risk indicators requiring immediate intervention."
        case .highMonitoring:
            return "Patient \(name) is presenting with HIGH MONITORING risk indicators requiring close follow-up."
        case .moderate:
            return "Patient \(name) is presenting with ELEVATED risk indicators warranting clinical attention."
        case .low:
            return "Patient \(name) completed routine wellness check-in with stable indicators."
        }
    }
    
    private static func buildBackground(
        record: CheckInRecord?,
        healthData: HealthData?,
        date: String
    ) -> String {
        var items: [String] = []
        items.append("Check-in completed: \(date)")
        
        // C-SSRS data
        if let record = record {
            let cssrsItems: [(Bool?, String)] = [
                (record.q1WishDead, "• Reports passive death wish"),
                (record.q2SuicidalThoughts, "• Reports suicidal thoughts"),
                (record.q3ThoughtsWithMethod, "• Reports thoughts with method consideration"),
                (record.q4Intent, "• Reports active suicidal intent"),
                (record.q5Plan, "• Reports specific suicide plan"),
                (record.q6RecentAttempt, "• Reports recent suicide attempt")
            ]
            items += cssrsItems.compactMap { $0.0 == true ? $0.1 : nil }
        }
        
        // Health data
        if let health = healthData {
            let sleepFormatted = health.sleep.totalSleepHours.formatted(asHealthMetric: "hr")
            items.append("• Sleep: \(sleepFormatted)")
            
            let stepsFormatted = Double(health.activity.stepCount).formatted(asHealthMetric: "steps")
            items.append("• Steps: \(stepsFormatted)")
            
            let hrvFormatted = health.hrv.sdnn.formatted(asHealthMetric: "ms", decimals: 0)
            items.append("• HRV: \(hrvFormatted)")
            
            // Deviations
            if let sleepZ = health.deviations.sleepZScore, sleepZ.magnitude > 1.5 {
                items.append("• Sleep deviation: \(sleepZ.formatted(asZScore: 1))")
            }
            if let hrvZ = health.deviations.hrvZScore, hrvZ.magnitude > 1.5 {
                items.append("• HRV deviation: \(hrvZ.formatted(asZScore: 1))")
            }
            if let stepsZ = health.deviations.stepsZScore, stepsZ.magnitude > 1.5 {
                items.append("• Activity deviation: \(stepsZ.formatted(asZScore: 1))")
            }
        }
        
        return items.isEmpty ? "No additional data available." : items.joined(separator: "\n")
    }
    
    private static func buildAssessment(riskTier: RiskTier) -> String {
        switch riskTier {
        case .crisis:
            return "Clinical assessment indicates immediate safety concerns. Active suicidal ideation with intent or plan reported."
        case .highMonitoring:
            return "Clinical assessment indicates significant risk factors. Enhanced monitoring and follow-up recommended."
        case .moderate:
            return "Clinical assessment indicates mild-to-moderate distress. Patient may benefit from supportive intervention."
        case .low:
            return "Clinical assessment indicates stable mental health status. No acute concerns identified."
        }
    }
    
    private static func buildRecommendation(riskTier: RiskTier, recipient: RecipientType) -> String {
        let recipientName = recipient.rawValue
        
        switch riskTier {
        case .crisis:
            return "Requesting URGENT follow-up with \(recipientName). Patient has been advised to contact 988 Veterans Crisis Line."
        case .highMonitoring:
            return "Requesting priority follow-up with \(recipientName) within 24-48 hours to reassess risk and adjust care plan."
        case .moderate:
            return "Requesting routine follow-up with \(recipientName) at next available appointment to discuss current stressors."
        case .low:
            return "No immediate action required. Recommend continued routine monitoring."
        }
    }
}
