import SwiftUI

/// Sheet shown when user indicates they are "Still not safe" during recheck
struct EscalationSheetView: View {
    var onCall988: () -> Void
    var onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: Spacing.xl) {
                // Warning icon
                Image(systemName: "phone.arrow.up.right.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse, options: .repeating)
                
                VStack(spacing: Spacing.sm) {
                    Text("IMMEDIATE SUPPORT")
                        .font(Typography.sectionHeader)
                        .foregroundStyle(.gray)
                        .tracking(2)
                    
                    Text("You're not alone")
                        .font(Typography.largeTitle)
                        .foregroundStyle(.white)
                }
                
                Text("The 988 Suicide & Crisis Lifeline provides free, confidential support 24/7. Trained counselors are ready to help.")
                    .font(Typography.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, Spacing.lg)
                
                VStack(spacing: Spacing.md) {
                    // Call 988 button
                    Button(action: onCall988) {
                        HStack(spacing: Spacing.md) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 24, weight: .semibold))
                            Text("CALL 988 NOW")
                                .font(Typography.buttonLarge)
                                .tracking(1.5)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Theme.emergency)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                    }
                    
                    // Dismiss option
                    Button(action: onDismiss) {
                        Text("Go back")
                            .font(Typography.headline)
                            .foregroundStyle(.white.opacity(0.6))
                            .padding()
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.md)
            }
            .padding(Spacing.lg)
        }
    }
}
