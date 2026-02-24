import Foundation
import OSLog

/// Builds clinical prompts for MedGemma inference
///
/// Constructs context-aware prompts based on risk tier, health data,
/// and user profile. Implements Safety-Bound Prompt Routing.
struct PromptBuilder {

    // MARK: - Main Prompt Builder (Multimodal Signal Integration)

    /// Build prompt with behavioral telemetry, voice analysis, and LCSC context
    static func buildRiskPrompt(
        record: CheckInRecord,
        healthData: HealthData?,
        userProfile: UserProfile?,
        transcript: String,
        wpm: Double,
        visualLog: String,
        voiceFeatures: VoiceFeatures? = nil,
        lcscState: LCSCState? = nil
    ) -> String {
        // Compact data summary
        let healthSummary: String
        if let h = healthData {
            healthSummary = h.summaryString()
        } else {
            healthSummary = "No HealthKit data"
        }

        let cssrsSummary = RiskCalculator.buildCompactCSSRS(record)

        // Build longitudinal context from LCSC state, truncating if necessary
        var historyContext = LCSCManager.formatForPrompt(lcscState)
        let maxHistoryChars = 500
        if historyContext.count > maxHistoryChars {
            historyContext = String(historyContext.prefix(maxHistoryChars)) + "...(truncated)"
        }

        // Get risk modifiers for vigilance guidance
        let (shouldIncreaseVigilance, vigilanceReason) = LCSCManager.getRiskModifiers(lcscState)
        let vigilanceNote = shouldIncreaseVigilance
            ? "\nNOTE: Increase vigilance - \(vigilanceReason ?? "trajectory concern")"
            : ""

        // Truncate behavioral telemetry to avoid overwhelming the 1024 token context window
        let maxTelemetryChars = 400
        let behavioralTelemetry: String
        if visualLog.isEmpty {
            behavioralTelemetry = "No data"
        } else if visualLog.count > maxTelemetryChars {
            behavioralTelemetry = String(visualLog.prefix(maxTelemetryChars)) + "...(truncated)"
        } else {
            behavioralTelemetry = visualLog
        }

        // Voice analysis summary
        let voiceAnalysis = formatVoiceFeatures(voiceFeatures, wpm: wpm)

        // Cross-modal discrepancy detection
        let discrepancy = DiscrepancyDetector.detect(
            transcript: transcript,
            voiceFeatures: voiceFeatures,
            behavioralReport: visualLog
        )
        let discrepancyNote = discrepancy.map { " | SIGNAL DISCREPANCY: \($0)" } ?? ""

        // Truncate transcript just in case it's huge
        let maxTranscriptChars = 600
        let safeTranscript = transcript.count > maxTranscriptChars ? String(transcript.prefix(maxTranscriptChars)) + "...(truncated)" : transcript

        // Load and format prompt
        let replacements = [
            "{{HISTORY_CONTEXT}}": historyContext,
            "{{HEALTH_SUMMARY}}": healthSummary,
            "{{TRANSCRIPT}}": safeTranscript,
            "{{VOICE_ANALYSIS}}": voiceAnalysis,
            "{{BEHAVIORAL_TELEMETRY}}": behavioralTelemetry,
            "{{CSSRS_SUMMARY}}": cssrsSummary,
            "{{VIGILANCE_NOTE}}": vigilanceNote,
            "{{SIGNAL_DISCREPANCY}}": discrepancyNote
        ]

        let prompt = applyReplacements(template: PromptLoader.shared.getPrompt(.riskAssessment), replacements: replacements)
        return prompt
    }

    // MARK: - Voice Features Formatting

    /// Format VoiceFeatures into compact clinical text for prompt
    private static func formatVoiceFeatures(_ features: VoiceFeatures?, wpm: Double) -> String {
        guard let f = features else {
            return "WPM=\(Int(wpm)), No prosodic data"
        }

        var parts: [String] = []
        parts.append("WPM=\(Int(wpm))")

        if let pauseCount = f.pauseCount {
            let avgPause = f.averagePauseDuration.map { String(format: "%.1fs", $0) } ?? "N/A"
            parts.append("Pauses=\(pauseCount) (avg \(avgPause))")
        }

        if let pitch = f.meanPitch {
            let pitchVar = f.pitchVariability.map { String(format: "%.1f", $0) } ?? "N/A"
            parts.append("Pitch=\(String(format: "%.0f", pitch))Hz (var=\(pitchVar))")
        }

        if let energy = f.meanEnergy {
            let energyVar = f.energyVariability.map { String(format: "%.1f", $0) } ?? "N/A"
            parts.append("Energy=\(String(format: "%.0f", energy))dB (var=\(energyVar))")
        }

        if let speechPct = f.speechPercentage {
            parts.append("Speech%=\(String(format: "%.0f", speechPct))%")
        }

        if let snr = f.snr {
            parts.append("SNR=\(String(format: "%.0f", snr))dB")
        }

        return parts.joined(separator: ", ")
    }

    // MARK: - Context Ingestion

    static func buildContextIngestionPrompt(currentNarrative: String, newContext: String, documentType: String = "Discharge Summary") -> String {
        let replacements = [
            "{{CURRENT_SUMMARY}}": currentNarrative,
            "{{NEW_CONTEXT}}": newContext,
            "{{DOCUMENT_TYPE}}": documentType
        ]
        
        let prompt = applyReplacements(template: PromptLoader.shared.getPrompt(.contextIngestion), replacements: replacements)
        Logger.ai.info("GENERATED PROMPT (Context Ingestion):\n\(prompt)")
        return prompt
    }

    // MARK: - Risk Explanation

    static func buildRiskExplanationPrompt(
        riskLevel: RiskTier,
        historyContext: String,
        lastCheckInTime: Date,
        dataSource: String,
        record: CheckInRecord?,
        healthData: HealthData?
    ) -> String {
        let timeAgo = lastCheckInTime.formatted(.relative(presentation: .named))
        
        // --- Borrowed Logic from buildReportPrompt ---
        var riskItems: [String] = []
        if let record = record {
            let cssrsChecks: [(Bool?, String)] = [
                (record.q1WishDead, "- Reported passive death wish"),
                (record.q2SuicidalThoughts, "- Reported suicidal thoughts"),
                (record.q3ThoughtsWithMethod, "- Thoughts with method"),
                (record.q4Intent, "- Active intent declared"),
                (record.q5Plan, "- Specific plan declared"),
                (record.q6RecentAttempt, "- Recent attempt reported")
            ]
            riskItems += cssrsChecks.compactMap { condition, report in
                condition == true ? report : nil
            }
        }
        let riskFactors = riskItems.isEmpty ? "None reported in this check-in." : riskItems.joined(separator: "\n")
        
        var healthItems: [String] = []
        if let health = healthData {
            if health.sleep.totalSleepHours > 0 {
                healthItems.append("Sleep: \(String(format: "%.1f", health.sleep.totalSleepHours)) hours")
            } else {
                healthItems.append("Sleep: N/A")
            }
            // Check for valid HRV (non-zero)
            if health.hrv.sdnn > 0 {
                healthItems.append("HRV: \(String(format: "%.0f", health.hrv.sdnn)) ms")
            }
            
            if let deviations = health.deviations as HealthDeviations? {
                if let sleepZ = deviations.sleepZScore, sleepZ.magnitude > 1.5 {
                    healthItems.append("Sleep deviation: z=\(String(format: "%.1f", sleepZ))")
                }
            }
            
            if healthItems.isEmpty {
                healthItems.append("No recent wearable data.")
            }
        } else {
            healthItems.append("No wearable data available.")
        }
        let healthContext = healthItems.joined(separator: "\n")
        // ---------------------------------------------
        
        let replacements = [
            "{{RISK_LEVEL}}": riskLevel.displayName,
            "{{HISTORY_CONTEXT}}": historyContext.isEmpty ? "No significant history." : historyContext,
            "{{RISK_FACTORS}}": riskFactors,
            "{{HEALTH_CONTEXT}}": healthContext,
            "{{TIME_AGO}}": timeAgo,
            "{{DATA_SOURCE}}": dataSource
        ]
        
        let prompt = applyReplacements(template: PromptLoader.shared.getPrompt(.explainRisk), replacements: replacements)
        Logger.ai.info("GENERATED PROMPT (Risk Explanation):\n\(prompt)")
        return prompt
    }

    // MARK: - Compression Prompt (Rolling Narrative)

    static func buildCompressionPrompt(
        previousSummary: String?,
        newRecord: CheckInRecord,
        newHealth: HealthData?,
        riskTier: RiskTier
    ) -> String {
        let transcript = newRecord.audioMetadata?.transcript ?? "No transcript"
        let checkInType = newRecord.checkInType
        let sleepVal = newHealth?.sleep.totalSleepHours ?? 0
        let sleepHours = sleepVal > 0 ? String(format: "%.1f", sleepVal) + "h" : "N/A"
        
        let sleepGeneric = newHealth?.deviations.sleepZScore ?? 0
        let sleepTrend = sleepGeneric != 0 ? String(format: "%.2f", sleepGeneric) : "N/A"
        let previousSummaryText = previousSummary ?? "Initial intake. No prior history."

        let replacements = [
            "{{PREVIOUS_SUMMARY}}": previousSummaryText,
            "{{RISK_TIER}}": riskTier.displayName,
            "{{CHECKIN_TYPE}}": checkInType,
            "{{TRANSCRIPT}}": transcript,
            "{{SLEEP_HOURS}}": sleepHours,
            "{{SLEEP_TREND}}": sleepTrend
        ]

        let prompt = applyReplacements(template: PromptLoader.shared.getPrompt(.compression), replacements: replacements)
        return prompt
    }

    // MARK: - C-SSRS Helpers

    private static func buildCompactCSSRS(_ record: CheckInRecord) -> String {
        var flags: [String] = []
        if record.q1WishDead == true { flags.append("Q1+") }
        if record.q2SuicidalThoughts == true { flags.append("Q2+") }
        if record.q3ThoughtsWithMethod == true { flags.append("Q3+") }
        if record.q4Intent == true { flags.append("Q4+CRISIS") }
        if record.q5Plan == true { flags.append("Q5+CRISIS") }
        if record.q6RecentAttempt == true { flags.append("Q6+") }
        return flags.isEmpty ? "All negative" : flags.joined(separator: ", ")
    }

    static func buildReportPrompt(
        record: CheckInRecord?,
        healthData: HealthData?,
        profile: UserProfile?,
        riskTier: RiskTier,
        recipient: RecipientType,
        // NEW PARAMS
        transcript: String,
        historyContext: String,
        voiceAnalysis: String,
        behavioralData: String
    ) -> String {
        let name = profile?.preferredName ?? "Veteran"

        // Create Health Context
        var healthItems: [String] = []
        if let health = healthData {
            healthItems.append("Sleep: \(String(format: "%.1f", health.sleep.totalSleepHours)) hours")
            healthItems.append("Steps: \(health.activity.stepCount)")
            healthItems.append("HRV: \(String(format: "%.0f", health.hrv.sdnn)) ms")
            if let deviations = health.deviations as HealthDeviations? {
                if let sleepZ = deviations.sleepZScore, sleepZ.magnitude > 1.5 {
                    healthItems.append("Sleep deviation: z=\(String(format: "%.1f", sleepZ))")
                }
                if let hrvZ = deviations.hrvZScore, hrvZ.magnitude > 1.5 {
                    healthItems.append("HRV deviation: z=\(String(format: "%.1f", hrvZ))")
                }
                if let stepsZ = deviations.stepsZScore, stepsZ.magnitude > 1.5 {
                    healthItems.append("Activity deviation: z=\(String(format: "%.1f", stepsZ))")
                }
            }
        } else {
            healthItems.append("No HealthKit data available")
        }
        
        // Add C-SSRS context to health/telemetry section per user request for "Clinical Argument"
        if let record = record {
             let cssrsChecks: [(Bool?, String)] = [
                (record.q1WishDead, "Passive death wish"),
                (record.q2SuicidalThoughts, "Suicidal thoughts"),
                (record.q3ThoughtsWithMethod, "Thoughts with method"),
                (record.q4Intent, "Active intent"),
                (record.q5Plan, "Specific plan"),
                (record.q6RecentAttempt, "Recent attempt reported")
            ]
            let positiveChecks = cssrsChecks.compactMap { $0.0 == true ? $0.1 : nil }
            if !positiveChecks.isEmpty {
                healthItems.append("C-SSRS FLAGS: " + positiveChecks.joined(separator: ", "))
            }
        }
        
        let healthContext = healthItems.joined(separator: "\n    ")

        // Create Voice/Behavior Context
        let voiceContext = "Voice: \(voiceAnalysis)\n    Behavior: \(behavioralData)"

        let replacements = [
            "{{PATIENT_NAME}}": name,
            "{{RISK_TIER}}": riskTier.displayName,
            "{{TRANSCRIPT}}": transcript,
            "{{HISTORY_CONTEXT}}": historyContext.isEmpty ? "None available" : historyContext,
            "{{HEALTH_CONTEXT}}": healthContext,
            "{{VOICE_CONTEXT}}": voiceContext
        ]

        let prompt = applyReplacements(template: PromptLoader.shared.getPrompt(.report), replacements: replacements)
        Logger.ai.info("GENERATED PROMPT (Report):\n\(prompt)")
        return prompt
    }

    // MARK: - Safety Plan Reranking

    /// Build prompt for MedGemma to rerank safety plan sections based on clinical context
    static func buildRerankPrompt(
        lcscState: LCSCState?,
        detectedPatterns: [DetectedPattern]
    ) -> String {
        let trajectory = lcscState?.trajectory.rawValue ?? "stable"
        let primaryDriver = lcscState?.primaryDriver?.rawValue ?? "combined"
        let riskTier = lcscState?.lastRiskTier?.displayName ?? "CRISIS"
        let recentCrisisCount = String(lcscState?.recentCrisisCount ?? 0)
        let narrative = lcscState?.clinicalNarrative ?? "No prior history."

        let patternsString: String
        if detectedPatterns.isEmpty {
            patternsString = "None detected"
        } else {
            patternsString = detectedPatterns
                .map { "\($0.type.rawValue) (\($0.severity.rawValue))" }
                .joined(separator: ", ")
        }

        let replacements = [
            "{{TRAJECTORY}}": trajectory,
            "{{PRIMARY_DRIVER}}": primaryDriver,
            "{{RISK_TIER}}": riskTier,
            "{{RECENT_CRISIS_COUNT}}": recentCrisisCount,
            "{{DETECTED_PATTERNS}}": patternsString,
            "{{CLINICAL_NARRATIVE}}": narrative
        ]

        let prompt = applyReplacements(
            template: PromptLoader.shared.getPrompt(.rerankSafetyPlan),
            replacements: replacements
        )
        Logger.ai.info("GENERATED PROMPT (Safety Plan Rerank):\n\(prompt)")
        return prompt
    }

    // MARK: - Helper Methods

    private static func applyReplacements(template: String, replacements: [String: String]) -> String {
        var prompt = template
        for key in replacements.keys.sorted() {
            if let value = replacements[key] {
                prompt = prompt.replacingOccurrences(of: key, with: value)
            }
        }
        return prompt
    }
}
