import Foundation
import ContactsUI
import Combine
import SwiftUI

/// Result from contact picker
struct PickedContact {
    let name: String
    let phoneNumber: String?
    let phoneLabel: String?
}

/// UIKit wrapper for CNContactPickerViewController
/// Provides native iOS contact selection with phone number selection
final class ContactPickerCoordinator: NSObject, CNContactPickerDelegate {
    var onContactPicked: ((PickedContact) -> Void)?
    var onCancel: (() -> Void)?

    /// Called when user selects a specific phone number from a contact
    /// This is triggered when displayedPropertyKeys is set to phone numbers
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
        let contact = contactProperty.contact
        let name = CNContactFormatter.string(from: contact, style: .fullName) ?? "Unknown"

        // Get the selected phone number
        var phoneNumber: String?
        var phoneLabel: String?

        if let phoneValue = contactProperty.value as? CNPhoneNumber {
            phoneNumber = phoneValue.stringValue
            // Get the label (e.g., "mobile", "home", "work")
            if let label = contactProperty.label {
                phoneLabel = CNLabeledValue<NSString>.localizedString(forLabel: label)
            }
        }

        let picked = PickedContact(name: name, phoneNumber: phoneNumber, phoneLabel: phoneLabel)
        onContactPicked?(picked)
    }

    /// Fallback: Called when user selects a contact (without specific property selection)
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        let name = CNContactFormatter.string(from: contact, style: .fullName) ?? "Unknown"

        // Get first phone number if available
        let phoneNumber = contact.phoneNumbers.first?.value.stringValue
        var phoneLabel: String?
        if let label = contact.phoneNumbers.first?.label {
            phoneLabel = CNLabeledValue<NSString>.localizedString(forLabel: label)
        }

        let picked = PickedContact(name: name, phoneNumber: phoneNumber, phoneLabel: phoneLabel)
        onContactPicked?(picked)
    }

    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        onCancel?()
    }
}

/// SwiftUI wrapper for CNContactPickerViewController
/// Configured to allow user to select a specific phone number when contact has multiple
struct ContactPickerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    let onContactPicked: (PickedContact) -> Void

    func makeCoordinator() -> ContactPickerCoordinator {
        ContactPickerCoordinator()
    }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator

        // Configure to show phone number selection
        // This allows user to pick a specific number if contact has multiple
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]

        context.coordinator.onContactPicked = { contact in
            onContactPicked(contact)
            dismiss()
        }

        context.coordinator.onCancel = {
            dismiss()
        }

        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
}

// MARK: - Contact Role Picker

/// A picker for selecting contact role/relationship
struct ContactRolePicker: View {
    @Binding var selectedRole: String
    let roles: [String]
    let onCustomRole: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(roles, id: \.self) { role in
                    RoleChip(
                        title: role,
                        isSelected: selectedRole == role
                    ) {
                        selectedRole = role
                    }
                }

                // Custom role button
                Button(action: onCustomRole) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Custom")
                            .font(Typography.caption)
                    }
                    .foregroundStyle(Theme.primary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(Theme.primary.opacity(0.1))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Theme.primary.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
        }
    }
}

/// Individual role selection chip
struct RoleChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
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
    }
}

// MARK: - Contact Entry Card

/// Card for displaying/editing a contact entry
struct ContactEntryCard: View {
    let contact: SocialContact
    let onDelete: () -> Void
    let onCall: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Theme.primary.opacity(0.2))
                    .frame(width: 44, height: 44)

                Text(contact.name.prefix(1).uppercased())
                    .font(Typography.headline)
                    .foregroundStyle(Theme.primary)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(Typography.bodyEmphasis)
                    .foregroundStyle(.white)

                if let relationship = contact.relationship, !relationship.isEmpty {
                    Text(relationship)
                        .font(Typography.caption)
                        .foregroundStyle(Theme.primary)
                }

                if let phone = contact.phoneNumber, !phone.isEmpty {
                    Text(phone)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Call button
            if contact.phoneNumber != nil {
                Button(action: onCall) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.primary)
                        .frame(width: 36, height: 36)
                        .background(Theme.primary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // Delete button
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
}

/// Card for displaying professional contact
struct ProfessionalContactCard: View {
    let contact: ProfessionalContact
    let onDelete: () -> Void
    let onCall: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(contact.isEmergency ? Theme.emergency.opacity(0.2) : Theme.primary.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: contact.isEmergency ? "staroflife.fill" : "person.badge.shield.checkmark.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(contact.isEmergency ? Theme.emergency : Theme.primary)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(Typography.bodyEmphasis)
                    .foregroundStyle(.white)

                if let org = contact.organization, !org.isEmpty {
                    Text(org)
                        .font(Typography.caption)
                        .foregroundStyle(contact.isEmergency ? Theme.emergency : Theme.primary)
                }

                Text(contact.phoneNumber)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Call/Text button
            Button(action: onCall) {
                Image(systemName: contact.isTextOnly ? "message.fill" : "phone.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(contact.isEmergency ? Theme.emergency : Theme.primary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Delete button (only for non-emergency)
            if !contact.isEmergency {
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
        }
        .padding(Spacing.md)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
    }
}
