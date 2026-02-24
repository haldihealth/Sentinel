import Foundation

/// Heart Rate Variability metrics from HealthKit
///
/// HRV is an objective biomarker that can indicate stress and mental health changes.
/// Research shows HRV drops 3-7 days before symptom onset (Kemp 2010, Pyne 2016).
struct HRVMetrics: Codable, Sendable {
    // MARK: - Properties

    let date: Date

    /// SDNN (Standard Deviation of NN intervals) in milliseconds
    /// Primary HRV measure from Apple Watch
    var sdnn: Double

    /// Resting heart rate in BPM (for context)
    var restingHeartRate: Double?

    /// Time of measurement
    var measurementTime: Date?

    // MARK: - Initialization

    init(
        date: Date,
        sdnn: Double,
        restingHeartRate: Double? = nil,
        measurementTime: Date? = nil
    ) {
        self.date = date
        self.sdnn = sdnn
        self.restingHeartRate = restingHeartRate
        self.measurementTime = measurementTime
    }

    // MARK: - Analysis

    /// General HRV interpretation
    /// Note: Individual baselines are more important than absolute values
    var generalInterpretation: HRVInterpretation {
        // These are rough guidelines; personal baseline is more accurate
        switch sdnn {
        case 0..<20:
            return .veryLow
        case 20..<50:
            return .low
        case 50..<100:
            return .normal
        default:
            return .high
        }
    }
}

// MARK: - Supporting Types

/// General HRV level interpretation
enum HRVInterpretation: String, Codable, Sendable {
    case veryLow = "Very Low"
    case low = "Low"
    case normal = "Normal"
    case high = "High"

    var description: String {
        switch self {
        case .veryLow:
            return "May indicate high stress or fatigue"
        case .low:
            return "Below typical range"
        case .normal:
            return "Within typical range"
        case .high:
            return "Indicates good recovery"
        }
    }
}
