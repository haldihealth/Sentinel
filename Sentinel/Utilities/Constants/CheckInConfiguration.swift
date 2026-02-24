import Foundation

/// Configuration constants for check-in flow
enum CheckInConfiguration {
    /// Total duration of multimodal check-in in seconds
    static let totalDuration: TimeInterval = 30.0

    /// Target face telemetry sampling rate (frames per second)
    static let telemetrySamplingFPS: Double = 2.0

    /// Health data fetch timeout in seconds
    static let healthDataTimeoutSeconds: TimeInterval = 5.0

    /// AI inference timeout in seconds (MedGemma LLM)
    static let aiInferenceTimeoutSeconds: TimeInterval = 60.0

    /// Semantic narrative compression timeout in seconds
    static let narrativeCompressionTimeoutSeconds: TimeInterval = 30.0

    /// Safety plan reranking timeout in seconds
    static let rerankTimeoutSeconds: TimeInterval = 15.0
}

/// LLM Configuration
enum LLMConfiguration {
    /// Maximum tokens for inference response
    static let maxTokens: Int = 256

    /// Temperature for sampling (lower = more deterministic)
    static let temperature: Float = 0.1

    /// Top-K sampling parameter
    static let topK: Int32 = 40

    /// Top-P (nucleus) sampling parameter
    static let topP: Float = 0.95

    /// Context window size
    static let maxTokenCount: Int32 = 1024

    /// GPU layers to offload (999 = full GPU)
    static let gpuLayers: Int32 = 999

    /// Repetition penalty (1.0 = none, higher = stronger penalty)
    static let repeatPenalty: Float = 1.15
    
    /// Number of previous tokens to consider for repetition penalty
    static let repetitionLookback: Int32 = 64
}

/// HealthKit baseline calculation configuration
enum BaselineConfiguration {
    /// Number of days to use for baseline calculation
    static let baselineWindowDays: Int = 30

    /// Minimum data points required for valid baseline
    static let minimumDataPoints: Int = 7
}


/// Health metrics deviation thresholds
enum HealthMetricsThresholds {
    /// Z-score threshold for concerning deviation
    static let concerningDeviation: Double = -1.5

    /// Z-score threshold for significant deviation
    static let significantDeviation: Double = -2.0

    /// Minimum number of concerning deviations for elevated risk
    static let minConcerningDeviationsForElevatedRisk: Int = 2
}

/// Crisis resources and contact information
enum CrisisResources {
    /// 988 Suicide & Crisis Lifeline phone URL
    static let suicidePreventionLine = "tel://988"

    /// Crisis Text Line SMS URL
    static let crisisTextLine = "sms://838255"

    /// Display phone number for 988
    static let displayPhone988 = "988"

    /// Display text number for Crisis Text Line
    static let displayTextLine = "838255"
}

/// Mandatory check-in intervals after crisis
enum CrisisFollowUp {
    /// Hours until mandatory follow-up check-in after crisis
    static let mandatoryCheckInHours: Int = 4

    /// Days to retain crisis history
    static let crisisHistoryRetentionDays: Int = 30
}
