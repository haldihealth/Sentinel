import SwiftUI

/// A card for tactical action items with icon and description
struct TacticalActionCard: View {
    let icon: String
    let title: String
    var subtitle: String?
    var showChevron: Bool

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        showChevron: Bool = false
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.showChevron = showChevron
    }

    var body: some View {
        HStack(spacing: Spacing.lg) {
            // Icon container
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(Theme.surfaceHover)
                    .frame(width: Spacing.iconContainerSize, height: Spacing.iconContainerSize)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.primary)
            }

            // Text content
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(Typography.cardTitle)
                    .foregroundStyle(.white)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(Typography.cardSubtitle)
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(0.5)
                }
            }

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        TacticalActionCard(
            icon: "waveform.and.mic",
            title: "Daily Check-in"
        )

        TacticalActionCard(
            icon: "message.fill",
            title: "Message Primary Care",
            subtitle: "CONNECT TO MHS GENESIS/MYHEALTHEVET",
            showChevron: true
        )

        TacticalActionCard(
            icon: "brain.head.profile",
            title: "Message Mental Health Provider",
            subtitle: "SECURE MESSAGE FOR NON-URGENT SUPPORT",
            showChevron: true
        )
    }
    .padding()
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
