import Foundation
import SwiftUI
import SwiftData
import Combine
import os.log
import Vision

/// Manages daily check-in workflow (Behavioral Telemetry + Audio + C-SSRS)
@MainActor
final class CheckInViewModel: NSObject, ObservableObject {

    // MARK: - Published State

    // UI State
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentStep: CheckInStep = .multimodal
    @Published var shouldDismiss = false

    // C-SSRS Navigation (delegated to manager)
    var currentQuestionIndex: Int {
        cssrsManager.currentQuestionIndex
    }

    // Check-In State
    @Published var isRecording = false
    @Published var timeRemaining: TimeInterval = 30.0
    @Published var transcript: String = ""
    @Published var wpm: Double = 0.0
    @Published var currentAudioLevel: Float = -60.0
    @Published var elapsedTime: TimeInterval = 0.0

    // Logic State
    @Published var checkInRecord: CheckInRecord?
    @Published var resultRiskTier: RiskTier?
    @Published var demoTelemetryText: String?

    // Private State
    private var healthData: HealthData?
    private var hasHealthDeviations = false

    // Parallel AI Task
    private var analysisTask: Task<MedGemmaResponse?, Never>?

    // Accumulators
    private var telemetryPoints: [FaceTelemetry] = []
    private var voiceFeatures: VoiceFeatures?
    
    // Face tracking preview
    @Published var currentFaceObservation: VNFaceObservation?

    // Dependencies
    let cameraService = CameraService()
    private let healthKitManager: HealthKitManager
    let audioEngine = AudioEngine()
    private let cssrsManager = CSSRSManager()

    var modelContext: ModelContext?

    // Timer Configuration
    private var checkInTimer: Timer?
    private let totalDuration: TimeInterval = CheckInConfiguration.totalDuration

    // MARK: - Constants
    let totalQuestions = 6

    // MARK: - Initialization

    init(healthKitManager: HealthKitManager = HealthKitManager()) {
        self.healthKitManager = healthKitManager
        super.init()
        setupBindings()

        // Configure Camera
        cameraService.delegate = self
        Task {
            try? await cameraService.configure()
        }
    }

    private func setupBindings() {
        audioEngine.$currentTranscript
            .receive(on: RunLoop.main)
            .assign(to: &$transcript)

        audioEngine.$currentAudioLevel
            .receive(on: RunLoop.main)
            .assign(to: &$currentAudioLevel)
    }

    // MARK: - Check-In Logic

    func startCheckIn() {
        // Reset state
        telemetryPoints = []
        voiceFeatures = nil
        timeRemaining = totalDuration
        elapsedTime = 0
        wpm = 0.0
        transcript = ""
        errorMessage = nil

        Task {
            let audioAuth = await audioEngine.requestAuthorization()
            guard audioAuth else {
                errorMessage = "Microphone access denied"
                return
            }

            // Load demo video if developer mode is active and a video has been selected
            let devModeActive = UserDefaults.standard.bool(forKey: DeveloperModeConstants.developerModeActiveKey)
            var devVideoURL: URL? = nil
            if devModeActive,
               let videoPath = UserDefaults.standard.string(forKey: "sentinel.developer.demoVideoPath"),
               FileManager.default.fileExists(atPath: videoPath) {
                let videoURL = URL(fileURLWithPath: videoPath)
                cameraService.demoVideoURL = videoURL
                devVideoURL = videoURL
            } else {
                cameraService.demoVideoURL = nil
            }

            do {
                if let videoURL = devVideoURL {
                    // Developer mode: bypass mic, read audio from the video file directly.
                    // AVPlayer routes video audio to the speaker; this handles transcription.
                    try audioEngine.startRecordingFromVideoFile(url: videoURL)
                } else {
                    try audioEngine.startRecording()
                }
                cameraService.startTelemetry()
                isRecording = true
                startTimer()
            } catch {
                errorMessage = "Failed to start recording: \(error.localizedDescription)"
            }
        }
    }

    #if DEBUG
    /// Bypasses actual recording and injects mock data for testing
    func simulateDebugCheckIn(customTranscript: String? = nil) {
        checkInTimer?.invalidate()
        checkInTimer = nil
        isRecording = false
        telemetryPoints = []
        
        let defaults = UserDefaults.standard
        let isSimulationEnabled = defaults.bool(forKey: "sentinel.settings.simulation")
        
        if isSimulationEnabled, 
           let scenarioRaw = defaults.string(forKey: "sentinel.settings.scenario"),
           let scenario = SimulationScenario(rawValue: scenarioRaw) {
            
            let simManager = CheckInSimulationManager()
            self.transcript = simManager.getSimulatedTranscript(for: scenario)
            self.wpm = simManager.getSimulatedWPM(for: scenario)
            self.telemetryPoints = simManager.getSimulatedTelemetry(for: scenario)
            
            Logger.checkIn.warning("[Simulation] Using scenario: \(scenario.rawValue)")
            
        } else {
            // Default mock if simulation is OFF but debug is called
            if let custom = customTranscript, !custom.isEmpty {
                self.transcript = custom
            } else {
                self.transcript = "I've been feeling a bit overwhelmed lately. Code reviews are piling up and I'm not sleeping well. But I'm trying to stay positive."
            }
            self.wpm = 125.0
            
            // Mock telemetry — simulate 60 frames at 2fps over 30s
            for i in 0..<60 {
                let t = Double(i) * 0.5
                telemetryPoints.append(FaceTelemetry(
                    timestamp: t,
                    eyeOpenness: 3.5 - Double(i) * 0.02,
                    headPitch: -0.02 - Double(i) * 0.001,
                    gazeDeviation: 2.0 + Double(i) * 0.05
                ))
            }
        }

        // Mock voice features
        self.voiceFeatures = VoiceFeatures(durationSeconds: 30.0)

        Logger.checkIn.debug("[Debug] Simulating Check-In with Mock Data")
        finishProcessing(audioUrl: nil)
    }
    #endif

    private func startTimer() {
        var elapsed = 0

        checkInTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }

            elapsed += 1
            self.timeRemaining = max(0, self.totalDuration - Double(elapsed))
            self.elapsedTime = Double(elapsed)

            if elapsed >= Int(self.totalDuration) {
                Task { @MainActor in
                    self.stopCheckIn()
                }
            }
        }
    }

    func stopCheckIn() {
        checkInTimer?.invalidate()
        checkInTimer = nil
        isRecording = false

        // Stop telemetry capture
        cameraService.stopTelemetry()

        // Stop audio and get voice features
        let (url, finalTranscript, finalWPM, features) = audioEngine.stopRecording()
        self.wpm = finalWPM
        self.transcript = finalTranscript
        self.voiceFeatures = features

        finishProcessing(audioUrl: url)
    }

    private func finishProcessing(audioUrl: URL?) {
        isLoading = true

        Task {
            // 1. Generate Behavioral Telemetry Report
            Logger.checkIn.warning("📹 Check-in Complete. Analyzing Multimodal Telemetry...")
            Logger.checkIn.warning("   -> Captured \(self.telemetryPoints.count) high-frequency facial telemetry frames")
            if let features = self.voiceFeatures {
                Logger.checkIn.warning("   -> Captured \(String(format: "%.1f", features.durationSeconds))s audio with WPM: \(String(format: "%.0f", self.wpm))")
            }
            let behavioralReport = VisualScribe.generateReport(from: telemetryPoints)
            Logger.checkIn.info("   -> VisualScribe generated text representation of physical biomarkers")

            // 2. Create Record
            let record = CheckInRecord(type: "behavioral-telemetry")
            record.checkInType = "interval-multimodal"
            if let context = modelContext {
                context.insert(record)
            }
            self.checkInRecord = record

            // 3. Capture voice features for prompt
            let capturedVoiceFeatures = self.voiceFeatures

            // 4. START PARALLEL AI Triage (Health + Audio/Visual)
            self.analysisTask = Task {
                Logger.checkIn.warning("🧠 Merging physiological data, behavioral telemetry, and clinical history for MedGemma...")

                // Health Data Fetch (will use simulation if enabled in HealthKitManager)
                await self.fetchHealthData()
                
                // Log if using simulation
                if let health = self.healthData, 
                   UserDefaults.standard.bool(forKey: "sentinel.settings.simulation") {
                    Logger.checkIn.warning("Analysis using SIMULATED HealthKit Data")
                }

                // Generate and publish the real-time demo text
                await MainActor.run {
                    self.generateDemoTelemetryText(
                        voiceFeatures: capturedVoiceFeatures,
                        telemetryPoints: self.telemetryPoints,
                        healthData: self.healthData
                    )
                }

                do {
                    let response = try await MedGemmaEngine.shared.analyze(
                        record: record,
                        healthData: self.healthData,
                        userProfile: nil,
                        visualLog: behavioralReport,
                        wpm: self.wpm,
                        transcript: self.transcript,
                        voiceFeatures: capturedVoiceFeatures
                    )
                    
                    await MainActor.run {
                        let tierStr = String(describing: response.assessedRisk ?? .low).uppercased()
                        let rationale = response.insights.first ?? ""
                        
                        var newLines = "[MedGemma] Risk tier proposal: \(tierStr)"
                        if !rationale.isEmpty {
                            newLines += "\n[MedGemma] \(rationale)"
                        }
                        
                        self.demoTelemetryText = (self.demoTelemetryText ?? "") + "\n" + newLines
                        
                        Logger.checkIn.debug("\n\(newLines)")
                    }
                    
                    return response
                } catch {
                    Logger.ai.error("Failed: \(error.localizedDescription)")
                    await MainActor.run {
                        Logger.checkIn.debug("\n[MedGemma] Inference failed.")
                    }
                    return nil
                }
            }

            isLoading = false

            // Clear telemetry from memory
            self.telemetryPoints = []

            // 5. Move to C-SSRS
            await MainActor.run {
                self.cssrsManager.reset()
                self.currentStep = .cssrs(questionIndex: 0)
            }
        }
    }

    func skipMultimodal() {
        let record = CheckInRecord(type: "cssrs-only")
        if let context = modelContext {
            context.insert(record)
        }
        self.checkInRecord = record
        cssrsManager.reset()
        currentStep = .cssrs(questionIndex: 0)
    }

    // MARK: - C-SSRS Logic (using CSSRSManager)

    func answerCurrentQuestion(_ answer: Bool) {
        guard let record = checkInRecord else { return }

        let hasMore = cssrsManager.submitAnswer(answer)

        if (currentQuestionIndex == 3 && answer) || (currentQuestionIndex == 4 && answer) {
            completeWithCrisis()
            return
        }

        if hasMore {
            currentStep = .cssrs(questionIndex: cssrsManager.currentQuestionIndex)
        } else {
            cssrsManager.applyAnswers(to: record)
            completeCheckIn()
        }
    }

    func goBack() {
        cssrsManager.goBack()
        currentStep = .cssrs(questionIndex: cssrsManager.currentQuestionIndex)
    }

    private func completeWithCrisis() {
        guard let record = checkInRecord else {
            shouldDismiss = true
            return
        }

        cssrsManager.applyAnswers(to: record)

        record.determinedRiskTier = String(RiskTier.crisis.rawValue)
        resultRiskTier = .crisis
        try? modelContext?.save()

        Task {
            await LCSCManager.updateNarrative(record: record, health: self.healthData, risk: .crisis)
        }

        shouldDismiss = true
    }

    private func completeCheckIn() {
        Task {
            await submitCheckIn()
        }
    }

    func submitCheckIn() async {
        isLoading = true
        defer { isLoading = false }
        guard let record = checkInRecord else { return }

        let submissionManager = CheckInSubmissionManager(healthKitManager: healthKitManager, modelContext: modelContext)

        let (finalRisk, updatedHealthData) = await submissionManager.processSubmission(
            record: record,
            currentHealthData: self.healthData,
            analysisTask: analysisTask,
            fallbackVisualLog: "User skipped visual check-in.",
            fallbackTranscript: "User skipped audio check-in."
        )

        self.resultRiskTier = finalRisk
        if let health = updatedHealthData {
            self.healthData = health
            self.hasHealthDeviations = checkForHealthDeviations(health)
        }

        shouldDismiss = true
    }

    func reset() {
        checkInRecord = nil
        currentStep = .multimodal
        cssrsManager.reset()
        resultRiskTier = nil
        errorMessage = nil
        telemetryPoints = []
        voiceFeatures = nil
        transcript = ""
        wpm = 0.0
        currentFaceObservation = nil
    }

    // MARK: - Private Logic

    private func fetchHealthData() async {
        do {
            _ = try await healthKitManager.requestAuthorization()

            self.healthData = try await healthKitManager.fetchHealthData(timeout: CheckInConfiguration.healthDataTimeoutSeconds)
            Logger.healthKit.info("Health data fetched successfully")
            self.hasHealthDeviations = checkForHealthDeviations(healthData)
        } catch {
            Logger.healthKit.error("Failed to fetch health data: \(error.localizedDescription)")
            self.healthData = nil
        }
    }

    private func checkForHealthDeviations(_ healthData: HealthData?) -> Bool {
        healthData?.deviations.hasSignificantDeviation ?? false
    }

    private func generateDemoTelemetryText(voiceFeatures: VoiceFeatures?, telemetryPoints: [FaceTelemetry], healthData: HealthData?) {
        var lines: [String] = []

        // === AUDIO / vDSP ===

        // Mean pitch
        if let meanPitch = voiceFeatures?.meanPitch, meanPitch > 0 {
            let meanPitchLabel: String
            switch meanPitch {
            case ..<100: meanPitchLabel = "unusually low"
            case 100..<150: meanPitchLabel = "low end"
            case 150..<250: meanPitchLabel = "normal range"
            default: meanPitchLabel = "elevated"
            }
            lines.append("[Audio/vDSP] Mean pitch: \(String(format: "%.1f", meanPitch))Hz — \(meanPitchLabel)")
        }

        // Pitch variability
        let pitchVar = voiceFeatures?.pitchVariability ?? 0.0
        let pitchVarLabel: String
        switch pitchVar {
        case ..<15:  pitchVarLabel = "severely flat"
        case 15..<30: pitchVarLabel = "reduced variability"
        case 30..<60: pitchVarLabel = "normal range"
        default:     pitchVarLabel = "elevated variability"
        }
        lines.append("[Audio/vDSP] Pitch variance: \(String(format: "%.1f", pitchVar))Hz — \(pitchVarLabel)")

        // Speech energy
        let energy = voiceFeatures?.meanEnergy ?? -60.0
        let energyLabel: String
        switch energy {
        case ..<(-50): energyLabel = "critically suppressed"
        case (-50)..<(-40): energyLabel = "suppressed"
        case (-40)..<(-25): energyLabel = "below baseline"
        case (-25)..<(-10): energyLabel = "normal range"
        default: energyLabel = "elevated"
        }
        lines.append("[Audio/vDSP] Speech energy: \(String(format: "%.0f", energy))dB — \(energyLabel)")

        // Energy variability
        if let energyVar = voiceFeatures?.energyVariability {
            let evLabel: String
            switch energyVar {
            case ..<3: evLabel = "monotone delivery"
            case 3..<6: evLabel = "low variability"
            case 6..<12: evLabel = "normal"
            default: evLabel = "high variability"
            }
            lines.append("[Audio/vDSP] Energy variability: \(String(format: "%.1f", energyVar))dB — \(evLabel)")
        }

        // Speech rate as % deviation from 130wpm baseline
        let currentWPM = self.wpm
        let baselineWPM = 130.0
        let wpmPct = Int(((currentWPM - baselineWPM) / baselineWPM) * 100)
        let wpmLabel: String
        if currentWPM < 100 {
            let absPct = Swift.abs(wpmPct)
            wpmLabel = "-\(absPct)% below baseline"
        } else if currentWPM <= 160 {
            wpmLabel = "within normal range"
        } else {
            wpmLabel = "+\(wpmPct)% above baseline"
        }
        lines.append("[Audio/vDSP] Speech rate: \(String(format: "%.0f", currentWPM))wpm — \(wpmLabel)")

        // Speech ratio
        if let speechPct = voiceFeatures?.speechPercentage {
            let speechPctLabel: String
            switch speechPct {
            case ..<40: speechPctLabel = "low engagement"
            case 40..<60: speechPctLabel = "moderate"
            case 60..<80: speechPctLabel = "normal"
            default: speechPctLabel = "high engagement"
            }
            lines.append("[Audio/vDSP] Speech ratio: \(String(format: "%.0f", speechPct))% of recording — \(speechPctLabel)")
        }

        // Pauses
        if let pauseCount = voiceFeatures?.pauseCount, let avgPause = voiceFeatures?.averagePauseDuration {
            lines.append("[Audio/vDSP] Pauses: \(pauseCount) detected, avg \(String(format: "%.1f", avgPause))s")
        }

        // Signal-to-noise ratio
        if let snr = voiceFeatures?.snr {
            let snrLabel: String
            switch snr {
            case ..<5: snrLabel = "poor signal quality"
            case 5..<10: snrLabel = "marginal"
            case 10..<20: snrLabel = "clean signal"
            default: snrLabel = "excellent"
            }
            lines.append("[Audio/vDSP] SNR: \(String(format: "%.1f", snr))dB — \(snrLabel)")
        }

        // === VISION / ANE ===
        if !telemetryPoints.isEmpty {
            let count = telemetryPoints.count
            let earlySlice = Array(telemetryPoints.prefix(count / 3))
            let lateSlice = Array(telemetryPoints.suffix(count / 3))

            func segAvg(_ vals: [Double]) -> Double {
                vals.isEmpty ? 0 : vals.reduce(0, +) / Double(vals.count)
            }

            // Eye openness: early → late trend
            let earlyEye = segAvg(earlySlice.map { $0.eyeOpenness })
            let lateEye = segAvg(lateSlice.map { $0.eyeOpenness })
            let allEye = segAvg(telemetryPoints.map { $0.eyeOpenness })
            let eyeTrendLabel: String
            if lateEye < earlyEye * 0.7 && earlyEye > 1.0 {
                eyeTrendLabel = "declining — fatigue signal"
            } else if allEye < 1.5 {
                eyeTrendLabel = "low throughout"
            } else if Swift.abs(lateEye - earlyEye) < 0.3 {
                eyeTrendLabel = "stable"
            } else {
                eyeTrendLabel = "variable"
            }
            lines.append("[Vision/ANE] Eye openness: \(String(format: "%.2f", earlyEye)) → \(String(format: "%.2f", lateEye)) (early→late) — \(eyeTrendLabel)")

            // Gaze deviation: early → late trend
            let earlyGaze = segAvg(earlySlice.map { $0.gazeDeviation })
            let lateGaze = segAvg(lateSlice.map { $0.gazeDeviation })
            let gazeLabel: String
            if lateGaze > earlyGaze * 1.3 && lateGaze > 3.0 {
                gazeLabel = "increasing avoidance"
            } else if lateGaze > 5.0 {
                gazeLabel = "sustained avoidance"
            } else {
                gazeLabel = "regulated"
            }
            lines.append("[Vision/ANE] Gaze deviation: \(String(format: "%.1f", earlyGaze)) → \(String(format: "%.1f", lateGaze)) (early→late) — \(gazeLabel)")

            // Head pitch: early → late drift
            let earlyPitch = segAvg(earlySlice.map { $0.headPitch })
            let latePitch = segAvg(lateSlice.map { $0.headPitch })
            let pitchDrift: String
            if Swift.abs(latePitch) > Swift.abs(earlyPitch) * 1.3 && Swift.abs(latePitch) > 0.05 {
                let dir = latePitch < 0 ? "downward" : "upward"
                pitchDrift = "progressive \(dir) drift"
            } else if Swift.abs(latePitch) > 0.1 {
                pitchDrift = "sustained droop"
            } else {
                pitchDrift = "stable"
            }
            lines.append("[Vision/ANE] Head pitch: \(String(format: "%.3f", earlyPitch)) → \(String(format: "%.3f", latePitch))rad — \(pitchDrift)")

            // Overall regulation pattern
            var decompSignals = 0
            let sessionDuration = max(1.0, (telemetryPoints.last?.timestamp ?? 30) - (telemetryPoints.first?.timestamp ?? 0))
            let pitchSlope = Swift.abs(latePitch - earlyPitch) / (sessionDuration / 3.0)
            if pitchSlope > 0.01 { decompSignals += 1 }
            if lateGaze > earlyGaze * 1.3 && lateGaze > 3.0 { decompSignals += 1 }
            if lateEye < earlyEye * 0.7 && earlyEye > 1.0 { decompSignals += 1 }
            let regPattern: String
            switch decompSignals {
            case 3: regPattern = "multi-signal decompensation"
            case 2: regPattern = "partial decompensation"
            case 1: regPattern = "single-signal drift — monitor"
            default: regPattern = "regulated — signals stable"
            }
            lines.append("[Vision/ANE] Regulation: \(regPattern)")

            lines.append("[Vision/ANE] Samples: \(telemetryPoints.count) frames @ ~2fps / 30s")
        } else {
            lines.append("[Vision/ANE] No face telemetry captured")
        }

        // === HEALTHKIT ===
        if let health = healthData {
            // Sleep
            let sleepVal = health.sleep.totalSleepHours
            let sleepLabel: String
            switch sleepVal {
            case ..<3.0: sleepLabel = "critical deficit"
            case 3.0..<5.0: sleepLabel = "significant deficit"
            case 5.0..<7.0: sleepLabel = "below recommended"
            default: sleepLabel = "adequate"
            }
            if let sleepZ = health.deviations.sleepZScore {
                let zSign = sleepZ >= 0 ? "+" : ""
                lines.append("[HealthKit] Sleep 48h: \(String(format: "%.1f", sleepVal))hrs — \(sleepLabel) (\(zSign)\(String(format: "%.1f", sleepZ))σ)")
            } else {
                lines.append("[HealthKit] Sleep 48h: \(String(format: "%.1f", sleepVal))hrs — \(sleepLabel)")
            }

            // HRV
            let sdnn = health.hrv.sdnn
            if sdnn > 0 {
                if let avgHRV = health.baseline.avgHRV, avgHRV > 0 {
                    let pct = Int(((sdnn - avgHRV) / avgHRV) * 100)
                    let sign = pct >= 0 ? "+" : ""
                    if let hrvZ = health.deviations.hrvZScore {
                        let zSign = hrvZ >= 0 ? "+" : ""
                        lines.append("[HealthKit] HRV (SDNN): \(String(format: "%.0f", sdnn))ms — \(sign)\(pct)% vs personal baseline (\(zSign)\(String(format: "%.1f", hrvZ))σ)")
                    } else {
                        lines.append("[HealthKit] HRV (SDNN): \(String(format: "%.0f", sdnn))ms — \(sign)\(pct)% vs personal baseline")
                    }
                } else if let zScore = health.deviations.hrvZScore {
                    lines.append("[HealthKit] HRV (SDNN): \(String(format: "%.0f", sdnn))ms — z: \(String(format: "%.1f", zScore))σ")
                } else {
                    lines.append("[HealthKit] HRV (SDNN): \(String(format: "%.0f", sdnn))ms")
                }
            } else {
                lines.append("[HealthKit] HRV: unavailable")
            }

            // Resting HR
            if let hr = health.hrv.restingHeartRate, hr > 0 {
                lines.append("[HealthKit] Resting HR: \(String(format: "%.0f", hr))bpm")
            }

            // Steps
            let steps = health.activity.stepCount
            if steps > 0 {
                let actLabel = steps < 2000 ? "sedentary" : steps < 5000 ? "low activity" : steps >= 10_000 ? "active" : "moderate"
                if let stepsZ = health.deviations.stepsZScore {
                    let zSign = stepsZ >= 0 ? "+" : ""
                    lines.append("[HealthKit] Steps: \(steps) — \(actLabel) (\(zSign)\(String(format: "%.1f", stepsZ))σ)")
                } else {
                    lines.append("[HealthKit] Steps: \(steps) — \(actLabel)")
                }
            }
        } else {
            lines.append("[HealthKit] Sleep: unavailable")
            lines.append("[HealthKit] HRV: unavailable")
        }

        self.demoTelemetryText = lines.joined(separator: "\n")

        // Mirror telemetry to the Xcode console for developer inspection immediately
        Logger.checkIn.debug("\n=== DEV MODE TELEMETRY ===\n\(self.demoTelemetryText ?? "")\n==========================")
    }
}

// MARK: - Camera Delegate
extension CheckInViewModel: CameraServiceDelegate {
    nonisolated func cameraService(_ service: CameraService, didCaptureTelemetry telemetry: FaceTelemetry, faceObservation: VNFaceObservation?) {
        Task { @MainActor in
            self.telemetryPoints.append(telemetry)
            self.currentFaceObservation = faceObservation
        }
    }

    nonisolated func cameraService(_ service: CameraService, didFailWithError error: CameraError) {
        Task { @MainActor in
            self.errorMessage = error.localizedDescription
        }
    }

    nonisolated func cameraServiceVideoDidFinish(_ service: CameraService) {
        Task { @MainActor in
            guard self.isRecording else { return }
            self.stopCheckIn()
        }
    }
}
