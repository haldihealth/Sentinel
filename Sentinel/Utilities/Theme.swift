import SwiftUI

/// Centralized theme management for Sentinel
/// Provides type-safe access to the tactical color palette
struct Theme {
    // MARK: - Tactical Palette
    
    /// Primary brand color - Tactical Teal (#1B9898)
    /// Use for: Primary actions, active states, brand identity
    static let primary = Color("SentinelPrimary")
    
    /// Darker variant of primary - Tactical Teal Dark (#136D6D)
    /// Use for: Hover states, emphasis, pressed states
    static let primaryDark = Color("SentinelPrimaryDark")
    
    /// Emergency/Crisis color - Sentinel Red (#EF4444)
    /// Use for: Crisis states, destructive actions, emergency buttons
    static let emergency = Color("SentinelRed")
    
    // MARK: - Risk Tier Colors
    
    /// Low risk tier color (Green)
    static let riskLow = primary
    
    /// Moderate risk tier color (Yellow)
    static let riskModerate = Color("SentinelYellow")
    
    /// High monitoring tier color (Orange)
    static let riskHighMonitoring = Color("SentinelOrange")
    
    /// Crisis tier color (Red)
    static let riskCrisis = emergency
    
    // MARK: - Tactical Backgrounds
    
    /// Main screen background
    /// Light: #F9FAFA, Dark: #16181D
    static let background = Color("TacticalBackground")
    
    /// Cards, modals, and elevated surfaces
    /// Light: #FFFFFF, Dark: #1E2126
    static let surface = Color("TacticalSurface")
    
    /// Active/Highlighted states
    /// Light: #F1F3F4, Dark: #252930
    static let surfaceHover = Color("TacticalSurfaceHover")
    
    // MARK: - Shadows & Effects
    
    /// Tactical glow effect for interactive elements
    /// Use instead of standard black shadows
    static func primaryGlow(opacity: Double = 0.6, radius: CGFloat = 10) -> some View {
        EmptyView().shadow(color: primary.opacity(opacity), radius: radius)
    }
}

// MARK: - Legacy Support

/// Extension to maintain backwards compatibility with string-based color names
/// This allows gradual migration from Color("SentinelGreen") to Theme.primary
extension Color {
    /// Initialize color from tactical palette name
    /// - Parameter tacticalName: Name of the tactical color
    init(tactical: String) {
        switch tactical {
        case "SentinelPrimary":
            self = Theme.primary
        case "SentinelPrimaryDark":
            self = Theme.primaryDark
        case "SentinelRed":
            self = Theme.emergency
        case "SentinelGreen": // Legacy support
            self = Theme.primary
        case "SentinelYellow":
            self = Theme.riskModerate
        case "SentinelOrange":
            self = Theme.riskHighMonitoring
        case "TacticalBackground":
            self = Theme.background
        case "TacticalSurface":
            self = Theme.surface
        case "TacticalSurfaceHover":
            self = Theme.surfaceHover
        default:
            self = Color(tactical)
        }
    }
}
