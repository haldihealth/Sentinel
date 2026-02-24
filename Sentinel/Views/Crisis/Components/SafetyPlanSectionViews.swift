import SwiftUI

// MARK: - Collapsible Safety Plan Card

/// Generic wrapper that makes any safety plan section collapsible.
/// Shows a card header with priority accent bar, section icon, title, item count badge,
/// and a chevron that rotates on expand. Content slides in below when expanded.
struct CollapsibleSafetyPlanCard<Content: View>: View {
    let section: SafetyPlanSection
    let rank: Int
    let itemCount: Int
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    private var accentColor: Color {
        SafetyPlanSection.priorityAccentColor(forRank: rank)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header row — always visible
            Button(action: toggleExpanded) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: section.icon)
                        .foregroundColor(accentColor)
                        .font(.system(size: 14))

                    Text(section.title)
                        .font(Typography.sectionHeader)
                        .foregroundColor(.white)

                    Spacer()

                    // Item count pill
                    Text("\(itemCount)")
                        .font(Typography.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.surfaceHover)
                        .cornerRadius(CornerRadius.small)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
            }
            .buttonStyle(PlainButtonStyle())

            // Content — conditionally shown
            if isExpanded {
                Divider()
                    .background(accentColor.opacity(0.2))

                content()
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
        .overlay(alignment: .leading) {
            // Left accent bar
            UnevenRoundedRectangle(
                topLeadingRadius: CornerRadius.standard,
                bottomLeadingRadius: CornerRadius.standard,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
            .fill(accentColor)
            .frame(width: 3)
        }
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.standard)
                .stroke(accentColor.opacity(0.2), lineWidth: 1)
        )
    }

    private func toggleExpanded() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isExpanded.toggle()
        }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - String List Section (Warning Signs, Coping Strategies, Environment Safety, Reasons for Living)

/// Displays a list of strings with checkbox toggles and haptic feedback.
/// Used for: warningSigns, copingStrategies, environmentSafetySteps, reasonsForLiving
struct StringListSection: View {
    let title: String
    let icon: String
    let items: [String]
    @Binding var completedItems: Set<String>
    var showHeader: Bool = true

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if showHeader {
                    sectionHeader
                }

                ForEach(items, id: \.self) { item in
                    Button(action: { toggle(item) }) {
                        HStack(alignment: .top) {
                            Image(systemName: completedItems.contains(item) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(completedItems.contains(item) ? .green : .red)
                                .font(.system(size: 20))
                            Text(item)
                                .font(Typography.body)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private var sectionHeader: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(.red.opacity(0.8))
                .font(.system(size: 14))
            Text(title)
                .font(Typography.sectionHeader)
                .foregroundColor(.gray)
        }
    }

    private func toggle(_ item: String) {
        if completedItems.contains(item) {
            completedItems.remove(item)
        } else {
            completedItems.insert(item)
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
}

// MARK: - Contact List Section (Social Distractions, Support Contacts)

/// Displays social contacts with name, relationship, and tap-to-call.
/// Used for: socialDistractions, supportContacts
struct ContactListSection: View {
    let title: String
    let icon: String
    let contacts: [SocialContact]
    var showHeader: Bool = true

    var body: some View {
        if !contacts.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if showHeader {
                    sectionHeader
                }

                ForEach(contacts) { contact in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.name)
                                .font(Typography.bodyEmphasis)
                                .foregroundColor(.white)
                            if let relationship = contact.relationship, !relationship.isEmpty {
                                Text(relationship)
                                    .font(Typography.caption)
                                    .foregroundColor(.gray)
                            }
                        }

                        Spacer()

                        if let phone = contact.phoneNumber, !phone.isEmpty {
                            Button(action: { callContact(phone) }) {
                                Image(systemName: "phone.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 18))
                                    .padding(Spacing.sm)
                                    .background(Color.green.opacity(0.15))
                                    .cornerRadius(CornerRadius.small)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var sectionHeader: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(.red.opacity(0.8))
                .font(.system(size: 14))
            Text(title)
                .font(Typography.sectionHeader)
                .foregroundColor(.gray)
        }
    }

    private func callContact(_ phone: String) {
        if let url = URL(string: "tel://\(phone)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Professional Contact Section (Professional Help)

/// Displays professional contacts with organization, phone/text, and emergency badge.
/// Used for: professionalContacts
struct ProfessionalContactSection: View {
    let title: String
    let icon: String
    let contacts: [ProfessionalContact]
    var showHeader: Bool = true

    var body: some View {
        if !contacts.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if showHeader {
                    sectionHeader
                }

                ForEach(contacts) { contact in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: Spacing.xs) {
                                Text(contact.name)
                                    .font(Typography.bodyEmphasis)
                                    .foregroundColor(.white)
                                if contact.isEmergency {
                                    Text("EMERGENCY")
                                        .font(Typography.tiny)
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                            if let org = contact.organization, !org.isEmpty {
                                Text(org)
                                    .font(Typography.caption)
                                    .foregroundColor(.gray)
                            }
                        }

                        Spacer()

                        if contact.isTextOnly {
                            Button(action: { textContact(contact.phoneNumber) }) {
                                Image(systemName: "message.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 18))
                                    .padding(Spacing.sm)
                                    .background(Color.blue.opacity(0.15))
                                    .cornerRadius(CornerRadius.small)
                            }
                        } else {
                            Button(action: { callContact(contact.phoneNumber) }) {
                                Image(systemName: "phone.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 18))
                                    .padding(Spacing.sm)
                                    .background(Color.green.opacity(0.15))
                                    .cornerRadius(CornerRadius.small)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var sectionHeader: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(.red.opacity(0.8))
                .font(.system(size: 14))
            Text(title)
                .font(Typography.sectionHeader)
                .foregroundColor(.gray)
        }
    }

    private func callContact(_ phone: String) {
        if let url = URL(string: "tel://\(phone)") {
            UIApplication.shared.open(url)
        }
    }

    private func textContact(_ phone: String) {
        if let url = URL(string: "sms://\(phone)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Battle Buddy Section (Pinned)

/// Displays the battle buddy contact prominently with call button.
/// Always pinned below the safety plan sections.
struct BattleBuddySection: View {
    let buddy: SocialContact

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "shield.checkered")
                    .foregroundColor(.orange)
                    .font(.system(size: 14))
                Text("BATTLE BUDDY")
                    .font(Typography.sectionHeader)
                    .foregroundColor(.gray)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(buddy.name)
                        .font(Typography.bodyEmphasis)
                        .foregroundColor(.white)
                    if let relationship = buddy.relationship, !relationship.isEmpty {
                        Text(relationship)
                            .font(Typography.caption)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                if let phone = buddy.phoneNumber, !phone.isEmpty {
                    Button(action: { callBuddy(phone) }) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "phone.fill")
                            Text("CALL")
                                .font(Typography.caption)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.orange)
                        .cornerRadius(CornerRadius.small)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(CornerRadius.standard)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.standard)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private func callBuddy(_ phone: String) {
        if let url = URL(string: "tel://\(phone)") {
            UIApplication.shared.open(url)
        }
    }
}
