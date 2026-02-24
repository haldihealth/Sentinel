import SwiftUI
import LocalAuthentication

struct AppLockView: View {
    let onUnlock: () -> Void

    @State private var authFailed = false
    @State private var isAuthenticating = false
    @State private var biometryType: LABiometryType = .none

    private var biometricIcon: String {
        biometryType == .faceID ? "faceid" : "touchid"
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: Spacing.xxxl) {
                Spacer()

                // Logo
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Theme.primary.opacity(0.15))
                        .frame(width: 72, height: 72)
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Theme.primary)
                        .rotationEffect(.degrees(-45))
                }

                VStack(spacing: Spacing.sm) {
                    Text("SENTINEL")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .tracking(3)
                    Text("LOCKED")
                        .font(Typography.sectionHeader)
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(2)
                }

                Spacer()

                // Unlock button
                VStack(spacing: Spacing.md) {
                    if authFailed {
                        Text("Authentication failed. Try again.")
                            .font(Typography.caption)
                            .foregroundStyle(Theme.emergency)
                    }

                    Button(action: {
                        Task { await authenticate() }
                    }) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: biometricIcon)
                                .font(.system(size: 20, weight: .medium))
                            Text("Tap to Unlock")
                                .font(Typography.buttonLarge)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Theme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
                    }
                    .disabled(isAuthenticating)
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.bottom, Spacing.xxxl)
            }
        }
        .task {
            // Detect biometry type once
            let context = LAContext()
            var error: NSError?
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                biometryType = context.biometryType
            }

            // Auto-trigger Face ID on appear
            await authenticate()
        }
    }

    private func authenticate() async {
        isAuthenticating = true
        defer { isAuthenticating = false }

        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Biometrics not available — fall through to app
            onUnlock()
            return
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Authenticate to access Sentinel"
            )
            if success {
                authFailed = false
                onUnlock()
            } else {
                authFailed = true
            }
        } catch {
            authFailed = true
        }
    }
}
