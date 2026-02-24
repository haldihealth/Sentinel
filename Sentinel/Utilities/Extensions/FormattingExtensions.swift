import Foundation

/// String formatting extensions for consistent health metric display
extension Double {
    
    /// Format as a z-score with sign
    /// - Parameter decimals: Number of decimal places (default: 1)
    /// - Returns: Formatted string like "z=-2.3" or "z=+1.5"
    func formatted(asZScore decimals: Int = 1) -> String {
        let formatted = String(format: "%.\(decimals)f", self)
        let sign = self >= 0 ? "+" : ""
        return "z=\(sign)\(formatted)"
    }
    
    /// Format as health metric with unit
    /// - Parameter unit: Unit string (e.g., "hr", "steps", "ms")
    /// - Returns: Formatted string like "7.5hr" or "5000 steps"
    func formatted(asHealthMetric unit: String, decimals: Int = 1) -> String {
        if unit == "steps" || unit == "count" {
            return "\(Int(self)) \(unit)"
        }
        let formatted = String(format: "%.\(decimals)f", self)
        return "\(formatted)\(unit)"
    }
}

/// Time interval formatting extensions
extension TimeInterval {
    
    /// Format as countdown timer (MM:SS)
    /// - Returns: Formatted string like "01:23" or "00:05"
    func formatted(asCountdown: Void = ()) -> String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Format as duration with unit (e.g., "2.3s", "1.5m")
    /// - Returns: Formatted duration string
    func formatted(asDuration: Void = ()) -> String {
        if self < 60 {
            return String(format: "%.2fs", self)
        } else if self < 3600 {
            return String(format: "%.1fm", self / 60)
        } else {
            return String(format: "%.1fh", self / 3600)
        }
    }
}

/// String formatting for separators and formatting
extension String {
    
    /// Create a separator line of repeated characters
    /// - Parameters:
    ///   - character: Character to repeat (default: "=")
    ///   - count: Number of repetitions (default: 80)
    /// - Returns: Separator string
    static func separator(_ character: String = "=", count: Int = 80) -> String {
        String(repeating: character, count: count)
    }
}
