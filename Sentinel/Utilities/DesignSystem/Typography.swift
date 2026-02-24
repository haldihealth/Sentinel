import SwiftUI

/// Centralized typography definitions for consistent text styling
enum Typography {
    // MARK: - Display

    /// Large display text (32pt, bold)
    static let largeTitle = Font.system(size: 32, weight: .bold)

    /// Standard title (24pt, bold)
    static let title = Font.system(size: 24, weight: .bold)

    /// Secondary title (20pt, semibold)
    static let title2 = Font.system(size: 20, weight: .semibold)

    /// Tertiary title (18pt, semibold)
    static let title3 = Font.system(size: 18, weight: .semibold)

    // MARK: - Body

    /// Primary body text (16pt, regular)
    static let body = Font.system(size: 16, weight: .regular)

    /// Emphasized body text (16pt, semibold)
    static let bodyEmphasis = Font.system(size: 16, weight: .semibold)

    /// Secondary body text (15pt, regular)
    static let bodySecondary = Font.system(size: 15, weight: .regular)

    // MARK: - UI Elements

    /// Headline for buttons and cards (16pt, bold)
    static let headline = Font.system(size: 16, weight: .bold)

    /// Subheadline (14pt, semibold)
    static let subheadline = Font.system(size: 14, weight: .semibold)

    /// Caption text (12pt, medium)
    static let caption = Font.system(size: 12, weight: .medium)

    /// Small caption (11pt, medium)
    static let captionSmall = Font.system(size: 11, weight: .medium)

    /// Tiny text (10pt, medium)
    static let tiny = Font.system(size: 10, weight: .medium)

    // MARK: - Section Headers

    /// Section header (12pt, semibold, for use with tracking)
    static let sectionHeader = Font.system(size: 12, weight: .semibold)

    // MARK: - Specialized

    /// Risk level display (14pt, bold)
    static let riskLevel = Font.system(size: 14, weight: .bold)

    /// Button label (18pt, bold)
    static let buttonLarge = Font.system(size: 18, weight: .bold)

    /// Card title (15pt, semibold)
    static let cardTitle = Font.system(size: 15, weight: .semibold)

    /// Card subtitle (10pt, medium)
    static let cardSubtitle = Font.system(size: 10, weight: .medium)
}

// MARK: - View Extensions

extension View {
    /// Apply section header typography with letter spacing
    func sectionHeaderStyle() -> some View {
        self
            .font(Typography.sectionHeader)
            .tracking(1.5)
    }

    /// Apply card subtitle style with letter spacing
    func cardSubtitleStyle() -> some View {
        self
            .font(Typography.cardSubtitle)
            .tracking(0.5)
    }
}
