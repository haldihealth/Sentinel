import SwiftUI

struct RecheckOverlayView: View {
    var onStable: () -> Void
    var onSame: () -> Void
    var onWorse: () -> Void

    var body: some View {
        ZStack {
            // Liquid glass blur background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                // Icon
                Image(systemName: "heart.text.square")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.primary)
                    .symbolEffect(.pulse, options: .repeating)
                
                // Header text
                VStack(spacing: Spacing.sm) {
                    Text("RECHECK")
                        .font(Typography.sectionHeader)
                        .foregroundStyle(.gray)
                        .tracking(2)
                    
                    Text("How are you feeling?")
                        .font(Typography.largeTitle)
                        .foregroundStyle(.white)
                }
                
                Text("You've been taking steps to get through a hard moment.")
                    .font(Typography.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, Spacing.lg)

                VStack(spacing: Spacing.md) {
                    // More stable - Green
                    Button(action: onStable) {
                        HStack(spacing: Spacing.md) {
                            Image(systemName: "arrow.down.heart.fill")
                                .font(.system(size: 20))
                            Text("MORE STABLE")
                                .font(Typography.buttonLarge)
                                .tracking(1)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                    }

                    // About the same - Yellow/Orange
                    Button(action: onSame) {
                        HStack(spacing: Spacing.md) {
                            Image(systemName: "equal")
                                .font(.system(size: 20, weight: .bold))
                            Text("ABOUT THE SAME")
                                .font(Typography.buttonLarge)
                                .tracking(1)
                        }
                        .foregroundStyle(Theme.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                    }

                    // Still not safe - Red
                    Button(action: onWorse) {
                        HStack(spacing: Spacing.md) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 20))
                            Text("STILL NOT SAFE")
                                .font(Typography.buttonLarge)
                                .tracking(1)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [Color.red, Color.red.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.md)
            }
            .padding(Spacing.lg)
        }
    }
}
