import SwiftUI
import AVKit

/// Full-screen slideshow view that plays through all reinforcements sequentially
struct ReinforcementSlideshowView: View {
    let reinforcements: [HopeBoxItem]
    @ObservedObject var viewModel: HopeBoxViewModel
    let onDismiss: () -> Void

    @State private var currentIndex = 0
    @State private var player: AVPlayer?
    @State private var showControls = true
    @State private var autoAdvanceTimer: Timer?
    @State private var photoDisplayDuration: TimeInterval = 5.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Current item display
            if currentIndex < reinforcements.count {
                let item = reinforcements[currentIndex]

                if item.mediaType == .video {
                    videoContent(for: item)
                } else {
                    photoContent(for: item)
                }
            }

            // Controls overlay
            if showControls {
                controlsOverlay
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showControls.toggle()
            }
        }
        .onAppear {
            startCurrentItem()
        }
        .onDisappear {
            cleanup()
        }
        .statusBarHidden(!showControls)
    }

    // MARK: - Video Content

    @ViewBuilder
    private func videoContent(for item: HopeBoxItem) -> some View {
        if let player = player {
            AVPlayerView(player: player)
                .edgesIgnoringSafeArea(.all)
        }
    }

    // MARK: - Photo Content

    @ViewBuilder
    private func photoContent(for item: HopeBoxItem) -> some View {
        let images = viewModel.getImages(for: item)

        if item.mediaType == .photoCollection {
            // For collections, show a mini-slideshow within
            PhotoCollectionSlideshow(images: images, onComplete: advanceToNext)
        } else if let image = images.first {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .ignoresSafeArea()
                .onAppear {
                    startPhotoTimer()
                }
        }
    }

    // MARK: - Controls Overlay

    private var controlsOverlay: some View {
        VStack {
            // Top bar
            HStack {
                Button(action: {
                    cleanup()
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }

                Spacer()

                // Title
                if currentIndex < reinforcements.count {
                    VStack(spacing: 2) {
                        Text(reinforcements[currentIndex].title)
                            .font(Typography.headline)
                            .foregroundStyle(.white)
                        if let subtitle = reinforcements[currentIndex].subtitle {
                            Text(subtitle)
                                .font(Typography.captionSmall)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }

                Spacer()

                // Counter
                Text("\(currentIndex + 1)/\(reinforcements.count)")
                    .font(Typography.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.black.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.lg)

            Spacer()

            // Bottom controls
            HStack(spacing: Spacing.xl) {
                // Previous button
                Button(action: goToPrevious) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .disabled(currentIndex == 0)
                .opacity(currentIndex == 0 ? 0.5 : 1)

                // Next button
                Button(action: advanceToNext) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .disabled(currentIndex >= reinforcements.count - 1)
                .opacity(currentIndex >= reinforcements.count - 1 ? 0.5 : 1)
            }
            .padding(.bottom, Spacing.xxxl)

            // Progress dots
            HStack(spacing: Spacing.sm) {
                ForEach(0..<reinforcements.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentIndex ? Theme.primary : .white.opacity(0.5))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, Spacing.xl)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.6),
                    Color.clear,
                    Color.clear,
                    Color.black.opacity(0.6)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - Playback Control

    private func startCurrentItem() {
        guard currentIndex < reinforcements.count else {
            onDismiss()
            return
        }

        let item = reinforcements[currentIndex]

        if item.mediaType == .video {
            if let url = viewModel.getVideoURL(for: item) {
                setupVideoPlayer(url: url)
            }
        } else if item.mediaType == .photo {
            startPhotoTimer()
        }
        // Photo collections are handled by PhotoCollectionSlideshow
    }

    private func setupVideoPlayer(url: URL) {
        let avPlayer = AVPlayer(url: url)
        player = avPlayer

        // Small delay to let AVPlayerViewController mount its display layer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            avPlayer.play()
        }

        // Observe when video ends
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: avPlayer.currentItem,
            queue: .main
        ) { _ in
            advanceToNext()
        }
    }

    private func startPhotoTimer() {
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: photoDisplayDuration, repeats: false) { _ in
            advanceToNext()
        }
    }

    private func advanceToNext() {
        cleanup()

        if currentIndex < reinforcements.count - 1 {
            currentIndex += 1
            startCurrentItem()
        } else {
            onDismiss()
        }
    }

    private func goToPrevious() {
        cleanup()

        if currentIndex > 0 {
            currentIndex -= 1
            startCurrentItem()
        }
    }

    private func cleanup() {
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = nil
        player?.pause()
        player = nil
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }
}

// MARK: - Photo Collection Slideshow

struct PhotoCollectionSlideshow: View {
    let images: [UIImage]
    let onComplete: () -> Void

    @State private var currentPhotoIndex = 0
    @State private var timer: Timer?
    private let photoInterval: TimeInterval = 3.0

    var body: some View {
        Group {
            if !images.isEmpty && currentPhotoIndex < images.count {
                Image(uiImage: images[currentPhotoIndex])
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .ignoresSafeArea()
                    .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                    .id(currentPhotoIndex)
            }
        }
        .onAppear(perform: startTimer)
        .onDisappear(perform: stopTimer)
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: photoInterval, repeats: true) { _ in
            if currentPhotoIndex < images.count - 1 {
                withAnimation {
                    currentPhotoIndex += 1
                }
            } else {
                stopTimer()
                onComplete()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}


// MARK: - Preview

#Preview {
    ReinforcementSlideshowView(
        reinforcements: [],
        viewModel: HopeBoxViewModel(),
        onDismiss: {}
    )
}
