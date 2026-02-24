import Foundation
import SwiftUI
import Combine
import os.log

/// Manages the Crisis screen and resolution flow with a Re-Check Loop
@MainActor
final class CrisisViewModel: ObservableObject {
    // MARK: - State Machine
    enum CrisisStatus {
        case active       // Initial 10-15 min containment
        case recheck      // The "How are you feeling?" prompt
        case stabilizing  // "About the same" - loop back
        case resolved     // "More stable" - exit
    }

    enum RecheckResponse {
        case stable       // "More stable"
        case same         // "About the same"
        case worse        // "Worse / Still at risk"
    }

    // MARK: - Published State
    @Published var status: CrisisStatus = .active
    @Published var showRecheckOptions = false

    @Published var isLoading = false
    @Published var errorMessage: String?

    /// Whether 988 has been called
    @Published var has988BeenCalled = false
    
    /// Show 988 call sheet for escalation
    @Published var show988Sheet = false

    /// Crisis start time (persisted to survive app reload)
    @Published var crisisStartTime: Date?
    
    /// Timer tick to trigger UI updates (view reads remainingSeconds each tick)
    @Published var timerTick: Int = 0

    /// Seconds remaining in the current 10-minute window
    var remainingSeconds: TimeInterval {
        _ = timerTick // Read to establish dependency for SwiftUI
        guard let start = crisisStartTime else { return TimeInterval(defaultActiveSeconds) }
        return max(0, TimeInterval(defaultActiveSeconds) - Date().timeIntervalSince(start))
    }

    /// Next mandatory check-in time (4 hours after resolution start)
    @Published var nextMandatoryCheckIn: Date?

    /// Reranked safety plan section order (MedGemma-driven)
    @Published var sectionOrder: [SafetyPlanSection] = SafetyPlanSection.defaultCrisisOrder

    /// Whether MedGemma reranking is in progress
    @Published var isReranking: Bool = false

    // MARK: - Dependencies
    private let localStorage: LocalStorage
    private let notificationManager: NotificationManager

    // MARK: - Timer
    private var timerTask: Task<Void, Never>?

    // MARK: - Constants
    private let defaultActiveSeconds = 600 // 10 minutes
    private let mandatoryCheckInHours: Int = 4

    // MARK: - Initialization
    init(
        localStorage: LocalStorage = LocalStorage(),
        notificationManager: NotificationManager = NotificationManager()
    ) {
        self.localStorage = localStorage
        self.notificationManager = notificationManager
    }

    // MARK: - Public Methods

    /// Enter crisis and start the holding pattern timer.
    /// Idempotent: reuses persisted start time on app reload instead of resetting.
    func enterCrisis() {
        // Check for existing persisted crisis timestamp
        if let persisted = localStorage.loadCrisisEnteredAt() {
            crisisStartTime = persisted
        } else {
            // Fresh crisis — persist the start time
            let now = Date()
            crisisStartTime = now
            localStorage.saveCrisisEnteredAt(now)
        }

        has988BeenCalled = false
        status = .active
        Logger.checkIn.info("Crisis mode entered (remaining: \(Int(self.remainingSeconds))s)")

        if remainingSeconds <= 0 {
            // Timer already expired while app was closed — show recheck immediately
            showRecheckOptions = true
            status = .recheck
        } else {
            startRecheckTimer()
        }
    }

    /// Debug function to skip to recheck prompt, bypassing the 10-minute timer
    func debugExit() {
        stopTimer()
        showRecheckOptions = true
        status = .recheck
        Logger.checkIn.debug("Crisis mode skipped to recheck via debug")
    }

    /// The Re-Check Logic (The Core Fix)
    func handleRecheck(response: RecheckResponse) {
        switch response {
        case .stable:
            // Exit: Log success, dismiss overlay, resolve crisis
            Logger.checkIn.info("Crisis recheck: User reports stable")
            showRecheckOptions = false
            Task { await resolveCrisis() }

        case .same:
            // Loop: Fresh 10-minute window, persist for app reload
            Logger.checkIn.info("Crisis recheck: User reports same - extending")
            status = .stabilizing
            showRecheckOptions = false
            let now = Date()
            crisisStartTime = now
            localStorage.saveCrisisEnteredAt(now)
            startRecheckTimer()

        case .worse:
            // Escalate: Show 988/support prominently
            Logger.checkIn.warning("Crisis recheck: User reports worse - escalating")
            showRecheckOptions = false
            triggerEscalationProtocol()
        }
    }

    /// Calls 988 Suicide & Crisis Lifeline
    func call988() {
        has988BeenCalled = true
        Logger.checkIn.info("988 call initiated")
        // Note: actual system call handled by the View
    }

    /// Resolves crisis after successful follow-up
    func resolveCrisis() async {
        isLoading = true
        defer { isLoading = false }

        // Defensive nil handling - use current date if crisisStartTime is nil
        let startTime = crisisStartTime ?? Date()
        
        do {
            try await localStorage.recordCrisisResolution(
                startTime: startTime,
                endTime: Date()
            )

            stopTimer()
            status = .resolved
            crisisStartTime = nil
            localStorage.clearCrisisEnteredAt()
            nextMandatoryCheckIn = nil
            has988BeenCalled = false
            Logger.checkIn.info("Crisis resolved successfully")
        } catch {
            Logger.checkIn.error("Failed to record crisis resolution: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// Handles missed mandatory check-in
    func handleMissedCheckIn() async {
        // Re-lock app
        status = .active
        startRecheckTimer()

        // Notify battle buddy
        await notifyBattleBuddy()
    }

    // MARK: - Safety Plan Reranking

    /// Reranks safety plan sections based on clinical context.
    /// Applies rule-based fallback immediately, then refines with MedGemma.
    func rerankSafetyPlanSections() async {
        isReranking = true

        // 1. Load LCSC state for clinical context
        let lcscState = await localStorage.loadLCSCState()

        // 2. Apply rule-based fallback immediately (instant)
        let fallbackOrder = SafetyPlanSection.fallbackOrder(for: lcscState?.primaryDriver)
        sectionOrder = fallbackOrder
        Logger.checkIn.info("Safety plan: applied fallback order for driver=\(lcscState?.primaryDriver?.rawValue ?? "nil")")

        // 3. Try MedGemma rerank (async, may take a few seconds)
        let detectedPatterns = lcscState?.detectedPatterns ?? []
        if let rerankResult = await MedGemmaEngine.shared.rerankSafetyPlanSections(
            lcscState: lcscState,
            detectedPatterns: detectedPatterns
        ) {
            let reranked = rerankResult.compactMap { SafetyPlanSection(rawValue: $0) }
            if reranked.count == 7 {
                sectionOrder = reranked
                Logger.checkIn.info("Safety plan: reranked by MedGemma → \(rerankResult)")
            }
        }

        isReranking = false
    }

    // MARK: - Private Methods

    private func startRecheckTimer() {
        stopTimer()
        let sleepSeconds = remainingSeconds
        guard sleepSeconds > 0 else {
            // Already expired
            showRecheckOptions = true
            status = .recheck
            return
        }
        timerTask = Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(nanoseconds: UInt64(sleepSeconds) * 1_000_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    self.showRecheckOptions = true
                    self.status = .recheck
                }
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func triggerEscalationProtocol() {
        // Show the "Call 988" sheet immediately
        show988Sheet = true
    }

    private func notifyBattleBuddy() async {
        // Implementation: Send SMS/notification to battle buddy
    }
}
