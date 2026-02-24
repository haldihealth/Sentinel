import SwiftUI
import AVKit
import os.log

// MARK: - AVPlayerViewController Wrapper

/// Reliable video player using UIKit's AVPlayerViewController
/// SwiftUI's VideoPlayer causes black screens inside fullScreenCover
struct AVPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = false
        controller.videoGravity = .resizeAspect
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

// MARK: - Video Player View

/// Near-fullscreen video player for briefings and video reinforcements
/// Uses AVPlayerViewController for reliable playback
struct VideoPlayerView: View {
    let url: URL
    let onDismiss: () -> Void

    @State private var player: AVPlayer?
    @State private var fileError = false

    var body: some View {
        ZStack {
            // Blurred background
            Color.black.ignoresSafeArea()

            if let player = player {
                AVPlayerView(player: player)
                    .edgesIgnoringSafeArea(.all)
            } else if fileError {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                    Text("Unable to play video")
                        .font(Typography.body)
                        .foregroundStyle(.white)
                }
            } else {
                ProgressView()
                    .tint(.white)
            }

            // Close button overlay
            VStack {
                HStack {
                    Button(action: {
                        player?.pause()
                        onDismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(.leading, Spacing.screenHorizontal)
                    .padding(.top, Spacing.lg)

                    Spacer()
                }
                Spacer()
            }
            .zIndex(100)
        }
        .task {
            if FileManager.default.fileExists(atPath: url.path) {
                let avPlayer = AVPlayer(url: url)
                player = avPlayer
                // Small delay to let AVPlayerViewController mount its display layer
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                avPlayer.play()
            } else {
                Logger.hopeBox.error("Video file not found at \(url.path)")
                fileError = true
            }
        }

        .onAppear {
            // Force audio to play even in silent mode
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try? AVAudioSession.sharedInstance().setActive(true)
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}

// MARK: - Preview

#Preview {
    VideoPlayerView(
        url: URL(string: "https://example.com/video.mp4")!,
        onDismiss: {}
    )
}
