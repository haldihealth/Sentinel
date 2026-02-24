import Foundation

/// Detects cross-modal discrepancies between verbal content, vocal prosody,
/// and behavioral telemetry signals.
///
/// A person saying "I'm fine" with flat vocal affect and progressive postural
/// slumping represents a masking pattern — the verbal content contradicts
/// the behavioral/vocal signals.
struct DiscrepancyDetector {

    // MARK: - Positive Content Markers

    private static let positiveMarkers = [
        "fine", "good", "okay", "great", "not bad", "alright",
        "better", "well", "doing okay", "i'm okay", "i'm fine",
        "i'm good", "no complaints", "can't complain"
    ]

    // MARK: - Detection

    /// Analyze transcript, voice features, and behavioral report for discrepancies.
    /// Returns a description of any detected discrepancy, or nil if signals are concordant.
    static func detect(
        transcript: String,
        voiceFeatures: VoiceFeatures?,
        behavioralReport: String
    ) -> String? {
        var findings: [String] = []

        let transcriptLower = transcript.lowercased()
        let hasPositiveContent = positiveMarkers.contains { transcriptLower.contains($0) }

        // 1. Masking Detection: Positive words + flat vocal affect
        if hasPositiveContent, let vf = voiceFeatures {
            let flatPitch = (vf.pitchVariability ?? 100) < 15.0
            let lowEnergy = (vf.meanEnergy ?? 0) < -30.0
            let lowEnergyVariability = (vf.energyVariability ?? 100) < 5.0

            if flatPitch || (lowEnergy && lowEnergyVariability) {
                findings.append("MASKING: Positive verbal content with flat vocal prosody (pitch var: \(String(format: "%.1f", vf.pitchVariability ?? 0)), energy: \(String(format: "%.0f", vf.meanEnergy ?? 0))dB)")
            }
        }

        // 2. Psychomotor-Speech Concordance: Both speech and posture declining
        if let vf = voiceFeatures {
            let slowSpeech = (vf.speechRate ?? 100) < 1.5 // syllables/sec
            let hasPosturalDecline = behavioralReport.contains("Progressive head droop") ||
                                     behavioralReport.contains("decompensation")

            if slowSpeech && hasPosturalDecline {
                findings.append("CONCORDANT DECOMPENSATION: Low speech rate with progressive postural decline")
            }
        }

        // 3. Avoidance Pattern: Gaze avoidance + frequent pauses
        if let vf = voiceFeatures {
            let highPauseCount = (vf.pauseCount ?? 0) > 6
            let hasGazeAvoidance = behavioralReport.contains("avoidance") ||
                                    behavioralReport.contains("Increasing avoidance")

            if highPauseCount && hasGazeAvoidance {
                findings.append("AVOIDANCE PATTERN: Gaze avoidance with frequent speech hesitations (\(vf.pauseCount ?? 0) pauses)")
            }
        }

        return findings.isEmpty ? nil : findings.joined(separator: "; ")
    }
}
