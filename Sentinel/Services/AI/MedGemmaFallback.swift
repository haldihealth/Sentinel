import Foundation

struct MedGemmaFallback {
    
    // MARK: - Legacy Logic
    
    /// Generate rule-based clinical response when LLM not available
    /// Uses deterministic logic based on C-SSRS + HealthKit data
    static func generateRuleBasedResponse(record: CheckInRecord, healthData: HealthData?) -> String {
        let deviations = healthData?.deviations
        let hasDeviations = deviations?.hasSignificantDeviation ?? false
        let riskLevel = determineRiskLevel(record: record, hasDeviations: hasDeviations)

        // Build deviation list
        var keyDeviations: [String] = []
        if let d = deviations {
            if let sleep = d.sleepZScore, sleep < -1.5 { keyDeviations.append("sleep") }
            if let hrv = d.hrvZScore, hrv < -1.5 { keyDeviations.append("hrv") }
            if let steps = d.stepsZScore, steps < -1.5 { keyDeviations.append("activity") }
        }

        // Generate properties
        let reasoning = generateReasoning(record: record, healthData: healthData, riskLevel: riskLevel)
        let action = generateAction(riskLevel: riskLevel, keyDeviations: keyDeviations)
        let riskScore = calculateRiskScore(record: record, deviations: deviations)
        let safetyPlanItem = determineSafetyPlanItem(riskLevel: riskLevel)

        // Create struct
        let response = ParsedModelResponse(
            riskTier: riskLevel,
            reasoning: reasoning,
            riskScore: riskScore,
            keyDeviations: keyDeviations,
            safetyPlanItem: safetyPlanItem,
            action: action
        )
        
        // Encode to JSON string
        // Safe encoding prevents JSON syntax errors (newlines, quotes)
        if let data = try? JSONEncoder().encode(response),
           let jsonString = String(data: data, encoding: .utf8) {
            return jsonString
        }
        
        // Emergency backup if encoding fails (should never happen)
        return """
        {
            "risk_tier": "green",
            "risk_score": 0.0,
            "reasoning": "Fallback generation failed.",
            "key_deviations": [],
            "safety_plan_item": 1,
            "action": "Continue monitoring."
        }
        """
    }

    static private func determineRiskLevel(record: CheckInRecord, hasDeviations: Bool) -> String {
        if record.q4Intent == true || record.q5Plan == true || record.q6RecentAttempt == true {
            return "red"
        } else if record.q3ThoughtsWithMethod == true {
            return "orange"
        } else if record.q1WishDead == true || record.q2SuicidalThoughts == true {
            return "yellow"
        } else if hasDeviations {
            return "yellow"
        }
        return "green"
    }

    static private func generateReasoning(record: CheckInRecord, healthData: HealthData?, riskLevel: String) -> String {
        var reasons: [String] = []

        // C-SSRS based reasoning
        if record.q4Intent == true {
            reasons.append("Active suicidal intent reported - immediate safety protocol required")
        } else if record.q5Plan == true {
            reasons.append("Specific suicide plan disclosed - crisis intervention needed")
        } else if record.q6RecentAttempt == true {
            reasons.append("Recent suicide attempt indicates elevated ongoing risk")
        } else if record.q3ThoughtsWithMethod == true {
            reasons.append("Suicidal ideation with method consideration present")
        } else if record.q2SuicidalThoughts == true {
            reasons.append("Active suicidal thoughts reported")
        } else if record.q1WishDead == true {
            reasons.append("Passive death wish indicated")
        }

        // HRV-based reasoning (objective biomarker)
        if let hrv = healthData?.deviations.hrvZScore, hrv < -1.5 {
            reasons.append("HRV shows autonomic dysregulation (z=\(String(format: "%.1f", hrv))), suggesting elevated stress")
        }

        // Sleep-based reasoning
        if let sleep = healthData?.deviations.sleepZScore, sleep < -1.5 {
            reasons.append("Sleep disruption detected (z=\(String(format: "%.1f", sleep))), a known risk factor")
        }

        // Activity-based reasoning
        if let steps = healthData?.deviations.stepsZScore, steps < -1.5 {
            reasons.append("Decreased activity levels may indicate withdrawal or anhedonia")
        }

        if reasons.isEmpty {
            return "No acute risk indicators. Veteran appears stable with consistent baseline metrics."
        }

        return reasons.joined(separator: ". ") + "."
    }

    static private func generateAction(riskLevel: String, keyDeviations: [String]) -> String {
        switch riskLevel {
        case "red":
            return "Contact 988 Veterans Crisis Line immediately. Do not leave veteran alone."
        case "orange":
            return "Activate Safety Plan Item 4 (Professional Contact). Schedule same-day follow-up."
        case "yellow":
            if keyDeviations.contains("hrv") {
                return "Practice 4-7-8 breathing exercise. Consider reaching out to a support contact today."
            } else if keyDeviations.contains("sleep") {
                return "Review sleep hygiene. Limit screen time before bed. Contact support if symptoms persist."
            }
            return "Review Safety Plan. Consider connecting with a trusted support contact."
        default:
            return "Continue daily check-ins. Maintain current wellness routines."
        }
    }

    static private func calculateRiskScore(record: CheckInRecord, deviations: HealthDeviations?) -> Double {
        var score: Double = 0.0

        // C-SSRS weights (primary)
        if record.q5Plan == true { score += 4.0 }
        if record.q4Intent == true { score += 3.5 }
        if record.q6RecentAttempt == true { score += 2.5 }
        if record.q3ThoughtsWithMethod == true { score += 2.0 }
        if record.q2SuicidalThoughts == true { score += 1.5 }
        if record.q1WishDead == true { score += 1.0 }

        // Health deviation weights (secondary)
        if let d = deviations {
            if let hrv = d.hrvZScore, hrv < -2.0 { score += 1.0 }
            else if let hrv = d.hrvZScore, hrv < -1.5 { score += 0.5 }

            if let sleep = d.sleepZScore, sleep < -2.0 { score += 0.75 }
            else if let sleep = d.sleepZScore, sleep < -1.5 { score += 0.5 }

            if let steps = d.stepsZScore, steps < -2.0 { score += 0.5 }
        }

        return min(10.0, max(0.0, score))
    }

    static private func determineSafetyPlanItem(riskLevel: String) -> Int {
        switch riskLevel {
        case "red": return 6     // Emergency services
        case "orange": return 4  // Professional contact
        case "yellow": return 3  // Social contact
        default: return 1        // Warning signs awareness
        }
    }
}
