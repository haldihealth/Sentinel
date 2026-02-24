import Foundation

/// Manages risk assessment calculations and baselines
///
/// Calculates risk tiers based on check-in data and health metrics.
actor RiskAssessmentManager {


    func getCurrentRiskTier(checkIns: [CheckInRecord]) -> RiskTier {
        // Find most recent check-in with a risk tier (O(n) vs O(n log n) for sorted)
        guard let lastRecord = checkIns.max(by: { $0.timestamp < $1.timestamp }),
              let riskString = lastRecord.determinedRiskTier else {
            return .low
        }

        // Try parsing as rawValue (stored as "0", "1", "2", "3")
        if let index = Int(riskString),
           let tier = RiskTier(rawValue: index) {
            return tier
        }

        // Try parsing as color name ("green", "yellow", "orange", "red")
        if let tier = RiskTier.from(string: riskString) {
            return tier
        }

        return .low
    }
}
