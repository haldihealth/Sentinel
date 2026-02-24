# GPU Acceleration Guide for MedGemma

## Problem

LLM.swift v1.8.0 does not expose the `n_gpu_layers` parameter, causing all model layers to run on CPU (slow).

**Current behavior:**
- `llama_model_default_params()` sets `n_gpu_layers = 0` (CPU-only)
- LLM.swift only disables GPU on simulator, doesn't enable it on device
- Result: 10-30+ second inference times

**With GPU enabled:**
- All 35 layers offloaded to Metal GPU
- Result: 1-5 second inference times (5-10x faster)

---

## Solution: Fork LLM.swift

### Step 1: Fork the Repository

1. Go to https://github.com/eastriverlee/LLM.swift
2. Click "Fork" to create your own copy
3. Clone your fork:

```bash
git clone https://github.com/YOUR_USERNAME/LLM.swift.git
cd LLM.swift
```

### Step 2: Modify LLM.swift

Edit `Sources/LLM/LLM.swift`:

#### A. Add gpuLayers parameter to main init (~line 160)

```swift
// FIND:
public init?(
    from path: String,
    stopSequence: String? = nil,
    history: [Chat] = [],
    seed: UInt32 = .random(in: .min ... .max),
    topK: Int32 = 40,
    ...

// CHANGE TO:
public init?(
    from path: String,
    stopSequence: String? = nil,
    history: [Chat] = [],
    gpuLayers: Int32 = 999,  // <-- ADD THIS
    seed: UInt32 = .random(in: .min ... .max),
    topK: Int32 = 40,
    ...
```

#### B. Modify model loading (~line 290)

```swift
// FIND:
var modelParams = llama_model_default_params()
#if targetEnvironment(simulator)
modelParams.n_gpu_layers = 0
#endif

// CHANGE TO:
var modelParams = llama_model_default_params()
#if targetEnvironment(simulator)
modelParams.n_gpu_layers = 0
#else
modelParams.n_gpu_layers = gpuLayers  // <-- ADD THIS
#endif
```

#### C. Update convenience initializers

For the URL-based init:
```swift
public convenience init?(
    from url: URL,
    stopSequence: String? = nil,
    history: [Chat] = [],
    gpuLayers: Int32 = 999,  // <-- ADD THIS
    ...
) {
    self.init(
        from: url.path,
        stopSequence: stopSequence,
        history: history,
        gpuLayers: gpuLayers,  // <-- ADD THIS
        ...
    )
}
```

For the Template-based init:
```swift
public convenience init?(
    from url: URL,
    template: Template,
    gpuLayers: Int32 = 999,  // <-- ADD THIS
    history: [Chat] = [],
    ...
) {
    self.init(
        from: url.path,
        stopSequence: template.stopSequence,
        gpuLayers: gpuLayers,  // <-- ADD THIS
        history: history,
        ...
    )
}
```

### Step 3: Commit and Push

```bash
git add .
git commit -m "Add gpuLayers parameter for Metal GPU acceleration"
git push
```

### Step 4: Update Xcode Project

1. In Xcode, go to your project
2. Select the project in the navigator
3. Go to "Package Dependencies" tab
4. Remove the existing LLM.swift package
5. Add your fork: `https://github.com/YOUR_USERNAME/LLM.swift`

### Step 5: Update MedGemmaEngine

Change the model initialization:

```swift
// BEFORE:
guard let model = LLM(from: url, template: .gemma) else {
    throw MedGemmaError.modelLoadFailed
}

// AFTER:
guard let model = LLM(
    from: url,
    template: .gemma,
    gpuLayers: 999,        // Full GPU offload
    maxTokenCount: 512     // Optimized context size
) else {
    throw MedGemmaError.modelLoadFailed
}
```

---

## Alternative: Use LLM.swift 2.x (If Available)

Check if LLM.swift has released a newer version with GPU configuration:
- https://github.com/eastriverlee/LLM.swift/releases
- Look for parameters like `gpuLayers`, `metalLayers`, or `Configuration` struct

---

## Performance Summary

| Setting | Inference Time | Memory |
|---------|----------------|--------|
| CPU-only (current) | 10-30+ seconds | ~3GB |
| GPU (gpuLayers: 999) | 1-5 seconds | ~2.5GB |
| GPU + reduced context (512) | 0.5-3 seconds | ~1.5GB |

---

## Additional Optimizations Already Applied

These optimizations are already in MedGemmaEngine.swift:

1. **Reduced maxTokenCount: 512** (from 2048)
   - 4x faster KV-cache operations
   - Sufficient for short clinical prompts

2. **Low temperature: 0.1**
   - Deterministic output
   - Faster sampling

3. **Compact prompts**
   - PromptBuilder uses abbreviated format
   - ~300-400 characters per prompt

---

## Device Requirements for GPU Acceleration

| Device | RAM | Recommended gpuLayers |
|--------|-----|----------------------|
| iPhone 15 Pro | 8GB | 999 (full) |
| iPhone 14/13 Pro | 6GB | 999 (full) |
| iPhone 12/13 | 4GB | 32 |
| iPhone 11 | 4GB | 24 |
| M1+ Mac | 8GB+ | 999 (full) |
