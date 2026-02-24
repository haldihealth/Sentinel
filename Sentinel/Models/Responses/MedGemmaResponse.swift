import Foundation

/// Response from MedGemma-4B on-device LLM analysis
///
/// Contains structured output from the model including risk assessment,
/// insights, and recommended actions.
struct MedGemmaResponse: Codable {
    // MARK: - Properties

    let id: UUID
    let timestamp: Date

    /// Raw model output text
    var rawOutput: String

    /// Processing time in seconds
    var inferenceTime: Double?

    // MARK: - Parsed Results

    /// Model's risk assessment (used as input, NOT override for C-SSRS)
    var assessedRisk: RiskTier?

    /// Key insights identified by the model
    var insights: [String]

    /// Recommended actions/coping strategies
    var recommendations: [String]

    /// Confidence score (0.0 - 1.0)
    var confidence: Double?

    // MARK: - Pattern Detection

    /// Detected patterns from health data
    var detectedPatterns: [DetectedPattern]

    /// Whether significant deviation from baseline was found
    var hasSignificantDeviation: Bool

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        rawOutput: String,
        inferenceTime: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.rawOutput = rawOutput
        self.inferenceTime = inferenceTime
        self.insights = []
        self.recommendations = []
        self.detectedPatterns = []
        self.hasSignificantDeviation = false
    }
}

// MARK: - Supporting Types

/// A pattern detected in health/behavioral data
struct DetectedPattern: Identifiable, Codable {
    let id: UUID
    var type: PatternType
    var description: String
    var severity: PatternSeverity
    var dataSource: DataSource

    init(
        id: UUID = UUID(),
        type: PatternType,
        description: String,
        severity: PatternSeverity,
        dataSource: DataSource
    ) {
        self.id = id
        self.type = type
        self.description = description
        self.severity = severity
        self.dataSource = dataSource
    }
}

/// Types of patterns that can be detected
enum PatternType: String, Codable {
    case sleepDisruption = "Sleep Disruption"
    case activityDecline = "Activity Decline"
    case hrvDrop = "HRV Drop"
    case moodDecline = "Mood Decline"
    case voiceChange = "Voice Change"
    case combinedIndicators = "Combined Indicators"

    /// Create PatternType from string representation
    static func from(string: String) -> PatternType {
        switch string.lowercased() {
        case "sleep":
            return .sleepDisruption
        case "activity", "steps":
            return .activityDecline
        case "hrv":
            return .hrvDrop
        case "mood":
            return .moodDecline
        case "voice":
            return .voiceChange
        default:
            return .combinedIndicators
        }
    }
}

/// Severity level of detected pattern
enum PatternSeverity: String, Codable {
    case mild = "Mild"
    case moderate = "Moderate"
    case significant = "Significant"
}

/// Source of the data for a pattern
enum DataSource: String, Codable {
    case sleep = "Sleep"
    case activity = "Activity"
    case hrv = "HRV"
    case mood = "Mood"
    case voice = "Voice"
    case cssrs = "C-SSRS"
    case combined = "Combined"

    /// Create DataSource from string representation
    static func from(string: String) -> DataSource {
        switch string.lowercased() {
        case "sleep":
            return .sleep
        case "activity", "steps":
            return .activity
        case "hrv":
            return .hrv
        case "mood":
            return .mood
        case "voice":
            return .voice
        default:
            return .combined
        }
    }
}
