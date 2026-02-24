import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Mission Profile (Settings/Dossier) view
/// Tactical-themed settings screen with OPSEC, sensors, neural engine, and identity management
struct MissionProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = MissionProfileViewModel()
    @State private var editingCallsign = false
    @State private var showLicenses = false
    @State private var tempCallsign = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // I. OPSEC (Security & Privacy)
                    opsecSection

                    // II. SENSORS (Data Sources - Read Only Status)
                    sensorsSection

                    // SIMULATION (Debug)
                    simulationSection
                    
                    // DEVELOPER MODE (Kaggle Demo)
                    developerModeSection

                    // III. NEURAL ENGINE (On-Device AI)
                    neuralEngineSection

                    // IV. COMMS (Notifications)
                    commsSection

                    // V. DOSSIER (Identity)
                    dossierSection

                    // VI. OPERATIONAL TRANSPARENCY
                    transparencySection

                    // Footer
                    footerSection
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xxxl)
            }
            .background(Theme.background)
            .navigationTitle("Mission Profile")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.loadProfile()
            }
            .alert("Reset All Data", isPresented: $viewModel.showResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Purge Data", role: .destructive) {
                    viewModel.purgeAllData()
                }
            } message: {
                Text("This will permanently delete all your data including your Safety Plan, check-in history, and settings. This action cannot be undone.")
            }
            .alert("Activate Developer Mode?", isPresented: $viewModel.showDeveloperModeAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Activate", role: .destructive) {
                    Task {
                        await viewModel.activateDeveloperMode(modelContext: modelContext)
                    }
                }
            } message: {
                Text("This will erase ALL user data and load the demo scenario (48h post-ED discharge with activation syndrome). This action cannot be undone.")
            }
            .alert("Demo Scenario Activated", isPresented: $viewModel.showDeveloperModeSuccess) {
                Button("OK") {
                    // User can now proceed to perform check-in
                }
            } message: {
                Text("Timeline: 48h post-discharge\nPatient: SENTINEL-DEMO\nReady for check-in recording.")
            }
            .alert("Edit Callsign", isPresented: $editingCallsign) {
                TextField("Callsign", text: $tempCallsign)
                Button("Cancel", role: .cancel) {
                    tempCallsign = ""
                }
                Button("Save") {
                    if !tempCallsign.isEmpty {
                        viewModel.updateCallsign(tempCallsign)
                    }
                    tempCallsign = ""
                }
            } message: {
                Text("Enter your new callsign")
            }
            .sheet(isPresented: $showLicenses) {
                LicenseView()
            }
            .fileImporter(
                isPresented: $viewModel.showVideoImporter,
                allowedContentTypes: [.movie, .video, .mpeg4Movie, .quickTimeMovie],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        viewModel.loadDemoVideo(from: url)
                    }
                case .failure(let error):
                    viewModel.errorMessage = "Failed to load video: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Section Helper

    private func profileSection<Content: View>(
        title: String,
        icon: String,
        iconColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header
            HStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 32, height: 32)

                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(iconColor)
                }

                Text(title)
                    .font(Typography.bodyEmphasis)
                    .foregroundStyle(.white)
            }

            // Content
            VStack(spacing: Spacing.sm) {
                content()
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
    }

    // MARK: - I. OPSEC Section

    private var opsecSection: some View {
        profileSection(
            title: "OPSEC Protocols",
            icon: "shield.checkered",
            iconColor: Theme.primary
        ) {
            ToggleRow(
                title: "Local-Only Mode",
                isOn: $viewModel.isLocalOnly,
                subtitle: "Excludes data from backup"
            )

            Divider().background(Theme.surfaceHover)

            ToggleRow(
                title: "Biometric Shield",
                isOn: $viewModel.useBiometrics,
                subtitle: "Require Face ID to unlock"
            )

            Divider().background(Theme.surfaceHover)

            HStack {
                Text("Auto-Lock Timer")
                    .font(Typography.body)
                    .foregroundStyle(.white)

                Spacer()

                Menu {
                    ForEach(AutoLockTimer.allCases, id: \.self) { timer in
                        Button(timer.rawValue) {
                            viewModel.autoLockTimer = timer
                            viewModel.saveSettings()
                        }
                    }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Text(viewModel.autoLockTimer.rawValue)
                            .font(Typography.body)
                            .foregroundStyle(.white)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.vertical, 4)

            Divider().background(Theme.surfaceHover)

            Button(action: { viewModel.showResetConfirmation = true }) {
                 HStack {
                     Image(systemName: "trash.fill")
                        .foregroundStyle(Theme.emergency)
                     Text("Data Reset (Irreversible)")
                         .font(Typography.body)
                         .foregroundStyle(Theme.emergency)
                     Spacer()
                 }
                 .padding(.vertical, 4)
            }
        }
    }

    // MARK: - II. SENSORS Section

    private var sensorsSection: some View {
        profileSection(
            title: "Sensor Status",
            icon: "waveform.path.ecg",
            iconColor: .blue
        ) {
            StatusRow(
                title: "Biometric Feed",
                status: viewModel.healthKitStatus,
                subtitle: "HRV, Sleep via HealthKit"
            )

            Divider().background(Theme.surfaceHover)

            StatusRow(
                title: "Clinical Feed",
                status: viewModel.clinicalFeedStatus,
                subtitle: "VA Records (Coming Soon)"
            )

            Divider().background(Theme.surfaceHover)

            HStack(spacing: Spacing.lg) {
                // Camera status
                VStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(viewModel.cameraStatus.color)

                    Text("Camera")
                        .font(Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                // Divider
                Rectangle()
                    .fill(Theme.surfaceHover)
                    .frame(width: 1, height: 30)

                // Microphone status
                VStack(spacing: 4) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(viewModel.microphoneStatus.color)

                    Text("Microphone")
                        .font(Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, Spacing.sm)

            Divider().background(Theme.surfaceHover)

            // Link to settings
            Button(action: openSystemSettings) {
                HStack {
                    Text("Manage System Permissions")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.primary)

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Simulation Section (Debug)

    private var simulationSection: some View {
        profileSection(
            title: "Simulation & Debug",
            icon: "testtube.2",
            iconColor: .pink
        ) {
            ToggleRow(
                title: "Enable HealthKit Simulation",
                isOn: Binding(
                    get: { viewModel.isSimulationEnabled },
                    set: { viewModel.toggleHealthKitSimulation($0) }
                ),
                subtitle: "Inject mock data for testing"
            )

            if viewModel.isSimulationEnabled {
                Divider().background(Theme.surfaceHover)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Scenario")
                        .font(Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    ForEach(SimulationScenario.allCases) { scenario in
                        Button(action: {
                            viewModel.loadSimulatedScenario(scenario)
                        }) {
                            HStack {
                                Text(scenario.rawValue)
                                    .font(Typography.body)
                                    .foregroundStyle(viewModel.selectedScenario == scenario ? Theme.primary : .white)

                                Spacer()

                                if viewModel.selectedScenario == scenario {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.primary)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Theme.surfaceHover.opacity(viewModel.selectedScenario == scenario ? 0.3 : 0.0))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }

                    // Instant Simulation Trigger
                    Divider().background(Theme.surfaceHover)
                    
                    Button(action: {
                        viewModel.performSimulatedCheckIn(context: modelContext)
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Run Simulated Check-In")
                                .font(Typography.bodyEmphasis)
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Theme.primary)
                        .foregroundStyle(Theme.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
    
    // MARK: - Developer Mode Section (Kaggle Demo)
    
    private var developerModeSection: some View {
        profileSection(
            title: "DEVELOPER MODE",
            icon: "hammer.fill",
            iconColor: .orange
        ) {
            Text("Load Kaggle Impact Competition demo scenario")
                .font(Typography.body)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            
            if viewModel.isLoadingDeveloperMode {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.primary))
                    Text("Activating...")
                        .font(Typography.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                Button(action: {
                    viewModel.showDeveloperModeAlert = true
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Activate Demo Scenario")
                            .font(Typography.bodyEmphasis)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(Color.orange.opacity(0.2))
                    .foregroundStyle(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            Divider().background(Theme.surfaceHover)

            // Demo video loader for camera injection
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Demo Video")
                        .font(Typography.bodyEmphasis)
                    Text(viewModel.demoVideoName ?? "No video loaded — tap to select")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Button(action: { viewModel.showVideoImporter = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.demoVideoName != nil ? "arrow.triangle.2.circlepath" : "plus.circle")
                            .font(.system(size: 12))
                        Text(viewModel.demoVideoName != nil ? "Replace" : "Load")
                            .font(Typography.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.15))
                    .foregroundStyle(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - III. NEURAL ENGINE Section

    private var neuralEngineSection: some View {
        profileSection(
            title: "Neural Engine",
            icon: "cpu.fill", // changed from brain to cpu for distinct look
            iconColor: .purple
        ) {
            InfoRow(label: "Model", value: viewModel.modelName)

            Divider().background(Theme.surfaceHover)

            InfoRow(
                label: "Status",
                value: viewModel.modelStatus.displayText,
                valueColor: viewModel.modelStatus.color
            )

            Divider().background(Theme.surfaceHover)

            InfoRow(label: "Last Inference", value: viewModel.lastInferenceTime)

            Divider().background(Theme.surfaceHover)

            // Diagnostics button
            Button(action: {
                Task { await viewModel.runDiagnostics() }
            }) {
                HStack {
                    if viewModel.isDiagnosticsRunning {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.primary))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "waveform.badge.magnifyingglass")
                            .font(.system(size: 14))
                    }

                    Text(viewModel.isDiagnosticsRunning ? "Running..." : "Run Diagnostics")
                        .font(Typography.caption)
                }
                .foregroundStyle(Theme.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Theme.background.opacity(0.5))
                .clipShape(Capsule())
            }
            .disabled(viewModel.isDiagnosticsRunning)
            .padding(.top, 4)
        }
    }

    // MARK: - IV. COMMS Section

    private var commsSection: some View {
        profileSection(
            title: "Communications",
            icon: "antenna.radiowaves.left.and.right",
            iconColor: .orange
        ) {
            ToggleRow(
                title: "Check-In Reminders",
                isOn: $viewModel.checkInRemindersEnabled
            )

            Divider().background(Theme.surfaceHover)

            ToggleRow(
                title: "Crisis Alert Notifications",
                isOn: $viewModel.crisisAlertSensitivity
            )

            Divider().background(Theme.surfaceHover)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Silent Hours")
                        .font(Typography.body)
                        .foregroundStyle(.white)

                    Text("Notifications paused")
                        .font(Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $viewModel.silentHoursEnabled)
                    .labelsHidden()
                    .tint(Theme.primary)
            }
            .padding(.vertical, 4)

            if viewModel.silentHoursEnabled {
                HStack {
                    Text("2200")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)

                    Rectangle()
                        .fill(Theme.primary.opacity(0.3))
                        .frame(height: 2)
                        .clipShape(Capsule())

                    Text("0600")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.sm)
            }
        }
    }

    // MARK: - V. DOSSIER Section

    private var dossierSection: some View {
        profileSection(
            title: "Identity Dossier",
            icon: "person.text.rectangle.fill",
            iconColor: .green
        ) {
            // Callsign
            Button(action: {
                tempCallsign = viewModel.userProfile.callsign
                editingCallsign = true
            }) {
                HStack {
                    Text("Callsign")
                        .font(Typography.body)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(viewModel.userProfile.callsign)
                        .font(Typography.bodyEmphasis)
                        .foregroundStyle(.white)

                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            Divider().background(Theme.surfaceHover)

            // Preferred Name
            EditableRow(
                label: "Preferred Name",
                value: Binding(
                    get: { viewModel.userProfile.preferredName ?? "" },
                    set: { viewModel.updatePreferredName($0) }
                ),
                placeholder: "Not Set"
            )

            Divider().background(Theme.surfaceHover)

            // Service Branch
            HStack {
                Text("Service Branch")
                    .font(Typography.body)
                    .foregroundStyle(.secondary)

                Spacer()

                Menu {
                    Button("None") {
                        viewModel.updateBranch(nil)
                    }
                    ForEach(MilitaryBranch.allCases, id: \.self) { branch in
                        Button(branch.rawValue) {
                            viewModel.updateBranch(branch)
                        }
                    }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Text(viewModel.userProfile.branchOfService?.rawValue ?? "Not Set")
                            .font(Typography.body)
                            .foregroundStyle(viewModel.userProfile.branchOfService != nil ? .white : .secondary)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - VI. TRANSPARENCY Section

    private var transparencySection: some View {
        profileSection(
            title: "Operational Data",
            icon: "doc.plaintext.fill",
            iconColor: .gray
        ) {
            Button(action: {
                // Action for About
            }) {
                HStack {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                    Text("About Sentinel")
                        .font(Typography.body)
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            Divider().background(Theme.surfaceHover)

            Button(action: {
                showLicenses = true
            }) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                    Text("Open Source Licenses")
                        .font(Typography.body)
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: Spacing.lg) {
            TransparencySeal()

            Text("App Version: \(viewModel.appVersion)")
                .font(Typography.captionSmall)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    MissionProfileView()
        .preferredColorScheme(.dark)
}
