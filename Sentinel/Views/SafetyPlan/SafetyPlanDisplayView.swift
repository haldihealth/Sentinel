import SwiftUI

/// Dashboard view for viewing a completed Safety Plan
/// Designed for quick access during crisis - all sections visible at glance
struct SafetyPlanDisplayView: View {
    @ObservedObject var viewModel: SafetyPlanViewModel
    @State private var showEditWizard = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Quick actions header
                quickActionsView

                // Plan sections
                if let plan = viewModel.safetyPlan {
                    // Warning Signs
                    planSection(
                        title: "Warning Signs",
                        icon: "exclamationmark.triangle.fill",
                        iconColor: Theme.riskModerate,
                        items: plan.warningSigns
                    )

                    // Coping Strategies
                    planSection(
                        title: "Coping Strategies",
                        icon: "brain.head.profile",
                        iconColor: Theme.primary,
                        items: plan.copingStrategies
                    )

                    // Social Distractions
                    contactSection(
                        title: "Social Distractions",
                        icon: "person.2.fill",
                        iconColor: .blue,
                        contacts: plan.socialDistractions
                    )

                    // Support Contacts
                    contactSection(
                        title: "Support Contacts",
                        icon: "hand.raised.fill",
                        iconColor: .green,
                        contacts: plan.supportContacts
                    )

                    // Professional Help
                    professionalSection(
                        title: "Professional Help",
                        icon: "staroflife.fill",
                        iconColor: Theme.emergency,
                        contacts: plan.professionalContacts
                    )

                    // Environment Safety
                    planSection(
                        title: "Environment Safety",
                        icon: "shield.checkered",
                        iconColor: .orange,
                        items: plan.environmentSafetySteps
                    )

                    // Reasons for Living
                    planSection(
                        title: "Reasons for Living",
                        icon: "heart.fill",
                        iconColor: .pink,
                        items: plan.reasonsForLiving
                    )
                }

                // Edit button
                editButton

                // Last updated
                if let plan = viewModel.safetyPlan {
                    Text("Last updated: \(plan.lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                        .font(Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, Spacing.lg)
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xxxl)
        }
        .background(Theme.background)
        .fullScreenCover(isPresented: $showEditWizard) {
            SafetyPlanWizardView(viewModel: viewModel, isEditing: true)
        }
    }

    // MARK: - Quick Actions

    @ViewBuilder
    private var quickActionsView: some View {
        // Call Battle Buddy (only shown if set)
        if let buddy = viewModel.safetyPlan?.battleBuddy {
            Button(action: { callContact(buddy) }) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 18))

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Call")
                            .font(Typography.bodyEmphasis)
                        Text(buddy.name)
                            .font(Typography.captionSmall)
                            .opacity(0.8)
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
            }
        }
    }

    // MARK: - Plan Section (String items)

    private func planSection(
        title: String,
        icon: String,
        iconColor: Color,
        items: [String]
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

            // Items (always visible)
            if items.isEmpty {
                Text("No items added")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            Circle()
                                .fill(iconColor)
                                .frame(width: 6, height: 6)
                                .padding(.top, 7)

                            Text(item)
                                .font(Typography.body)
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
    }

    // MARK: - Contact Section

    private func contactSection(
        title: String,
        icon: String,
        iconColor: Color,
        contacts: [SocialContact]
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

            // Contacts (always visible)
            if contacts.isEmpty {
                Text("No contacts added")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: Spacing.sm) {
                    ForEach(contacts) { contact in
                        HStack(spacing: Spacing.md) {
                            // Avatar
                            ZStack {
                                Circle()
                                    .fill(iconColor.opacity(0.2))
                                    .frame(width: 36, height: 36)

                                Text(contact.name.prefix(1).uppercased())
                                    .font(Typography.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(iconColor)
                            }

                            // Info
                            VStack(alignment: .leading, spacing: 0) {
                                Text(contact.name)
                                    .font(Typography.body)
                                    .foregroundStyle(.white)

                                if let role = contact.relationship {
                                    Text(role)
                                        .font(Typography.captionSmall)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            // Call button
                            if contact.phoneNumber != nil {
                                Button(action: { callContact(contact) }) {
                                    Image(systemName: "phone.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white)
                                        .frame(width: 32, height: 32)
                                        .background(iconColor)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
    }

    // MARK: - Professional Contact Section

    private func professionalSection(
        title: String,
        icon: String,
        iconColor: Color,
        contacts: [ProfessionalContact]
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

            // Professional contacts (always visible)
            VStack(spacing: Spacing.sm) {
                // Default crisis resources first
                ForEach(SafetyPlanSuggestions.defaultProfessionalContacts) { contact in
                    professionalContactRow(contact: contact)
                }

                // User's professional contacts
                ForEach(contacts) { contact in
                    professionalContactRow(contact: contact)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
    }

    private func professionalContactRow(contact: ProfessionalContact) -> some View {
        HStack(spacing: Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(contact.isEmergency ? Theme.emergency.opacity(0.2) : Theme.primary.opacity(0.2))
                    .frame(width: 36, height: 36)

                Image(systemName: contact.isEmergency ? "staroflife.fill" : "person.badge.shield.checkmark.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(contact.isEmergency ? Theme.emergency : Theme.primary)
            }

            // Info
            VStack(alignment: .leading, spacing: 0) {
                Text(contact.name)
                    .font(Typography.body)
                    .foregroundStyle(.white)

                if let org = contact.organization {
                    Text(org)
                        .font(Typography.captionSmall)
                        .foregroundStyle(contact.isEmergency ? Theme.emergency : .secondary)
                }
            }

            Spacer()

            // Call/Text button
            Button(action: { callProfessional(contact) }) {
                Image(systemName: contact.isTextOnly ? "message.fill" : "phone.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(contact.isEmergency ? Theme.emergency : Theme.primary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.sm)
    }

    // MARK: - Edit Button

    private var editButton: some View {
        Button(action: { showEditWizard = true }) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "pencil")
                    .font(.system(size: 16))
                Text("Edit Safety Plan")
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
    }

    // MARK: - Actions

    private func callContact(_ contact: SocialContact) {
        PhoneUtilities.call(contact)
    }

    private func callProfessional(_ contact: ProfessionalContact) {
        PhoneUtilities.call(contact)
    }
}

// MARK: - Preview

#Preview {
    // Create a sample plan for preview
    let viewModel = SafetyPlanViewModel()
    viewModel.safetyPlan = SafetyPlan(
        warningSigns: ["Feeling hopeless", "Isolating from others", "Trouble sleeping"],
        copingStrategies: ["Go for a walk", "Listen to music", "Deep breathing"],
        socialDistractions: [
            SocialContact(name: "Coffee Shop", phoneNumber: nil, relationship: "Place"),
            SocialContact(name: "John Smith", phoneNumber: "555-1234", relationship: "Friend")
        ],
        supportContacts: [
            SocialContact(name: "Jane Doe", phoneNumber: "555-5678", relationship: "Spouse"),
            SocialContact(name: "Mike Johnson", phoneNumber: "555-9012", relationship: "Battle Buddy")
        ],
        professionalContacts: [
            ProfessionalContact(name: "Dr. Williams", phoneNumber: "555-3456", organization: "VA Mental Health", isEmergency: false)
        ],
        environmentSafetySteps: ["Lock up firearms at friend's house", "Store medications with spouse"],
        reasonsForLiving: ["My children", "My spouse", "Future goals"]
    )

    return SafetyPlanDisplayView(viewModel: viewModel)
        .preferredColorScheme(.dark)
}
