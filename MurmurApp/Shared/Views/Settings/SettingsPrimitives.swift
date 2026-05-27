import SwiftUI

/// Title + optional subtitle at the top of each settings section.
struct PageHeader: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Subsection header inside a settings page.
struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// `Label: value` row, optionally with a colored status pill on the right.
struct StatusRow: View {
    let label: String
    let value: String
    let color: Color?

    init(_ label: String, value: String, color: Color? = nil) {
        self.label = label
        self.value = value
        self.color = color
    }

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(color ?? .primary)
        }
    }
}

/// A labeled text input used inside `SettingsCard` rows.
struct SettingsInput: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var accessibilityIdentifier: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .optionalAccessibilityIdentifier(accessibilityIdentifier)
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .optionalAccessibilityIdentifier(accessibilityIdentifier)
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func optionalAccessibilityIdentifier(_ identifier: String?) -> some View {
        if let identifier {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}

/// Grouped card used for related rows in a section.
struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            content
        }
        .padding(Spacing.m)
        .background(Color.settingsSectionBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.m))
    }
}
