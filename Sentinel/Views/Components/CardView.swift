import SwiftUI

/// A reusable card container with consistent styling
struct CardView<Content: View>: View {
    let content: Content
    var backgroundColor: Color
    var cornerRadius: CGFloat
    var padding: CGFloat

    init(
        backgroundColor: Color = Theme.surface,
        cornerRadius: CGFloat = CornerRadius.standard,
        padding: CGFloat = Spacing.cardPadding,
        @ViewBuilder content: () -> Content
    ) {
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Convenience Initializers

extension CardView {
    /// Create a card with default surface styling
    static func surface(@ViewBuilder content: () -> Content) -> CardView {
        CardView(content: content)
    }

    /// Create a card with emergency styling
    static func emergency(@ViewBuilder content: () -> Content) -> CardView {
        CardView(backgroundColor: Theme.emergency, content: content)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Card Title")
                    .font(Typography.cardTitle)
                    .foregroundStyle(.white)

                Text("Card content goes here")
                    .font(Typography.body)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }

        CardView.emergency {
            HStack {
                Image(systemName: "phone.fill")
                Text("Emergency")
            }
            .foregroundStyle(.white)
        }
    }
    .padding()
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
