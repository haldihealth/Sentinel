import Foundation
import SwiftUI
import LocalAuthentication
import AVFoundation
import HealthKit
import Combine
import SwiftData
import OSLog

/// ViewModel for Mission Profile (Settings/Dossier) screen
@MainActor
final class MissionProfileViewModel: ObservableObject {
    // MARK: - Published State

    @Published var userProfile: UserProfile
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - OPSEC Settings

    @Published var isLocalOnly: Bool = false {
        didSet { toggleLocalOnlyMode(isLocalOnly) }
    }
    @Published var useBiometrics: Bool = true
    @Published var autoLockTimer: AutoLockTimer = .oneMinute

    // MARK: - COMMS Settings

    @Published var checkInRemindersEnabled: Bool = true
    @Published var crisisAlertSensitivity: Bool = true
    @Published var silentHoursEnabled: Bool = true
    @Published var silentHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 22)) ?? Date()
    @Published var silentHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 6)) ?? Date()

    // MARK: - Sensor Status (Read-Only)

    @Published var healthKitStatus: PermissionStatus = .unknown
    @Published var cameraStatus: PermissionStatus = .unknown
    @Published var microphoneStatus: PermissionStatus = .unknown
    @Published var clinicalFeedStatus: PermissionStatus = .disconnected

    // MARK: - Neural Engine Status

    @Published var modelStatus: NeuralEngineStatus = .unknown
    @Published var modelName: String = "MedGemma-4B-Q4"
    @Published var lastInferenceTime: String = "—"
    @Published var isDiagnosticsRunning = false

    // MARK: - UI State

    @Published var showResetConfirmation = false

    @Published var showBranchPicker = false
    
    // Developer Mode
    @Published var showDeveloperModeAlert = false
    @Published var showDeveloperModeSuccess = false
    @Published var isLoadingDeveloperMode = false
    @Published var showVideoImporter = false
    @Published var demoVideoName: String?

    // MARK: - Simulation Settings
    
    @Published var isSimulationEnabled: Bool = false
    @Published var selectedScenario: SimulationScenario = .normal
    
    // MARK: - Dependencies
    
    private let localStorage: LocalStorage
    private let healthKitManager: HealthKitManager?
    
    // MARK: - Initialization
    
    init(localStorage: LocalStorage = LocalStorage()) {
        self.localStorage = localStorage
        
        // Always initialize HealthKitManager to support simulation on all devices
        self.healthKitManager = HealthKitManager()
        
        // Load profile or create default
        if let savedProfile = localStorage.loadUserProfile() {
            self.userProfile = savedProfile
        } else {
            self.userProfile = UserProfile()
        }
        
        // Load saved settings
        loadSettings()

        // Apply simulation if enabled
        if isSimulationEnabled {
            applySimulation()
        }

        // Restore demo video name if a video was previously loaded
        if let videoPath = UserDefaults.standard.string(forKey: "sentinel.developer.demoVideoPath"),
           FileManager.default.fileExists(atPath: videoPath) {
            demoVideoName = URL(fileURLWithPath: videoPath).lastPathComponent
        }
    }
    
    // MARK: - Loading
    
    func loadProfile() async {
        isLoading = true
        defer { isLoading = false }
        
        // Refresh sensor statuses
        await refreshSensorStatuses()
        
        // Refresh neural engine status
        await refreshNeuralEngineStatus()
    }
    
    private func loadSettings() {
        // Load from UserDefaults
        let defaults = UserDefaults.standard
        
        isLocalOnly = defaults.bool(forKey: "sentinel.settings.localOnly")
        useBiometrics = defaults.bool(forKey: "sentinel.settings.biometrics")
        
        if let autoLockRaw = defaults.string(forKey: "sentinel.settings.autoLock"),
           let autoLock = AutoLockTimer(rawValue: autoLockRaw) {
            autoLockTimer = autoLock
        }
        
        checkInRemindersEnabled = defaults.object(forKey: "sentinel.settings.checkInReminders") as? Bool ?? true
        crisisAlertSensitivity = defaults.object(forKey: "sentinel.settings.crisisAlert") as? Bool ?? true
        silentHoursEnabled = defaults.object(forKey: "sentinel.settings.silentHours") as? Bool ?? true
        
        // Simulation Settings
        isSimulationEnabled = defaults.bool(forKey: "sentinel.settings.simulation")
        if let savedScenarioRaw = defaults.string(forKey: "sentinel.settings.scenario"),
           let scenario = SimulationScenario(rawValue: savedScenarioRaw) {
            selectedScenario = scenario
        }
    }
    
    func saveSettings() {
        let defaults = UserDefaults.standard
        
        defaults.set(isLocalOnly, forKey: "sentinel.settings.localOnly")
        defaults.set(useBiometrics, forKey: "sentinel.settings.biometrics")
        defaults.set(autoLockTimer.rawValue, forKey: "sentinel.settings.autoLock")
        defaults.set(checkInRemindersEnabled, forKey: "sentinel.settings.checkInReminders")
        defaults.set(crisisAlertSensitivity, forKey: "sentinel.settings.crisisAlert")
        defaults.set(silentHoursEnabled, forKey: "sentinel.settings.silentHours")
        
        // Simulation Settings
        defaults.set(isSimulationEnabled, forKey: "sentinel.settings.simulation")
        defaults.set(selectedScenario.rawValue, forKey: "sentinel.settings.scenario")
    }

    // MARK: - Profile Updates

    func updateCallsign(_ newCallsign: String) {
        userProfile.callsign = newCallsign
        saveProfile()
    }

    func updatePreferredName(_ name: String) {
        userProfile.preferredName = name.isEmpty ? nil : name
        saveProfile()
    }

    func updateBranch(_ branch: MilitaryBranch?) {
        userProfile.branchOfService = branch
        saveProfile()
    }

    private func saveProfile() {
        localStorage.saveUserProfile(userProfile)
    }

    // MARK: - OPSEC Functions

    func toggleLocalOnlyMode(_ enabled: Bool) {
        // Exclude app data from iCloud backup
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }

        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = enabled

        var mutableURL = url
        try? mutableURL.setResourceValues(resourceValues)

        saveSettings()
    }

    func authenticateWithBiometrics() async -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Authenticate to access Sentinel"
            )
        } catch {
            return false
        }
    }

    func purgeAllData() {
        // Clear all UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }

        // Clear documents directory
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? FileManager.default.removeItem(at: documentsURL)
            try? FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        }

        // Reset to default profile
        userProfile = UserProfile()
    }

    // MARK: - Simulation Functions

    func toggleHealthKitSimulation(_ enabled: Bool) {
        isSimulationEnabled = enabled
        saveSettings()
        
        if enabled {
            applySimulation()
        } else {
            Task { await healthKitManager?.disableSimulation() }
            Task { await refreshSensorStatuses() }
        }
    }
    
    func loadSimulatedScenario(_ scenario: SimulationScenario) {
        selectedScenario = scenario
        saveSettings()
        if isSimulationEnabled {
            applySimulation()
        }
    }
    
    private func applySimulation() {
        guard let manager = healthKitManager else { return }
        let scenario = selectedScenario
        Task {
            let data = scenario.generateData()
            await manager.enableSimulation(with: data)
            await refreshSensorStatuses()
        }
    }

    // MARK: - Sensor Status

    func refreshSensorStatuses() async {
        // HealthKit
        if let manager = healthKitManager, await manager.isSimulationActive {
            healthKitStatus = .authorized
        } else if HKHealthStore.isHealthDataAvailable() {
            let status = HKHealthStore().authorizationStatus(for: HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!)
            switch status {
            case .sharingAuthorized:
                healthKitStatus = .authorized
            case .sharingDenied:
                healthKitStatus = .denied
            default:
                healthKitStatus = .notDetermined
            }
        } else {
            healthKitStatus = .unavailable
        }

        // Camera
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraStatus = .authorized
        case .denied, .restricted:
            cameraStatus = .denied
        case .notDetermined:
            cameraStatus = .notDetermined
        @unknown default:
            cameraStatus = .unknown
        }

        // Microphone
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            microphoneStatus = .authorized
        case .denied, .restricted:
            microphoneStatus = .denied
        case .notDetermined:
            microphoneStatus = .notDetermined
        @unknown default:
            microphoneStatus = .unknown
        }
    }

    // MARK: - Neural Engine

    func refreshNeuralEngineStatus() async {
        let engine = MedGemmaEngine.shared

        if await engine.isModelLoaded() {
            modelStatus = .ready
            lastInferenceTime = getLastInferenceTime()
        } else {
            modelStatus = .notLoaded
            lastInferenceTime = "—"
        }
    }

    func runDiagnostics() async {
        isDiagnosticsRunning = true
        modelStatus = .scanning

        // Simulate diagnostic check
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        let engine = MedGemmaEngine.shared
        if await engine.isModelLoaded() {
            modelStatus = .ready
        } else {
            // Try to load model
            do {
                try await engine.loadModel()
                modelStatus = .ready
            } catch {
                modelStatus = .error
            }
        }

        isDiagnosticsRunning = false
    }



    private func getLastInferenceTime() -> String {
        // Would need to track this in MedGemmaEngine
        return "Recent"
    }

    // MARK: - App Info

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (Build \(build))"
    }

    // MARK: - Instant Simulation
    
    func performSimulatedCheckIn(context: ModelContext) {
        guard isSimulationEnabled else { return }
        
        let scenario = selectedScenario
        let now = Date()
        
        // 1. Generate Data
        let healthData = scenario.generateData()
        let simManager = CheckInSimulationManager()
        
        let transcript = simManager.getSimulatedTranscript(for: scenario)
        let wpm = simManager.getSimulatedWPM(for: scenario)
        let answers = simManager.getSuggestedCSSRSAnswers(for: scenario)
        
        // 2. Create Record
        let record = CheckInRecord(type: "interval-multimodal")
        record.timestamp = now
        // record.checkInType is set by init but we can ensure it
        
        // Create Audio Metadata for Transcript
        let audioMeta = AudioMetadata(duration: 30.0, sampleRate: 44100.0, transcript: transcript)
        record.audioMetadata = audioMeta
        
        // Note: WPM is not stored directly on CheckInRecord model currently.
        
        // 3. Apply C-SSRS Answers
        record.q1WishDead = answers[0]
        record.q2SuicidalThoughts = answers[1]
        record.q3ThoughtsWithMethod = answers[2]
        record.q4Intent = answers[3]
        record.q5Plan = answers[4]
        record.q6RecentAttempt = answers[5]
        
        // 4. Calculate Risk Trigger
        let calculatedRisk = RiskCalculator.calculateRiskTier(from: record)
        record.determinedRiskTier = String(calculatedRisk.rawValue)
        record.derivedRiskSource = "Simulated (\(scenario.rawValue))"
        record.riskExplanation = "This is a simulated check-in based on the '\(scenario.rawValue)' scenario."
        
        // 5. Insert
        context.insert(record)
        
        // 6. Save
        try? context.save()
        
        // Feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - Supporting Types

enum AutoLockTimer: String, CaseIterable {
    case immediate = "Immediate"
    case oneMinute = "1 min"
    case fiveMinutes = "5 min"

    var seconds: Int {
        switch self {
        case .immediate: return 0
        case .oneMinute: return 60
        case .fiveMinutes: return 300
        }
    }
}

enum PermissionStatus {
    case authorized
    case denied
    case notDetermined
    case unavailable
    case disconnected
    case unknown

    var displayText: String {
        switch self {
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .notDetermined: return "Not Set"
        case .unavailable: return "Unavailable"
        case .disconnected: return "Disconnected"
        case .unknown: return "Unknown"
        }
    }

    var iconName: String {
        switch self {
        case .authorized: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .notDetermined: return "questionmark.circle.fill"
        case .unavailable: return "minus.circle.fill"
        case .disconnected: return "link.badge.plus"
        case .unknown: return "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .authorized: return Theme.primary
        case .denied: return Theme.emergency
        case .notDetermined: return .orange
        case .unavailable: return .secondary
        case .disconnected: return .secondary
        case .unknown: return .secondary
        }
    }
}

enum NeuralEngineStatus {
    case ready
    case loading
    case notLoaded
    case scanning
    case error
    case unknown

    var displayText: String {
        switch self {
        case .ready: return "READY"
        case .loading: return "LOADING..."
        case .notLoaded: return "NOT LOADED"
        case .scanning: return "SCANNING..."
        case .error: return "ERROR"
        case .unknown: return "UNKNOWN"
        }
    }

    var color: Color {
        switch self {
        case .ready: return Theme.primary
        case .loading, .scanning: return .orange
        case .notLoaded: return .secondary
        case .error: return Theme.emergency
        case .unknown: return .secondary
        }
    }
}

enum SimulationScenario: String, CaseIterable, Identifiable {
    case normal = "Normal Baseline"
    case doingWell = "Doing Well (Optimal)"
    case decompensating = "Decompensating (Trending Down)"
    case erratic = "Erratic / Volatile"
    case highRisk = "High Risk (Sleep/HRV)"
    case sleepDeprived = "Sleep Deprived"
    case sedentary = "Sedentary/Withdrawal"
    
    var id: String { rawValue }
    
    func generateData() -> HealthData {
        let now = Date()
        var baseline = Baseline(lastUpdated: now)
        // Standard baseline for reference
        baseline.avgSleepHours = 7.5
        baseline.sleepStdDev = 1.0
        baseline.avgSteps = 8000
        baseline.stepsStdDev = 2000
        baseline.avgHRV = 60
        baseline.hrvStdDev = 10
        
        var sleep: SleepMetrics
        var activity: ActivityMetrics
        var hrv: HRVMetrics
        
        switch self {
        case .normal:
            sleep = SleepMetrics(date: now, totalSleepHours: 7.2, timeInBedHours: 8.0)
            activity = ActivityMetrics(date: now, stepCount: 8500, activeCalories: 400, distanceMeters: 5000)
            hrv = HRVMetrics(date: now, sdnn: 58, restingHeartRate: 65)
            
        case .doingWell:
            // 2 weeks of good metrics
            sleep = SleepMetrics(date: now, totalSleepHours: 8.0, timeInBedHours: 8.5) // Above average
            activity = ActivityMetrics(date: now, stepCount: 10000, activeCalories: 600, distanceMeters: 7000) // Highly active
            hrv = HRVMetrics(date: now, sdnn: 75, restingHeartRate: 58) // High resilience
            
        case .decompensating:
            // All numbers down trending significantly
            sleep = SleepMetrics(date: now, totalSleepHours: 5.5, timeInBedHours: 9.0) // Low efficiency
            activity = ActivityMetrics(date: now, stepCount: 3000, activeCalories: 150) // Withdrawal
            hrv = HRVMetrics(date: now, sdnn: 35, restingHeartRate: 78) // Rising stress
            
        case .erratic:
            // Volatile - good one day, bad next (represented as high instant variance vs baseline)
            sleep = SleepMetrics(date: now, totalSleepHours: 3.0, timeInBedHours: 4.0) // Acute insomnia
            activity = ActivityMetrics(date: now, stepCount: 15000, activeCalories: 900) // Manic energy?
            hrv = HRVMetrics(date: now, sdnn: 20, restingHeartRate: 90) // Acute stress
            
        case .highRisk:
            sleep = SleepMetrics(date: now, totalSleepHours: 4.0, timeInBedHours: 5.0)
            activity = ActivityMetrics(date: now, stepCount: 2000, activeCalories: 100)
            hrv = HRVMetrics(date: now, sdnn: 25, restingHeartRate: 85)
            
        case .sleepDeprived:
            sleep = SleepMetrics(date: now, totalSleepHours: 4.5, timeInBedHours: 5.0)
            activity = ActivityMetrics(date: now, stepCount: 7500, activeCalories: 350)
            hrv = HRVMetrics(date: now, sdnn: 55, restingHeartRate: 68)
            
        case .sedentary:
            sleep = SleepMetrics(date: now, totalSleepHours: 7.0, timeInBedHours: 8.0)
            activity = ActivityMetrics(date: now, stepCount: 1500, activeCalories: 50)
            hrv = HRVMetrics(date: now, sdnn: 50, restingHeartRate: 70)
        }
        
        return HealthData(sleep: sleep, activity: activity, hrv: hrv, baseline: baseline)
    }
}

// MARK: - Developer Mode Extension

extension MissionProfileViewModel {
    /// Activates developer mode by clearing all data and loading demo scenario
    func activateDeveloperMode(modelContext: ModelContext) async {
        isLoadingDeveloperMode = true

        // Call service
        await DeveloperModeService.shared.activateDemoMode(modelContext: modelContext)

        isLoadingDeveloperMode = false
        showDeveloperModeSuccess = true
    }

    /// Copies a user-selected video to the app's Documents directory and
    /// saves the path so the next check-in uses it as camera input.
    func loadDemoVideo(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            Logger.ai.error("Failed to start accessing security-scoped resource for URL: \(url.lastPathComponent)")
            errorMessage = "Cannot access the selected video file. Please ensure permissions are granted."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            errorMessage = "Cannot access Documents directory."
            return
        }

        let destURL = docDir.appendingPathComponent("sentinel_demo_video.mp4")

        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: url, to: destURL)
            UserDefaults.standard.set(destURL.path, forKey: "sentinel.developer.demoVideoPath")
            demoVideoName = url.lastPathComponent
            Logger.ai.info("Demo video loaded: \(url.lastPathComponent)")
        } catch {
            errorMessage = "Failed to copy video: \(error.localizedDescription)"
        }
    }
}
