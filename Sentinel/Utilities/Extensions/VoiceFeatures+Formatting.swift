import Foundation

extension VoiceFeatures {
    /// Returns a compact formatted string of voice features
    func summaryString(wpm: Double) -> String {
        var parts: [String] = []
        parts.append("WPM=\(Int(wpm))")

        if let pauseCount = pauseCount {
            let avgPause = averagePauseDuration.map { String(format: "%.1fs", $0) } ?? "N/A"
            parts.append("Pauses=\(pauseCount) (avg \(avgPause))")
        }

        if let pitch = meanPitch {
            let pitchVar = pitchVariability.map { String(format: "%.1f", $0) } ?? "N/A"
            parts.append("Pitch=\(String(format: "%.0f", pitch))Hz (var=\(pitchVar))")
        }

        if let energy = meanEnergy {
            let energyVar = energyVariability.map { String(format: "%.1f", $0) } ?? "N/A"
            parts.append("Energy=\(String(format: "%.0f", energy))dB (var=\(energyVar))")
        }

        if let speechPct = speechPercentage {
            parts.append("Speech%=\(String(format: "%.0f", speechPct))%")
        }

        if let snr = snr {
            parts.append("SNR=\(String(format: "%.0f", snr))dB")
        }

        return parts.joined(separator: ", ")
    }
    
    /// Fallback static method for when VoiceFeatures is nil but WPM exists
    static func fallbackSummary(wpm: Double) -> String {
        return "WPM=\(Int(wpm)), No prosodic data"
    }
}
