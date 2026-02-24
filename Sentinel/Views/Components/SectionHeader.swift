import SwiftUI

/// A styled section header with consistent typography
struct SectionHeader: View {
    let title: String
    var color: Color

    init(_ title: String, color: Color = .white.opacity(0.5)) {
        self.title = title
        self.color = color
    }

    var body: some View {
        Text(title)
            .font(Typography.sectionHeader)
            .foregroundStyle(color)
            .tracking(1.5)
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        SectionHeader("YOUR REDCON LEVEL")
        SectionHeader("TACTICAL ACTIONS")
        SectionHeader("CUSTOM COLOR", color: Theme.primary)
    }
    .padding()
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
