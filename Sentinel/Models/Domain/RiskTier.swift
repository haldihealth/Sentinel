import Foundation
import SwiftUI

/// Risk assessment tiers based on C-SSRS screening
enum RiskTier: Int, Codable, CaseIterable, Sendable, Comparable {
    static func < (lhs: RiskTier, rhs: RiskTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    case low = 0             // GREEN
    case moderate = 1        // YELLOW
    case highMonitoring = 2  // ORANGE
    case crisis = 3          // RED

    // MARK: - Display Properties

    var displayName: String {
        switch self {
        case .low: return "ALL CLEAR"
        case .moderate: return "ELEVATED"
        case .highMonitoring: return "HIGH MONITORING"
        case .crisis: return "CRISIS"
        }
    }

    var color: Color {
        switch self {
        case .low: return Theme.riskLow
        case .moderate: return Theme.riskModerate
        case .highMonitoring: return Theme.riskHighMonitoring
        case .crisis: return Theme.riskCrisis
        }
    }
    
    var colorName: String {
        switch self {
        case .low: return "SentinelPrimary"
        case .moderate: return "SentinelYellow"
        case .highMonitoring: return "SentinelOrange"
        case .crisis: return "SentinelRed"
        }
    }

    var isLocked: Bool {
        self == .crisis
    }

    // MARK: - Card Content (Compassionate Commander Voice)

    var cardDescription: String {
        switch self {
        case .low: // GREEN
            return "Operational status is stable. No risk indicators detected."
        case .moderate: // YELLOW
            return "Early warning indicators detected. Your check-in suggests you may be experiencing some difficult thoughts."
        case .highMonitoring:
            return "Significant risk factors identified. It is critical that you do not isolate yourself right now."
        case .crisis:
            return "Immediate safety concerns detected. Your life is valuable, and support is available 24/7."
        }
    }
    
    var cardRecommendation: String {
        switch self {
        case .low:
            return "Maintain current routine. Continue building your baseline with daily check-ins."
        case .moderate:
            return "This is a good time to review your Safety Plan. Connecting with a trusted contact can help."
        case .highMonitoring:
            return "Please activate your support network. Contact a professional or trusted peer from your Safety Plan today."
        case .crisis:
            return "Please use the Emergency Help button below or call 988 immediately."
        }
    }
    
    /// Title for the primary action button.
    /// Returns nil for Low/Green so no button is shown.
    var actionButtonTitle: String? {
        switch self {
        case .moderate:
            return "REVIEW SAFETY PLAN"
        case .highMonitoring:
            return "CONTACT SUPPORT"
        case .crisis:
            return "EMERGENCY HELP"
        default:
            return nil
        }
    }

    /// Create RiskTier from string representation
    /// Supports both color names (green, yellow, etc.) and level names (low, moderate, etc.)
    static func from(string: String) -> RiskTier? {
        switch string.lowercased() {
        case "green", "low":
            return .low
        case "yellow", "moderate":
            return .moderate
        case "orange", "high":
            return .highMonitoring
        case "red", "crisis":
            return .crisis
        default:
            return nil
        }
    }
}
