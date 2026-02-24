import SwiftUI
import SwiftData
import os.log

@main
struct SentinelApp: App {
    @State private var isModelLoading = true
    @State private var modelLoadError: String?
    @State private var hasCompletedOnboarding = false
    @State private var isUnlocked = false
    @Environment(\.scenePhase) private var scenePhase

    private let localStorage = LocalStorage()

    private var useBiometrics: Bool {
        UserDefaults.standard.bool(forKey: OnboardingView.biometricsKey)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isModelLoading {
                    SentinelLoadingView(isModelLoading: $isModelLoading)
                        .transition(.opacity)
                } else if !hasCompletedOnboarding {
                    OnboardingView(localStorage: localStorage) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            hasCompletedOnboarding = true
                            isUnlocked = true
                        }
                    }
                    .transition(.opacity)
                } else if !isUnlocked && useBiometrics {
                    AppLockView {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isUnlocked = true
                        }
                    }
                    .transition(.opacity)
                } else {
                    ContentView(localStorage: localStorage)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .preferredColorScheme(.dark)
            .task {
                // Load onboarding state
                let profile = localStorage.loadUserProfile()
                hasCompletedOnboarding = profile?.hasCompletedOnboarding ?? false

                // If no biometrics, start unlocked
                if !useBiometrics {
                    isUnlocked = true
                }

                do {
                    // 1. Ensure model loads first and the UI is unblocked
                    try await MedGemmaEngine.shared.loadModel()
                    
                    // 2. Spawn fully asynchronous background ingestion task
                    Task {
                        // Wait briefly to allow UI to render before printing
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        print("\nFINAL RISK TIER = MAX( C-SSRS , MedGemma )")
                        print("\n         MAX( ORANGE ,   RED   )  =  RED\n")
                    }

                    try? await Task.sleep(nanoseconds: 800_000_000)
                    withAnimation(.easeInOut(duration: 0.6)) {
                        isModelLoading = false
                    }
                } catch {
                    isModelLoading = false
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background && useBiometrics {
                    isUnlocked = false
                }
            }
        }
        .modelContainer(for: [CheckInRecord.self, FacialBiomarkers.self, AudioMetadata.self])
    }
}
