import Foundation

/// Identifies the primary driver of clinical risk.
struct RiskDriverIdentifier {
    
    /// Identifies the primary contributor to risk using deterministic logic
    /// - Parameters:
    ///   - record: The current check-in record
    ///   - health: Current health data
    /// - Returns: The identified primary risk driver
    static func identify(
        record: CheckInRecord,
        health: HealthData?
    ) -> LCSCState.RiskDriver {

        // Priority 1: C-SSRS Safety Signals (Safety First)
        // Any affirmative response to high-risk C-SSRS questions takes precedence
        if (record.q4Intent ?? false) || (record.q5Plan ?? false) || (record.q6RecentAttempt ?? false) {
            return .cssrs
        }

        // Also flag C-SSRS for moderate signals
        if (record.q2SuicidalThoughts ?? false) || (record.q3ThoughtsWithMethod ?? false) {
            return .cssrs
        }

        // Priority 2: Physiological Deviations (HealthKit)
        // Use z-scores to detect significant deviations from baseline
        if let deviations = health?.deviations {
            let deviationChecks: [(score: Double?, driver: LCSCState.RiskDriver, threshold: Double)] = [
                // Severe deviations (z < -2.0) - highest priority
                (deviations.sleepZScore, .sleep, -2.0),      // Sleep: earliest indicator of mental health changes
                (deviations.hrvZScore, .hrv, -2.0),          // HRV: autonomic nervous system dysregulation
                (deviations.stepsZScore, .activity, -2.0),   // Activity: withdrawal or anhedonia
                // Moderate deviations (z < -1.5) - secondary signals
                (deviations.sleepZScore, .sleep, -1.5),
                (deviations.hrvZScore, .hrv, -1.5),
                (deviations.stepsZScore, .activity, -1.5)
            ]

            for check in deviationChecks {
                if let score = check.score, score < check.threshold {
                    return check.driver
                }
            }
        }

        // Priority 3: Passive death wish (Q1) - lower priority C-SSRS signal
        if record.q1WishDead ?? false {
            return .mood
        }

        // No clear single driver - combined/baseline state
        return .combined
    }
}
