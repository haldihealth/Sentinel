import SwiftUI

/// Main entry point for the Safety Plan feature
/// Shows creation options if no plan exists, or the dashboard view if plan exists
struct SafetyPlanView: View {
    @StateObject private var viewModel = SafetyPlanViewModel()
    @State private var showWizard = false
    @State private var showOCRScanner = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.hasPlan {
                    SafetyPlanDisplayView(viewModel: viewModel)
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Safety Plan")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    emergencyButton
                }
            }
        }
        .task {
            await viewModel.loadSafetyPlan()
        }
        .fullScreenCover(isPresented: $showWizard) {
            SafetyPlanWizardView(viewModel: viewModel)
        }
        .sheet(isPresented: $showOCRScanner) {
            SafetyPlanOCRView(viewModel: viewModel)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.primary))
                .scaleEffect(1.5)

            Text("Loading your safety plan...")
                .font(Typography.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    // MARK: - Empty State (No Plan Yet)

    private var emptyStateView: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                // Illustration
                illustrationView

                // Description
                descriptionView

                // Creation options
                creationOptionsView

                // Info card
                infoCard
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.xxxl)
        }
        .background(Theme.background)
    }

    private var illustrationView: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                // Background circles
                Circle()
                    .fill(Theme.primary.opacity(0.1))
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(Theme.primary.opacity(0.2))
                    .frame(width: 120, height: 120)

                // Shield icon
                Image(systemName: "shield.checkered")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.primary)
            }

            VStack(spacing: Spacing.sm) {
                Text("Create Your Safety Plan")
                    .font(Typography.title)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("A personalized plan to help you stay safe during difficult moments")
                    .font(Typography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var descriptionView: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("WHAT'S INCLUDED")
                .font(Typography.captionSmall)
                .foregroundStyle(.secondary)
                .tracking(1)

            VStack(spacing: Spacing.sm) {
                featureRow(icon: "exclamationmark.triangle.fill", color: Theme.riskModerate, text: "Warning signs to recognize")
                featureRow(icon: "brain.head.profile", color: Theme.primary, text: "Coping strategies")
                featureRow(icon: "person.2.fill", color: .blue, text: "People & places for support")
                featureRow(icon: "staroflife.fill", color: Theme.emergency, text: "Professional contacts")
                featureRow(icon: "shield.checkered", color: .orange, text: "Environment safety steps")
                featureRow(icon: "heart.fill", color: .pink, text: "Reasons for living")
            }
        }
        .padding(Spacing.lg)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
    }

    private func featureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 24)

            Text(text)
                .font(Typography.body)
                .foregroundStyle(.white)

            Spacer()
        }
    }

    private var creationOptionsView: some View {
        VStack(spacing: Spacing.md) {
            // Start fresh button
            Button(action: { showWizard = true }) {
                HStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Theme.primary.opacity(0.2))
                            .frame(width: 52, height: 52)

                        Image(systemName: "pencil.line")
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.primary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start Fresh")
                            .font(Typography.bodyEmphasis)
                            .foregroundStyle(.white)

                        Text("Build your plan step by step")
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(Spacing.lg)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
            }
            .buttonStyle(.plain)

            // Scan existing button
            Button(action: { showOCRScanner = true }) {
                HStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Theme.primary.opacity(0.2))
                            .frame(width: 52, height: 52)

                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.primary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scan Existing Plan")
                            .font(Typography.bodyEmphasis)
                            .foregroundStyle(.white)

                        Text("Import from a paper copy")
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(Spacing.lg)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
            }
            .buttonStyle(.plain)
        }
    }

    private var infoCard: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Theme.primary)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Based on the Stanley-Brown Protocol")
                    .font(Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text("This evidence-based safety planning intervention is used by the VA and mental health professionals nationwide.")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.md)
        .background(Theme.primary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
    }

    // MARK: - Emergency Button

    private var emergencyButton: some View {
        Button(action: call988) {
            Image(systemName: "phone.fill")
                .font(.system(size: 16))
                .foregroundStyle(Theme.emergency)
                .frame(width: 36, height: 36)
                .background(Theme.emergency.opacity(0.1))
                .clipShape(Circle())
        }
    }

    private func call988() {
        guard let url = URL(string: "tel://988") else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Preview

#Preview("Empty State") {
    SafetyPlanView()
        .preferredColorScheme(.dark)
}

#Preview("With Plan") {
    let view = SafetyPlanView()
    // Note: In actual preview, the viewModel would need to be pre-populated
    return view.preferredColorScheme(.dark)
}
