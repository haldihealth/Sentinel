import SwiftUI

// MARK: - Tactical Section

/// A styled section container with military-inspired header
struct TacticalSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section header
            Text(title)
                .font(Typography.captionSmall)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .tracking(1.5)

            // Content container
            VStack(spacing: 0) {
                content
            }
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
        }
    }
}

// MARK: - Info Row

/// Displays a label-value pair
struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .white

    var body: some View {
        HStack {
            Text(label)
                .font(Typography.body)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(Typography.bodyEmphasis)
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - Status Row

/// Displays a permission/sensor status with icon
struct StatusRow: View {
    let title: String
    let status: PermissionStatus
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.body)
                    .foregroundStyle(.white)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: Spacing.xs) {
                Text(status.displayText)
                    .font(Typography.caption)
                    .foregroundStyle(status.color)

                Image(systemName: status.iconName)
                    .font(.system(size: 14))
                    .foregroundStyle(status.color)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - Toggle Row

/// A styled toggle with optional subtitle
struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.body)
                    .foregroundStyle(.white)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Theme.primary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - Action Row

/// A tappable row for navigation or actions
struct ActionRow: View {
    let title: String
    var icon: String? = nil
    var iconColor: Color = Theme.primary
    var showChevron: Bool = true
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: Spacing.md) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(iconColor)
                        .frame(width: 24)
                }

                Text(title)
                    .font(Typography.body)
                    .foregroundStyle(.white)

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Editable Row

/// A row with an inline text field for editing
struct EditableRow: View {
    let label: String
    @Binding var value: String
    var placeholder: String = ""

    var body: some View {
        HStack {
            Text(label)
                .font(Typography.body)
                .foregroundStyle(.secondary)

            Spacer()

            TextField(placeholder, text: $value)
                .font(Typography.body)
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - Picker Row

/// A row with a menu picker
struct PickerRow<T: Hashable>: View where T: CustomStringConvertible {
    let label: String
    @Binding var selection: T
    let options: [T]

    var body: some View {
        HStack {
            Text(label)
                .font(Typography.body)
                .foregroundStyle(.secondary)

            Spacer()

            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option.description) {
                        selection = option
                    }
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Text(selection.description)
                        .font(Typography.body)
                        .foregroundStyle(.white)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - Section Divider

/// A subtle divider between rows
struct SectionDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.surfaceHover)
            .frame(height: 1)
            .padding(.leading, Spacing.md)
    }
}

// MARK: - Destructive Button Row

/// A destructive action button styled as a row
struct DestructiveButtonRow: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                }

                Text(title)
                    .font(Typography.bodyEmphasis)
            }
            .foregroundStyle(Theme.emergency)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(Theme.emergency.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - Transparency Seal

/// Footer component showing privacy/transparency info
struct TransparencySeal: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            // Privacy badge
            HStack(spacing: Spacing.sm) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 14))

                Text("ZERO EXTERNAL TRANSMISSION")
                    .font(Typography.captionSmall)
                    .fontWeight(.bold)
                    .tracking(1)

                Spacer()

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14))
            }
            .foregroundStyle(Theme.primary)
            .padding(Spacing.md)
            .background(Theme.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

            // Info text
            Text("All analysis performed locally on your device's Neural Engine. Your data never leaves this device.")
                .font(Typography.captionSmall)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Previews

#Preview("Tactical Section") {
    ScrollView {
        VStack(spacing: Spacing.lg) {
            TacticalSection(title: "I. OPSEC") {
                ToggleRow(title: "Local-Only Mode", isOn: .constant(true), subtitle: "Disables iCloud backups")
                SectionDivider()
                ToggleRow(title: "Biometric Shield", isOn: .constant(true))
                SectionDivider()
                ActionRow(title: "Panic Wipe Setup", icon: "bolt.shield.fill", iconColor: .orange)
            }

            TacticalSection(title: "II. SENSORS") {
                StatusRow(title: "Biometric Feed (HRV/Sleep)", status: .authorized)
                SectionDivider()
                StatusRow(title: "Clinical Feed (VA Records)", status: .disconnected)
                SectionDivider()
                StatusRow(title: "Hardware (Camera/Mic)", status: .authorized)
            }

            TransparencySeal()
        }
        .padding()
    }
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
