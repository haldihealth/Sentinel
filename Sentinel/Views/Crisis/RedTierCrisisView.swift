import SwiftUI
import AVKit

struct RedTierCrisisView: View {
    @StateObject var crisisVM = CrisisViewModel()
    @StateObject var hopeBoxVM = HopeBoxViewModel()
    @StateObject var safetyPlanVM = SafetyPlanViewModel()
    var onDebugExit: (() -> Void)? = nil
    var onResolved: (() -> Void)? = nil
    
    @State private var player: AVPlayer?
    @State private var completedItems: Set<String> = []
    @State private var expandedSections: Set<SafetyPlanSection> = []
    @State private var timer: Timer?

    // Playback State
    @State private var selectedReinforcement: HopeBoxItem?
    
    /// Wrapper for URL to make it Identifiable for fullScreenCover(item:)
    struct IdentifiableURL: Identifiable {
        let id = UUID()
        let url: URL
    }
    @State private var selectedVideoItem: IdentifiableURL?
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Header
                    headerSection
                    
                    // Countdown Timer
                    countdownTimerSection
                    
                    // 1. Automatic Briefing Player
                    briefingSection
                    
                    // 2. Tactical Assets (Reinforcements)
                    assetsSection
                    
                    // 3. Safety Plan (reranked by MedGemma)
                    safetyPlanHeader

                    ForEach(Array(filteredSectionOrder.enumerated()), id: \.element.id) { index, section in
                        CollapsibleSafetyPlanCard(
                            section: section,
                            rank: index,
                            itemCount: section.itemCount(from: safetyPlanVM.safetyPlan),
                            isExpanded: isExpandedBinding(for: section)
                        ) {
                            safetyPlanSectionContent(for: section)
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: crisisVM.sectionOrder)

                    // 4. Battle Buddy (pinned)
                    if let buddy = safetyPlanVM.safetyPlan?.battleBuddy {
                        BattleBuddySection(buddy: buddy)
                    }

                    // 5. Extraction Logic
                    extractionSection
                }
                .padding()
            }
        }
        .overlay {
            if crisisVM.showRecheckOptions {
                RecheckOverlayView(
                    onStable: {
                        crisisVM.handleRecheck(response: .stable)
                        onResolved?()
                    },
                    onSame: {
                        crisisVM.handleRecheck(response: .same)
                        startCountdownTimer()
                    },
                    onWorse: { crisisVM.handleRecheck(response: .worse) }
                )
                .transition(.opacity)
            }
        }
        .background(Color("TacticalBackground"))
        .task {
            await hopeBoxVM.loadHopeBox()
            await safetyPlanVM.loadSafetyPlan()
            setupBriefingAutoplay()
            await crisisVM.rerankSafetyPlanSections()
            // Auto-expand top 3 priority sections after reranking
            let top3 = Array(filteredSectionOrder.prefix(3))
            expandedSections = Set(top3)
        }
        .onAppear {
            // Ensure crisis VM is in active holding pattern when view appears
            crisisVM.enterCrisis()
            startCountdownTimer()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
        .sheet(isPresented: $crisisVM.show988Sheet) {
            EscalationSheetView(
                onCall988: {
                    crisisVM.call988()
                    if let url = URL(string: "tel://988") {
                        UIApplication.shared.open(url)
                    }
                },
                onDismiss: {
                    crisisVM.show988Sheet = false
                }
            )
            .presentationDetents([.medium])
        }
        .fullScreenCover(item: $selectedVideoItem) { videoItem in
            VideoPlayerView(url: videoItem.url, onDismiss: {
                selectedVideoItem = nil
            })
        }
        .fullScreenCover(item: $selectedReinforcement) { item in
            ReinforcementGalleryView(
                item: item,
                viewModel: hopeBoxVM,
                onDismiss: {
                    selectedReinforcement = nil
                }
            )
        }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text("MISSION CRITICAL: RED TIER")
                .font(Typography.title)
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.bottom, Spacing.sm)
    }
    
    private var countdownTimerSection: some View {
        HStack {
            Image(systemName: "clock")
                .foregroundColor(.orange)
            Text("Recheck in \(formatCountdown(crisisVM.remainingSeconds))")
                .font(Typography.body)
                .foregroundColor(.white)
            Spacer()
        }
        .padding(Spacing.md)
        .background(Color.white.opacity(0.06))
        .cornerRadius(CornerRadius.standard)
    }

    private var briefingSection: some View {
        VStack(alignment: .leading) {
            Text("YOUR BRIEFING")
                .font(Typography.sectionHeader)
                .foregroundColor(.gray)
            
            if let briefing = hopeBoxVM.hopeBox?.selfCommandBriefing {
                VideoPlayer(player: player)
                    .frame(height: 200)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.5), lineWidth: 2)
                    )
            } else {
                Text("No briefing recorded.")
                    .italic()
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var assetsSection: some View {
        VStack(alignment: .leading) {
            Text("TACTICAL ASSETS")
                .font(Typography.sectionHeader)
                .foregroundColor(.gray)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    ForEach(hopeBoxVM.hopeBox?.reinforcements ?? []) { item in
                        TacticalAssetCard(item: item, viewModel: hopeBoxVM)
                            .onTapGesture {
                                if item.mediaType == .video {
                                    if let url = hopeBoxVM.getVideoURL(for: item) {
                                        selectedVideoItem = IdentifiableURL(url: url)
                                    }
                                } else {
                                    selectedReinforcement = item
                                }
                            }
                    }
                }
            }
        }
    }
    
    private var safetyPlanHeader: some View {
        HStack {
            Text("YOUR SAFETY PLAN")
                .font(Typography.sectionHeader)
                .foregroundColor(.gray)
            if crisisVM.isReranking {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(.gray)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func safetyPlanSectionContent(for section: SafetyPlanSection) -> some View {
        let plan = safetyPlanVM.safetyPlan
        switch section {
        case .warningSigns:
            StringListSection(
                title: section.title, icon: section.icon,
                items: plan?.warningSigns ?? [],
                completedItems: $completedItems,
                showHeader: false
            )
        case .copingStrategies:
            StringListSection(
                title: section.title, icon: section.icon,
                items: plan?.copingStrategies ?? [],
                completedItems: $completedItems,
                showHeader: false
            )
        case .socialDistractions:
            ContactListSection(
                title: section.title, icon: section.icon,
                contacts: plan?.socialDistractions ?? [],
                showHeader: false
            )
        case .supportContacts:
            ContactListSection(
                title: section.title, icon: section.icon,
                contacts: plan?.supportContacts ?? [],
                showHeader: false
            )
        case .professionalContacts:
            ProfessionalContactSection(
                title: section.title, icon: section.icon,
                contacts: plan?.professionalContacts ?? [],
                showHeader: false
            )
        case .environmentSafety:
            StringListSection(
                title: section.title, icon: section.icon,
                items: plan?.environmentSafetySteps ?? [],
                completedItems: $completedItems,
                showHeader: false
            )
        case .reasonsForLiving:
            StringListSection(
                title: section.title, icon: section.icon,
                items: plan?.reasonsForLiving ?? [],
                completedItems: $completedItems,
                showHeader: false
            )
        }
    }
    
    private var extractionSection: some View {
        Button(action: {
            crisisVM.call988()
            if let url = URL(string: "tel://988") {
                UIApplication.shared.open(url)
            }
        }) {
            HStack {
                Image(systemName: "phone.fill")
                Text("CALL 988 LIFELINE")
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Section Helpers

    /// Sections filtered to only those with content, in reranked order
    private var filteredSectionOrder: [SafetyPlanSection] {
        crisisVM.sectionOrder.filter { !$0.isEmpty(from: safetyPlanVM.safetyPlan) }
    }

    /// Creates a per-section binding into the expandedSections set
    private func isExpandedBinding(for section: SafetyPlanSection) -> Binding<Bool> {
        Binding(
            get: { expandedSections.contains(section) },
            set: { newValue in
                if newValue {
                    expandedSections.insert(section)
                } else {
                    expandedSections.remove(section)
                }
            }
        )
    }

    // MARK: - Helper Methods

    private func setupBriefingAutoplay() {
        if let briefing = hopeBoxVM.hopeBox?.selfCommandBriefing,
           let url = hopeBoxVM.getVideoURL(for: briefing) {
            player = AVPlayer(url: url)
            player?.play()
        }
    }
    
    
    private func startCountdownTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak crisisVM] _ in
            guard let crisisVM = crisisVM else { return }
            // Increment tick to trigger SwiftUI view updates
            crisisVM.timerTick += 1
            // Stop timer when countdown reaches zero
            if crisisVM.remainingSeconds <= 0 {
                timer?.invalidate()
                timer = nil
            }
        }
    }
    
    private func formatCountdown(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}


struct TacticalAssetCard: View {
    let item: HopeBoxItem
    @ObservedObject var viewModel: HopeBoxViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            if let thumbnail = viewModel.getThumbnail(for: item) {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .cornerRadius(8)
            }
            
            if let subtitle = item.subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(width: 120, alignment: .leading)
            }
        }
    }
}