import SwiftUI

struct AppearanceSettingsContent: View {
    @Bindable var settings: AppearanceSettingsState

    private var accent: Color {
        settings.tintsWithTheme ? Color(red: 0.0, green: 0.78, blue: 0.65) : .accentColor
    }

    var body: some View {
        Group {
            Section {
                AppearanceSelectionRow(settings: settings, accent: accent)
                Toggle("Tint with theme", isOn: $settings.tintsWithTheme)
                    .accessibilityIdentifier("appearance.tintWithTheme")
                Toggle("Use glass for panes", isOn: $settings.usesGlassForPanes)
                    .accessibilityIdentifier("appearance.glassPanes")
            } header: {
                Text("Appearance")
            } footer: {
                Label(
                    settings.interfaceStyle == .glass
                        ? "Pane background colors ignore the theme when Glass is active."
                        : "Pane backgrounds use the selected color scheme.",
                    systemImage: "info.circle"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            Section("Tabs") {
                Picker("Tab style", selection: $settings.tabStyle) {
                    ForEach(TabStyleOption.allCases) { style in
                        Label(style.title, systemImage: style.symbolName).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("appearance.tabStyle")

                LabeledContent("Show tab icons") {
                    HStack(spacing: 12) {
                        Slider(value: $settings.tabIconCount, in: 0...3, step: 1)
                            .frame(minWidth: 100, maxWidth: 230)
                            .accessibilityLabel("Number of tab icons")
                            .accessibilityIdentifier("appearance.tabIconCount")
                        Text(Int(settings.tabIconCount), format: .number)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle("Always show tab bar", isOn: $settings.alwaysShowsTabBar)
            }

            Section("Preview") {
                AppearanceThemePreview(settings: settings, accent: accent)
                    .frame(height: 190)
                    .padding(.vertical, 8)
            }

            Section("Text") {
                LabeledContent("Text size") {
                    HStack(spacing: 12) {
                        Slider(value: $settings.textSize, in: 11...18, step: 1)
                            .frame(minWidth: 100, maxWidth: 230)
                            .accessibilityLabel("Preview text size")
                        Text("\(Int(settings.textSize)) pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Font", value: "System")
            }
        }
        .tint(accent)
        .preferredColorScheme(settings.colorScheme.preferredColorScheme)
    }
}
