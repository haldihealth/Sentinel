import Foundation

/// Sleep data collected from HealthKit
///
/// Captures sleep duration and quality metrics for risk assessment.
/// Sleep disruption is a key indicator of mental health changes.
struct SleepMetrics: Codable, Sendable {
    // MARK: - Properties

    let date: Date

    /// Total sleep duration in hours
    var totalSleepHours: Double

    /// Time in bed (may differ from actual sleep)
    var timeInBedHours: Double?

    /// Sleep efficiency (sleep time / time in bed)
    var sleepEfficiency: Double? {
        guard let inBed = timeInBedHours, inBed > 0 else { return nil }
        return totalSleepHours / inBed
    }

    // MARK: - Sleep Stages (if available)

    var deepSleepHours: Double?
    var remSleepHours: Double?
    var lightSleepHours: Double?
    var awakeMinutes: Double?

    // MARK: - Timing

    var bedtime: Date?
    var wakeTime: Date?

    // MARK: - Initialization

    init(
        date: Date,
        totalSleepHours: Double,
        timeInBedHours: Double? = nil
    ) {
        self.date = date
        self.totalSleepHours = totalSleepHours
        self.timeInBedHours = timeInBedHours
    }

    // MARK: - Analysis

    /// Indicates if sleep is below clinical threshold (< 4 hours)
    var isSeverelySleepDeprived: Bool {
        totalSleepHours < 4.0
    }

    /// Indicates if sleep is below recommended (< 7 hours)
    var isBelowRecommended: Bool {
        totalSleepHours < 7.0
    }
}
