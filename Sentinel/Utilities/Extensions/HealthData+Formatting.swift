import Foundation

extension HealthData {
    /// Returns a compact summary string for prompts (e.g., "Sleep: 7.5hr, Steps: 8500, HRV: 45ms")
    func summaryString() -> String {
        let sleepStr = sleep.totalSleepHours > 0 ? "\(String(format: "%.1f", sleep.totalSleepHours))hr" : "N/A"
        let stepsStr = activity.stepCount > 0 ? "\(activity.stepCount)" : "N/A"
        let hrvStr = hrv.sdnn > 0 ? "\(String(format: "%.0f", hrv.sdnn))ms" : "N/A"
        
        return "Sleep: \(sleepStr), Steps: \(stepsStr), HRV: \(hrvStr)"
    }

    /// Returns a detailed formatted string for risk explanation and reports
    func detailedSummaryString() -> String {
        var items: [String] = []
        if sleep.totalSleepHours > 0 {
            items.append("Sleep: \(String(format: "%.1f", sleep.totalSleepHours)) hours")
        }
        if hrv.sdnn > 0 {
            items.append("HRV: \(String(format: "%.0f", hrv.sdnn)) ms")
        }
        
        // Include significant deviations if present
        if let deviations = deviations as HealthDeviations? {
            if let sleepZ = deviations.sleepZScore, sleepZ.magnitude > 1.5 {
                items.append("Sleep deviation: z=\(String(format: "%.1f", sleepZ))")
            }
            if let hrvZ = deviations.hrvZScore, hrvZ.magnitude > 1.5 {
                items.append("HRV deviation: z=\(String(format: "%.1f", hrvZ))")
            }
            if let stepsZ = deviations.stepsZScore, stepsZ.magnitude > 1.5 {
                items.append("Activity deviation: z=\(String(format: "%.1f", stepsZ))")
            }
        }
        
        return items.isEmpty ? "No significant recent data." : items.joined(separator: "\n")
    }

    /// Returns a multi-line formatted string suitable for SBAR reports
    func reportFormat() -> String {
        var items: [String] = []
        items.append("Sleep: \(String(format: "%.1f", sleep.totalSleepHours)) hours")
        items.append("Steps: \(activity.stepCount)")
        items.append("HRV: \(String(format: "%.0f", hrv.sdnn)) ms")
        
        if let deviations = deviations as HealthDeviations? {
            if let sleepZ = deviations.sleepZScore, sleepZ.magnitude > 1.5 {
                items.append("Sleep deviation: z=\(String(format: "%.1f", sleepZ))")
            }
            if let hrvZ = deviations.hrvZScore, hrvZ.magnitude > 1.5 {
                items.append("HRV deviation: z=\(String(format: "%.1f", hrvZ))")
            }
            if let stepsZ = deviations.stepsZScore, stepsZ.magnitude > 1.5 {
                items.append("Activity deviation: z=\(String(format: "%.1f", stepsZ))")
            }
        }
        return items.isEmpty ? "No HealthKit data available" : items.joined(separator: "\n    ")
    }
}
