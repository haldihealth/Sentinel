import Foundation

/// Activity data collected from HealthKit
///
/// Tracks physical activity which correlates with mental health.
/// Significant drops in activity can indicate depression or withdrawal.
struct ActivityMetrics: Codable, Sendable {
    // MARK: - Properties

    let date: Date

    /// Total steps for the day
    var stepCount: Int

    /// Active calories burned
    var activeCalories: Double?

    /// Distance walked/run in meters
    var distanceMeters: Double?

    /// Minutes of exercise
    var exerciseMinutes: Int?

    /// Stand hours (Apple Watch)
    var standHours: Int?

    // MARK: - Initialization

    init(
        date: Date,
        stepCount: Int,
        activeCalories: Double? = nil,
        distanceMeters: Double? = nil
    ) {
        self.date = date
        self.stepCount = stepCount
        self.activeCalories = activeCalories
        self.distanceMeters = distanceMeters
    }

    // MARK: - Analysis

    /// Indicates sedentary behavior (< 2000 steps)
    var isSedentary: Bool {
        stepCount < 2000
    }

    /// Indicates low activity (< 5000 steps)
    var isLowActivity: Bool {
        stepCount < 5000
    }

    /// Indicates active day (>= 10000 steps)
    var isActive: Bool {
        stepCount >= 10000
    }

    /// Distance in miles (for display)
    var distanceMiles: Double? {
        guard let meters = distanceMeters else { return nil }
        return meters / 1609.344
    }
}
