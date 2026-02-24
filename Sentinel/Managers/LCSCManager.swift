import Foundation
import Combine
import os.log

/// Manages Longitudinal Clinical State Compression (LCSC)
///
/// This manager shifts the AI from "Amnesic" (treating every check-in like the first time)
/// to "Context-Aware" (understanding trends and trajectories).
///
/// Calculates trajectory and risk drivers based on historical comparisons,
/// enabling on-device models with small context windows to maintain
/// longitudinal awareness without feeding 30+ days of raw logs.
struct LCSCManager {

    // MARK: - State Update

    /// Updates the LCSC state based on new check-in data
    /// - Parameters:
    ///   - currentState: The previous LCSC state (nil for first check-in)
    ///   - newRecord: The current check-in record
    ///   - newHealth: Current health data from HealthKit
    ///   - newRisk: The assessed risk tier from this check-in
    /// - Returns: Updated LCSC state for persistence
    static func updateState(
        currentState: LCSCState?,
        newRecord: CheckInRecord,
        newHealth: HealthData?,
        newRisk: RiskTier
    ) -> LCSCState {

        var state = currentState ?? LCSCState()

        // 1. Update basic counters
        state.checkInCount += 1
        state.lastUpdated = Date()

        // 2. Determine Trajectory
        // Compare new risk to the last recorded risk
        state.trajectory = calculateTrajectory(
            previousRisk: state.lastRiskTier,
            newRisk: newRisk
        )
        state.lastRiskTier = newRisk

        // 3. Identify Primary Risk Driver
        // What is the "loudest" signal today?
        state.primaryDriver = identifyDriver(record: newRecord, health: newHealth)

        // 4. Crisis Tracking
        if newRisk == .crisis {
            state.recentCrisisCount += 1
            state.daysSinceLastCrisis = 0
        } else if let days = state.daysSinceLastCrisis, let previousUpdate = currentState?.lastUpdated {
            // Calculate actual days passed since last update for accuracy
            let daysPassed = Calendar.current.dateComponents([.day], from: previousUpdate, to: state.lastUpdated).day ?? 0
            state.daysSinceLastCrisis = days + daysPassed
        }

        return state
    }

    // MARK: - Trajectory Calculation

    /// Calculates the trajectory based on risk tier changes
    /// - Parameters:
    ///   - previousRisk: The risk tier from the previous check-in
    ///   - newRisk: The risk tier from the current check-in
    /// - Returns: Updated trajectory (stable/improving/worsening)
    private static func calculateTrajectory(
        previousRisk: RiskTier?,
        newRisk: RiskTier
    ) -> LCSCState.Trajectory {

        guard let lastRisk = previousRisk else {
            // First check-in - no trajectory yet
            return .stable
        }

        // Compare risk tier raw values (0=low, 1=moderate, 2=highMonitoring, 3=crisis)
        if newRisk.rawValue > lastRisk.rawValue {
            return .worsening
        } else if newRisk.rawValue < lastRisk.rawValue {
            return .improving
        } else {
            // Same risk level - maintain current trajectory with dampening toward stable
            // This prevents flip-flopping: if we were improving and stayed same, we're stable now
            return .stable
        }
    }

    // MARK: - Driver Identification

    /// Identifies the primary contributor to risk using deterministic logic
    /// This is "safe" because it uses rules, not LLM guessing
    /// - Parameters:
    ///   - record: The current check-in record
    ///   - health: Current health data
    /// - Returns: The identified primary risk driver
    private static func identifyDriver(
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
        // Checks are ordered by threshold (severe first) and by clinical priority (sleep > HRV > activity)
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

    // MARK: - State Formatting

    /// Formats the LCSC state as a compact context string for prompts
    /// - Parameter state: The current LCSC state
    /// - Returns: A formatted string suitable for inclusion in AI prompts
    static func formatForPrompt(_ state: LCSCState?) -> String {
        guard let state = state else {
            return "No prior history."
        }

        var lines: [String] = []

        // Include any LLM-generated narrative first for richer context
        if let narrative = state.clinicalNarrative, !narrative.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("CLINICAL NARRATIVE: \(narrative)")
        }

        // Core trajectory info
        lines.append("- Trajectory: \(state.trajectory.rawValue.uppercased())")

        // Primary driver (what's causing changes)
        if let driver = state.primaryDriver {
            lines.append("- Primary Driver: \(driver.rawValue)")
        }

        // Last assessed risk
        if let lastRisk = state.lastRiskTier {
            lines.append("- Last Risk: \(lastRisk.displayName)")
        }

        // Check-in count for context
        lines.append("- Check-ins: \(state.checkInCount)")

        // Crisis tracking (important safety context)
        if state.recentCrisisCount > 0 {
            lines.append("- Recent Crises: \(state.recentCrisisCount)")
        }
        if let days = state.daysSinceLastCrisis {
            lines.append("- Days Since Crisis: \(days)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Risk Modifiers

    /// Calculates risk modifiers based on longitudinal patterns
    /// Use this to adjust vigilance levels based on trajectory
    /// - Parameter state: The current LCSC state
    /// - Returns: A tuple of (shouldIncreaseVigilance, reason)
    static func getRiskModifiers(_ state: LCSCState?) -> (shouldIncreaseVigilance: Bool, reason: String?) {
        guard let state = state else {
            return (false, nil)
        }

        // Worsening trajectory requires increased vigilance
        if state.trajectory == .worsening {
            return (true, "Trajectory is worsening")
        }

        // Multiple recent crises indicate elevated baseline risk
        if state.recentCrisisCount >= 2 {
            return (true, "Multiple recent crisis events (\(state.recentCrisisCount))")
        }

        // Recent crisis (within last few days) maintains elevated vigilance
        if let days = state.daysSinceLastCrisis, days <= 7 {
            return (true, "Recent crisis \(days) days ago")
        }

        return (false, nil)
    }

    // MARK: - State Reset

    /// Creates a fresh LCSC state (use when user requests reset or after extended absence)
    /// - Returns: A new blank LCSC state
    static func createFreshState() -> LCSCState {
        return LCSCState()
    }

    /// Determines if the state should be reset (e.g., after extended absence)
    /// - Parameter state: The current LCSC state
    /// - Returns: True if state is stale and should be reset
    static func shouldResetState(_ state: LCSCState?) -> Bool {
        guard let state = state else {
            return false // No state to reset
        }

        // If more than 30 days since last update, consider state stale
        let daysSinceUpdate = Calendar.current.dateComponents(
            [.day],
            from: state.lastUpdated,
            to: Date()
        ).day ?? 0

        return daysSinceUpdate > 30
    }

    // MARK: - Narrative Update

    /// Updates the longitudinal narrative using MedGemma and persists it
    @MainActor
    static func updateNarrative(record: CheckInRecord, health: HealthData?, risk: RiskTier, storage: LocalStorage = LocalStorage()) async {
        let oldState = storage.loadLCSCState() ?? createFreshState()

        let updatedState = await MedGemmaEngine.shared.updateLongitudinalContext(
            currentState: oldState,
            record: record,
            health: health,
            riskTier: risk
        )

        storage.saveLCSCState(updatedState)
    }
}
