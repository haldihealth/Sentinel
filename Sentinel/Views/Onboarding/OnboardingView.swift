import SwiftUI
import LocalAuthentication

struct OnboardingView: View {
    static let biometricsKey = "sentinel.settings.biometrics"

    let localStorage: LocalStorage
    let onComplete: () -> Void

    @State private var step: OnboardingStep = .welcome
    @State private var biometricError: String?
    @State private var biometryType: LABiometryType = .none

    private enum OnboardingStep {
        case welcome
        case faceID
    }

    private var biometricIcon: String {
        biometryType == .faceID ? "faceid" : "touchid"
    }

    private var biometricName: String {
        biometryType == .faceID ? "Face ID" : "Touch ID"
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            switch step {
            case .welcome:
                welcomeStep
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            case .faceID:
                faceIDStep
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .task {
            let context = LAContext()
            var error: NSError?
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                biometryType = context.biometryType
            }
        }
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo
            ZStack {
                Circle()
                    .fill(Theme.primary.opacity(0.15))
                    .frame(width: 120, height: 120)
                Circle()
                    .fill(Theme.primary.opacity(0.08))
                    .frame(width: 180, height: 180)
                RoundedRectangle(cornerRadius: 24)
                    .fill(Theme.primary)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(-45))
                    )
            }
            .padding(.bottom, Spacing.xxxl)

            // Title
            Text("SENTINEL")
                .font(.system(size: 36, weight: .bold, design: .default))
                .foregroundStyle(.white)
                .tracking(4)
                .padding(.bottom, Spacing.sm)

            Text("Everything stays on-device. Private. Yours.")
                .font(Typography.body)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.bottom, Spacing.xxxl)

            // Bullet points
            VStack(alignment: .leading, spacing: Spacing.lg) {
                featureRow(icon: "cpu", text: "On-device AI — nothing leaves your phone")
                featureRow(icon: "icloud.slash", text: "No cloud. No accounts. No tracking.")
                featureRow(icon: "lock.shield", text: "Your data, encrypted and local")
            }
            .padding(.horizontal, Spacing.xxxl)

            Spacer()
            Spacer()

            // Continue button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.35)) {
                    step = .faceID
                }
            }) {
                Text("CONTINUE")
                    .font(Typography.buttonLarge)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Theme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.bottom, Spacing.xxxl)
        }
    }

    // MARK: - Face ID Setup

    private var faceIDStep: some View {
        VStack(spacing: 0) {
            Spacer()

            // Face ID icon
            ZStack {
                Circle()
                    .fill(Theme.primary.opacity(0.15))
                    .frame(width: 120, height: 120)
                Circle()
                    .fill(Theme.primary.opacity(0.08))
                    .frame(width: 180, height: 180)
                Image(systemName: biometricIcon)
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(Theme.primary)
            }
            .padding(.bottom, Spacing.xxxl)

            Text("SECURE WITH \(biometricName.uppercased())")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .tracking(2)
                .padding(.bottom, Spacing.sm)

            Text("Sentinel locks automatically.\nOnly you can access it.")
                .font(Typography.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.bottom, Spacing.md)

            if let error = biometricError {
                Text(error)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.emergency)
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.bottom, Spacing.md)
            }

            Spacer()
            Spacer()

            VStack(spacing: Spacing.md) {
                // Enable button
                Button(action: {
                    Task { await enableBiometrics() }
                }) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: biometricIcon)
                            .font(.system(size: 18, weight: .medium))
                        Text("ENABLE \(biometricName.uppercased())")
                            .font(Typography.buttonLarge)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Theme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
                }

                // Skip button
                Button(action: {
                    completeOnboarding(biometricsEnabled: false)
                }) {
                    Text("Skip for Now")
                        .font(Typography.headline)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding()
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.bottom, Spacing.xxxl)
        }
    }

    // MARK: - Helpers

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.primary)
                .frame(width: 28)
            Text(text)
                .font(Typography.body)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private func enableBiometrics() async {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometricError = "Biometrics not available on this device."
            return
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Set up biometric authentication for Sentinel"
            )
            if success {
                completeOnboarding(biometricsEnabled: true)
            }
        } catch {
            biometricError = "Authentication failed. Try again or skip."
        }
    }

    private func completeOnboarding(biometricsEnabled: Bool) {
        // Save biometrics preference
        UserDefaults.standard.set(biometricsEnabled, forKey: Self.biometricsKey)

        // Mark onboarding complete on the profile
        var profile = localStorage.loadUserProfile() ?? UserProfile()
        profile.hasCompletedOnboarding = true
        localStorage.saveUserProfile(profile)

        onComplete()
    }
}
