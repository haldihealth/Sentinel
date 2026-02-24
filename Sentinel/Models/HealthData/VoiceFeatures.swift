import Foundation

/// Acoustic features extracted from voice recordings
///
/// Voice biomarkers can indicate mental health changes through
/// prosodic features like pitch, energy, and speech rate.
struct VoiceFeatures: Codable {
    // MARK: - Properties

    let id: UUID
    let recordingDate: Date

    /// Duration of recording in seconds
    var durationSeconds: Double

    // MARK: - Prosodic Features

    /// Mean fundamental frequency (pitch) in Hz
    var meanPitch: Double?

    /// Pitch variability (standard deviation)
    var pitchVariability: Double?

    /// Speech rate (syllables per second)
    var speechRate: Double?

    /// Mean energy/loudness in dB
    var meanEnergy: Double?

    /// Energy variability
    var energyVariability: Double?

    // MARK: - Temporal Features

    /// Percentage of recording that is speech (vs silence)
    var speechPercentage: Double?

    /// Average pause duration in seconds
    var averagePauseDuration: Double?

    /// Number of pauses
    var pauseCount: Int?

    // MARK: - Quality Metrics

    /// Signal-to-noise ratio
    var snr: Double?

    /// Whether recording quality is sufficient for analysis
    var isValidRecording: Bool {
        guard let snr = snr else { return false }
        return snr > 10.0 && durationSeconds >= 10.0
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        recordingDate: Date = Date(),
        durationSeconds: Double
    ) {
        self.id = id
        self.recordingDate = recordingDate
        self.durationSeconds = durationSeconds
    }
}
