import Foundation
import LLM
import os.log


/// Manages MedGemma-4B inference on-device using LLM.swift
///
/// Provides clinical risk analysis by processing check-in data through
/// a quantized LLM running entirely on-device for privacy.
actor MedGemmaEngine {

    // MARK: - Singleton

    static let shared = MedGemmaEngine(storage: LocalStorage())

    // MARK: - Properties

    private var llm: LLM?
    private var isLoaded = false
    private let storage: LocalStorage

    // MARK: - Configuration (from LLMConfiguration)
    
    private var maxTokens: Int { LLMConfiguration.maxTokens }
    private var temperature: Float { LLMConfiguration.temperature }
    private var topK: Int32 { LLMConfiguration.topK }
    private var topP: Float { LLMConfiguration.topP }
    private var maxTokenCount: Int32 { LLMConfiguration.maxTokenCount }
    private var gpuLayers: Int32 { LLMConfiguration.gpuLayers }
    private var repeatPenalty: Float { LLMConfiguration.repeatPenalty }
    private var repetitionLookback: Int32 { LLMConfiguration.repetitionLookback }

    // MARK: - Model Path

    private var modelURL: URL? {
        // First check bundle
        if let bundlePath = Bundle.main.path(
            forResource: "medgemma-1.5-4b-it.Q4_K_M",
            ofType: "gguf"
        ) {
            return URL(fileURLWithPath: bundlePath)
        }

        // Then check Documents directory (for downloaded models)
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let modelPath = documentsURL.appendingPathComponent("medgemma-1.5-4b-it.Q4_K_M.gguf")
            if FileManager.default.fileExists(atPath: modelPath.path) {
                return modelPath
            }
        }

        return nil
    }

    // MARK: - Initialization

    private init(storage: LocalStorage) {
        self.storage = storage
    }

    // MARK: - Model Loading

    /// Load the model into memory (call on app launch in background)
    func loadModel() async throws {
        guard !isLoaded else { return }

        guard let url = modelURL else {
            Logger.ai.warning("MedGemma model file not found - using rule-based fallback")
            throw MedGemmaError.modelNotFound
        }

        // Verify file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            Logger.ai.warning("MedGemma model file missing at \(url.path) - using rule-based fallback")
            throw MedGemmaError.modelNotFound
        }

        guard let model = LLM(
            from: url,
            template: .gemma,
            gpuLayers: gpuLayers,
            topK: topK,
            topP: topP,
            temp: temperature,
            repeatPenalty: repeatPenalty,
            repetitionLookback: repetitionLookback,
            maxTokenCount: maxTokenCount
        ) else {
            Logger.ai.error("Failed to initialize LLM - using rule-based fallback")
            throw MedGemmaError.modelLoadFailed
        }
        
        // Silence the default LLM.swift print($0) behavior
        model.postprocess = { _ in }
        
        self.llm = model
        isLoaded = true

        // Log device configuration
        let memory = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(memory) / (1024 * 1024 * 1024)
        Logger.ai.info("✅ MedGemma model loaded: \(url.lastPathComponent)")
        Logger.ai.info("   Device Memory: \(String(format: "%.1f", memoryGB)) GB")
        Logger.ai.info("   Context: \(self.maxTokenCount) tokens, GPU Layers: \(self.gpuLayers)")
    }

    /// Check if model is ready for inference
    func isModelLoaded() -> Bool {
        return isLoaded
    }

    // MARK: - Primary Analysis Function

    /// Executes risk assessment combining patient check-in data and optional health metrics
    ///
    /// This method:
    /// 1. Loads previous longitudinal context (LCSC)
    /// 2. Builds multimodal prompt (visual, audio, health, history)
    /// 3. Runs LLM inference with timeout fallback
    /// 4. Parses structured response (risk tier, rationale, flags)
    /// 5. Updates longitudinal state for future check-ins
    ///
    /// ## Risk Assessment Process
    /// - Primary: MedGemma LLM inference
    /// - Fallback: Rule-based response if model unavailable/times out
    ///
    /// - Parameters:
    ///   - record: User check-in (C-SSRS, visual scribe data)
    ///   - healthData: Optional HealthKit metrics (sleep, HRV, activity)
    ///  - userProfile: Optional user profile
    ///   - visualLog: Visual scribe report from face tracking (detected gestures, expressions)
    ///   - wpm: Words per minute from audio (speech rate indicator)
    ///   - transcript: Full audio transcript of clinical interview
    /// - Returns: `MedGemmaResponse` with parsed risk assessment
    /// - Throws: If both LLM and fallback fail (rare - fallback is defensive)
    func analyze(
        record: CheckInRecord,
        healthData: HealthData?,
        userProfile: UserProfile?,
        visualLog: String,
        wpm: Double,
        transcript: String,
        voiceFeatures: VoiceFeatures? = nil
    ) async throws -> MedGemmaResponse {
        let startTime = Date()
        Logger.ai.warning("⚙️ MedGemma: Calculating Multi-Modal Risk Score...")

        // 0. Auto-load if model missing (Regression Fix)
        if !isLoaded {
            Logger.ai.info("Model not loaded for analysis. Attempting auto-load...")
            do {
                try await loadModel()
            } catch {
                Logger.ai.error("Auto-load failed: \(error.localizedDescription)")
                // Continue to fallback if load fails
            }
        }

        // 1. LOAD LCSC STATE - Retrieve longitudinal context
        var previousState = await storage.loadLCSCState()

        // Check if state should be reset (e.g., extended absence > 30 days)
        if LCSCManager.shouldResetState(previousState) {
            Logger.lcsc.info("State stale (>30 days). Resetting to fresh state.")
            previousState = nil
        }

        // 2. Build the multimodal risk prompt WITH LCSC context
        let prompt = PromptBuilder.buildRiskPrompt(
            record: record,
            healthData: healthData,
            userProfile: userProfile,
            transcript: transcript,
            wpm: wpm,
            visualLog: visualLog,
            voiceFeatures: voiceFeatures,
            lcscState: previousState
        )

        // Run inference or fall back to rule-based response
        var output: String
        var usedLLM = false

        if let llm = llm {
            let inferenceStartTime = Date()
            
            do {
                // Stream tokens directly from core so we can stop as soon as the
                // 2-line response is complete (color word + reason sentence).
                // Both getCompletion and respond(to:) let the model run to maxTokenCount
                // (~400-600 output tokens with a full prompt) which at on-device speeds
                // of 5-10 tok/sec reliably exceeds the 60s timeout.
                // Stopping after 2 newlines caps output to ~20 tokens regardless.
                llm.reset()

                var completedOutput = ""
                try await AsyncHelpers.withTimeout(seconds: CheckInConfiguration.aiInferenceTimeoutSeconds) {
                    let stream = await llm.core.generateResponseStream(from: prompt)
                    var newlineCount = 0
                    for await token in stream {
                        completedOutput += token
                        for char in token where char == "\n" {
                            newlineCount += 1
                        }
                        // Risk assessment format: line 1 = color word, line 2 = reason.
                        // Two newlines means both lines are complete — stop immediately.
                        if newlineCount >= 2 {
                            llm.stop()
                            break
                        }
                    }
                }

                output = completedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                let totalTime = Date().timeIntervalSince(inferenceStartTime)
                let tokenCount = output.split(separator: " ").count
                let tokensPerSec = Double(tokenCount) / totalTime

                Logger.ai.debug("Speed: \(String(format: "%.1f", tokensPerSec)) tokens/sec")
            } catch {
                Logger.ai.warning("LLM Inference Timed Out or Failed: \(error.localizedDescription)")
                Logger.ai.warning("No usable output. Falling back to rule-based response.")
                output = MedGemmaFallback.generateRuleBasedResponse(record: record, healthData: healthData)
            }
        } else {
            // Fallback
            Logger.ai.warning("Model not loaded. Using Rule-Based Fallback.")
            output = MedGemmaFallback.generateRuleBasedResponse(record: record, healthData: healthData)
            Logger.ai.debug("Fallback Output generated.")
        }

        let inferenceTime = Date().timeIntervalSince(startTime)

        // Parse the response using MedGemmaParser
        var response: MedGemmaResponse
        do {
            response = try MedGemmaParser.parse(output)
        } catch {
            Logger.ai.error("Parsing Failed: \(error.localizedDescription)")
            if usedLLM {
                Logger.ai.warning("Attempting fallback due to parse error...")
                output = MedGemmaFallback.generateRuleBasedResponse(record: record, healthData: healthData)
                response = try MedGemmaParser.parse(output)
            } else {
                throw error
            }
        }
        // Update metadata on parsed response (preserve parsed fields!)
        response.rawOutput = output
        response.inferenceTime = inferenceTime

        // 5. UPDATE & SAVE LCSC STATE - Close the loop for next check-in
        if let newRisk = response.assessedRisk {
            var newState = LCSCManager.updateState(
                currentState: previousState,
                newRecord: record,
                newHealth: healthData,
                newRisk: newRisk
            )

            // Store detected patterns for crisis card reranking
            newState.detectedPatterns = response.detectedPatterns

            // Persist for next time
            await storage.saveLCSCState(newState)
        } else {
            Logger.lcsc.warning("No risk tier parsed - state not updated")
        }

        Logger.ai.warning("📊 MedGemma Risk Assessment Complete")
        Logger.ai.info("   -> Raw Output: \(output.replacingOccurrences(of: "\n", with: " "))")
        Logger.ai.info("   -> Assessed Tier: \(response.assessedRisk.map { String(describing: $0).uppercased() } ?? "UNKNOWN")")
        
        return response
    }

    // MARK: - Longitudinal Context Update (Semantic Compression)

    /// Updates the LCSC state's `clinicalNarrative` by merging the previous summary
    /// with today's check-in data using a lightweight LLM prompt.
    func updateLongitudinalContext(
        currentState: LCSCState,
        record: CheckInRecord,
        health: HealthData?,
        riskTier: RiskTier
    ) async -> LCSCState {

        // 0. Auto-load if model missing (Regression Fix)
        if !isLoaded {
            Logger.ai.info("Model not loaded for context update. Attempting auto-load...")
            try? await loadModel()
        }

        // 1. Prepare Prompt
        let prompt = await PromptBuilder.buildCompressionPrompt(
            previousSummary: currentState.clinicalNarrative,
            newRecord: record,
            newHealth: health,
            riskTier: riskTier
        )

        // 2. Run Inference with timeout
        var newNarrative = currentState.clinicalNarrative ?? ""

        if let llm = llm {
            do {
                // Clear history before new generation so prior turns don't bleed in.
                // Use respond(to:) to keep Gemma chat template wrapping — narrative
                // compression is an instruction-following task that needs it.
                llm.reset()

                try await AsyncHelpers.withTimeout(seconds: CheckInConfiguration.narrativeCompressionTimeoutSeconds) {
                    await llm.respond(to: prompt)
                }

                let raw = MedGemmaParser.stripThinkingBlock(
                    llm.output.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                if !raw.isEmpty {
                    newNarrative = raw
                }
            } catch {
                Logger.ai.warning("updateLongitudinalContext failed or timed out: \(error.localizedDescription)")
                // Attempt to recover partial output
                let partialOutput = llm.output.trimmingCharacters(in: .whitespacesAndNewlines)
                if !partialOutput.isEmpty {
                    newNarrative = partialOutput
                    Logger.ai.info("Recovered partial narrative.")
                }
            }
        } else {
            // No model - keep existing narrative
            Logger.ai.warning("updateLongitudinalContext: model not loaded; skipping LLM compression")
        }

        // 3. Update State (keep deterministic counters intact)
        var newState = currentState
        newState.clinicalNarrative = newNarrative
        newState.lastUpdated = Date()

        return newState
    }

    // MARK: - Context Ingestion

    /// Ingests raw clinical text (e.g., Discharge Summary) into the longitudinal record
    func ingestClinicalContext(_ text: String) async {
        // 0. Ensure model is loaded
        if !isLoaded { try? await loadModel() }

        // 1. Load current state or create fresh
        var state = await storage.loadLCSCState() ?? LCSCState(clinicalNarrative: "Patient intake initiated.")
        
        // 2. Build prompt
        let prompt = PromptBuilder.buildContextIngestionPrompt(
            currentNarrative: state.clinicalNarrative ?? "",
            newContext: text
        )

        // 3. Run Inference
        guard let llm = llm else { return }
        
        do {
            Logger.ai.info("🧠 Processing clinical document...")
            
            // Clear history then use respond(to:) to keep Gemma template wrapping.
            // Context ingestion is instruction-following and needs the chat format.
            llm.reset()
            
            try await AsyncHelpers.withTimeout(seconds: 60) {
                await llm.respond(to: prompt)
            }
            
            let newNarrative = MedGemmaParser.stripThinkingBlock(
                llm.output.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            if !newNarrative.isEmpty {
                // 4. Update and Save
                state.clinicalNarrative = newNarrative
                state.lastUpdated = Date()
                await storage.saveLCSCState(state)
                Logger.lcsc.info("✅ Ingested clinical document into LCSC memory.")
                Logger.lcsc.info("📝 Clinical Summary: \(newNarrative)")
            }
        } catch {
            Logger.ai.error("Failed to ingest context: \(error.localizedDescription)")
        }
    }

    func generateClinicalReportStream(
        record: CheckInRecord?,
        healthData: HealthData?,
        profile: UserProfile?,
        riskTier: RiskTier,
        recipient: RecipientType
    ) async -> AsyncStream<String> {

        // 1. Auto-load if model missing
        if !isLoaded {
            Logger.ai.info("Model not loaded for report generation. Attempting auto-load...")
            do {
                try await loadModel()
            } catch {
                Logger.ai.error("Auto-load failed: \(error.localizedDescription)")
            }
        }

        // 2. Fallback if model still missing
        guard let llm = llm else {
            // Fallback to template-based SBAR
            let content = SBARGenerator.generate(
                record: record,
                healthData: healthData,
                profile: profile,
                riskTier: riskTier,
                recipient: recipient
            )
            return AsyncStream { continuation in
                continuation.yield(content)
                continuation.finish()
            }
        }

        // 3. Build Prompt (Now passing recipient)
        // Extract Context
        let transcript = record?.audioMetadata?.transcript ?? "No transcript available."
        
        let state = await storage.loadLCSCState()
        let historyContext = state?.clinicalNarrative ?? ""
        
        // Voice & Behavior - Not persisted in CheckInRecord, so for retrospective reports we must handle gracefully
        // If this is a live generation (immediately after check-in), these might be available in memory, but here we only have the record.
        // Future TODO: Persist voice features / visual log summaries in CheckInRecord.
        let voiceAnalysis = "Data not retained for retrospective report."
        let behavioralData = "Data not retained for retrospective report."

        let prompt = PromptBuilder.buildReportPrompt(
            record: record,
            healthData: healthData,
            profile: profile,
            riskTier: riskTier,
            recipient: recipient,
            transcript: transcript,
            historyContext: historyContext,
            voiceAnalysis: voiceAnalysis,
            behavioralData: behavioralData
        )

        // 4. Inference — reset, apply Gemma chat template, then seed the model's
        // response turn with "SITUATION:" so it begins filling in the SBAR directly
        // instead of narrating what it plans to do first.
        // preprocess() wraps the prompt as:  <start_of_turn>user\n…<end_of_turn>\n<start_of_turn>model\n
        // Appending "SITUATION:" after that marker forces the model to continue from there.
        // We also yield "SITUATION:" as the first stream chunk since input tokens are
        // NOT emitted by the stream — only newly generated tokens are.
        llm.reset()
        let formattedPrompt = llm.preprocess(prompt, [], .none) + "SITUATION:"
        let coreStream = await llm.core.generateResponseStream(from: formattedPrompt)
        return AsyncStream { continuation in
            Task {
                continuation.yield("SITUATION:")
                for await token in coreStream {
                    continuation.yield(token)
                }
                continuation.finish()
            }
        }
    }

    func generateClinicalReport(
        record: CheckInRecord?,
        healthData: HealthData?,
        profile: UserProfile?,
        riskTier: RiskTier,
        recipient: RecipientType
    ) async -> String {

        // 1. Fallback if model missing - use SBARGenerator
        guard let llm = llm else {
            return SBARGenerator.generate(
                record: record,
                healthData: healthData,
                profile: profile,
                riskTier: riskTier,
                recipient: recipient
            )
        }

        // 2. Build Prompt (Now passing recipient)
        // Extract Context
        let transcript = record?.audioMetadata?.transcript ?? "No transcript available."
        
        let state = await storage.loadLCSCState()
        let historyContext = state?.clinicalNarrative ?? ""
        
        // Voice & Behavior - Not persisted, use safe defaults
        let voiceAnalysis = "Data not retained for retrospective report."
        let behavioralData = "Data not retained for retrospective report."
        
        let prompt = PromptBuilder.buildReportPrompt(
            record: record,
            healthData: healthData,
            profile: profile,
            riskTier: riskTier,
            recipient: recipient,
            transcript: transcript,
            historyContext: historyContext,
            voiceAnalysis: voiceAnalysis,
            behavioralData: behavioralData
        )

        // 3. Inference — clear history then use respond(to:) to keep Gemma template.
        // SBAR generation is a rich instruction-following task; the chat format is
        // required for the model to fill in sections rather than echo the instructions.
        llm.reset()

        await llm.respond(to: prompt)
        
        let output = MedGemmaParser.stripThinkingBlock(
            llm.output.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        return output.isEmpty ? SBARGenerator.generate(record: record, healthData: healthData, profile: profile, riskTier: riskTier, recipient: recipient) : output
    }

    // MARK: - Risk Explanation

    func generateRiskExplanation(
        riskTier: RiskTier,
        lastRecord: CheckInRecord
    ) async -> String {
        // 0. Auto-load
        if !isLoaded { try? await loadModel() }

        // 1. Get History Context
        let state = await storage.loadLCSCState()
        let history = state?.clinicalNarrative ?? ""
        
        // 2. Build Prompt
        // Note: We access health data if available on the record relation or fetch latest
        let healthManager = HealthKitManager()
        let healthData = try? await healthManager.fetchHealthData(timeout: 5.0)
        
        let prompt = PromptBuilder.buildRiskExplanationPrompt(
            riskLevel: riskTier,
            historyContext: history,
            lastCheckInTime: lastRecord.timestamp,
            dataSource: lastRecord.derivedRiskSource ?? "System",
            record: lastRecord,
            healthData: healthData
        )

        // 3. Inference
        guard let llm = llm else {
            return "Unable to generate explanation (AI model offline). Risk level is based on your most recent check-in protocol."
        }
        
        do {
            Logger.ai.info("🧠 Generating risk explanation...")
            
            // Clear history then use respond(to:) to keep Gemma chat template.
            // Risk explanation is instruction-following (2 sentences) and needs the format.
            llm.reset()
            
            try await AsyncHelpers.withTimeout(seconds: 60) {
                await llm.respond(to: prompt)
            }
            var output = llm.output.trimmingCharacters(in: .whitespacesAndNewlines)

            // Strip chain-of-thought / thinking blocks
            output = MedGemmaParser.stripThinkingBlock(output)

            // Truncate to 2 sentences max (matches prompt constraint)
            output = MedGemmaParser.truncateToSentences(output, max: 2)

            return output.isEmpty ? "No explanation generated." : output
        } catch {
            Logger.ai.error("Explanation generation failed: \(error.localizedDescription)")
            return "Unable to generate explanation at this time."
        }
    }

    // MARK: - Safety Plan Reranking

    /// Reranks safety plan sections based on clinical context.
    /// Returns an ordered array of section numbers (1-7), or nil on failure.
    func rerankSafetyPlanSections(
        lcscState: LCSCState?,
        detectedPatterns: [DetectedPattern]
    ) async -> [Int]? {
        // 0. Auto-load
        if !isLoaded { try? await loadModel() }

        // 1. Build prompt
        let prompt = PromptBuilder.buildRerankPrompt(
            lcscState: lcscState,
            detectedPatterns: detectedPatterns
        )

        Logger.ai.debug("[MedGemma:rerank] Prompt: \(prompt.prefix(200))...")

        // 2. Inference with tight timeout
        guard let llm = llm else {
            Logger.ai.warning("Model not loaded for reranking")
            return nil
        }

        do {
            // Clear history then use respond(to:) to keep Gemma chat template.
            // Reranking output ("6,5,2,7,4,3,1") still needs instruction-following format.
            llm.reset()

            try await AsyncHelpers.withTimeout(seconds: CheckInConfiguration.rerankTimeoutSeconds) {
                await llm.respond(to: prompt)
            }

            let output = MedGemmaParser.stripThinkingBlock(
                llm.output.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            Logger.ai.info("[MedGemma:rerank] Output: \(output)")

            // 3. Parse
            return parseRerankOutput(output)
        } catch {
            Logger.ai.warning("Rerank inference failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Parses rerank output into validated [Int] with graceful recovery.
    /// Handles: "6,5,2,7,4,3,1", "```json\n[7,5,2,4,3,1]\n```", partial lists (appends missing).
    private func parseRerankOutput(_ text: String) -> [Int]? {
        // Strip markdown code fences, JSON brackets, whitespace
        var cleaned = text
        cleaned = cleaned.replacingOccurrences(of: "```json", with: "")
        cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        cleaned = cleaned.replacingOccurrences(of: "[", with: "")
        cleaned = cleaned.replacingOccurrences(of: "]", with: "")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract valid integers 1-7, preserving order, deduplicating
        var seen = Set<Int>()
        var result: [Int] = []
        let tokens = cleaned.split(whereSeparator: { $0 == "," || $0.isWhitespace })
        for token in tokens {
            if let num = Int(token.trimmingCharacters(in: .whitespaces)),
               (1...7).contains(num), !seen.contains(num) {
                seen.insert(num)
                result.append(num)
            }
        }

        // Need at least 3 valid sections to trust the ordering
        guard result.count >= 3 else {
            Logger.ai.warning("Rerank parse failed: got \(result) — need at least 3 valid values")
            return nil
        }

        // Append any missing sections at the end (preserves MedGemma's partial intent)
        if result.count < 7 {
            let missing = (1...7).filter { !seen.contains($0) }
            Logger.ai.info("Rerank: appending missing sections \(missing) to partial result \(result)")
            result.append(contentsOf: missing)
        }

        return result
    }

    // MARK: - Cleanup

    /// Unload model from memory
    func unloadModel() {
        llm = nil
        isLoaded = false
        Logger.ai.info("MedGemma model unloaded")
    }

    /// Explicitly resets the engine (unload -> reload)
    /// Useful if inference state gets corrupted
    func resetEngine() async {
        Logger.ai.info("Resetting engine...")
        unloadModel()
        try? await loadModel()
        Logger.ai.info("Engine reset complete")
    }
}
