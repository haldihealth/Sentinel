import Foundation

/// State machine for multimodal check-in flow
enum CheckInState: Equatable {
    case requestingPermissions
    case ready
    case recording(progress: Double, qualityScore: Float, elapsedTime: TimeInterval)
    case processing
    case completed(result: CheckInRecord?)
    case failed(error: CheckInError)
    
    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }
    
    var canStartRecording: Bool {
        if case .ready = self { return true }
        return false
    }
    
    static func == (lhs: CheckInState, rhs: CheckInState) -> Bool {
        switch (lhs, rhs) {
        case (.requestingPermissions, .requestingPermissions),
             (.ready, .ready),
             (.processing, .processing):
            return true
        case (.recording(let lp, let lq, let lt), .recording(let rp, let rq, let rt)):
            return lp == rp && lq == rq && lt == rt
        case (.completed(let l), .completed(let r)):
            return l?.id == r?.id
        case (.failed(let l), .failed(let r)):
            return l == r
        default:
            return false
        }
    }
}

/// Comprehensive error cases for multimodal check-in
enum CheckInError: LocalizedError, Equatable {
    case cameraPermissionDenied
    case microphonePermissionDenied
    case captureSessionFailed(underlying: String)
    case noFaceDetected
    case poorQualityFrames(score: Float)
    case embeddingGenerationFailed
    case audioExtractionFailed
    case hearAPITimeout
    case hearAPIError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .cameraPermissionDenied:
            return "Camera access is required to continue."
        case .microphonePermissionDenied:
            return "Microphone access is required for voice analysis."
        case .captureSessionFailed(let underlying):
            return "Camera failed to start: \(underlying)"
        case .noFaceDetected:
            return "We couldn't detect your face. Please ensure good lighting and look at the camera."
        case .poorQualityFrames(let score):
            return "Video quality was too low (score: \(String(format: "%.1f", score))). Please try again in better lighting."
        case .embeddingGenerationFailed:
            return "Failed to analyze facial data."
        case .audioExtractionFailed:
            return "Failed to process audio."
        case .hearAPITimeout:
            return "Audio analysis timed out. Please check your connection."
        case .hearAPIError(let statusCode):
            return "Audio analysis failed (error \(statusCode))."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .cameraPermissionDenied, .microphonePermissionDenied:
            return "Please enable permissions in Settings to use this feature."
        case .noFaceDetected, .poorQualityFrames:
            return "Try moving to a well-lit area and keeping your face centered."
        case .captureSessionFailed, .embeddingGenerationFailed:
            return "Please try again. If the problem persists, you can skip this step."
        case .audioExtractionFailed, .hearAPITimeout, .hearAPIError:
            return "You can proceed with video-only analysis or skip this step."
        }
    }
    
    static func == (lhs: CheckInError, rhs: CheckInError) -> Bool {
        switch (lhs, rhs) {
        case (.cameraPermissionDenied, .cameraPermissionDenied),
             (.microphonePermissionDenied, .microphonePermissionDenied),
             (.noFaceDetected, .noFaceDetected),
             (.embeddingGenerationFailed, .embeddingGenerationFailed),
             (.audioExtractionFailed, .audioExtractionFailed),
             (.hearAPITimeout, .hearAPITimeout):
            return true
        case (.captureSessionFailed(let a), .captureSessionFailed(let b)):
            return a == b
        case (.poorQualityFrames(let a), .poorQualityFrames(let b)):
            return a == b
        case (.hearAPIError(let a), .hearAPIError(let b)):
            return a == b
        default:
            return false
        }
    }
}
