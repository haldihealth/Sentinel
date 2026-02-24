import Foundation
import SwiftData

/// Main check-in record containing all data from a daily check-in
@Model
final class CheckInRecord {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var checkInType: String  // "multimodal", "text-only", etc.
    
    // Multimodal data (optional)
    @Relationship(deleteRule: .cascade) var facialBiomarkers: FacialBiomarkers?
    @Relationship(deleteRule: .cascade) var audioMetadata: AudioMetadata?
    
    // C-SSRS responses (Phase 6)
    var q1WishDead: Bool?
    var q2SuicidalThoughts: Bool?
    var q3ThoughtsWithMethod: Bool?
    var q4Intent: Bool?
    var q5Plan: Bool?
    var q6RecentAttempt: Bool?
    var determinedRiskTier: String?  // Stored as rawValue string ("0", "1", etc.). Legacy data may use color names ("green", "yellow", etc.)
    var derivedRiskSource: String? // "CSSR" or "MedGemma"
    var riskExplanation: String? // Explanation for the risk tier
    
    init(id: UUID = UUID(), timestamp: Date = Date(), type: String = "multimodal") {
        self.id = id
        self.timestamp = timestamp
        self.checkInType = type
    }
}

/// Facial embeddings and metadata from video analysis
@Model
final class FacialBiomarkers {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    
    // Embeddings (encrypted at rest via SwiftData)
    @Attribute(.externalStorage) var embedding: Data  // Float array stored as Data
    
    // Metadata
    var frameCount: Int
    var averageQuality: Float
    var embeddingDimension: Int  // Typically 512 for Vision Feature Print
    
    init(embedding: Data, frameCount: Int, quality: Float, dimension: Int = 512) {
        self.id = UUID()
        self.timestamp = Date()
        self.embedding = embedding
        self.frameCount = frameCount
        self.averageQuality = quality
        self.embeddingDimension = dimension
    }
    
    /// Convert embedding Data back to float array
    func getEmbeddingArray() -> [Float]? {
        let floatCount = embedding.count / MemoryLayout<Float>.size
        guard floatCount == embeddingDimension else { return nil }
        
        return embedding.withUnsafeBytes { rawBufferPointer in
            let floatBuffer = rawBufferPointer.bindMemory(to: Float.self)
            return Array(floatBuffer)
        }
    }
}

/// Audio metadata and transcript from voice analysis
@Model
final class AudioMetadata {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var duration: TimeInterval
    var sampleRate: Double

    // Speech transcript (Apple Speech framework)
    var transcript: String?

    init(duration: TimeInterval, sampleRate: Double, transcript: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.duration = duration
        self.sampleRate = sampleRate
        self.transcript = transcript
    }
}

// MARK: - Helper Extensions

extension CheckInRecord {
    /// Check if this record has multimodal data
    var hasMultimodalData: Bool {
        facialBiomarkers != nil || audioMetadata != nil
    }
    
    /// Get facial embedding if available
    var facialEmbedding: [Float]? {
        facialBiomarkers?.getEmbeddingArray()
    }
}
