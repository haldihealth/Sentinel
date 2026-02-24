import Foundation
import os.log

/// Numerical face geometry captured at ~2fps during check-in.
/// No images saved — just float values from Apple Vision landmarks.
struct FaceTelemetry {
    let timestamp: TimeInterval
    let eyeOpenness: Double
    let headPitch: Double
    let gazeDeviation: Double
}

/// Analyzes continuous face telemetry time-series data to produce
/// a behavioral regulation report for MedGemma.
///
/// Reframed from "emotion detection" to "postural stability monitoring."
/// Compares early, mid, and late segments to detect progressive trends
/// (e.g., head drooping, gaze avoidance increasing over 30 seconds).
class VisualScribe {

    /// Generate a behavioral telemetry report from continuous face geometry samples.
    /// - Parameter telemetry: Array of FaceTelemetry captured at ~2fps over 30s
    /// - Returns: Clinical text report in behavioral/regulatory language
    static func generateReport(from telemetry: [FaceTelemetry]) -> String {
        guard !telemetry.isEmpty else {
            Logger.camera.info("VisualScribe: No telemetry data for analysis")
            return "=== BEHAVIORAL TELEMETRY ===\n[No face telemetry captured]\n"
        }

        let frameCount = telemetry.count
        let duration = (telemetry.last?.timestamp ?? 0) - (telemetry.first?.timestamp ?? 0)

        var report = "=== BEHAVIORAL TELEMETRY (\(String(format: "%.0f", duration))s continuous @ \(frameCount) frames) ===\n"

        // Split into three temporal segments: early / mid / late
        let segments = splitIntoSegments(telemetry)

        // Compute segment means
        let earlyMeans = segmentMeans(segments.early)
        let midMeans = segmentMeans(segments.mid)
        let lateMeans = segmentMeans(segments.late)

        // 1. Postural Stability (Head Pitch)
        let pitchTrend = analyzeTrend(
            early: earlyMeans.headPitch,
            mid: midMeans.headPitch,
            late: lateMeans.headPitch
        )
        let pitchSlope = computeSlope(values: [earlyMeans.headPitch, midMeans.headPitch, lateMeans.headPitch], intervalSeconds: duration / 3.0)

        let posturalStatus: String
        if Swift.abs(pitchSlope) > 0.01 && lateMeans.headPitch.magnitude > earlyMeans.headPitch.magnitude {
            posturalStatus = "Progressive head droop detected (slope: \(String(format: "%.3f", pitchSlope)) deg/s) — \(pitchTrend)"
        } else if lateMeans.headPitch.magnitude > 0.1 {
            posturalStatus = "Sustained head droop (pitch: \(String(format: "%.2f", lateMeans.headPitch))) — static"
        } else {
            posturalStatus = "Stable (\(pitchTrend))"
        }
        report += "- Postural Stability: \(posturalStatus)\n"

        // 2. Gaze Regulation (Gaze Deviation)
        let gazeTrend = analyzeTrend(
            early: earlyMeans.gazeDeviation,
            mid: midMeans.gazeDeviation,
            late: lateMeans.gazeDeviation
        )
        let gazeStatus: String
        if lateMeans.gazeDeviation > earlyMeans.gazeDeviation * 1.3 && lateMeans.gazeDeviation > 3.0 {
            gazeStatus = "Increasing avoidance (early: \(String(format: "%.1f", earlyMeans.gazeDeviation)), late: \(String(format: "%.1f", lateMeans.gazeDeviation))) — \(gazeTrend)"
        } else if lateMeans.gazeDeviation > 5.0 {
            gazeStatus = "Sustained avoidance (deviation: \(String(format: "%.1f", lateMeans.gazeDeviation)))"
        } else {
            gazeStatus = "Regulated (\(gazeTrend))"
        }
        report += "- Gaze Regulation: \(gazeStatus)\n"

        // 3. Alertness (Eye Openness)
        let eyeTrend = analyzeTrend(
            early: earlyMeans.eyeOpenness,
            mid: midMeans.eyeOpenness,
            late: lateMeans.eyeOpenness
        )
        let alertnessStatus: String
        if lateMeans.eyeOpenness < earlyMeans.eyeOpenness * 0.7 && earlyMeans.eyeOpenness > 1.0 {
            alertnessStatus = "Declining (early: \(String(format: "%.1f", earlyMeans.eyeOpenness)), late: \(String(format: "%.1f", lateMeans.eyeOpenness))) — fatigue signal"
        } else if lateMeans.eyeOpenness < 1.5 {
            alertnessStatus = "Low throughout (avg: \(String(format: "%.1f", lateMeans.eyeOpenness)))"
        } else {
            alertnessStatus = "Adequate (\(eyeTrend))"
        }
        report += "- Alertness: \(alertnessStatus)\n"

        // 4. Overall Regulation Pattern
        report += "=== TEMPORAL TREND ===\n"
        let regulationPattern = assessRegulationPattern(
            pitchSlope: pitchSlope,
            gazeEarly: earlyMeans.gazeDeviation,
            gazeLate: lateMeans.gazeDeviation,
            eyeEarly: earlyMeans.eyeOpenness,
            eyeLate: lateMeans.eyeOpenness
        )
        report += "- Regulation Pattern: \(regulationPattern)\n"

        return report
    }

    // MARK: - Segment Analysis

    private struct Segments {
        let early: [FaceTelemetry]
        let mid: [FaceTelemetry]
        let late: [FaceTelemetry]
    }

    private struct SegmentMeans {
        let headPitch: Double
        let gazeDeviation: Double
        let eyeOpenness: Double
    }

    /// Split telemetry into three roughly equal temporal segments
    private static func splitIntoSegments(_ telemetry: [FaceTelemetry]) -> Segments {
        guard let first = telemetry.first, let last = telemetry.last else {
            return Segments(early: [], mid: [], late: [])
        }

        let totalDuration = last.timestamp - first.timestamp
        let oneThird = totalDuration / 3.0
        let startTime = first.timestamp

        let early = telemetry.filter { $0.timestamp < startTime + oneThird }
        let mid = telemetry.filter { $0.timestamp >= startTime + oneThird && $0.timestamp < startTime + 2 * oneThird }
        let late = telemetry.filter { $0.timestamp >= startTime + 2 * oneThird }

        return Segments(early: early, mid: mid, late: late)
    }

    /// Compute mean values for a segment
    private static func segmentMeans(_ segment: [FaceTelemetry]) -> SegmentMeans {
        guard !segment.isEmpty else {
            return SegmentMeans(headPitch: 0, gazeDeviation: 0, eyeOpenness: 0)
        }
        let count = Double(segment.count)
        return SegmentMeans(
            headPitch: segment.map(\.headPitch).reduce(0, +) / count,
            gazeDeviation: segment.map(\.gazeDeviation).reduce(0, +) / count,
            eyeOpenness: segment.map(\.eyeOpenness).reduce(0, +) / count
        )
    }

    // MARK: - Trend Analysis

    /// Describe the directional trend across three segment means
    private static func analyzeTrend(early: Double, mid: Double, late: Double) -> String {
        let earlyToMid = mid - early
        let midToLate = late - mid
        let totalChange = late - early

        if Swift.abs(totalChange) < 0.5 {
            return "stable"
        } else if earlyToMid > 0 && midToLate > 0 {
            return "progressive increase"
        } else if earlyToMid < 0 && midToLate < 0 {
            return "progressive decrease"
        } else if earlyToMid > 0 && midToLate < 0 {
            return "peaked mid-session"
        } else {
            return "variable"
        }
    }

    /// Compute simple slope (units per second) from three evenly-spaced values
    private static func computeSlope(values: [Double], intervalSeconds: Double) -> Double {
        guard values.count >= 2, intervalSeconds > 0 else { return 0 }
        // Linear regression on [0, 1, 2] mapped to time
        let n = Double(values.count)
        let xMean = (n - 1) / 2.0
        let yMean = values.reduce(0, +) / n

        var numerator = 0.0
        var denominator = 0.0
        for (i, y) in values.enumerated() {
            let x = Double(i)
            numerator += (x - xMean) * (y - yMean)
            denominator += (x - xMean) * (x - xMean)
        }

        guard denominator > 0 else { return 0 }
        return (numerator / denominator) / intervalSeconds
    }

    // MARK: - Regulation Assessment

    /// Assess overall regulation pattern from multi-signal trends
    private static func assessRegulationPattern(
        pitchSlope: Double,
        gazeEarly: Double,
        gazeLate: Double,
        eyeEarly: Double,
        eyeLate: Double
    ) -> String {
        var decompensationSignals = 0

        // Progressive head droop
        if Swift.abs(pitchSlope) > 0.01 { decompensationSignals += 1 }

        // Increasing gaze avoidance
        if gazeLate > gazeEarly * 1.3 && gazeLate > 3.0 { decompensationSignals += 1 }

        // Declining alertness
        if eyeLate < eyeEarly * 0.7 && eyeEarly > 1.0 { decompensationSignals += 1 }

        switch decompensationSignals {
        case 3:
            return "Multi-signal decompensation — postural, gaze, and alertness declining"
        case 2:
            return "Partial decompensation — regulation eroding across session"
        case 1:
            return "Single-signal drift — monitor for trend"
        default:
            return "Regulated — behavioral signals stable throughout session"
        }
    }
}
