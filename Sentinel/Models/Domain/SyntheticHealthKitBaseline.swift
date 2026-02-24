import Foundation

/// Synthetic HealthKit baseline data for developer mode demo
///
/// Provides realistic baseline metrics and current values that produce
/// clinically significant z-scores for the demo scenario.
struct SyntheticHealthKitBaseline: Codable {
    // MARK: - 30-Day Baseline Averages
    
    /// Average sleep duration over 30 days (hours)
    var avgSleepHours: Double = 7.0
    
    /// Standard deviation of sleep duration
    var sleepStdDev: Double = 0.8
    
    /// Average daily steps over 30 days
    var avgSteps: Double = 8000
    
    /// Standard deviation of daily steps
    var stepsStdDev: Double = 1500
    
    /// Average HRV (SDNN in milliseconds) over 30 days
    var avgHRV: Double = 60.0
    
    /// Standard deviation of HRV
    var hrvStdDev: Double = 12.0
    
    // MARK: - Current State (48h post-discharge, activation syndrome)
    
    /// Current sleep duration (produces -6.9 SD z-score)
    var currentSleepHours: Double = 1.5
    
    /// Current daily steps (produces -4.0 SD z-score)
    var currentSteps: Double = 2000
    
    /// Current HRV (produces -2.1 SD z-score)
    var currentHRV: Double = 35.0
    
    /// When this baseline was created
    var lastUpdated: Date = Date()
    
    // MARK: - Initialization
    
    init(
        avgSleepHours: Double = 7.0,
        sleepStdDev: Double = 0.8,
        avgSteps: Double = 8000,
        stepsStdDev: Double = 1500,
        avgHRV: Double = 60.0,
        hrvStdDev: Double = 12.0,
        currentSleepHours: Double = 1.5,
        currentSteps: Double = 2000,
        currentHRV: Double = 35.0,
        lastUpdated: Date = Date()
    ) {
        self.avgSleepHours = avgSleepHours
        self.sleepStdDev = sleepStdDev
        self.avgSteps = avgSteps
        self.stepsStdDev = stepsStdDev
        self.avgHRV = avgHRV
        self.hrvStdDev = hrvStdDev
        self.currentSleepHours = currentSleepHours
        self.currentSteps = currentSteps
        self.currentHRV = currentHRV
        self.lastUpdated = lastUpdated
    }
}
