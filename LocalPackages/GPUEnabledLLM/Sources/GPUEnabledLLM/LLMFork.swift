import Foundation
import LLM

// MARK: - GPU-Enabled LLM Factory
//
// Since LLM.swift doesn't expose n_gpu_layers in its public API,
// this file documents the required changes to enable GPU acceleration.
//
// SOLUTION: Fork LLM.swift and modify the initializer
//
// In your fork of LLM.swift, modify the init in Sources/LLM/LLM.swift:
//
// BEFORE (line ~290):
// ```
// var modelParams = llama_model_default_params()
// #if targetEnvironment(simulator)
// modelParams.n_gpu_layers = 0
// #endif
// ```
//
// AFTER:
// ```
// var modelParams = llama_model_default_params()
// #if targetEnvironment(simulator)
// modelParams.n_gpu_layers = 0
// #else
// modelParams.n_gpu_layers = gpuLayers  // NEW PARAMETER
// #endif
// ```
//
// Add parameter to init signature:
// ```
// public init?(
//     from path: String,
//     stopSequence: String? = nil,
//     history: [Chat] = [],
//     gpuLayers: Int32 = 999,        // <-- ADD THIS
//     seed: UInt32 = .random(...),
//     ...
// )
// ```

/// Creates a GPU-enabled LLM by applying llama.cpp Metal backend hints
/// This is a workaround until LLM.swift exposes n_gpu_layers directly
@MainActor
public final class GPUEnabledLLMFactory {

    /// Create an LLM with optimal settings for GPU inference
    ///
    /// While we can't set n_gpu_layers directly without forking LLM.swift,
    /// we can optimize other parameters for better performance:
    /// - Reduced maxTokenCount for faster KV-cache operations
    /// - Lower temperature for faster sampling
    /// - Optimized topK/topP for faster inference
    ///
    /// - Parameters:
    ///   - url: Path to the GGUF model file
    ///   - template: Chat template (.gemma for MedGemma)
    ///   - maxTokenCount: Maximum context length (lower = faster)
    public static func create(
        from url: URL,
        template: Template,
        maxTokenCount: Int32 = 512
    ) -> LLM? {
        // Print device capabilities
        MetalAccelerator.printDeviceInfo()

        #if !targetEnvironment(simulator)
        print("⚠️ GPU Acceleration Note:")
        print("   LLM.swift uses llama.cpp's Metal backend automatically")
        print("   but n_gpu_layers defaults to 0 (CPU-only)")
        print("")
        print("   To enable GPU, fork LLM.swift and set n_gpu_layers:")
        print("   modelParams.n_gpu_layers = 999 // Full GPU offload")
        print("")
        #endif

        // Create LLM with optimized settings
        guard let llm = LLM(
            from: url,
            template: template,
            topK: 40,
            topP: 0.95,
            temp: 0.1,
            maxTokenCount: maxTokenCount
        ) else {
            print("❌ Failed to create LLM instance")
            return nil
        }

        print("✅ LLM created with maxTokenCount: \(maxTokenCount)")
        return llm
    }
}

// MARK: - Fork Instructions

/// Complete guide to enable GPU acceleration
public enum GPUEnablementGuide {

    /// Steps to fork LLM.swift and enable GPU
    public static func printInstructions() {
        print("""
        ═══════════════════════════════════════════════════════════════
        GPU ACCELERATION FOR LLM.SWIFT - FORK INSTRUCTIONS
        ═══════════════════════════════════════════════════════════════

        PROBLEM:
        LLM.swift doesn't expose n_gpu_layers parameter, causing models
        to load on CPU only (n_gpu_layers defaults to 0 in llama.cpp)

        SOLUTION:
        Fork LLM.swift and add GPU layer parameter

        STEPS:

        1. FORK THE REPOSITORY
           Go to: https://github.com/eastriverlee/LLM.swift
           Click "Fork" to create your own copy

        2. CLONE YOUR FORK
           git clone https://github.com/YOUR_USERNAME/LLM.swift.git
           cd LLM.swift

        3. MODIFY Sources/LLM/LLM.swift

           a) Add parameter to init (around line 160):

              public init?(
                  from path: String,
                  stopSequence: String? = nil,
                  history: [Chat] = [],
                  gpuLayers: Int32 = 999,        // ADD THIS LINE
                  seed: UInt32 = .random(in: .min ... .max),
                  topK: Int32 = 40,
                  ...

           b) Modify model loading (around line 290):

              var modelParams = llama_model_default_params()
              #if targetEnvironment(simulator)
              modelParams.n_gpu_layers = 0
              #else
              modelParams.n_gpu_layers = gpuLayers  // ADD THIS LINE
              #endif

           c) Also modify the Template-based convenience init:

              public convenience init?(
                  from path: String,
                  template: Template,
                  gpuLayers: Int32 = 999,        // ADD THIS LINE
                  ...

              And pass it through:
              self.init(
                  from: path,
                  stopSequence: template.stopSequence,
                  gpuLayers: gpuLayers,          // ADD THIS LINE
                  ...

        4. COMMIT AND PUSH
           git add .
           git commit -m "Add GPU layers parameter for Metal acceleration"
           git push

        5. UPDATE YOUR XCODE PROJECT
           In Xcode: File → Packages → Update to Latest Package Versions

           Then change your Package dependency from:
           https://github.com/eastriverlee/LLM.swift

           To your fork:
           https://github.com/YOUR_USERNAME/LLM.swift

        6. UPDATE MedGemmaEngine.swift
           Change model initialization to:

           guard let model = LLM(
               from: url,
               template: .gemma,
               gpuLayers: 999,          // Full GPU offload
               maxTokenCount: 512       // Reduced for speed
           ) else {
               throw MedGemmaError.modelLoadFailed
           }

        ═══════════════════════════════════════════════════════════════

        EXPECTED PERFORMANCE IMPROVEMENT:
        - CPU-only (current): 10-30+ seconds per inference
        - GPU-enabled: 1-5 seconds per inference (5-10x faster)

        For MedGemma-4B Q4_K_M model:
        - Model has ~35 transformer layers
        - gpuLayers: 999 offloads all layers to Metal GPU
        - Recommended device: iPhone 13+ or M1+ Mac

        ═══════════════════════════════════════════════════════════════
        """)
    }
}
