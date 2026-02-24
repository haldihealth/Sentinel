import Foundation

/// Rolling baseline metrics for deviation detection
///
/// Maintains 30-day rolling averages for health metrics to detect
/// significant deviations that may indicate mental health changes.
struct Baseline: Codable, Sendable {
    // MARK: - Properties

    var lastUpdated: Date

    // MARK: - Sleep Baseline

    /// 30-day average sleep duration in hours
    var avgSleepHours: Double?

    /// Standard deviation of sleep hours
    var sleepStdDev: Double?

    // MARK: - Activity Baseline

    /// 30-day average daily steps
    var avgSteps: Double?

    /// Standard deviation of steps
    var stepsStdDev: Double?

    // MARK: - HRV Baseline

    /// 30-day average HRV (SDNN in ms)
    var avgHRV: Double?

    /// Standard deviation of HRV
    var hrvStdDev: Double?

    // MARK: - Mood Baseline

    /// 30-day average mood score
    var avgMoodScore: Double?

    /// Standard deviation of mood
    var moodStdDev: Double?

    // MARK: - Initialization

    init(lastUpdated: Date = Date()) {
        self.lastUpdated = lastUpdated
    }

    // MARK: - Z-Score Calculations

    /// Calculates z-score for sleep deviation
    /// - Parameter currentSleep: Current sleep hours
    /// - Returns: Z-score (positive = above average, negative = below)
    func sleepZScore(current currentSleep: Double) -> Double? {
        guard let avg = avgSleepHours,
              let stdDev = sleepStdDev,
              stdDev > 0 else {
            return nil
        }
        return (currentSleep - avg) / stdDev
    }

    /// Calculates z-score for step deviation
    func stepsZScore(current currentSteps: Double) -> Double? {
        guard let avg = avgSteps,
              let stdDev = stepsStdDev,
              stdDev > 0 else {
            return nil
        }
        return (currentSteps - avg) / stdDev
    }

    /// Calculates z-score for HRV deviation
    /// Note: Lower HRV often indicates stress/risk
    func hrvZScore(current currentHRV: Double) -> Double? {
        guard let avg = avgHRV,
              let stdDev = hrvStdDev,
              stdDev > 0 else {
            return nil
        }
        return (currentHRV - avg) / stdDev
    }

    /// Calculates z-score for mood deviation
    func moodZScore(current currentMood: Double) -> Double? {
        guard let avg = avgMoodScore,
              let stdDev = moodStdDev,
              stdDev > 0 else {
            return nil
        }
        return (currentMood - avg) / stdDev
    }
}
