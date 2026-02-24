import Foundation

/// Calculates clinical trajectory based on risk tier progression.
struct TrajectoryCalculator {
    
    /// Calculates the trajectory based on risk tier changes
    /// - Parameters:
    ///   - previousRisk: The risk tier from the previous check-in
    ///   - newRisk: The risk tier from the current check-in
    /// - Returns: Updated trajectory (stable/improving/worsening)
    static func calculate(
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
}
