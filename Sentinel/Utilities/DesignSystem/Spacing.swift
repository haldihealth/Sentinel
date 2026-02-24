import SwiftUI

/// Centralized spacing definitions for consistent layout
enum Spacing {
    // MARK: - Base Scale

    /// Extra small spacing (4pt)
    static let xs: CGFloat = 4

    /// Small spacing (8pt)
    static let sm: CGFloat = 8

    /// Medium spacing (12pt)
    static let md: CGFloat = 12

    /// Large spacing (16pt)
    static let lg: CGFloat = 16

    /// Extra large spacing (20pt)
    static let xl: CGFloat = 20

    /// Double extra large spacing (24pt)
    static let xxl: CGFloat = 24

    /// Triple extra large spacing (32pt)
    static let xxxl: CGFloat = 32

    // MARK: - Semantic Spacing

    /// Standard screen horizontal padding
    static let screenHorizontal: CGFloat = 20

    /// Standard card internal padding
    static let cardPadding: CGFloat = 16

    /// Standard card vertical spacing
    static let cardVerticalSpacing: CGFloat = 12

    /// Section spacing between major sections
    static let sectionSpacing: CGFloat = 24

    /// Button internal padding
    static let buttonPadding: CGFloat = 16

    /// Icon container size
    static let iconContainerSize: CGFloat = 48

    /// Large icon container size
    static let iconContainerLarge: CGFloat = 64
}

/// Corner radius definitions
enum CornerRadius {
    /// Small corners (8pt) - for badges, small elements
    static let small: CGFloat = 8

    /// Medium corners (10pt) - for icon containers
    static let medium: CGFloat = 10

    /// Standard corners (12pt) - for cards, buttons
    static let standard: CGFloat = 12

    /// Large corners (16pt) - for large cards, overlays
    static let large: CGFloat = 16

    /// Full pill shape (28pt) - for pill buttons
    static let pill: CGFloat = 28
}
