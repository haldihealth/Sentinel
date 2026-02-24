import SwiftUI
import AVFoundation
import Combine

/// Full-screen view for recording mission briefing videos
struct BriefingRecorderView: View {
    @ObservedObject var viewModel: HopeBoxViewModel
    let onDismiss: () -> Void

    @StateObject private var recorder = VideoRecorderController()
    @State private var showPermissionAlert = false
    @State private var recordingTimeRemaining: TimeInterval = 30
    @State private var isRecording = false
    @State private var recordingTimer: Timer?
    @State private var showCountdown = false
    @State private var countdownValue = 3

    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(session: recorder.session)
                .ignoresSafeArea()

            // Overlay controls
            VStack {
                // Top bar
                topBar

                Spacer()

                // Countdown overlay
                if showCountdown {
                    countdownOverlay
                }

                Spacer()

                // Bottom controls
                bottomControls
            }
        }
        .background(Color.black)
        .onAppear {
            Task {
                await recorder.checkPermissions()
                if recorder.hasPermission {
                    recorder.startSession()
                } else {
                    showPermissionAlert = true
                }
            }
        }
        .onDisappear {
            recorder.stopSession()
            recordingTimer?.invalidate()
        }
        .alert("Camera Access Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {
                onDismiss()
            }
        } message: {
            Text("Please enable camera and microphone access in Settings to record your mission briefing.")
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }

            Spacer()

            // Recording indicator
            if isRecording {
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(Theme.emergency)
                        .frame(width: 12, height: 12)
                        .opacity(isPulsing ? 0.3 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isPulsing)

                    Text(formatTime(recordingTimeRemaining))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color.black.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
            } else {
                // Source indicator
                Text("SELF-COMMAND")
                    .font(Typography.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.primary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
            }

            Spacer()

            // Flip camera button
            Button(action: { recorder.flipCamera() }) {
                Image(systemName: "camera.rotate")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .disabled(isRecording)
            .opacity(isRecording ? 0.5 : 1)
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.top, Spacing.lg)
    }

    // MARK: - Countdown Overlay

    private var countdownOverlay: some View {
        ZStack {
            Circle()
                .fill(Theme.primary.opacity(0.2))
                .frame(width: 150, height: 150)

            Text("\(countdownValue)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primary)
        }
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: Spacing.lg) {
            // Progress bar
            if isRecording {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(.white.opacity(0.3))
                            .frame(height: 4)

                        Rectangle()
                            .fill(Theme.primary)
                            .frame(width: geo.size.width * CGFloat((30 - recordingTimeRemaining) / 30), height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, Spacing.xxxl)
            }

            // Instructions
            if !isRecording && !showCountdown {
                instructionsCard
            }

            // Record button
            HStack {
                Spacer()

                Button(action: toggleRecording) {
                    ZStack {
                        Circle()
                            .stroke(.white, lineWidth: 4)
                            .frame(width: 80, height: 80)

                        if isRecording {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Theme.emergency)
                                .frame(width: 32, height: 32)
                        } else {
                            Circle()
                                .fill(Theme.emergency)
                                .frame(width: 64, height: 64)
                        }
                    }
                }

                Spacer()
            }
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.bottom, Spacing.xxxl)
    }

    private var instructionsCard: some View {
        VStack(spacing: Spacing.sm) {
            Text("Give your future self 3 clear orders:")
                .font(Typography.bodyEmphasis)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                instructionRow(number: 1, text: "What to do immediately")
                instructionRow(number: 2, text: "Who to call for help")
                instructionRow(number: 3, text: "Where to go to be safe")
            }
        }
        .padding(Spacing.md)
        .background(Color.black.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
    }

    private func instructionRow(number: Int, text: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Text("\(number)")
                .font(Typography.caption)
                .fontWeight(.bold)
                .foregroundStyle(Theme.background)
                .frame(width: 20, height: 20)
                .background(Theme.primary)
                .clipShape(Circle())

            Text(text)
                .font(Typography.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    // MARK: - Recording Logic

    @State private var isPulsing = false

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startCountdown()
        }
    }

    private func startCountdown() {
        countdownValue = 3
        showCountdown = true

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if countdownValue > 1 {
                countdownValue -= 1
            } else {
                timer.invalidate()
                showCountdown = false
                startRecording()
            }
        }
    }

    private func startRecording() {
        recordingTimeRemaining = 30
        isRecording = true
        isPulsing = true

        recorder.startRecording()

        // Recording timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if recordingTimeRemaining > 0 {
                recordingTimeRemaining -= 0.1
            } else {
                timer.invalidate()
                stopRecording()
            }
        }
    }

    private func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false
        isPulsing = false

        recorder.stopRecording { url in
            if let videoURL = url {
                let duration = recorder.getRecordingDuration()
                Task {
                    await viewModel.saveBriefing(from: videoURL, duration: duration)
                    await MainActor.run {
                        onDismiss()
                    }
                }
            }
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let tenths = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", mins, secs, tenths)
    }
}

// MARK: - Camera Preview

/// A dedicated UIView for AVCaptureVideoPreviewLayer to ensure correct layout
class AVCapturePreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> AVCapturePreviewView {
        let view = AVCapturePreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill

        // Initial orientation set
        if let connection = view.videoPreviewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }

        return view
    }

    func updateUIView(_ uiView: AVCapturePreviewView, context: Context) {
        // Ensure connection orientation is correct
        if let connection = uiView.videoPreviewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }
}

// MARK: - Video Recorder Controller

@MainActor
class VideoRecorderController: NSObject, ObservableObject {
    @Published var hasPermission = false
    @Published var isRecording = false

    let session = AVCaptureSession()
    private var videoOutput: AVCaptureMovieFileOutput?
    private var currentCamera: AVCaptureDevice.Position = .front
    private var completionHandler: ((URL?) -> Void)?

    func checkPermissions() async {
        let videoStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        if videoStatus == .authorized && audioStatus == .authorized {
            hasPermission = true
            return
        }

        if videoStatus == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted {
                hasPermission = false
                return
            }
        }

        if audioStatus == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            if !granted {
                hasPermission = false
                return
            }
        }

        hasPermission = videoStatus == .authorized && audioStatus == .authorized
    }

    func startSession() {
        guard !session.isRunning else { return }

        session.beginConfiguration()
        session.sessionPreset = .high

        // Add video input
        if let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCamera),
           let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
           session.canAddInput(videoInput) {
            session.addInput(videoInput)
        }

        // Add audio input
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        // Add movie output
        let output = AVCaptureMovieFileOutput()
        output.maxRecordedDuration = CMTime(seconds: 30, preferredTimescale: 600)
        if session.canAddOutput(output) {
            session.addOutput(output)
            videoOutput = output
        }

        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func stopSession() {
        guard session.isRunning else { return }
        session.stopRunning()
    }

    func flipCamera() {
        currentCamera = currentCamera == .front ? .back : .front

        session.beginConfiguration()

        // Remove existing video input
        for input in session.inputs {
            if let deviceInput = input as? AVCaptureDeviceInput,
               deviceInput.device.hasMediaType(.video) {
                session.removeInput(deviceInput)
            }
        }

        // Add new video input
        if let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCamera),
           let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
           session.canAddInput(videoInput) {
            session.addInput(videoInput)
        }

        session.commitConfiguration()
    }

    func startRecording() {
        guard let output = videoOutput, !output.isRecording else { return }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        output.startRecording(to: tempURL, recordingDelegate: self)
        isRecording = true
    }

    func stopRecording(completion: @escaping (URL?) -> Void) {
        guard let output = videoOutput, output.isRecording else {
            completion(nil)
            return
        }

        completionHandler = completion
        output.stopRecording()
    }

    func getRecordingDuration() -> TimeInterval {
        return videoOutput?.recordedDuration.seconds ?? 0
    }
}

extension VideoRecorderController: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        Task { @MainActor in
            isRecording = false
            if error == nil {
                completionHandler?(outputFileURL)
            } else {
                completionHandler?(nil)
            }
            completionHandler = nil
        }
    }
}

// MARK: - Preview

#Preview {
    BriefingRecorderView(
        viewModel: HopeBoxViewModel(),
        onDismiss: {}
    )
}
