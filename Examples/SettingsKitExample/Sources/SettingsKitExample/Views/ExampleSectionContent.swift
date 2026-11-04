import SettingsKit
import SwiftUI

struct ExampleSectionContent: View {
    let section: ExampleSection
    @Bindable var appearance: AppearanceSettingsState
    @State private var isWiFiEnabled = true
    @Setting(.checksForUpdatesAutomatically) private var isAutomaticUpdateEnabled

    @ContentBuilder var body: some View {
        switch section {
        case .general:
            Section {
                NavigationLink("About", value: ExampleDestination.about)
                    .accessibilityIdentifier("example.about")
                NavigationLink("Storage", value: ExampleDestination.storage)
            }
            Section("Software Update") {
                Toggle("Check for updates automatically", isOn: $isAutomaticUpdateEnabled)
            }
        case .appearance:
            AppearanceSettingsContent(settings: appearance)
        case .wiFi:
            Section {
                Toggle("Wi-Fi", isOn: $isWiFiEnabled)
                if isWiFiEnabled {
                    LabeledContent("Example Network", value: "Connected")
                    NavigationLink("Details…", value: ExampleDestination.networkDetails)
                }
            } footer: {
                Text("This section uses in-memory sample data.")
            }
            Section("Other Networks") {
                ForEach(["Studio", "Guest", "Office"], id: \.self) { name in
                    LabeledContent(name) {
                        Image(systemName: "lock.fill")
                    }
                }
            }
        default:
            Section("Information") {
                LabeledContent("Section", value: title)
                Text("Application-provided Form content appears here.")
                    .foregroundStyle(.secondary)
            }
            Section("Example Options") {
                ForEach(1...12, id: \.self) { index in
                    LabeledContent("Option \(index)", value: "Default")
                }
            }
        }
    }

    private var title: String {
        ExampleSection.groups.flatMap(\.sections).first {
            $0.id == section
        }?.title ?? "Settings"
    }
}

struct ExampleDestinationContent: View {
    let destination: ExampleDestination
    @Environment(SettingsNavigation<ExampleSection, ExampleDestination>.self) private var navigation

    @ContentBuilder var body: some View {
        switch destination {
        case .about:
            Section("Application") {
                LabeledContent("Name", value: "SettingsKit Example")
                LabeledContent("Version", value: "1.0")
                NavigationLink("Storage", value: ExampleDestination.storage)
                    .accessibilityIdentifier("example.storage")
            }
            Section {
                Button("Open Wi-Fi Settings") {
                    navigation.select(.wiFi)
                }
                .accessibilityIdentifier("example.openWiFi")
            }
        case .storage:
            Section("Storage") {
                LabeledContent("Used", value: "128 GB")
                LabeledContent("Available", value: "384 GB")
                ProgressView(value: 0.25)
                    .accessibilityLabel("Storage used")
            }
            Section {
                Button("Open Wi-Fi Settings") {
                    navigation.select(.wiFi)
                }
                .accessibilityIdentifier("example.openWiFi")
                Button("Open Appearance Settings") {
                    navigation.select(.appearance)
                }
            }
        case .networkDetails:
            Section("Connection") {
                LabeledContent("Network", value: "Example Network")
                LabeledContent("Security", value: "WPA3 Personal")
            }
        }
    }
}
