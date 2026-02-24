import Foundation
import Speech
import AVFoundation
import Combine
import os.log

/// Error types for AudioEngine failures
enum AudioEngineError: LocalizedError {
    case recognitionRequestFailed
    case authorizationDenied
    case audioSessionFailed(String)
    case recordingFailed(String)

    var errorDescription: String? {
        switch self {
        case .recognitionRequestFailed:
            return "Unable to create speech recognition request"
        case .authorizationDenied:
            return "Speech recognition authorization denied"
        case .audioSessionFailed(let reason):
            return "Audio session error: \(reason)"
        case .recordingFailed(let reason):
            return "Recording failed: \(reason)"
        }
    }
}

/// Handles audio recording, transcription, WPM analysis, and prosodic feature extraction
@MainActor
class AudioEngine: ObservableObject {

    // MARK: - Published State
    @Published var currentTranscript: String = ""
    @Published var isRecording = false
    @Published var currentAudioLevel: Float = -60.0

    // MARK: - Private Properties
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private var audioFile: AVAudioFile?
    private var recordingURL: URL?
    private var startTime: Date?
    private var wordCount: Int = 0

    // MARK: - Prosody Analyzer
    private let prosodyAnalyzer = ProsodyAnalyzer()

    // MARK: - Authorization
    func requestAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    // MARK: - Recording Control
    func startRecording() throws {
        // Cancel any existing task
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        // Reset prosody analyzer for fresh session
        prosodyAnalyzer.reset()

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Prepare file for writing
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "checkin_audio_\(Date().timeIntervalSince1970).caf"
        let fileURL = tempDir.appendingPathComponent(fileName)
        self.recordingURL = fileURL

        // Prepare Speech Request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw AudioEngineError.recognitionRequestFailed
        }
        recognitionRequest.shouldReportPartialResults = true

        // Configure input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Initialize audio file for writing
        do {
           self.audioFile = try AVAudioFile(forWriting: fileURL, settings: recordingFormat.settings)
        } catch {
            Logger.audio.error("Failed to create audio file: \(error.localizedDescription)")
        }

        let file = self.audioFile
        let analyzer = self.prosodyAnalyzer
        let recordingStartTime = Date()
        self.startTime = recordingStartTime

        // Install Tap — feeds speech recognition, file writer, AND prosody analyzer
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self, weak recognitionRequest] (buffer, when) in
            guard let self = self else { return }

            // 1. Append to speech recognition
            recognitionRequest?.append(buffer)

            // 2. Write to file
            try? file?.write(from: buffer)

            // 3. Process for prosodic features
            let elapsed = Date().timeIntervalSince(recordingStartTime)
            analyzer.processBuffer(buffer, at: elapsed)

            // 4. Update audio level for waveform visualization
            Task { @MainActor in
                self.currentAudioLevel = analyzer.currentLevelDB
            }
        }

        // Start Recognition
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            var isFinal = false

            if let result = result {
                self.currentTranscript = result.bestTranscription.formattedString
                self.wordCount = result.bestTranscription.segments.count
                isFinal = result.isFinal
            }

            if error != nil || isFinal {
                if self.audioEngine.isRunning {
                    self.audioEngine.stop()
                    inputNode.removeTap(onBus: 0)
                }
                self.isRecording = false
            }
        }

        audioEngine.prepare()
        try audioEngine.start()

        isRecording = true
        Logger.audio.info("Audio recording started with prosody analysis")
    }

    // MARK: - Developer Video Mode

    /// Developer mode only — bypasses the microphone entirely.
    /// Reads audio directly from the video file and feeds it to SFSpeechRecognizer
    /// so the video's speech is transcribed as if it were a real check-in.
    /// AVPlayer continues to route video audio to the speaker independently.
    func startRecordingFromVideoFile(url: URL) throws {
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        prosodyAnalyzer.reset()

        // playAndRecord + defaultToSpeaker: lets AVPlayer output to speaker
        // while this session handles recognition.
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        try? audioSession.overrideOutputAudioPort(.speaker)

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "checkin_audio_\(Date().timeIntervalSince1970).caf"
        recordingURL = tempDir.appendingPathComponent(fileName)
        startTime = Date()
        wordCount = 0

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let req = recognitionRequest else { throw AudioEngineError.recognitionRequestFailed }
        req.shouldReportPartialResults = true

        recognitionTask = speechRecognizer?.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let result = result {
                self.currentTranscript = result.bestTranscription.formattedString
                self.wordCount = result.bestTranscription.segments.count
            }
            if error != nil || result?.isFinal == true {
                self.isRecording = false
            }
        }

        isRecording = true
        Logger.audio.info("[DevMode] Audio recognition started from video file")

        // Read the video's audio track on a background thread and pipe it into the recognizer.
        // Using 'outputSettings: nil' preserves the native format (AAC, PCM, etc.);
        // SFSpeechAudioBufferRecognitionRequest handles all common iOS audio formats.
        let capturedURL = url
        let capturedReq = req
        DispatchQueue.global(qos: .userInitiated).async {
            AudioEngine.feedVideoAudio(from: capturedURL, into: capturedReq)
        }
    }

    private static func feedVideoAudio(from url: URL, into request: SFSpeechAudioBufferRecognitionRequest) {
        let asset = AVURLAsset(url: url)
        let audioTracks = asset.tracks(withMediaType: .audio)
        guard let audioTrack = audioTracks.first else {
            Logger.audio.warning("[DevMode] Video has no audio track — transcript will be empty")
            request.endAudio()
            return
        }

        do {
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
            output.alwaysCopiesSampleData = false
            reader.add(output)

            guard reader.startReading() else {
                Logger.audio.error("[DevMode] AVAssetReader failed: \(reader.error?.localizedDescription ?? "unknown")")
                request.endAudio()
                return
            }

            while reader.status == .reading {
                guard let buffer = output.copyNextSampleBuffer() else { break }
                request.appendAudioSampleBuffer(buffer)
            }

            let status = reader.status == .completed ? "complete" : "interrupted"
            Logger.audio.info("[DevMode] Finished feeding video audio (\(status))")
        } catch {
            Logger.audio.error("[DevMode] AVAssetReader setup failed: \(error)")
        }

        request.endAudio()
    }

    // MARK: - Stop

    /// Stop recording and return all captured data including voice features
    func stopRecording() -> (url: URL?, transcript: String, wpm: Double, voiceFeatures: VoiceFeatures) {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        // Always end audio — covers both mic mode and video-file mode.
        recognitionRequest?.endAudio()

        isRecording = false
        Logger.audio.info("Audio recording stopped")

        // Calculate WPM
        let duration = Date().timeIntervalSince(startTime ?? Date())
        let minutes = duration / 60.0
        let wpm = minutes > 0 ? Double(wordCount) / minutes : 0.0

        // Finalize prosodic features
        let voiceFeatures = prosodyAnalyzer.finalize(totalDuration: duration, wordCount: wordCount)

        Logger.audio.info("Voice features: pitch=\(String(format: "%.1f", voiceFeatures.meanPitch ?? 0))Hz, pauses=\(voiceFeatures.pauseCount ?? 0), energy=\(String(format: "%.1f", voiceFeatures.meanEnergy ?? 0))dB")

        return (recordingURL, currentTranscript, wpm, voiceFeatures)
    }
}
