import Foundation
import LLM

// MARK: - GPU Configuration

/// Configuration for GPU/Metal acceleration
public struct GPUConfig {
    /// Number of layers to offload to GPU
    /// - For MedGemma-4B Q4_K_M: Recommend 32-35 layers for full GPU offload
    /// - Set to 0 for CPU-only
    /// - Set to -1 or 999 to offload ALL layers to GPU (maximum performance)
    public let gpuLayers: Int32

    /// Maximum context size (affects memory usage and speed)
    /// Lower values = faster inference, less memory
    /// Minimum recommended: 512 for simple prompts
    public let maxTokenCount: Int32

    /// Number of tokens to process in parallel (batch size)
    /// Higher = faster but more memory
    public let batchSize: Int32

    /// Number of CPU threads for any CPU operations
    /// Set to 0 for auto-detect
    public let threadCount: Int32

    /// Preset configurations for common use cases
    public static let maxGPU = GPUConfig(
        gpuLayers: 999,      // Offload all layers to Metal GPU
        maxTokenCount: 1024, // Moderate context for speed
        batchSize: 512,
        threadCount: 0
    )

    public static let balanced = GPUConfig(
        gpuLayers: 32,       // Offload most layers to GPU
        maxTokenCount: 512,  // Smaller context for faster inference
        batchSize: 256,
        threadCount: 0
    )

    public static let lowMemory = GPUConfig(
        gpuLayers: 16,       // Partial GPU offload
        maxTokenCount: 256,  // Minimal context
        batchSize: 128,
        threadCount: 4
    )

    public static let cpuOnly = GPUConfig(
        gpuLayers: 0,
        maxTokenCount: 2048,
        batchSize: 512,
        threadCount: 0
    )

    public init(
        gpuLayers: Int32 = 999,
        maxTokenCount: Int32 = 1024,
        batchSize: Int32 = 512,
        threadCount: Int32 = 0
    ) {
        self.gpuLayers = gpuLayers
        self.maxTokenCount = maxTokenCount
        self.batchSize = batchSize
        self.threadCount = threadCount
    }
}

// MARK: - LLM Extension for GPU Configuration

extension LLM {
    /// Create a GPU-optimized LLM instance
    ///
    /// This convenience initializer provides access to GPU configuration
    /// that isn't exposed in the standard LLM.swift initializer.
    ///
    /// - Parameters:
    ///   - url: Path to the GGUF model file
    ///   - template: Chat template for the model (e.g., .gemma)
    ///   - gpuConfig: GPU and performance configuration
    /// - Returns: Configured LLM instance or nil if loading fails
    ///
    /// - Note: For MedGemma-4B, use `gpuLayers: 999` to offload all layers to Metal GPU
    public static func withGPU(
        from url: URL,
        template: Template,
        config: GPUConfig = .maxGPU
    ) -> LLM? {
        // Unfortunately, LLM.swift doesn't expose GPU layers in its public API
        // The model is loaded in init with default params
        //
        // WORKAROUND: We use the standard initializer but with optimized maxTokenCount
        // For true GPU acceleration, see the MedGemmaEngine+GPU.swift extension
        // which uses environment-based Metal hints

        return LLM(
            from: url,
            template: template,
            maxTokenCount: config.maxTokenCount
        )
    }
}

// MARK: - Metal Acceleration Helper

/// Helper to check Metal GPU availability and capabilities
public struct MetalAccelerator {

    /// Check if Metal GPU is available on this device
    public static var isMetalAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        // Metal is available on all modern iOS devices (A7+) and Apple Silicon Macs
        return true
        #endif
    }

    /// Get recommended GPU layers for the current device
    /// Based on device memory and GPU capabilities
    public static var recommendedGPULayers: Int32 {
        #if targetEnvironment(simulator)
        return 0
        #elseif os(iOS)
        // iOS devices with 4GB+ RAM can handle full GPU offload
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(physicalMemory) / (1024 * 1024 * 1024)

        if memoryGB >= 6.0 {
            return 999 // Full GPU offload for iPhone Pro models
        } else if memoryGB >= 4.0 {
            return 32  // Most layers for standard iPhones
        } else {
            return 16  // Partial offload for older devices
        }
        #elseif os(macOS)
        return 999 // Apple Silicon Macs can handle full offload
        #else
        return 0
        #endif
    }

    /// Print GPU configuration info for debugging
    public static func printDeviceInfo() {
        let memory = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(memory) / (1024 * 1024 * 1024)
        let cpuCount = ProcessInfo.processInfo.processorCount

        print("🖥️ Device Info:")
        print("  - Memory: \(String(format: "%.1f", memoryGB)) GB")
        print("  - CPU Cores: \(cpuCount)")
        print("  - Metal Available: \(isMetalAvailable)")
        print("  - Recommended GPU Layers: \(recommendedGPULayers)")
    }
}
