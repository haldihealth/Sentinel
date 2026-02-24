import SwiftUI

/// Full-screen gallery view for photo reinforcements
struct ReinforcementGalleryView: View {
    let item: HopeBoxItem
    @ObservedObject var viewModel: HopeBoxViewModel
    let onDismiss: () -> Void

    @State private var images: [UIImage] = []
    @State private var currentIndex: Int = 0
    @State private var showControls = true
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Image display
            if !images.isEmpty {
                TabView(selection: $currentIndex) {
                    ForEach(images.indices, id: \.self) { index in
                        Image(uiImage: images[index])
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
            } else {
                VStack(spacing: Spacing.md) {
                    ProgressView()
                        .tint(Theme.primary)
                    Text("Loading images...")
                        .font(Typography.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            
            // Empty/Error state overlay
            if images.isEmpty && !isLoading {
                 VStack(spacing: Spacing.md) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("No images available")
                        .font(Typography.body)
                        .foregroundStyle(.white)
                }
            }

            // Controls overlay
            if showControls || images.isEmpty {
                controlsOverlay
                    .zIndex(100)
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showControls.toggle()
            }
        }
        .task {
            // Load images off the presentation animation cycle
            isLoading = true
            let loaded = viewModel.getImages(for: item)
            images = loaded
            isLoading = false
        }
        .statusBarHidden(!showControls)
    }

    // MARK: - Controls Overlay

    private var controlsOverlay: some View {
        ZStack {
            // Gradient background - ignore hits so swipes pass through
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
            .allowsHitTesting(false)
            
            // Interaction layer
            VStack {
                // Top bar
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

                    // Title
                    VStack(spacing: 2) {
                        Text(item.title)
                            .font(Typography.headline)
                            .foregroundStyle(.white)
                        if let subtitle = item.subtitle {
                            Text(subtitle)
                                .font(Typography.captionSmall)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }

                    Spacer()

                    // Page indicator
                    Text("\(currentIndex + 1)/\(images.count)")
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

                // Bottom indicator dots
                if images.count > 1 {
                    HStack(spacing: Spacing.sm) {
                        ForEach(images.indices, id: \.self) { index in
                            Circle()
                                .fill(index == currentIndex ? Theme.primary : .white.opacity(0.5))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.bottom, Spacing.xxxl)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ReinforcementGalleryView(
        item: HopeBoxItem(
            title: "Family Photos",
            subtitle: "Home Base Archives",
            type: .reinforcement,
            mediaType: .photoCollection,
            filePaths: []
        ),
        viewModel: HopeBoxViewModel(),
        onDismiss: {}
    )
}
