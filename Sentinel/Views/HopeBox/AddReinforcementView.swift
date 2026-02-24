import SwiftUI
import PhotosUI
import AVKit

/// Sheet view for adding new reinforcement assets
struct AddReinforcementView: View {
    @ObservedObject var viewModel: HopeBoxViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var subtitle = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var selectedVideoURL: URL?
    @State private var videoDuration: TimeInterval = 0
    @State private var isLoadingMedia = false
    @State private var mediaType: ReinforcementMediaType = .photos

    enum ReinforcementMediaType: String, CaseIterable {
        case photos = "Photos"
        case video = "Video"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.sectionSpacing) {
                    // Media type selector
                    mediaTypeSelector

                    // Media picker
                    mediaPickerSection

                    // Title & subtitle
                    detailsSection

                    // Preview
                    if !selectedImages.isEmpty || selectedVideoURL != nil {
                        previewSection
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.vertical, Spacing.lg)
            }
            .background(Theme.background)
            .navigationTitle("Add Reinforcement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveReinforcement() }
                        .foregroundStyle(Theme.primary)
                        .disabled(!canSave)
                }
            }
            .toolbarBackground(Theme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Media Type Selector

    private var mediaTypeSelector: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("MEDIA TYPE")

            HStack(spacing: 0) {
                ForEach(ReinforcementMediaType.allCases, id: \.self) { type in
                    Button(action: {
                        withAnimation {
                            mediaType = type
                            // Clear previous selection when switching types
                            selectedImages = []
                            selectedItems = []
                            selectedVideoURL = nil
                        }
                    }) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: type == .photos ? "photo.on.rectangle" : "video.fill")
                                .font(.system(size: 14))
                            Text(type.rawValue.uppercased())
                                .font(Typography.caption)
                                .fontWeight(.bold)
                        }
                        .foregroundStyle(mediaType == type ? Theme.background : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(mediaType == type ? Theme.primary : Color.clear)
                    }
                }
            }
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.standard)
                    .stroke(Theme.primary.opacity(0.5), lineWidth: 1)
            )
        }
    }

    // MARK: - Media Picker Section

    private var mediaPickerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("SELECT MEDIA")

            if mediaType == .photos {
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 10,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    pickerButton(
                        icon: "photo.badge.plus",
                        title: selectedImages.isEmpty ? "Choose Photos" : "Change Selection",
                        subtitle: selectedImages.isEmpty ? "Select up to 10 photos" : "\(selectedImages.count) photo(s) selected"
                    )
                }
                .onChange(of: selectedItems) { _, newItems in
                    loadImages(from: newItems)
                }
            } else {
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 1,
                    matching: .videos,
                    photoLibrary: .shared()
                ) {
                    pickerButton(
                        icon: "video.badge.plus",
                        title: selectedVideoURL == nil ? "Choose Video" : "Change Video",
                        subtitle: selectedVideoURL == nil ? "Select a video from your library" : formatDuration(videoDuration)
                    )
                }
                .onChange(of: selectedItems) { _, newItems in
                    loadVideo(from: newItems.first)
                }
            }

            if isLoadingMedia {
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                        .tint(Theme.primary)
                    Text("Loading media...")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, Spacing.sm)
            }
        }
    }

    private func pickerButton(icon: String, title: String, subtitle: String) -> some View {
        CardView {
            HStack(spacing: Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(Theme.primary.opacity(0.2))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typography.bodyEmphasis)
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("DETAILS")

            CardView {
                VStack(spacing: Spacing.md) {
                    // Title field
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Title")
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g., Tac-Pup Deployed", text: $title)
                            .font(Typography.body)
                            .foregroundStyle(.white)
                            .textFieldStyle(.plain)
                            .padding(Spacing.md)
                            .background(Theme.surfaceHover)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    }

                    // Subtitle field
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Subtitle (optional)")
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g., Canine Unit 1", text: $subtitle)
                            .font(Typography.body)
                            .foregroundStyle(.white)
                            .textFieldStyle(.plain)
                            .padding(Spacing.md)
                            .background(Theme.surfaceHover)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    }
                }
            }

            // Suggestions
            suggestionChips
        }
    }

    private var suggestionChips: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Quick suggestions:")
                .font(Typography.captionSmall)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    suggestionChip(title: "Family Photos", subtitle: "Family Archives")
                    suggestionChip(title: "Pet Photos", subtitle: "Animal Support Unit")
                    suggestionChip(title: "Happy Memories", subtitle: "Morale Boost")
                    suggestionChip(title: "Vacation", subtitle: "R&R Archives")
                    suggestionChip(title: "Friends", subtitle: "Battle Buddy Squad")
                }
            }
        }
    }

    private func suggestionChip(title: String, subtitle: String) -> some View {
        Button(action: {
            self.title = title
            self.subtitle = subtitle
        }) {
            Text(title)
                .font(Typography.captionSmall)
                .foregroundStyle(self.title == title ? Theme.background : Theme.primary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(self.title == title ? Theme.primary : Theme.primary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.pill))
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("PREVIEW")

            if !selectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(selectedImages.indices, id: \.self) { index in
                            Image(uiImage: selectedImages[index])
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
                        }
                    }
                }
            }

            if selectedVideoURL != nil {
                CardView(padding: 0) {
                    ZStack {
                        Rectangle()
                            .fill(Theme.surface)
                            .frame(height: 150)

                        VStack(spacing: Spacing.sm) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(Theme.primary)

                            Text(formatDuration(videoDuration))
                                .font(Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var canSave: Bool {
        !title.isEmpty && (!selectedImages.isEmpty || selectedVideoURL != nil)
    }

    private func loadImages(from items: [PhotosPickerItem]) {
        isLoadingMedia = true
        selectedImages = []

        Task {
            var images: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    images.append(image)
                }
            }
            await MainActor.run {
                selectedImages = images
                isLoadingMedia = false
            }
        }
    }

    private func loadVideo(from item: PhotosPickerItem?) {
        guard let item = item else { return }

        isLoadingMedia = true
        selectedVideoURL = nil

        Task {
            if let movie = try? await item.loadTransferable(type: VideoTransferable.self) {
                let asset = AVAsset(url: movie.url)
                let duration = try? await asset.load(.duration)

                await MainActor.run {
                    selectedVideoURL = movie.url
                    videoDuration = duration?.seconds ?? 0
                    isLoadingMedia = false
                }
            } else {
                await MainActor.run {
                    isLoadingMedia = false
                }
            }
        }
    }

    private func saveReinforcement() {
        Task {
            if !selectedImages.isEmpty {
                await viewModel.addReinforcement(
                    title: title,
                    subtitle: subtitle.isEmpty ? nil : subtitle,
                    images: selectedImages
                )
            } else if let videoURL = selectedVideoURL {
                await viewModel.addVideoReinforcement(
                    title: title,
                    subtitle: subtitle.isEmpty ? nil : subtitle,
                    videoURL: videoURL,
                    duration: videoDuration
                )
            }
            dismiss()
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Video Transferable

struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp4")
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}

// MARK: - Preview

#Preview {
    AddReinforcementView(viewModel: HopeBoxViewModel())
}
