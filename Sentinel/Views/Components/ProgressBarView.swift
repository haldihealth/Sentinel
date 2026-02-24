import SwiftUI

/// A progress bar with glow effect for check-in progress
struct ProgressBarView: View {
    let current: Int
    let total: Int
    var height: CGFloat
    var backgroundColor: Color
    var foregroundColor: Color
    var cornerRadius: CGFloat

    init(
        current: Int,
        total: Int,
        height: CGFloat = 6,
        backgroundColor: Color = Theme.surfaceHover,
        foregroundColor: Color = Theme.primary,
        cornerRadius: CGFloat = 3
    ) {
        self.current = current
        self.total = total
        self.height = height
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.cornerRadius = cornerRadius
    }

    private var progress: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(current) / CGFloat(total)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
                    .frame(height: height)

                // Progress fill with glow
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(foregroundColor)
                    .frame(width: geometry.size.width * progress, height: height)
                    .shadow(color: foregroundColor.opacity(0.6), radius: 10, x: 0, y: 0)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        VStack(alignment: .leading, spacing: 8) {
            Text("Question 2 of 6")
                .foregroundStyle(.white)
            ProgressBarView(current: 2, total: 6)
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Question 5 of 6")
                .foregroundStyle(.white)
            ProgressBarView(current: 5, total: 6)
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Complete")
                .foregroundStyle(.white)
            ProgressBarView(current: 6, total: 6)
        }
    }
    .padding()
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
