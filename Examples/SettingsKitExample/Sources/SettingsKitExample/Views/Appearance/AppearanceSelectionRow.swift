import SettingsKit
import SwiftUI

struct AppearanceSelectionRow: View {
    @Bindable var settings: AppearanceSettingsState
    let accent: Color

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 20) {
                colorSchemeChoices
                Divider().frame(height: 132)
                interfaceStyleChoices
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading, spacing: 20) {
                colorSchemeChoices
                Divider()
                interfaceStyleChoices
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var colorSchemeChoices: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Color scheme")
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ForEach(ColorSchemeOption.allCases) { option in
                    AppearanceOptionButton(
                        title: option.title,
                        isSelected: settings.colorScheme == option,
                        accent: accent,
                        identifier: "appearance.colorScheme.\(option.rawValue)"
                    ) {
                        settings.colorScheme = option
                    } preview: {
                        ColorSchemeThumbnail(option: option)
                    }
                }
            }
        }
    }

    private var interfaceStyleChoices: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Interface style")
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ForEach(InterfaceStyleOption.allCases) { option in
                    AppearanceOptionButton(
                        title: option.title,
                        isSelected: settings.interfaceStyle == option,
                        accent: accent,
                        identifier: "appearance.interfaceStyle.\(option.rawValue)"
                    ) {
                        settings.interfaceStyle = option
                    } preview: {
                        InterfaceStyleThumbnail(option: option)
                    }
                }
            }
        }
    }
}

private struct AppearanceOptionButton<Preview: View>: View {
    let title: String
    let isSelected: Bool
    let accent: Color
    let identifier: String
    let action: () -> Void
    @ContentBuilder let preview: () -> Preview

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                preview()
                    .frame(width: 92, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(4)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(isSelected ? accent : .clear, lineWidth: 3)
                    }
                Text(title)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
            }
            .frame(width: 100)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}
