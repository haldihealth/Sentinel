import SwiftUI
import SwiftData
import UIKit
import os

enum Tab: Int {
    case command = 0
    case hopeBox = 1
    case safetyPlan = 2
    case profile = 3
}

struct ContentView: View {
    let localStorage: LocalStorage

    @State private var selectedTab = Tab.command.rawValue
    
    // Add presentation state for daily check-in
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingDailyCheckIn = false

    // 1. REAL DATA: Fetch check-ins to determine state
    @Query(sort: \CheckInRecord.timestamp, order: .reverse) private var records: [CheckInRecord]

    // 2. Track dismissal of the Risk warning
    @State private var hasDismissedRiskOverlay = false

    // Computed Tier from Data
    private var currentRiskTier: RiskTier {
        guard let lastRecord = records.first,
              let tierString = lastRecord.determinedRiskTier,
              let tierInt = Int(tierString),
              let tier = RiskTier(rawValue: tierInt) else {
            return .low
        }
        return tier
    }
    
    // Overlay Logic: Show for High Monitoring (Orange) if not dismissed
    // Red Tier is handled by RedTierCrisisView instead
    private var showRiskOverlay: Bool {
        if currentRiskTier == .highMonitoring && !hasDismissedRiskOverlay { return true }
        return false
    }

    var body: some View {
        ZStack {
            // LAYER 1: Main Tab Interface
            TabView(selection: $selectedTab) {
                // Pass the binding and the data
                CommandView(
                    selectedTab: $selectedTab,
                    currentRiskTier: currentRiskTier,
                    hasCheckInData: !records.isEmpty,
                    latestRecord: records.first,
                    localStorage: localStorage
                )
                .tabItem {
                    Label("Command", systemImage: "square.grid.2x2.fill")
                }
                .tag(Tab.command.rawValue)

                HopeBoxView()
                    .tabItem {
                        Label("Hope Box", systemImage: "archivebox.fill")
                    }
                    .tag(Tab.hopeBox.rawValue)

                SafetyPlanView()
                    .tabItem {
                        Label("Safety Plan", systemImage: "list.bullet.clipboard")
                    }
                    .tag(Tab.safetyPlan.rawValue)

                MissionProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.fill")
                    }
                    .tag(Tab.profile.rawValue)
            }
            .tint(Theme.primary)
            
            // Developer mode indicator (top-right corner) removed
            // Red Tier: Full Crisis View with tactical briefings and assets
            if currentRiskTier == .crisis && !hasDismissedRiskOverlay {
                RedTierCrisisView(
                    onDebugExit: {
                        withAnimation {
                            hasDismissedRiskOverlay = true
                            selectedTab = Tab.command.rawValue
                        }
                    },
                    onResolved: {
                        withAnimation {
                            hasDismissedRiskOverlay = true
                            selectedTab = Tab.command.rawValue
                        }
                    }
                )
                    .transition(.opacity)
                    .zIndex(100)
            }
            // Orange Tier: Generic Warning Overlay
            else if showRiskOverlay {
                RiskStateOverlay(
                    tier: currentRiskTier,
                    onDismiss: {
                        withAnimation { hasDismissedRiskOverlay = true }
                    },
                    onAction: {
                        // Navigate to Safety Plan for Orange
                        withAnimation {
                            hasDismissedRiskOverlay = true
                            selectedTab = Tab.safetyPlan.rawValue
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .fullScreenCover(isPresented: $showingDailyCheckIn) {
            CheckInView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                checkDailyCheckInStatus()
            }
        }
        .onAppear {
            configureTabBarAppearance()
            checkDailyCheckInStatus()
        }
    }

    private func checkDailyCheckInStatus() {
        guard let latestRecord = records.first else {
            // No records at all, prompt for check-in
            showingDailyCheckIn = true
            return
        }
        // If the latest record is not from today, prompt for check-in
        if !Calendar.current.isDateInToday(latestRecord.timestamp) {
            showingDailyCheckIn = true
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        appearance.backgroundColor = UIColor(Theme.surface).withAlphaComponent(0.8)

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Command View (Home)

struct CommandView: View {
    @Binding var selectedTab: Int
    let currentRiskTier: RiskTier
    let hasCheckInData: Bool
    let latestRecord: CheckInRecord?
    let localStorage: LocalStorage

    // MARK: - SBAR Generation State
    @Environment(\.scenePhase) var scenePhase
    @State private var showingMessagePreview = false
    @State private var generatedMessage = ""
    @State private var isGenerating = false
    @State private var targetPortalURL: URL?
    @State private var generationTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView
                ScrollView {
                    VStack(spacing: Spacing.sectionSpacing) {
                        emergencyHelpCard
                        redconSection
                        tacticalActionsSection
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, Spacing.xxxl)
                }
            }
            .background(Theme.background)
            .navigationBarHidden(true)
            .sheet(isPresented: $showingMessagePreview) {
                if let targetURL = targetPortalURL {
                    MessagePreviewSheet(
                        message: generatedMessage,
                        isGenerating: isGenerating,
                        targetPortalURL: targetURL,
                        onClose: {
                            generationTask?.cancel()
                            generationTask = nil
                            showingMessagePreview = false
                            withAnimation { isGenerating = false }
                            // Unload model to free memory
                            Task { await MedGemmaEngine.shared.unloadModel() }
                        }
                    )

                }
            }
            // Cancel generation if app backgrounds to prevent Metal limit crash
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .background {
                    Logger.ai.info("App backgrounded - cancelling active LLM task")
                    generationTask?.cancel()
                    withAnimation { isGenerating = false }
                }
            }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.standard)
                    .fill(Theme.primary)
                    .frame(width: 44, height: 44)
                Image(systemName: "location.north.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(-45))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("SENTINEL COMMAND")
                    .font(Typography.headline)
                    .foregroundStyle(.white)
                    .tracking(1)
                Text("OFFLINE • ON-DEVICE ONLY • PRIVATE")
                    .font(Typography.tiny)
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(0.5)
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.vertical, Spacing.lg)
        .background(Theme.background)
    }

    // MARK: - Emergency Card
    private var emergencyHelpCard: some View {
        VStack(spacing: Spacing.sm) {
            Button(action: {
                if let url = URL(string: CrisisResources.suicidePreventionLine) {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 24, weight: .semibold))
                    Text("EMERGENCY HELP")
                        .font(Typography.buttonLarge)
                        .tracking(1.5)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Theme.emergency)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.standard)
                        .stroke(Theme.emergency.opacity(0.5), lineWidth: 2)
                )
            }
            Text("IMMEDIATE LINK: SUICIDE PREVENTION COORDINATOR")
                .font(Typography.captionSmall)
                .foregroundStyle(Theme.emergency)
                .tracking(0.5)
        }
    }

    // MARK: - REDCON Section (Green/Yellow)
    private var redconSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("YOUR REDCON LEVEL")
            RiskLevelCard(
                riskTier: currentRiskTier,
                hasCheckInData: hasCheckInData,
                latestRecord: latestRecord,
                selectedTab: $selectedTab
            )
        }
    }

    // MARK: - Tactical Actions
    private var tacticalActionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("TACTICAL ACTIONS")
            NavigationLink { CheckInView() } label: {
                TacticalActionCard(icon: "waveform.and.mic", title: "Daily Check-in")
            }
            Button(action: {
                generateAndPreview(
                    for: "https://myhealthevet.va.gov/secure-messaging",
                    recipient: .primaryCare
                )
            }) {
                TacticalActionCard(icon: "message.fill", title: "Message Primary Care", subtitle: "CONNECT TO MHS GENESIS/MYHEALTHEVET", showChevron: true)
            }
            .disabled(isGenerating)

            Button(action: {
                generateAndPreview(
                    for: "https://patientportal.mhsgenesis.health.mil/",
                    recipient: .mentalHealth
                )
            }) {
                TacticalActionCard(
                    icon: "brain.head.profile",
                    title: "Message Mental Health",
                    subtitle: "MHS GENESIS PORTAL",
                    showChevron: true
                )
            }
            .disabled(isGenerating)

            // Loading Indicator
            if isGenerating {
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                    Text("MedGemma AI generating secure handoff...")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, Spacing.sm)
                .transition(.opacity)
            }
        }
    }

    // MARK: - Helper Methods

    private func generateAndPreview(for urlString: String, recipient: RecipientType) {
        if let existing = generationTask {
            Logger.ai.info("Cancelling existing generation task")
            existing.cancel()
            generationTask = nil
        }

        self.targetPortalURL = URL(string: urlString)
        self.generatedMessage = ""
        withAnimation { self.isGenerating = true }
        self.showingMessagePreview = true

        let userProfile = localStorage.loadUserProfile()

        generationTask = Task {
            // Check cancellation before starting
            if Task.isCancelled { return }

            do {
                try await MedGemmaEngine.shared.loadModel()
            } catch {
                Logger.ai.warning("Model load failed: \(error.localizedDescription). Falling back to SBARGenerator.")
                await MainActor.run {
                    self.generatedMessage = SBARGenerator.generate(
                        record: latestRecord,
                        healthData: nil,
                        profile: userProfile,
                        riskTier: currentRiskTier,
                        recipient: recipient
                    )
                    withAnimation { self.isGenerating = false }
                }
                return
            }
            
            // 2. TIMEOUT RACE: Stream vs Timer
            // If first token doesn't arrive in 10s, fallback.
            let stream = await MedGemmaEngine.shared.generateClinicalReportStream(
                record: latestRecord,
                healthData: nil,
                profile: userProfile,
                riskTier: currentRiskTier,
                recipient: recipient
            )

            let maxCharacters = 3000
            var totalCharacters = 0
            var foundRecommendation = false
            var charsAfterRecommendation = 0
            var hasReceivedFirstToken = false
            
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)
                if !hasReceivedFirstToken {
                    Logger.ai.warning("Timeout reached waiting for first token")
                    return true
                }
                return false
            }

            for await token in stream {
                if Task.isCancelled { break }

                if !hasReceivedFirstToken {
                    hasReceivedFirstToken = true
                    timeoutTask.cancel()
                }

                totalCharacters += token.count

                if totalCharacters > maxCharacters { break }

                if token.contains("<<END_OF_REPORT>>") { break }

                await MainActor.run {
                    let filteredToken = token.replacingOccurrences(of: "<<END_OF_REPORT>>", with: "")
                    self.generatedMessage += filteredToken
                }

                if !foundRecommendation {
                    let currentMessage = await MainActor.run { self.generatedMessage }
                    if currentMessage.range(of: "RECOMMENDATION", options: .caseInsensitive) != nil {
                        foundRecommendation = true
                        charsAfterRecommendation = 0
                    }
                }
                if foundRecommendation {
                    charsAfterRecommendation += token.count
                    if charsAfterRecommendation > 150 { break }
                }
            }
            
            let finalMessage = await MainActor.run { self.generatedMessage }
            let didTimeout = await timeoutTask.value

            if finalMessage.isEmpty || didTimeout {
                Logger.ai.warning("Generation failed or timed out — using rule-based fallback")
                let fallback = SBARGenerator.generate(
                    record: latestRecord,
                    healthData: nil,
                    profile: userProfile,
                    riskTier: currentRiskTier,
                    recipient: recipient
                )
                await MainActor.run {
                    self.generatedMessage = fallback
                }
                await MedGemmaEngine.shared.resetEngine()
            }

            await MainActor.run {
                withAnimation { self.isGenerating = false }
            }
        }
    }
}

// MARK: - Risk Level Card
struct RiskLevelCard: View {
    let riskTier: RiskTier
    let hasCheckInData: Bool
    let latestRecord: CheckInRecord?
    @Binding var selectedTab: Int
    
    @State private var isFlipped = false
    
    var body: some View {
        ZStack {
            frontView
                .opacity(isFlipped ? 0 : 1)
                // Disable hit testing when hidden to prevent interaction
                .allowsHitTesting(!isFlipped)
            
            backView
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, 0))
                .opacity(isFlipped ? 1 : 0)
                .allowsHitTesting(isFlipped)
        }
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, 0))
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isFlipped)
    }
    
    private var frontView: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if hasCheckInData {
                    // 1. Status Row
                    HStack(spacing: Spacing.sm) {
                        Circle()
                            .fill(riskTier.color)
                            .frame(width: 12, height: 12)
                            .shadow(color: riskTier.color.opacity(0.5), radius: 4, x: 0, y: 0)
                        Text("\(riskTier.colorName.replacingOccurrences(of: "Sentinel", with: "").uppercased()) - \(riskTier.displayName)")
                            .font(Typography.riskLevel)
                            .foregroundStyle(riskTier.color)
                            .tracking(0.5)
                        
                        Spacer()
                        
                        // Flip Button
                        Button(action: { isFlipped.toggle() }) {
                            HStack(spacing: 4) {
                                Text("Why?")
                                    .font(Typography.tiny)
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 10))
                            }
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                    // 2. Description
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(riskTier.cardDescription)
                            .font(Typography.subheadline)
                            .foregroundStyle(.white)
                        Text(riskTier.cardRecommendation)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    // 3. Action Button (Yellow only)
                    if let actionTitle = riskTier.actionButtonTitle {
                        Button(action: {
                            if riskTier == .crisis {
                                if let url = URL(string: "tel://988") { UIApplication.shared.open(url) }
                            } else {
                                selectedTab = 2 // Go to Safety Plan
                            }
                        }) {
                            HStack {
                                Text(actionTitle).font(Typography.headline)
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                            }
                            .foregroundStyle(Theme.background)
                            .padding(.vertical, Spacing.sm)
                            .padding(.horizontal, Spacing.md)
                            .background(riskTier.color)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                        }
                        .padding(.top, Spacing.xs)
                    }
                } else {
                    // Empty State
                    HStack(spacing: Spacing.sm) {
                        Circle()
                            .strokeBorder(Theme.primary.opacity(0.5), lineWidth: 2)
                            .frame(width: 12, height: 12)
                        Text("PENDING INITIAL CHECK-IN")
                            .font(Typography.riskLevel)
                            .foregroundStyle(.secondary)
                            .tracking(0.5)
                    }
                    Text("Complete your first Daily Check-in to establish your baseline and safety status.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }
    
    
    private var backView: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("RISK ASSESSMENT SOURCE")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    // Flip Back Button
                    Button(action: { isFlipped.toggle() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                
                // Source Badge
                let source = latestRecord?.derivedRiskSource ?? "System"
                Text(source.uppercased())
                    .font(Typography.headline)
                    .foregroundStyle(Theme.primary)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Theme.primary.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                
                // Explanation
                ScrollView {
                    Group {
                         if isGeneratingExplanation {
                             ProgressView()
                                 .padding()
                         } else {
                             Text(currentExplanation)
                                 .font(Typography.body)
                                 .foregroundStyle(.white)
                                 .padding(.top, 4)
                         }
                    }
                }
                
                if !isGeneratingExplanation && !currentExplanation.isEmpty {
                    Button("Regenerate Explanation") {
                        generateExplanation()
                    }
                    .font(Typography.caption)
                    .foregroundStyle(Theme.primary)
                    .padding(.top, 4)
                }
                
                Spacer()
            }
        }
        .task(id: isFlipped) {
            if isFlipped && currentExplanation.isEmpty {
                generateExplanation()
            }
        }
    }
    
    @State private var currentExplanation: String = ""
    @State private var isGeneratingExplanation: Bool = false
    
    private func generateExplanation() {
        guard let record = latestRecord else { return }
        
        // If we already have a static one from the record, use it first, but allow regen
        if currentExplanation.isEmpty, let existing = record.riskExplanation, !existing.isEmpty {
            currentExplanation = existing
        }
        
        isGeneratingExplanation = true
        
        Task {
            // Add slight delay so it doesn't look like a glitch if fast
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            let explanation = await MedGemmaEngine.shared.generateRiskExplanation(
                riskTier: riskTier,
                lastRecord: record
            )
            
            await MainActor.run {
                withAnimation {
                    self.currentExplanation = explanation
                    self.isGeneratingExplanation = false
                }
            }
        }
    }
}

// MARK: - Risk Overlay (Orange Tier Only)
struct RiskStateOverlay: View {
    let tier: RiskTier
    let onDismiss: () -> Void
    let onAction: () -> Void
    
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            Color.black.opacity(0.8).ignoresSafeArea()
            Circle().fill(tier.color).frame(width: 300, height: 300).blur(radius: 100).opacity(0.3)
            
            VStack(spacing: Spacing.xl) {
                Image(systemName: "eye.trianglebadge.exclamationmark.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(tier.color)
                    .symbolEffect(.pulse, options: .repeating)
                
                VStack(spacing: Spacing.md) {
                    Text(tier.displayName).font(Typography.largeTitle).foregroundStyle(tier.color).tracking(2)
                    Text(tier.cardDescription).font(Typography.bodyEmphasis).foregroundStyle(.white).multilineTextAlignment(.center).padding(.horizontal, Spacing.lg)
                    Text(tier.cardRecommendation).font(Typography.body).foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center).padding(.horizontal, Spacing.lg)
                }
                
                VStack(spacing: Spacing.md) {
                    Button(action: onAction) {
                        Text("OPEN SAFETY PLAN")
                            .font(Typography.buttonLarge)
                            .foregroundStyle(Theme.background)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(tier.color)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                    }
                    Button(action: onDismiss) {
                        Text("Proceed to Dashboard").font(Typography.headline).foregroundStyle(.white.opacity(0.6)).padding()
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.lg)
            }
        }
    }
}

// MARK: - Message Preview Sheet
struct MessagePreviewSheet: View {
    let message: String
    let isGenerating: Bool
    let targetPortalURL: URL
    let onClose: () -> Void
    
    @State private var showingCopiedAlert = false

    private func copyToClipboard() {
        UIPasteboard.general.string = message
        showingCopiedAlert = true
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.md) {
                ScrollView {
                    if message.isEmpty && isGenerating {
                       VStack(spacing: Spacing.md) {
                           ProgressView()
                               .scaleEffect(1.5)
                           Text("Analyzing check-in data...")
                               .font(Typography.caption)
                               .foregroundStyle(.secondary)
                       }
                       .frame(maxWidth: .infinity, maxHeight: .infinity)
                       .padding(.top, 60)
                    } else {
                        Text(message)
                            .font(Typography.body)
                            .padding()
                            .textSelection(.enabled)
                    }
                }
                
                // Actions
                VStack(spacing: Spacing.sm) {
                    if isGenerating {
                        Button(action: onClose) {
                             Text("Cancel Generation")
                                .font(Typography.buttonLarge)
                                .foregroundStyle(.red)
                        }
                        .padding()
                    } else {
                        Button(action: {
                            copyToClipboard()
                        }) {
                            Label("Copy to Clipboard", systemImage: "doc.on.doc")
                                .font(Typography.buttonLarge)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                        }
                        
                        Button(action: {
                            copyToClipboard()
                            UIApplication.shared.open(targetPortalURL)
                        }) {
                            Label("Copy & Open Portal", systemImage: "arrow.up.right.square")
                                .font(Typography.buttonLarge)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.primary)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Clinical Handoff")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                }
            }
            .alert("Copied", isPresented: $showingCopiedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Report copied to clipboard.")
            }
        }
    }
}
