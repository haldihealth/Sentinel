# MedGemma-4B Integration Guide
## llama.cpp with Swift for On-Device LLM

---

## Overview

**Model**: MedGemma-1.5-4B-GGUF (4-bit quantized)  
**Size**: 2.2GB  
**Runtime**: llama.cpp with Metal acceleration  
**Target**: iPhone 15+ (6GB+ RAM)

---

## Setup Instructions

### 1. Download Model

```bash
# From HuggingFace
huggingface-cli download \
  mradermacher/medgemma-1.5-4b-it-GGUF \
  medgemma-1.5-4b-it.Q4_K_M.gguf \
  --local-dir ./Resources/Models
```

### 2. Add llama.cpp to Xcode

**Option A: Swift Package Manager**

1. File → Add Package Dependencies
2. URL: `https://github.com/ggerganov/llama.cpp`
3. Branch: `master`
4. Add to target: Sentinel

**Option B: Manual Integration**

```bash
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
make
# Copy libllama.a to Xcode project
```

---

## MedGemma Engine Implementation

```swift
// Services/AI/MedGemmaEngine.swift
import Foundation

/// Manages MedGemma-4B inference on-device
actor MedGemmaEngine {
    static let shared = MedGemmaEngine()
    
    // MARK: - Properties
    private var model: OpaquePointer?
    private var context: OpaquePointer?
    private let modelPath: String
    
    // MARK: - Configuration
    private let contextSize: Int32 = 2048
    private let threads: Int32 = 4
    private let temperature: Float = 0.2
    private let maxTokens: Int32 = 100
    
    // MARK: - Initialization
    init() {
        guard let path = Bundle.main.path(
            forResource: "medgemma-1.5-4b-it.Q4_K_M",
            ofType: "gguf"
        ) else {
            fatalError("Model file not found")
        }
        self.modelPath = path
    }
    
    // MARK: - Model Loading
    func loadModel() throws {
        // Load model parameters
        var params = llama_model_default_params()
        params.use_mmap = true
        params.use_mlock = false
        
        // Load model
        model = llama_load_model_from_file(modelPath, params)
        guard model != nil else {
            throw MedGemmaError.modelLoadFailed
        }
        
        // Create context
        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = contextSize
        ctxParams.n_threads = threads
        ctxParams.n_threads_batch = threads
        
        context = llama_new_context_with_model(model, ctxParams)
        guard context != nil else {
            throw MedGemmaError.contextCreationFailed
        }
    }
    
    // MARK: - Inference
    func analyze(_ checkIn: CheckIn, baseline: Baseline) async throws -> MedGemmaResponse {
        let startTime = Date()
        
        // Build prompt
        let prompt = buildPrompt(checkIn: checkIn, baseline: baseline)
        
        // Tokenize
        let tokens = try tokenize(prompt)
        
        // Run inference
        let response = try generate(tokens: tokens)
        
        // Parse JSON
        let parsed = try parseResponse(response)
        
        let inferenceTime = Date().timeIntervalSince(startTime)
        
        return MedGemmaResponse(
            riskTier: parsed.riskTier,
            riskScore: parsed.riskScore,
            reasoning: parsed.reasoning,
            keyDeviations: parsed.keyDeviations,
            safetyPlanItem: parsed.safetyPlanItem,
            action: parsed.action,
            inferenceTimeSeconds: inferenceTime
        )
    }
    
    // MARK: - Private Methods
    private func tokenize(_ text: String) throws -> [llama_token] {
        var tokens = [llama_token](
            repeating: 0,
            count: Int(contextSize)
        )
        
        let count = llama_tokenize(
            model,
            text,
            Int32(text.utf8.count),
            &tokens,
            contextSize,
            true,  // add_bos
            false  // special
        )
        
        guard count >= 0 else {
            throw MedGemmaError.tokenizationFailed
        }
        
        return Array(tokens.prefix(Int(count)))
    }
    
    private func generate(tokens: [llama_token]) throws -> String {
        var tokens = tokens
        var output = ""
        
        // Feed input tokens
        for (i, token) in tokens.enumerated() {
            let status = llama_decode(
                context,
                llama_batch_get_one(&tokens[i], 1, Int32(i), 0)
            )
            
            guard status == 0 else {
                throw MedGemmaError.decodeFailed
            }
        }
        
        // Generate output tokens
        var generatedCount: Int32 = 0
        while generatedCount < maxTokens {
            // Sample next token
            let logits = llama_get_logits(context)
            let vocab_size = llama_n_vocab(model)
            
            // Apply temperature
            var candidates = [llama_token_data]()
            for i in 0..<vocab_size {
                candidates.append(llama_token_data(
                    id: i,
                    logit: logits![Int(i)],
                    p: 0.0
                ))
            }
            
            var candidatesP = llama_token_data_array(
                data: &candidates,
                size: candidates.count,
                sorted: false
            )
            
            llama_sample_temp(context, &candidatesP, temperature)
            let token = llama_sample_token(context, &candidatesP)
            
            // Check for EOS
            if token == llama_token_eos(model) {
                break
            }
            
            // Decode token to text
            var buffer = [CChar](repeating: 0, count: 32)
            let n = llama_token_to_piece(model, token, &buffer, 32)
            if n > 0 {
                output += String(cString: buffer)
            }
            
            // Feed token back
            var batch = llama_batch_get_one(&token, 1, tokens.count + Int(generatedCount), 0)
            llama_decode(context, batch)
            
            generatedCount += 1
        }
        
        return output
    }
    
    private func parseResponse(_ text: String) throws -> ParsedResponse {
        // Remove markdown code blocks if present
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Parse JSON
        guard let data = cleaned.data(using: .utf8) else {
            throw MedGemmaError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        return try decoder.decode(ParsedResponse.self, from: data)
    }
    
    // MARK: - Cleanup
    func unloadModel() {
        if let context = context {
            llama_free(context)
        }
        if let model = model {
            llama_free_model(model)
        }
    }
    
    deinit {
        unloadModel()
    }
}

// MARK: - Supporting Types

enum MedGemmaError: LocalizedError {
    case modelLoadFailed
    case contextCreationFailed
    case tokenizationFailed
    case decodeFailed
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .modelLoadFailed:
            return "Failed to load MedGemma model"
        case .contextCreationFailed:
            return "Failed to create inference context"
        case .tokenizationFailed:
            return "Failed to tokenize input"
        case .decodeFailed:
            return "Inference failed"
        case .invalidResponse:
            return "Could not parse model response"
        }
    }
}

struct ParsedResponse: Codable {
    let riskTier: String
    let riskScore: Double
    let reasoning: String
    let keyDeviations: [String]
    let safetyPlanItem: Int
    let action: String
}
```

---

## Prompt Builder

```swift
// Services/AI/PromptBuilder.swift
import Foundation

struct PromptBuilder {
    static func buildClinicalPrompt(
        checkIn: CheckIn,
        baseline: Baseline,
        userProfile: UserProfile
    ) -> String {
        """
        You are a VA suicide prevention clinical assistant. Analyze this veteran's data.
        
        VETERAN PROFILE:
        - Age: \(userProfile.age), Gender: \(userProfile.gender)
        - Conditions: \(userProfile.diagnoses.joined(separator: ", "))
        - Last crisis: \(formatDate(userProfile.lastCrisis))
        
        BASELINE (30-day average):
        - Sleep: \(baseline.sleep.mean) hours/night
        - Steps: \(Int(baseline.activity.mean)) steps/day
        - HRV: \(baseline.hrv.mean)ms
        - Voice energy: \(baseline.voice.mean)
        - Mood: \(baseline.mood.mean)/10
        
        CURRENT DATA:
        - Sleep: \(checkIn.sleepData?.duration ?? 0)hr (z=\(calculateZ(checkIn.sleepData?.duration, baseline.sleep)))
        - Steps: \(checkIn.activityData?.steps ?? 0) (z=\(calculateZ(checkIn.activityData?.steps, baseline.activity)))
        - HRV: \(checkIn.hrvData?.sdnn ?? 0)ms (z=\(calculateZ(checkIn.hrvData?.sdnn, baseline.hrv)))
        - Voice: \(checkIn.voiceFeatures?.energy ?? 0) (z=\(calculateZ(checkIn.voiceFeatures?.energy, baseline.voice)))
        - Mood: \(checkIn.moodScore)/10
        - C-SSRS tier: \(checkIn.riskTier.rawValue)
        
        CLINICAL CONTEXT (HRV):
        HRV < 50ms indicates autonomic dysregulation (PTSD hypervigilance or acute stress).
        This is an OBJECTIVE biomarker (cannot be masked by self-report bias).
        HRV decline often precedes subjective symptoms by 3-7 days.
        
        \(checkIn.riskTier == .highMonitoring ? orangeModeContext(userProfile) : "")
        
        TASK: Assess risk and recommend intervention.
        
        OUTPUT (JSON only, no markdown):
        {
          "risk_tier": "low|moderate|high",
          "risk_score": 0.0-10.0,
          "reasoning": "Brief clinical explanation (2-3 sentences)",
          "key_deviations": ["hrv", "sleep", "activity", "voice"],
          "safety_plan_item": 1-6,
          "action": "Specific instruction for veteran"
        }
        """
    }
    
    private static func orangeModeContext(_ profile: UserProfile) -> String {
        """
        
        ⚠️ ORANGE MODE CONTEXT:
        - Recent suicide attempt: \(formatDate(profile.lastAttempt))
        - Professional help received: \(profile.receivedProfessionalHelp ? "Yes" : "No")
        - Current status: Post-discharge recovery
        
        HEIGHTENED MONITORING:
        - Be MORE sensitive to small changes (patient is fragile)
        - NEVER downplay concerns
        - Recommend professional contact (Item 4) earlier than usual
        """
    }
    
    private static func calculateZ(_ current: Double?, _ baseline: Baseline) -> String {
        guard let current = current else { return "N/A" }
        let z = (current - baseline.mean) / baseline.stdDev
        return String(format: "%.1f", z)
    }
    
    private static func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "None" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
```

---

## ViewModel Integration

```swift
// ViewModels/CheckInViewModel.swift
@MainActor
final class CheckInViewModel: ObservableObject {
    @Published var isAnalyzing = false
    @Published var medgemmaResponse: MedGemmaResponse?
    
    private let medgemma = MedGemmaEngine.shared
    
    func submitCheckIn() async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        do {
            // Load model if needed (one-time)
            try await medgemma.loadModel()
            
            // Run analysis
            let response = try await medgemma.analyze(
                checkIn,
                baseline: baseline
            )
            
            medgemmaResponse = response
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

---

## Performance Optimization

### 1. Model Loading Strategy

```swift
// Load model on app launch (background thread)
@main
struct SentinelApp: App {
    init() {
        Task {
            do {
                try await MedGemmaEngine.shared.loadModel()
            } catch {
                print("Failed to preload model: \(error)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 2. Batch Size Optimization

```swift
// Adjust based on device
let batchSize: Int32 = {
    let ram = ProcessInfo.processInfo.physicalMemory
    if ram >= 8_000_000_000 {  // 8GB+
        return 512
    } else {
        return 256
    }
}()
```

### 3. Metal Acceleration

```swift
// Enable Metal backend (GPU)
var ctxParams = llama_context_default_params()
ctxParams.n_gpu_layers = 32  // Offload layers to GPU
```

---

## Testing

```swift
@MainActor
class MedGemmaEngineTests: XCTestCase {
    func testModelLoading() async throws {
        let engine = MedGemmaEngine.shared
        try await engine.loadModel()
        // Model should be loaded without errors
    }
    
    func testInference() async throws {
        let engine = MedGemmaEngine.shared
        try await engine.loadModel()
        
        let checkIn = CheckIn.mock
        let baseline = Baseline.mock
        
        let response = try await engine.analyze(checkIn, baseline: baseline)
        
        XCTAssertNotNil(response)
        XCTAssert(response.inferenceTimeSeconds < 20)  // < 20 seconds
    }
    
    func testPromptBuilding() {
        let prompt = PromptBuilder.buildClinicalPrompt(
            checkIn: .mock,
            baseline: .mock,
            userProfile: .mock
        )
        
        XCTAssertTrue(prompt.contains("VETERAN PROFILE"))
        XCTAssertTrue(prompt.contains("HRV"))
    }
}
```

---

## Troubleshooting

### Model Won't Load

```
Error: modelLoadFailed
```

**Fix**:
1. Check model file exists in bundle
2. Verify file size (~2.2GB)
3. Check file extension (.gguf)

### Out of Memory

```
Error: Failed to allocate memory
```

**Fix**:
1. Reduce context size: `contextSize = 1024`
2. Reduce batch size: `batchSize = 128`
3. Close background apps on device

### Slow Inference (>30 seconds)

**Fix**:
1. Enable Metal: `n_gpu_layers = 32`
2. Reduce max tokens: `maxTokens = 80`
3. Use smaller model (2B instead of 4B) - fallback only

---

## Performance Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| Model load time | < 10 seconds | First launch |
| Inference latency | < 15 seconds | CheckIn submit |
| Memory usage | < 3GB | Instruments |
| Battery per inference | < 2% | 7-day test |

---

## Checklist

- [ ] Model file added to Xcode bundle
- [ ] llama.cpp integrated (SPM or manual)
- [ ] Metal acceleration enabled
- [ ] Load model on app launch (background)
- [ ] Error handling for all operations
- [ ] Inference time logged (monitoring)
- [ ] Tested on real device (iPhone 15 Pro)
- [ ] Memory profiled (Instruments)
- [ ] Fallback for older devices (rule-based)
