import Foundation

// MARK: - LCSC State (Longitudinal Clinical State Compression)

/// Compressed state summary for maintaining context across check-ins
struct LCSCState: Codable {
    var lastUpdated: Date = Date()
    var checkInCount: Int = 0
    var trajectory: Trajectory = .stable
    var primaryDriver: RiskDriver?
    var lastRiskTier: RiskTier?
    var recentCrisisCount: Int = 0
    var daysSinceLastCrisis: Int?
    
    /// LLM-generated clinical narrative summarizing the last N check-ins
    /// Example: "Subjective mood stable, but objective sleep fragmentation persists. Patient noted 'nightmares' on 1/24. Risk factors shifting from HRV to Sleep."
    var clinicalNarrative: String?

    /// Detected patterns from the most recent risk assessment (for crisis reranking)
    var detectedPatterns: [DetectedPattern]?

    enum Trajectory: String, Codable {
        case stable
        case improving
        case worsening
    }

    enum RiskDriver: String, Codable {
        case sleep
        case activity
        case hrv
        case mood
        case cssrs
        case combined
    }
}
