import SwiftUI

/// Audio-first tactical check-in interface.
///
/// Camera runs silently in background for behavioral telemetry.
/// Primary UX focuses on audio: waveform, transcript, and voice analysis.
struct IntervalCheckInView: View {
    @EnvironmentObject var viewModel: CheckInViewModel
    @Environment(\.dismiss) var dismiss

    // Debug State
    @State private var showDebugInput = false
    @State private var debugTranscript = ""

    // Theme Colors
    private let bgColor = Color(red: 0.04, green: 0.055, blue: 0.08) // Dark navy
    private let accentCyan = Color(red: 0, green: 0.9, blue: 0.85)
    private let accentRed = Color(red: 0.9, green: 0.2, blue: 0.2)
    private let dimText = Color.white.opacity(0.4)
    private let borderColor = Color(red: 0, green: 0.9, blue: 0.85).opacity(0.3)

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            if viewModel.isLoading {
                analysisView
            } else if viewModel.isRecording {
                recordingView
            } else {
                preRecordingView
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isRecording)
    }

    // MARK: - Pre-Recording State

    private var preRecordingView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Privacy Header
            privacyHeader

            Spacer()

            // System Status
            VStack(spacing: 8) {
                Image(systemName: "waveform.circle")
                    .font(.system(size: 60))
                    .foregroundStyle(accentCyan)

                Text("DAILY SNAPSHOT")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(accentCyan)
                    .tracking(2)

                Text("30-second multimodal assessment")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(dimText)
            }

            Spacer()

            // Start Button
            VStack(spacing: 16) {
                Button(action: { viewModel.startCheckIn() }) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(accentRed)
                            .frame(width: 12, height: 12)
                        Text("BEGIN ASSESSMENT")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .tracking(1)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(accentCyan, lineWidth: 1)
                            .background(RoundedRectangle(cornerRadius: 12).fill(accentCyan.opacity(0.1)))
                    )
                }

                Button(action: { viewModel.skipMultimodal() }) {
                    Text("SKIP TO QUESTIONS")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(dimText)
                        .tracking(1)
                }
            }
            .padding(.horizontal, 32)

            #if DEBUG
            debugButton
            #endif

            Spacer().frame(height: 20)

            // Version footer
            Text("SENTINEL SECURE ENVIRONMENT V2.4")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(dimText)
                .padding(.bottom, 8)
        }
    }

    // MARK: - Analysis State

    private var analysisView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer().frame(height: 60)
            
            HStack {
                Text("ANALYZING MULTIMODAL TELEMETRY...")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(accentCyan)
                Spacer()
                ProgressView()
                    .tint(accentCyan)
            }
            .padding(.horizontal, 24)
            
            Divider()
                .background(accentCyan.opacity(0.3))
                .padding(.horizontal, 24)
            
            ScrollView {
                if let text = viewModel.demoTelemetryText {
                    Text(text)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineSpacing(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(accentCyan.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Recording State

    private var recordingView: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // Privacy + Close Header
            HStack {
                Button(action: { viewModel.stopCheckIn() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("OFFLINE \u{2022} ON-DEVICE ONLY")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(accentCyan)
                    Text("PROCESSED LOCALLY. AUDIO NEVER LEAVES YOUR PHONE")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(dimText)
                }

                Spacer()

                // Camera active indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(accentCyan)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            // Transcript Area
            transcriptArea
                .frame(maxHeight: .infinity)

            // Status Line
            statusLine
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            // Waveform + Timer
            VStack(spacing: 8) {
                AudioWaveformView(
                    audioLevel: viewModel.currentAudioLevel,
                    accentColor: accentCyan
                )
                .padding(.horizontal, 40)

                // Timer
                HStack(spacing: 6) {
                    Circle()
                        .fill(accentRed)
                        .frame(width: 8, height: 8)
                    Text(formattedTime)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(accentCyan)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(accentCyan.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .padding(.bottom, 16)

            // Control Bar
            controlBar
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            
            // Preview Overlay — video pane (dev mode) or live camera
            Group {
                if let player = viewModel.cameraService.videoPlayer {
                    // Developer video-injection mode: use AVPlayerViewController so the
                    // preview renders correctly alongside AVPlayerItemVideoOutput.
                    InlineVideoPlayer(player: player)
                } else if viewModel.cameraService.isConfigured {
                    FaceTrackingPreviewView(
                        session: viewModel.cameraService.captureSession,
                        faceObservation: viewModel.currentFaceObservation,
                        accentColor: accentCyan
                    )
                }
            }
            .frame(width: 90, height: 135)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(accentCyan.opacity(0.3), lineWidth: 1)
            )
            .padding(.top, 56)
            .padding(.trailing, 16)
            .transition(.opacity)
        }
    }

    // MARK: - Components

    private var privacyHeader: some View {
        VStack(spacing: 4) {
            Text("OFFLINE \u{2022} ON-DEVICE ONLY")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(accentCyan)
                .tracking(1)
            Text("ALL DATA PROCESSED LOCALLY")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(dimText)
        }
    }

    private var transcriptArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Timestamp header
                    Text("[\(formattedTime)] System initialized, ready for input...")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(dimText)

                    if !viewModel.transcript.isEmpty {
                        Text(viewModel.transcript)
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(.white)
                            .lineSpacing(6)
                            .id("transcript-end")
                    }

                    // Blinking cursor
                    if viewModel.isRecording {
                        Rectangle()
                            .fill(accentCyan)
                            .frame(width: 10, height: 20)
                            .opacity(cursorOpacity)
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: viewModel.elapsedTime)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .onChange(of: viewModel.transcript) { _, _ in
                withAnimation {
                    proxy.scrollTo("transcript-end", anchor: .bottom)
                }
            }
        }
    }

    private var statusLine: some View {
        HStack {
            Text("MEDGEMMA-2B :: ANALYZING TOKENS...")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(accentCyan.opacity(0.6))

            Spacer()

            // Animated dots
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(accentCyan)
                        .frame(width: 4, height: 4)
                        .opacity(dotOpacity(index: i))
                }
            }
        }
    }

    private var controlBar: some View {
        HStack(spacing: 16) {
            // 988 Emergency Button
            Button(action: { callCrisisLine() }) {
                VStack(spacing: 4) {
                    Image(systemName: "cross.circle.fill")
                        .font(.system(size: 28))
                    Text("988-1")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(accentRed)
                .frame(width: 60, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(accentRed.opacity(0.4), lineWidth: 1)
                )
            }

            Spacer()

            // Stop Button
            Button(action: { viewModel.stopCheckIn() }) {
                VStack(spacing: 4) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 24))
                    Text("STOP")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.white)
                .frame(width: 60, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }

    #if DEBUG
    private var debugButton: some View {
        Button(action: { showDebugInput = true }) {
            Text("SIMULATE (DEBUG)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(dimText)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().strokeBorder(dimText, lineWidth: 0.5)
                )
        }
        .alert("Debug Simulation", isPresented: $showDebugInput) {
            TextField("Enter transcript (optional)", text: $debugTranscript)
            Button("Run Simulation") {
                viewModel.simulateDebugCheckIn(customTranscript: debugTranscript)
                debugTranscript = ""
            }
            Button("Use Default Mock") {
                viewModel.simulateDebugCheckIn(customTranscript: nil)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter text to simulate audio transcription, or use default mock data.")
        }
    }
    #endif

    // MARK: - Helpers

    private var formattedTime: String {
        let elapsed = Int(viewModel.elapsedTime)
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%02d:%02d:%02d", 0, minutes, seconds)
    }

    private var cursorOpacity: Double {
        Int(viewModel.elapsedTime * 2) % 2 == 0 ? 1.0 : 0.3
    }

    private func dotOpacity(index: Int) -> Double {
        let phase = Int(viewModel.elapsedTime * 3) % 3
        return phase == index ? 1.0 : 0.3
    }

    private func callCrisisLine() {
        if let url = URL(string: CrisisResources.suicidePreventionLine) {
            UIApplication.shared.open(url)
        }
    }
}
