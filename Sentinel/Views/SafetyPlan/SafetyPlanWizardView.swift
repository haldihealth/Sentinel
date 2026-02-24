import SwiftUI

/// Editing mode for the safety plan wizard
enum SafetyPlanEditMode {
    case fullWizard      // Walk through all steps (new plan or full review)
    case sectionPicker   // Show section picker (editing existing plan)
    case singleSection   // Edit a single section
}

/// Step-by-step wizard for creating/editing a Safety Plan
struct SafetyPlanWizardView: View {
    @ObservedObject var viewModel: SafetyPlanViewModel
    @Environment(\.dismiss) private var dismiss

    /// Whether this is editing an existing plan (shows section picker first)
    var isEditing: Bool = false

    @State private var editMode: SafetyPlanEditMode = .fullWizard
    @State private var textInput = ""
    @State private var showContactPicker = false
    @State private var showRolePicker = false
    @State private var pendingContact: PickedContact?
    @State private var selectedRole = ""
    @State private var showCustomRoleAlert = false
    @State private var customRole = ""

    // For professional contact entry
    @State private var showProfessionalEntry = false
    @State private var professionalName = ""
    @State private var professionalPhone = ""
    @State private var professionalOrg = ""
    @State private var isEmergencyContact = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Show section picker or step content
            if editMode == .sectionPicker {
                sectionPickerView
            } else {
                // Progress (only in wizard/single section mode)
                if editMode == .fullWizard {
                    progressView
                }

                // Content
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // Step info
                        stepInfoView

                        // Step-specific content
                        stepContentView

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.lg)
                }

                // Navigation buttons
                navigationButtonsView
            }
        }
        .background(Theme.background)
        .sheet(isPresented: $showContactPicker) {
            ContactPickerView { contact in
                pendingContact = contact
                showRolePicker = true
            }
        }
        .sheet(isPresented: $showRolePicker) {
            rolePickerSheet
        }
        .sheet(isPresented: $showProfessionalEntry) {
            professionalEntrySheet
        }
        .alert("Custom Role", isPresented: $showCustomRoleAlert) {
            TextField("Enter role", text: $customRole)
            Button("Cancel", role: .cancel) { customRole = "" }
            Button("Add") {
                if !customRole.isEmpty {
                    selectedRole = customRole
                    addContactWithRole()
                }
                customRole = ""
            }
        }
        .onAppear {
            viewModel.startEditing()
            // Show section picker if editing existing plan
            if isEditing && viewModel.hasPlan {
                editMode = .sectionPicker
            } else {
                editMode = .fullWizard
                viewModel.goToStep(1)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
                    .background(Theme.surface)
                    .clipShape(Circle())
            }

            Spacer()

            Text("SAFETY PLAN")
                .font(Typography.caption)
                .fontWeight(.bold)
                .tracking(1.5)
                .foregroundStyle(.secondary)

            Spacer()

            // Emergency button
            Button(action: call988) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.emergency)
                    .frame(width: 40, height: 40)
                    .background(Theme.emergency.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Progress

    private var progressView: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Text("Step \(viewModel.currentStep)")
                    .font(Typography.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.primary)

                Spacer()

                Text("\(viewModel.currentStep) of \(viewModel.totalSteps)")
                    .font(Typography.captionSmall)
                    .foregroundStyle(.tertiary)
            }

            ProgressBarView(current: viewModel.currentStep, total: viewModel.totalSteps)
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.bottom, Spacing.md)
    }

    // MARK: - Section Picker

    private var sectionPickerView: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Header
                VStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Theme.primary.opacity(0.2))
                            .frame(width: 64, height: 64)

                        Image(systemName: "pencil.and.list.clipboard")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.primary)
                    }

                    Text("What would you like to update?")
                        .font(Typography.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Select a section to edit, or review your entire plan")
                        .font(Typography.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Spacing.lg)

                // Section cards
                VStack(spacing: Spacing.sm) {
                    sectionPickerRow(
                        step: 1,
                        title: "Warning Signs",
                        icon: "exclamationmark.triangle.fill",
                        iconColor: Theme.riskModerate,
                        count: viewModel.safetyPlan?.warningSigns.count ?? 0,
                        unit: "sign"
                    )

                    sectionPickerRow(
                        step: 2,
                        title: "Coping Strategies",
                        icon: "brain.head.profile",
                        iconColor: Theme.primary,
                        count: viewModel.safetyPlan?.copingStrategies.count ?? 0,
                        unit: "strategy"
                    )

                    sectionPickerRow(
                        step: 3,
                        title: "Social Distractions",
                        icon: "person.2.fill",
                        iconColor: .blue,
                        count: viewModel.safetyPlan?.socialDistractions.count ?? 0,
                        unit: "contact"
                    )

                    sectionPickerRow(
                        step: 4,
                        title: "Support Contacts",
                        icon: "hand.raised.fill",
                        iconColor: .green,
                        count: viewModel.safetyPlan?.supportContacts.count ?? 0,
                        unit: "contact"
                    )

                    sectionPickerRow(
                        step: 5,
                        title: "Professional Help",
                        icon: "staroflife.fill",
                        iconColor: Theme.emergency,
                        count: viewModel.safetyPlan?.professionalContacts.count ?? 0,
                        unit: "contact"
                    )

                    sectionPickerRow(
                        step: 6,
                        title: "Environment Safety",
                        icon: "shield.checkered",
                        iconColor: .orange,
                        count: viewModel.safetyPlan?.environmentSafetySteps.count ?? 0,
                        unit: "step"
                    )

                    sectionPickerRow(
                        step: 7,
                        title: "Reasons for Living",
                        icon: "heart.fill",
                        iconColor: .pink,
                        count: viewModel.safetyPlan?.reasonsForLiving.count ?? 0,
                        unit: "reason"
                    )
                }

                // Review entire plan button
                Button(action: {
                    viewModel.goToStep(1)
                    editMode = .fullWizard
                }) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 16))
                        Text("Review Entire Plan")
                            .font(Typography.bodyEmphasis)
                    }
                    .foregroundStyle(Theme.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.standard)
                            .stroke(Theme.primary.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.top, Spacing.md)

                Spacer(minLength: 100)
            }
            .padding(.horizontal, Spacing.screenHorizontal)
        }
    }

    private func sectionPickerRow(
        step: Int,
        title: String,
        icon: String,
        iconColor: Color,
        count: Int,
        unit: String
    ) -> some View {
        Button(action: {
            viewModel.goToStep(step)
            editMode = .singleSection
        }) {
            HStack(spacing: Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(iconColor)
                }

                // Title and count
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typography.bodyEmphasis)
                        .foregroundStyle(.white)

                    let plural = count == 1 ? unit : "\(unit)s"
                    Text(count > 0 ? "\(count) \(plural)" : "Not set")
                        .font(Typography.caption)
                        .foregroundStyle(count > 0 ? .secondary : Theme.riskModerate)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(Spacing.md)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step Info

    private var stepInfoView: some View {
        VStack(spacing: Spacing.md) {
            // Step icon
            stepIcon

            // Title
            Text(viewModel.stepTitles[viewModel.currentStep] ?? "")
                .font(Typography.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            // Description
            Text(viewModel.stepDescriptions[viewModel.currentStep] ?? "")
                .font(Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var stepIcon: some View {
        let iconName: String
        let iconColor: Color

        switch viewModel.currentStep {
        case 1:
            iconName = "exclamationmark.triangle.fill"
            iconColor = Theme.riskModerate
        case 2:
            iconName = "brain.head.profile"
            iconColor = Theme.primary
        case 3:
            iconName = "person.2.fill"
            iconColor = .blue
        case 4:
            iconName = "hand.raised.fill"
            iconColor = .green
        case 5:
            iconName = "staroflife.fill"
            iconColor = Theme.emergency
        case 6:
            iconName = "shield.checkered"
            iconColor = .orange
        case 7:
            iconName = "heart.fill"
            iconColor = .pink
        default:
            iconName = "questionmark"
            iconColor = .gray
        }

        return ZStack {
            Circle()
                .fill(iconColor.opacity(0.2))
                .frame(width: 64, height: 64)

            Image(systemName: iconName)
                .font(.system(size: 28))
                .foregroundStyle(iconColor)
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContentView: some View {
        switch viewModel.currentStep {
        case 1:
            stringListStepView(
                items: viewModel.safetyPlan?.warningSigns ?? [],
                suggestions: SafetyPlanSuggestions.warningSigns,
                placeholder: "Add a warning sign...",
                onAdd: { viewModel.addWarningSign($0) },
                onRemove: { viewModel.removeWarningSign(at: $0) }
            )
        case 2:
            stringListStepView(
                items: viewModel.safetyPlan?.copingStrategies ?? [],
                suggestions: SafetyPlanSuggestions.copingStrategies,
                placeholder: "Add a coping strategy...",
                onAdd: { viewModel.addCopingStrategy($0) },
                onRemove: { viewModel.removeCopingStrategy(at: $0) }
            )
        case 3:
            contactStepView(
                contacts: viewModel.safetyPlan?.socialDistractions ?? [],
                title: "Add people or places",
                onRemove: { viewModel.removeSocialDistraction(at: $0) },
                onCall: { callContact($0) },
                isProfessional: false
            )
        case 4:
            contactStepView(
                contacts: viewModel.safetyPlan?.supportContacts ?? [],
                title: "Add support contacts",
                onRemove: { viewModel.removeSupportContact(at: $0) },
                onCall: { callContact($0) },
                isProfessional: false
            )
        case 5:
            professionalContactStepView
        case 6:
            stringListStepView(
                items: viewModel.safetyPlan?.environmentSafetySteps ?? [],
                suggestions: SafetyPlanSuggestions.environmentSafetySteps,
                placeholder: "Add a safety step...",
                onAdd: { viewModel.addEnvironmentSafetyStep($0) },
                onRemove: { viewModel.removeEnvironmentSafetyStep(at: $0) }
            )
        case 7:
            stringListStepView(
                items: viewModel.safetyPlan?.reasonsForLiving ?? [],
                suggestions: SafetyPlanSuggestions.reasonsForLiving,
                placeholder: "Add a reason for living...",
                onAdd: { viewModel.addReasonForLiving($0) },
                onRemove: { viewModel.removeReasonForLiving(at: $0) }
            )
        default:
            EmptyView()
        }
    }

    // MARK: - String List Step (Steps 1, 2, 6, 7)

    private func stringListStepView(
        items: [String],
        suggestions: [String],
        placeholder: String,
        onAdd: @escaping (String) -> Void,
        onRemove: @escaping (Int) -> Void
    ) -> some View {
        VStack(spacing: Spacing.lg) {
            // Suggestion chips
            suggestionChipsView(
                suggestions: suggestions,
                selectedItems: items,
                onSelect: { suggestion in
                    if !items.contains(suggestion) {
                        onAdd(suggestion)
                    }
                }
            )

            // Text input
            HStack(spacing: Spacing.sm) {
                TextField(placeholder, text: $textInput)
                    .font(Typography.body)
                    .padding(Spacing.md)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
                    .submitLabel(.done)
                    .onSubmit {
                        if !textInput.isEmpty {
                            onAdd(textInput)
                            textInput = ""
                        }
                    }

                Button(action: {
                    if !textInput.isEmpty {
                        onAdd(textInput)
                        textInput = ""
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(textInput.isEmpty ? .secondary : Theme.primary)
                }
                .disabled(textInput.isEmpty)
            }

            // Added items
            if !items.isEmpty {
                VStack(spacing: Spacing.sm) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        addedItemCard(item: item) {
                            onRemove(index)
                        }
                    }
                }
            }
        }
    }

    private func suggestionChipsView(
        suggestions: [String],
        selectedItems: [String],
        onSelect: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("SUGGESTIONS")
                .font(Typography.captionSmall)
                .foregroundStyle(.secondary)
                .tracking(1)

            FlowLayout(spacing: Spacing.sm) {
                ForEach(suggestions.prefix(12), id: \.self) { suggestion in
                    let isSelected = selectedItems.contains(suggestion)

                    Button(action: { onSelect(suggestion) }) {
                        Text(suggestion)
                            .font(Typography.caption)
                            .foregroundStyle(isSelected ? .white : .secondary)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(isSelected ? Theme.primary : Theme.surface)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? Theme.primary : Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSelected)
                }
            }
        }
    }

    private func addedItemCard(item: String, onDelete: @escaping () -> Void) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Theme.primary)

            Text(item)
                .font(Typography.body)
                .foregroundStyle(.white)

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Theme.surfaceHover)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.md)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
    }

    // MARK: - Contact Step (Steps 3, 4)

    private func contactStepView(
        contacts: [SocialContact],
        title: String,
        onRemove: @escaping (Int) -> Void,
        onCall: @escaping (SocialContact) -> Void,
        isProfessional: Bool
    ) -> some View {
        VStack(spacing: Spacing.lg) {
            // Add from contacts button
            Button(action: { showContactPicker = true }) {
                HStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Theme.primary.opacity(0.2))
                            .frame(width: 44, height: 44)

                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.primary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add from Contacts")
                            .font(Typography.bodyEmphasis)
                            .foregroundStyle(.white)

                        Text("Select from your phone contacts")
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(Spacing.md)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
            }
            .buttonStyle(.plain)

            // Added contacts
            if !contacts.isEmpty {
                VStack(spacing: Spacing.sm) {
                    ForEach(Array(contacts.enumerated()), id: \.element.id) { index, contact in
                        ContactEntryCard(
                            contact: contact,
                            onDelete: { onRemove(index) },
                            onCall: { onCall(contact) }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Professional Contact Step (Step 5)

    private var professionalContactStepView: some View {
        VStack(spacing: Spacing.lg) {
            // Default crisis resources (non-removable)
            VStack(spacing: Spacing.sm) {
                ForEach(SafetyPlanSuggestions.defaultProfessionalContacts) { contact in
                    ProfessionalContactCard(
                        contact: contact,
                        onDelete: { },
                        onCall: { callProfessional(contact) }
                    )
                }
            }

            // Add professional button
            Button(action: { showProfessionalEntry = true }) {
                HStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Theme.primary.opacity(0.2))
                            .frame(width: 44, height: 44)

                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add Professional Contact")
                            .font(Typography.bodyEmphasis)
                            .foregroundStyle(.white)

                        Text("Therapist, doctor, VA counselor, etc.")
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(Spacing.md)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
            }
            .buttonStyle(.plain)

            // User's professional contacts
            if let contacts = viewModel.safetyPlan?.professionalContacts, !contacts.isEmpty {
                VStack(spacing: Spacing.sm) {
                    ForEach(Array(contacts.enumerated()), id: \.element.id) { index, contact in
                        ProfessionalContactCard(
                            contact: contact,
                            onDelete: { viewModel.removeProfessionalContact(at: index) },
                            onCall: { callProfessional(contact) }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtonsView: some View {
        VStack(spacing: Spacing.md) {
            if editMode == .singleSection {
                // Single section editing mode
                HStack(spacing: Spacing.md) {
                    // Back to sections button
                    Button(action: {
                        viewModel.autoSave()
                        editMode = .sectionPicker
                    }) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "chevron.left")
                            Text("Sections")
                        }
                        .font(Typography.bodyEmphasis)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
                    }

                    // Done button
                    Button(action: {
                        viewModel.saveSafetyPlan()
                        dismiss()
                    }) {
                        HStack(spacing: Spacing.sm) {
                            Text("Done")
                            Image(systemName: "checkmark")
                        }
                        .font(Typography.bodyEmphasis)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Theme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
                    }
                }
            } else {
                // Full wizard mode
                HStack(spacing: Spacing.md) {
                    // Back button
                    if viewModel.currentStep > 1 {
                        Button(action: { viewModel.previousStep() }) {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .font(Typography.bodyEmphasis)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
                        }
                    }

                    // Next/Done button
                    Button(action: {
                        if viewModel.currentStep == viewModel.totalSteps {
                            viewModel.saveSafetyPlan()
                            dismiss()
                        } else {
                            viewModel.nextStep()
                        }
                    }) {
                        HStack(spacing: Spacing.sm) {
                            Text(viewModel.currentStep == viewModel.totalSteps ? "Complete" : "Next")
                            if viewModel.currentStep < viewModel.totalSteps {
                                Image(systemName: "chevron.right")
                            } else {
                                Image(systemName: "checkmark")
                            }
                        }
                        .font(Typography.bodyEmphasis)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Theme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
                    }
                }

                // Skip for now
                if viewModel.currentStep < viewModel.totalSteps {
                    Button(action: { viewModel.nextStep() }) {
                        Text("Skip for now")
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.vertical, Spacing.lg)
        .background(Theme.background)
    }

    // MARK: - Role Picker Sheet

    private var rolePickerSheet: some View {
        NavigationStack {
            VStack(spacing: Spacing.xl) {
                // Contact preview
                if let contact = pendingContact {
                    VStack(spacing: Spacing.sm) {
                        ZStack {
                            Circle()
                                .fill(Theme.primary.opacity(0.2))
                                .frame(width: 64, height: 64)

                            Text(contact.name.prefix(1).uppercased())
                                .font(Typography.title)
                                .foregroundStyle(Theme.primary)
                        }

                        Text(contact.name)
                            .font(Typography.title3)
                            .foregroundStyle(.white)

                        if let phone = contact.phoneNumber {
                            Text(phone)
                                .font(Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, Spacing.xl)
                }

                // Role selection
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("SELECT RELATIONSHIP")
                        .font(Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .tracking(1)

                    let roles = viewModel.currentStep == 3 || viewModel.currentStep == 4
                        ? SafetyPlanSuggestions.contactRoles
                        : SafetyPlanSuggestions.professionalRoles

                    FlowLayout(spacing: Spacing.sm) {
                        ForEach(roles, id: \.self) { role in
                            Button(action: {
                                selectedRole = role
                                addContactWithRole()
                                showRolePicker = false
                            }) {
                                Text(role)
                                    .font(Typography.body)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, Spacing.lg)
                                    .padding(.vertical, Spacing.md)
                                    .background(Theme.surface)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        // Custom role
                        Button(action: {
                            showRolePicker = false
                            showCustomRoleAlert = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Custom")
                            }
                            .font(Typography.body)
                            .foregroundStyle(Theme.primary)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.md)
                            .background(Theme.primary.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)

                Spacer()
            }
            .background(Theme.background)
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        pendingContact = nil
                        showRolePicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Professional Entry Sheet

    private var professionalEntrySheet: some View {
        NavigationStack {
            Form {
                Section("Contact Information") {
                    TextField("Name", text: $professionalName)
                    TextField("Phone Number", text: $professionalPhone)
                        .keyboardType(.phonePad)
                    TextField("Organization (optional)", text: $professionalOrg)
                }

                Section {
                    Toggle("Emergency Contact", isOn: $isEmergencyContact)
                } footer: {
                    Text("Mark as emergency if this contact should be highlighted during a crisis")
                }
            }
            .navigationTitle("Add Professional")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        resetProfessionalEntry()
                        showProfessionalEntry = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addProfessionalContact()
                        showProfessionalEntry = false
                    }
                    .disabled(professionalName.isEmpty || professionalPhone.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func addContactWithRole() {
        guard let contact = pendingContact else { return }

        let socialContact = SocialContact(
            name: contact.name,
            phoneNumber: contact.phoneNumber,
            relationship: selectedRole.isEmpty ? nil : selectedRole
        )

        switch viewModel.currentStep {
        case 3:
            viewModel.addSocialDistraction(socialContact)
        case 4:
            viewModel.addSupportContact(socialContact)
        default:
            break
        }

        pendingContact = nil
        selectedRole = ""
    }

    private func addProfessionalContact() {
        let contact = ProfessionalContact(
            name: professionalName,
            phoneNumber: professionalPhone,
            organization: professionalOrg.isEmpty ? nil : professionalOrg,
            isEmergency: isEmergencyContact
        )

        viewModel.addProfessionalContact(contact)
        resetProfessionalEntry()
    }

    private func resetProfessionalEntry() {
        professionalName = ""
        professionalPhone = ""
        professionalOrg = ""
        isEmergencyContact = false
    }

    private func callContact(_ contact: SocialContact) {
        PhoneUtilities.call(contact)
    }

    private func callProfessional(_ contact: ProfessionalContact) {
        PhoneUtilities.call(contact)
    }

    private func call988() {
        PhoneUtilities.call988()
    }
}

// MARK: - Flow Layout

/// A layout that arranges views in a flowing horizontal pattern
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return layout(sizes: sizes, containerWidth: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let offsets = layout(sizes: sizes, containerWidth: bounds.width).offsets

        for (subview, offset) in zip(subviews, offsets) {
            subview.place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }

    private func layout(sizes: [CGSize], containerWidth: CGFloat) -> (offsets: [CGPoint], size: CGSize) {
        var offsets: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for size in sizes {
            if currentX + size.width > containerWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            offsets.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxWidth = max(maxWidth, currentX)
        }

        return (offsets, CGSize(width: maxWidth, height: currentY + lineHeight))
    }
}

// MARK: - Preview

#Preview {
    SafetyPlanWizardView(viewModel: SafetyPlanViewModel())
        .preferredColorScheme(.dark)
}
