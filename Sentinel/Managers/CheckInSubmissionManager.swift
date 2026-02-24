import Foundation
import SwiftData
import os.log

@MainActor
final class CheckInSubmissionManager {

    private let healthKitManager: HealthKitManager
    private let modelContext: ModelContext?

    init(healthKitManager: HealthKitManager, modelContext: ModelContext?) {
        self.healthKitManager = healthKitManager
        self.modelContext = modelContext
    }

    /// Processes the check-in submission workflow
    /// - Returns: Tuple containing the final risk tier and updated health data (if fetched during process)
    func processSubmission(
        record: CheckInRecord,
        currentHealthData: HealthData?,
        analysisTask: Task<MedGemmaResponse?, Never>?,
        fallbackVisualLog: String = "User skipped visual check-in.",
        fallbackTranscript: String = "User skipped audio check-in.",
        fallbackWPM: Double = 0.0
    ) async -> (RiskTier, HealthData?) {

        var healthData = currentHealthData
        var aiResult: MedGemmaResponse? = nil

        // Wait for AI Analysis with timeout

        if let task = analysisTask {
            // Happy path: Task is already running/done
            aiResult = await task.value
        } else {
            // Fallback: User skipped multimodal or task failed to start.
            Logger.checkIn.warning("Analysis Task was NIL. Running Just-In-Time Analysis...")

            // A. Fetch Health Data (if needed)
            if healthData == nil {
                do {
                    _ = try await healthKitManager.requestAuthorization()
                    healthData = try await healthKitManager.fetchHealthData(timeout: CheckInConfiguration.healthDataTimeoutSeconds)
                    Logger.healthKit.info("JIT Health data fetched successfully")
                } catch {
                    Logger.healthKit.error("Failed to fetch JIT health data: \(error.localizedDescription)")
                    healthData = nil
                }
            }

            // B. Run MedGemma (Text-only/Fallback mode)
            do {
                Logger.ai.info("Running JIT MedGemma inference (CSSR + Health)...")
                aiResult = try await MedGemmaEngine.shared.analyze(
                    record: record,
                    healthData: healthData,
                    userProfile: nil,
                    visualLog: fallbackVisualLog,
                    wpm: fallbackWPM,
                    transcript: fallbackTranscript
                )
                Logger.ai.info("JIT Success. Risk: \(String(describing: aiResult?.assessedRisk))")
            } catch {
                Logger.ai.error("JIT Failed: \(error.localizedDescription)")
            }
        }

        // 2. Risk Calculation
        // A. C-SSRS Risk (Deterministic)
        let cssrsRisk = RiskCalculator.calculateRiskTier(from: record)

        // B. AI Risk (Probabilistic)
        let aiRisk = aiResult?.assessedRisk ?? .low

        // Debug Failure if N/A
        if aiResult == nil {
            Logger.checkIn.warning("AI Result is nil. Analysis failed or returned nil.")
        }

        // 3. Final Risk Determination
        // Determine tier, source, and explanation (CSSR vs MedGemma)
        let riskInfo = RiskCalculator.determineRiskSource(
            cssrsRisk: cssrsRisk,
            aiRisk: aiRisk,
            aiExplanation: aiResult?.insights.first // Primary insight is the 1-2 sentence explanation
        )
        let finalRisk = max(cssrsRisk, aiRisk)

        // 4. Update Record
        record.determinedRiskTier = String(finalRisk.rawValue)
        record.derivedRiskSource = riskInfo.source
        record.riskExplanation = riskInfo.explanation
        do {
            try modelContext?.save()
        } catch {
            Logger.storage.error("Failed to save CheckInRecord with final risk tier: \(error.localizedDescription)")
        }

        // 5. Update Semantic Narrative (LCSC)
        // Delegate to LCSCManager
        // 5. Update Semantic Narrative (LCSC) - Fire and Forget to unblock UI
        Task {
            await LCSCManager.updateNarrative(record: record, health: healthData, risk: finalRisk)
        }

        return (finalRisk, healthData)
    }
}
