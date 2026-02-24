import Foundation

// MARK: - Error Types

enum MedGemmaError: LocalizedError {
    case modelNotFound
    case modelLoadFailed
    case contextCreationFailed
    case tokenizationFailed
    case inferenceFailed
    case invalidResponse
    case notLoaded

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "MedGemma model file not found in app bundle"
        case .modelLoadFailed:
            return "Failed to load MedGemma model"
        case .contextCreationFailed:
            return "Failed to create inference context"
        case .tokenizationFailed:
            return "Failed to tokenize input"
        case .inferenceFailed:
            return "Model inference failed"
        case .invalidResponse:
            return "Could not parse model response"
        case .notLoaded:
            return "Model not loaded. Call loadModel() first"
        }
    }
}
