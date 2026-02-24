import Foundation
import AVFoundation
import UIKit
import Vision
import Combine
import os.log

/// Error types for CameraService
enum CameraError: LocalizedError {
    case notAvailable
    case permissionDenied
    case configurationFailed(String)
    case captureSessionNotRunning

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Camera hardware not available on this device"
        case .permissionDenied:
            return "Camera access denied. Please enable in Settings > Sentinel"
        case .configurationFailed(let reason):
            return "Camera setup failed: \(reason)"
        case .captureSessionNotRunning:
            return "Camera session is not running"
        }
    }
}

/// Delegate protocol for continuous face telemetry events
@MainActor
protocol CameraServiceDelegate: AnyObject {
    func cameraService(_ service: CameraService, didCaptureTelemetry telemetry: FaceTelemetry, faceObservation: VNFaceObservation?)
    func cameraService(_ service: CameraService, didFailWithError error: CameraError)
    func cameraServiceVideoDidFinish(_ service: CameraService)
}

extension CameraServiceDelegate {
    func cameraServiceVideoDidFinish(_ service: CameraService) {}
}

/// Manages front-facing camera for continuous behavioral telemetry.
///
/// Uses AVCaptureVideoDataOutput to receive frames at camera rate (~30fps),
/// throttles to ~2fps, runs Apple Vision face landmark detection on each
/// processed frame, and delivers FaceTelemetry (numerical values only,
/// no images saved) to the delegate.
@MainActor
final class CameraService: NSObject, ObservableObject {

    // MARK: - Published State

    @Published private(set) var isConfigured = false

    // MARK: - Properties

    let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.sentinel.face-telemetry", qos: .userInitiated)

    weak var delegate: CameraServiceDelegate?

    // MARK: - Telemetry State (accessed from processingQueue)
    // These are nonisolated(unsafe) because they're accessed from the
    // AVCaptureVideoDataOutput delegate callback on processingQueue.
    // Start/stop is always called from MainActor before/after recording.

    nonisolated(unsafe) var isTelemetryActive = false
    nonisolated(unsafe) private var telemetryStartTime: Date?
    nonisolated(unsafe) private var lastProcessedTime: CFAbsoluteTime = 0

    // MARK: - Video Injection (Developer Mode)

    /// Set this URL before calling startTelemetry() to use a pre-recorded video instead of live camera.
    var demoVideoURL: URL?

    /// Exposed for the preview card (AVPlayerLayer) during video injection mode.
    @Published private(set) var videoPlayer: AVPlayer?

    private var videoItemOutput: AVPlayerItemVideoOutput?
    private var videoFrameTimer: Timer?

    @Published private(set) var isVideoInjectionActive = false

    // MARK: - Configuration

    private let targetFPS: Double = CheckInConfiguration.telemetrySamplingFPS

    // MARK: - Configuration

    /// Configure the camera for front-facing continuous capture
    func configure() async throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            Logger.camera.error("Camera hardware not found")
            throw CameraError.notAvailable
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)

            captureSession.beginConfiguration()

            captureSession.inputs.forEach { captureSession.removeInput($0) }
            captureSession.outputs.forEach { captureSession.removeOutput($0) }

            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            } else {
                Logger.camera.error("Failed to add camera input")
                throw CameraError.configurationFailed("Cannot add camera input")
            }

            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: processingQueue)

            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            } else {
                Logger.camera.error("Failed to add video output")
                throw CameraError.configurationFailed("Cannot add video output")
            }

            captureSession.commitConfiguration()
            isConfigured = true
            Logger.camera.info("Camera configured for continuous telemetry")

            await startSession()
        } catch let error as CameraError {
            throw error
        } catch {
            Logger.camera.error("Camera configuration exception: \(error.localizedDescription)")
            throw CameraError.configurationFailed(error.localizedDescription)
        }
    }

    func startSession() async {
        guard !captureSession.isRunning else { return }

        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
                continuation.resume()
            }
        }
        Logger.camera.info("Camera session started")
    }

    func stopSession() {
        guard captureSession.isRunning else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.stopRunning()
        }
        Logger.camera.info("Camera session stopped")
    }

    // MARK: - Telemetry Control

    func startTelemetry() {
        if let url = demoVideoURL, FileManager.default.fileExists(atPath: url.path) {
            startVideoInjection(url: url)
        } else {
            telemetryStartTime = Date()
            lastProcessedTime = 0
            isTelemetryActive = true
        }
        Logger.camera.info("Behavioral telemetry capture started")
    }

    func stopTelemetry() {
        isTelemetryActive = false
        telemetryStartTime = nil

        // Stop video injection if active
        isVideoInjectionActive = false
        videoFrameTimer?.invalidate()
        videoFrameTimer = nil
        // Capture the item before nilling out the player so removeObserver
        // targets only the specific AVPlayerItem that was observed (not all items).
        let observedItem = videoPlayer?.currentItem
        videoPlayer?.pause()
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: observedItem)
        videoPlayer = nil
        videoItemOutput = nil

        Logger.camera.info("Behavioral telemetry capture stopped")
    }

    // MARK: - Video Injection (Developer Mode)

    private func startVideoInjection(url: URL) {
        let item = AVPlayerItem(url: url)
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        item.add(output)
        videoItemOutput = output

        let player = AVPlayer(playerItem: item)
        videoPlayer = player

        // When the video ends, stop the check-in instead of looping
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.delegate?.cameraServiceVideoDidFinish(self)
            }
        }

        player.play()
        isVideoInjectionActive = true

        // Sample frames at targetFPS (matching live telemetry rate)
        videoFrameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / targetFPS, repeats: true) { [weak self] _ in
            self?.processNextVideoFrame()
        }

        Logger.camera.info("Video injection mode started: \(url.lastPathComponent)")
    }

    private func processNextVideoFrame() {
        guard isVideoInjectionActive,
              let output = videoItemOutput,
              let player = videoPlayer else { return }

        let currentTime = player.currentTime()
        guard output.hasNewPixelBuffer(forItemTime: currentTime) else { return }

        var presentationTime = CMTime()
        guard let pixelBuffer = output.copyPixelBuffer(
            forItemTime: currentTime,
            itemTimeForDisplay: &presentationTime
        ) else { return }

        let elapsed = CMTimeGetSeconds(currentTime)

        processingQueue.async { [weak self] in
            guard let self = self else { return }
            if let result = self.analyzeFace(in: pixelBuffer, at: elapsed) {
                Task { @MainActor in
                    self.delegate?.cameraService(self, didCaptureTelemetry: result.0, faceObservation: result.1)
                }
            }
        }
    }

    // MARK: - Face Analysis (runs on processingQueue)

    /// Extract face telemetry from a pixel buffer using Apple Vision.
    /// This runs on the background processingQueue, not the main actor.
    nonisolated private func analyzeFace(in pixelBuffer: CVPixelBuffer, at timestamp: TimeInterval) -> (FaceTelemetry, VNFaceObservation)? {
        let request = VNDetectFaceLandmarksRequest()
        request.revision = VNDetectFaceLandmarksRequestRevision3

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored, options: [:])

        do {
            try handler.perform([request])
            guard let face = request.results?.first, let landmarks = face.landmarks else { return nil }

            // Eye Openness (left eye bounding box height)
            let leftEye = landmarks.leftEye?.normalizedPoints ?? []
            var eyeMetric = 0.0
            if !leftEye.isEmpty {
                let ys = leftEye.map { $0.y }
                eyeMetric = Double(ys.max()! - ys.min()!) * 100
            }

            // Gaze Deviation (pupil offset from eye center)
            var gazeMetric = 0.0
            if let pupil = landmarks.leftPupil?.normalizedPoints.first {
                let xs = leftEye.map { $0.x }
                let eyeCenterX = (xs.max()! + xs.min()!) / 2
                gazeMetric = Double(Swift.abs(pupil.x - eyeCenterX)) * 100
            }

            // Head Pitch
            let headPitch = face.pitch?.doubleValue ?? 0.0

            let telemetry = FaceTelemetry(
                timestamp: timestamp,
                eyeOpenness: eyeMetric,
                headPitch: headPitch,
                gazeDeviation: gazeMetric
            )
            return (telemetry, face)
        } catch {
            return nil
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Frame throttle: only process at ~2fps
        let now = CFAbsoluteTimeGetCurrent()
        let interval = 1.0 / targetFPS
        guard now - lastProcessedTime >= interval else { return }
        lastProcessedTime = now

        // Only process when telemetry is active
        guard isTelemetryActive, let startTime = telemetryStartTime else { return }

        // Extract pixel buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Calculate relative timestamp
        let elapsed = Date().timeIntervalSince(startTime)

        // Run face analysis on processingQueue (already there from delegate)
        if let result = analyzeFace(in: pixelBuffer, at: elapsed) {
            Task { @MainActor in
                self.delegate?.cameraService(self, didCaptureTelemetry: result.0, faceObservation: result.1)
            }
        }
    }
}
