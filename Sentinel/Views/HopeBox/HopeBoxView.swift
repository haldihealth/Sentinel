import SwiftUI
import AVKit
import PhotosUI

/// Main Hope Box tab view
/// Contains mission briefing recordings and reinforcement assets
struct HopeBoxView: View {
    @StateObject private var viewModel = HopeBoxViewModel()
    @State private var showAddReinforcement = false
    @State private var selectedReinforcement: HopeBoxItem?
    @State private var showSlideshow = false
    
    /// Wrapper for URL to make it Identifiable for fullScreenCover(item:)
    struct IdentifiableURL: Identifiable {
        let id = UUID()
        let url: URL
    }
    @State private var selectedVideoItem: IdentifiableURL?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView
                ScrollView {
                    VStack(spacing: Spacing.sectionSpacing) {
                        missionBriefingSection
                        reinforcementsSection
                        deployButton
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, Spacing.xxxl)
                }
            }
            .background(Theme.background)
            .navigationBarHidden(true)
            .task {
                await viewModel.loadHopeBox()
            }
            .sheet(isPresented: $showAddReinforcement) {
                AddReinforcementView(viewModel: viewModel)
            }
            .fullScreenCover(item: $selectedVideoItem) { videoItem in
                VideoPlayerView(url: videoItem.url, onDismiss: {
                    selectedVideoItem = nil
                })
            }
            .fullScreenCover(item: $selectedReinforcement) { item in
                ReinforcementGalleryView(
                    item: item,
                    viewModel: viewModel,
                    onDismiss: {
                        selectedReinforcement = nil
                    }
                )
            }
            .fullScreenCover(isPresented: $showSlideshow) {
                if let reinforcements = viewModel.hopeBox?.reinforcements, !reinforcements.isEmpty {
                    ReinforcementSlideshowView(
                        reinforcements: reinforcements,
                        viewModel: viewModel,
                        onDismiss: {
                            showSlideshow = false
                        }
                    )
                }
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: Spacing.xs) {
            HStack {
                Circle()
                    .fill(Theme.primary)
                    .frame(width: 8, height: 8)
                Text("OFFLINE \u{2022} ON-DEVICE ONLY \u{2022} PRIVATE")
                    .font(Typography.tiny)
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(0.5)
            }

            Text("OPERATING INSTRUCTIONS")
                .font(Typography.title)
                .foregroundStyle(.white)
                .tracking(2)
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.vertical, Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(Theme.background)
    }

    // MARK: - Mission Briefing Section

    private var missionBriefingSection: some View {
        VStack(spacing: Spacing.md) {
            // Video recording card
            BriefingRecorderCard(
                viewModel: viewModel,
                onPlay: { url in
                    selectedVideoItem = IdentifiableURL(url: url)
                }
            )

            // Instructions card
            missionBriefingInstructions
        }
    }


    private var missionBriefingInstructions: some View {
        CardView(backgroundColor: Theme.primary.opacity(0.15)) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("MISSION BRIEFING: SELF-COMMAND")
                    .font(Typography.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.primary)
                    .tracking(1)

                Text("Record a 30-second briefing for yourself. When you are in ")
                    .font(Typography.body)
                    .foregroundStyle(.white.opacity(0.9))
                +
                Text("RedCon RED")
                    .font(Typography.bodyEmphasis)
                    .foregroundStyle(Theme.emergency)
                +
                Text(" status, you will be compromised. Give your future self three clear orders on how to survive until help arrives.")
                    .font(Typography.body)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    // MARK: - Reinforcements Section

    private var reinforcementsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section header with action
            HStack {
                Text("REINFORCEMENTS // ASSETS")
                    .font(Typography.sectionHeader)
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(1.5)

                Spacer()

                Button(action: { showAddReinforcement = true }) {
                    Text("ADD NEW")
                        .font(Typography.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.primary)
                }
            }

            // Horizontal scroll of reinforcement cards
            if let reinforcements = viewModel.hopeBox?.reinforcements, !reinforcements.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.md) {
                        ForEach(reinforcements) { item in
                            ReinforcementCard(
                                item: item,
                                viewModel: viewModel,
                                onTap: {
                                    if item.mediaType == .video {
                                        if let url = viewModel.getVideoURL(for: item) {
                                            selectedVideoItem = IdentifiableURL(url: url)
                                        }
                                    } else {
                                        selectedReinforcement = item
                                    }
                                },
                                onDelete: {
                                    viewModel.removeReinforcement(item)
                                }
                            )
                        }
                    }
                    .padding(.vertical, Spacing.xs)
                }
            } else {
                // Empty state
                emptyReinforcementsView
            }
        }
    }

    private var emptyReinforcementsView: some View {
        CardView {
            VStack(spacing: Spacing.md) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.primary.opacity(0.5))

                Text("No reinforcements yet")
                    .font(Typography.bodyEmphasis)
                    .foregroundStyle(.white.opacity(0.7))

                Text("Add photos or videos that bring you comfort during difficult moments.")
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)

                Button(action: { showAddReinforcement = true }) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "plus")
                        Text("ADD REINFORCEMENT")
                    }
                    .font(Typography.headline)
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .background(Theme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
                }
                .padding(.top, Spacing.sm)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
        }
    }

    // MARK: - Deploy Button

    private var deployButton: some View {
        Button(action: {
            showSlideshow = true
        }) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16))
                Text("DEPLOY ALL REINFORCEMENTS")
                    .font(Typography.headline)
                    .tracking(0.5)
            }
            .foregroundStyle(Theme.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
            .background(Theme.primary)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
        }
        .disabled(viewModel.hopeBox?.reinforcements.isEmpty ?? true)
        .opacity((viewModel.hopeBox?.reinforcements.isEmpty ?? true) ? 0.5 : 1)
    }
}

// MARK: - Briefing Recorder Card

struct BriefingRecorderCard: View {
    @ObservedObject var viewModel: HopeBoxViewModel
    @State private var showRecorder = false
    @State private var selectedVideoItems: [PhotosPickerItem] = []
    @State private var isLoadingVideo = false
    let onPlay: (URL) -> Void

    var body: some View {
        CardView(padding: 0) {
            VStack(spacing: 0) {
                // Video preview area
                ZStack {
                    // Background
                    Rectangle()
                        .fill(Color.black.opacity(0.8))

                    // Thumbnail or camera icon
                    if let briefing = viewModel.currentBriefing,
                       let thumbnail = viewModel.getThumbnail(for: briefing) {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .overlay(Color.black.opacity(0.3))
                    } else {
                        // Placeholder camera view
                        VStack(spacing: Spacing.md) {
                            ZStack {
                                Circle()
                                    .fill(Theme.primary)
                                    .frame(width: 64, height: 64)
                                Image(systemName: "video.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.white)
                            }
                        }
                    }

                    // Status overlay
                    VStack {
                        HStack {
                            HStack(spacing: Spacing.xs) {
                                Circle()
                                    .fill(viewModel.currentBriefing != nil ? Theme.primary : Theme.emergency)
                                    .frame(width: 8, height: 8)
                                Text(viewModel.currentBriefing != nil ? "REC_SAVED" : "REC_STANDBY")
                                    .font(Typography.captionSmall)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            }

                            Spacer()

                            Text("CAM_01")
                                .font(Typography.captionSmall)
                                .fontWeight(.bold)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(Spacing.md)

                        Spacer()

                        // Timeline
                        HStack {
                            Text("00:00:00")
                                .font(Typography.captionSmall)
                                .foregroundStyle(.white.opacity(0.7))

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(.white.opacity(0.3))
                                        .frame(height: 2)

                                    if let briefing = viewModel.currentBriefing,
                                       let duration = briefing.duration {
                                        Rectangle()
                                            .fill(Theme.primary)
                                            .frame(
                                                width: geo.size.width * CGFloat(duration / 30.0),
                                                height: 2
                                            )
                                    }
                                }
                            }
                            .frame(height: 2)

                            Text("00:00:30")
                                .font(Typography.captionSmall)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(Spacing.md)
                    }

                    // Play button overlay if video exists
                    if viewModel.currentBriefing != nil {
                        Button(action: {
                            if let briefing = viewModel.currentBriefing,
                               let url = viewModel.getVideoURL(for: briefing) {
                                onPlay(url)
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Theme.primary.opacity(0.9))
                                    .frame(width: 64, height: 64)
                                Image(systemName: "play.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
                .frame(height: 200)
                .clipped()

                // Record and Import buttons
                HStack(spacing: 2) {
                    Button(action: { showRecorder = true }) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: viewModel.currentBriefing != nil ? "arrow.counterclockwise" : "mic.fill")
                                .font(.system(size: 14))
                            Text("RECORD")
                                .font(Typography.headline)
                                .tracking(0.5)
                        }
                        .foregroundStyle(Theme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(Theme.primary)
                    }

                    PhotosPicker(
                        selection: $selectedVideoItems,
                        maxSelectionCount: 1,
                        matching: .videos,
                        photoLibrary: .shared()
                    ) {
                        HStack(spacing: Spacing.sm) {
                            if isLoadingVideo {
                                ProgressView()
                                    .tint(Theme.background)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "plus.rectangle.fill")
                                    .font(.system(size: 14))
                            }
                            Text(isLoadingVideo ? "LOADING..." : "IMPORT VIDEO")
                                .font(Typography.headline)
                                .tracking(0.5)
                        }
                        .foregroundStyle(Theme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(Theme.primary.opacity(isLoadingVideo ? 0.6 : 1.0))
                    }
                    .disabled(isLoadingVideo)
                }
            }
        }
        .onChange(of: selectedVideoItems) { _, newItems in
            guard let item = newItems.first else { return }
            loadVideo(from: item)
        }
        .fullScreenCover(isPresented: $showRecorder) {
            BriefingRecorderView(viewModel: viewModel, onDismiss: { showRecorder = false })
        }
    }

    private func loadVideo(from item: PhotosPickerItem) {
        isLoadingVideo = true
        Task {
            if let movie = try? await item.loadTransferable(type: VideoTransferable.self) {
                let asset = AVAsset(url: movie.url)
                let duration = try? await asset.load(.duration)
                let durationSeconds = duration?.seconds ?? 0
                
                await viewModel.saveBriefing(from: movie.url, duration: durationSeconds)
            }
            await MainActor.run {
                isLoadingVideo = false
                selectedVideoItems = []
            }
        }
    }
}

// MARK: - Reinforcement Card

struct ReinforcementCard: View {
    let item: HopeBoxItem
    @ObservedObject var viewModel: HopeBoxViewModel
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Thumbnail
            Button(action: onTap) {
                ZStack(alignment: .bottomTrailing) {
                    if let thumbnail = viewModel.getThumbnail(for: item) {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 200, height: 150)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Theme.surface)
                            .frame(width: 200, height: 150)
                            .overlay(
                                Image(systemName: item.mediaType == .video ? "video.fill" : "photo.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(Theme.primary.opacity(0.5))
                            )
                    }

                    // Duration badge for videos
                    if item.mediaType == .video, let duration = item.formattedDuration {
                        Text(duration)
                            .font(Typography.captionSmall)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(Color.black.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                            .padding(Spacing.sm)
                    }

                    // Photo count badge for collections
                    if item.mediaType == .photoCollection {
                        let count = item.filePaths.count
                        HStack(spacing: 2) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 10))
                            Text("\(count)")
                                .font(Typography.captionSmall)
                                .fontWeight(.bold)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                        .padding(Spacing.sm)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                    Label("Delete", systemImage: "trash")
                }
            }

            // Title & subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(Typography.bodyEmphasis)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(Typography.captionSmall)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
        }
        .frame(width: 200)
        .alert("Delete Reinforcement?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("This will permanently remove \"\(item.title)\" from your Hope Box.")
        }
    }
}

// MARK: - Preview

#Preview {
    HopeBoxView()
        .preferredColorScheme(.dark)
}
