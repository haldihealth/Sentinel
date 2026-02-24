import Foundation
import AVFoundation
import Accelerate
import os.log

/// Real-time prosodic feature extractor for audio buffers.
///
/// Hooks into AudioEngine's tap to analyze each PCM buffer for
/// energy (RMS), pitch (F0 via autocorrelation), and pause patterns.
/// Call `processBuffer(_:at:)` for each buffer during recording,
/// then `finalize()` to compute aggregate VoiceFeatures.
class ProsodyAnalyzer {

    // MARK: - Accumulated Metrics

    private var energySamples: [Float] = []
    private var pitchSamples: [Float] = []
    private var speechEnergySamples: [Float] = []
    private var silenceEnergySamples: [Float] = []

    // MARK: - Pause Detection State

    private var isSpeaking = false
    private var silenceStartTime: TimeInterval = 0
    private var pauseDurations: [TimeInterval] = []
    private var totalSilenceDuration: TimeInterval = 0
    private var hasSpokeOnce = false

    // MARK: - Configuration

    /// RMS threshold in dB below which audio is considered silence
    private let silenceThresholdDB: Float = -40.0

    /// Minimum silence gap (seconds) to count as a pause (not just a breath)
    private let minimumPauseDuration: TimeInterval = 0.3

    /// Pitch detection range (Hz) — typical human speech
    private let minPitchHz: Float = 80.0
    private let maxPitchHz: Float = 400.0

    // MARK: - Current Level (for waveform visualization)

    /// Most recent RMS level in dB, updated per buffer
    private(set) var currentLevelDB: Float = -60.0

    // MARK: - Processing

    /// Process a single audio buffer. Call this inside the AudioEngine tap.
    /// - Parameters:
    ///   - buffer: PCM audio buffer from AVAudioEngine tap
    ///   - time: Seconds since recording started
    func processBuffer(_ buffer: AVAudioPCMBuffer, at time: TimeInterval) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        let sampleRate = Float(buffer.format.sampleRate)

        // 1. RMS Energy
        let rmsDB = computeRMSdB(channelData, count: frameCount)
        energySamples.append(rmsDB)
        currentLevelDB = rmsDB

        let isSilent = rmsDB < silenceThresholdDB

        // 2. Pause Detection
        updatePauseState(isSilent: isSilent, at: time)

        // 3. Categorize energy for SNR
        if isSilent {
            silenceEnergySamples.append(rmsDB)
        } else {
            speechEnergySamples.append(rmsDB)
        }

        // 4. Pitch (only on speech frames — silence gives garbage F0)
        if !isSilent {
            if let f0 = estimatePitch(channelData, count: frameCount, sampleRate: sampleRate) {
                pitchSamples.append(f0)
            }
        }
    }

    /// Compute final aggregate voice features after recording ends.
    /// - Parameters:
    ///   - totalDuration: Total recording duration in seconds
    ///   - wordCount: Word count from speech recognizer (for speech rate)
    func finalize(totalDuration: TimeInterval, wordCount: Int = 0) -> VoiceFeatures {
        var features = VoiceFeatures(durationSeconds: totalDuration)

        // Prosodic: Pitch
        let speechPitches = pitchSamples.filter { $0 > 0 }
        if !speechPitches.isEmpty {
            features.meanPitch = Double(mean(speechPitches))
            features.pitchVariability = Double(stddev(speechPitches))
        }

        // Prosodic: Energy
        if !energySamples.isEmpty {
            features.meanEnergy = Double(mean(energySamples))
            features.energyVariability = Double(stddev(energySamples))
        }

        // Prosodic: Speech rate
        let speechDuration = totalDuration - totalSilenceDuration
        if speechDuration > 0 && wordCount > 0 {
            features.speechRate = Double(wordCount) / speechDuration
        }

        // Temporal: Pauses
        features.pauseCount = pauseDurations.count
        if !pauseDurations.isEmpty {
            features.averagePauseDuration = pauseDurations.reduce(0, +) / Double(pauseDurations.count)
        }

        // Temporal: Speech percentage
        if totalDuration > 0 {
            features.speechPercentage = ((totalDuration - totalSilenceDuration) / totalDuration) * 100.0
        }

        // Quality: SNR
        if !speechEnergySamples.isEmpty && !silenceEnergySamples.isEmpty {
            features.snr = Double(mean(speechEnergySamples) - mean(silenceEnergySamples))
        }

        return features
    }

    /// Reset all state for a new recording session
    func reset() {
        energySamples.removeAll()
        pitchSamples.removeAll()
        speechEnergySamples.removeAll()
        silenceEnergySamples.removeAll()
        pauseDurations.removeAll()
        totalSilenceDuration = 0
        isSpeaking = false
        silenceStartTime = 0
        hasSpokeOnce = false
        currentLevelDB = -60.0
    }

    // MARK: - Private: RMS

    private func computeRMSdB(_ samples: UnsafePointer<Float>, count: Int) -> Float {
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(count))

        // Convert to dB, clamp to avoid -inf
        let db = 20.0 * log10(max(rms, 1e-10))
        return db
    }

    // MARK: - Private: Pitch via Autocorrelation

    private func estimatePitch(_ samples: UnsafePointer<Float>, count: Int, sampleRate: Float) -> Float? {
        // Lag range for human speech pitch
        let minLag = Int(sampleRate / maxPitchHz)  // ~110 at 44.1kHz/400Hz
        let maxLag = Int(sampleRate / minPitchHz)  // ~551 at 44.1kHz/80Hz

        guard maxLag < count else { return nil }

        // Autocorrelation via vDSP
        var correlation = [Float](repeating: 0, count: maxLag + 1)
        for lag in minLag...maxLag {
            var sum: Float = 0
            vDSP_dotpr(samples, 1, samples.advanced(by: lag), 1, &sum, vDSP_Length(count - lag))
            correlation[lag] = sum
        }

        // Find the lag with maximum correlation
        var bestLag = minLag
        var bestCorrelation: Float = correlation[minLag]
        for lag in (minLag + 1)...maxLag {
            if correlation[lag] > bestCorrelation {
                bestCorrelation = correlation[lag]
                bestLag = lag
            }
        }

        // Validate: peak must be significantly above noise floor
        let energy = correlation[0] // autocorrelation at lag 0 = total energy
        guard energy > 0, bestCorrelation / energy > 0.2 else { return nil }

        return sampleRate / Float(bestLag)
    }

    // MARK: - Private: Pause State Machine

    private func updatePauseState(isSilent: Bool, at time: TimeInterval) {
        if isSilent {
            if isSpeaking {
                // Transition: speech → silence
                isSpeaking = false
                silenceStartTime = time
            }
        } else {
            if !isSpeaking {
                // Transition: silence → speech
                if hasSpokeOnce {
                    let gap = time - silenceStartTime
                    if gap >= minimumPauseDuration {
                        pauseDurations.append(gap)
                    }
                    totalSilenceDuration += gap
                }
                isSpeaking = true
                hasSpokeOnce = true
            }
        }
    }

    // MARK: - Private: Stats Helpers

    private func mean(_ values: [Float]) -> Float {
        guard !values.isEmpty else { return 0 }
        var result: Float = 0
        vDSP_meanv(values, 1, &result, vDSP_Length(values.count))
        return result
    }

    private func stddev(_ values: [Float]) -> Float {
        guard values.count > 1 else { return 0 }
        let m = mean(values)
        var squared = [Float](repeating: 0, count: values.count)
        var mNeg = -m
        vDSP_vsadd(values, 1, &mNeg, &squared, 1, vDSP_Length(values.count))
        vDSP_vsq(squared, 1, &squared, 1, vDSP_Length(values.count))
        var variance: Float = 0
        vDSP_meanv(squared, 1, &variance, vDSP_Length(squared.count))
        return sqrt(variance)
    }
}
