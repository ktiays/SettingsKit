import SettingsKit
import SwiftUI

// These fixtures type-check the public builders without relying on internal APIs.
private enum ExampleSection: Hashable {
    case general, appearance
}

private enum ExampleDestination: Hashable {
    case about
}

@MainActor
private let exampleGroups: [SettingsGroup<ExampleSection>] = [
    SettingsGroup("Application", id: "application", sections: [
        SettingsSection("General", id: .general, systemImage: "gearshape"),
        SettingsSection("Appearance", id: .appearance, systemImage: "paintpalette"),
    ]),
]

private struct CustomRow: View {
    var body: some View {
        HStack {
            Image(systemName: "paintpalette")
            VStack(alignment: .leading) {
                Text("Custom Appearance")
                Text("Application-provided content").foregroundStyle(.secondary)
            }
        }
    }
}

private struct SectionsOnlyExample: View {
    var body: some View {
        SettingsView(groups: exampleGroups) { section in
            SwiftUI.Section("Preferences") {
                if section == .appearance {
                    CustomRow()
                }
                ForEach(0..<3) { index in
                    Text("Option \(index)")
                }
            }
        }
    }
}

private struct TypedDestinationsExample: View {
    var body: some View {
        SettingsView(
            groups: exampleGroups,
            destinationTitle: { (_: ExampleDestination) in
                "About"
            }
        ) { section in
            if section == .general {
                NavigationLink("About", value: ExampleDestination.about)
            } else {
                CustomRow()
            }
        } destinationContent: { _ in
            aboutContent
        }
    }

    @ContentBuilder private var aboutContent: some View {
        SwiftUI.Section("Information") {
            LabeledContent("Version", value: "1.0")
            CustomRow()
        }
    }
}

private struct SectionsOnlyWindowExample: Scene {
    var body: some Scene {
        SettingsWindow(groups: exampleGroups) { _ in
            CustomRow()
        }
    }
}

private struct TypedWindowExample: Scene {
    var body: some Scene {
        SettingsWindow(
            groups: exampleGroups,
            destinationTitle: { (_: ExampleDestination) in
                "About"
            }
        ) { _ in
            NavigationLink("About", value: ExampleDestination.about)
        } destinationContent: { _ in
            CustomRow()
        }
    }
}

// MARK: - Persistence

private enum ExampleTheme: String, SettingValue, CaseIterable {
    case light
    case dark
}

private struct ExampleEditorPreferences: CodableSettingValue {
    var showsLineNumbers = true
    var tabWidth = 4
}

extension SettingKey where Value == Bool {
    fileprivate static var exampleChecksForUpdates: Self {
        Self("example.checksForUpdates", defaultValue: true)
    }
}

extension SettingKey where Value == ExampleTheme {
    fileprivate static var exampleTheme: Self {
        Self("example.theme", defaultValue: .light)
    }
}

extension SettingKey where Value == ExampleEditorPreferences {
    fileprivate static var exampleEditor: Self {
        Self("example.editor", defaultValue: ExampleEditorPreferences())
    }
}

@Observable
private final class ExampleSettingsModel {
    @ObservationIgnored private let store: SettingsStore

    init(store: SettingsStore) {
        self.store = store
    }

    var checksForUpdates: Bool {
        get {
            store[.exampleChecksForUpdates]
        }
        set {
            store[.exampleChecksForUpdates] = newValue
        }
    }
}

private struct SettingPropertyExample: View {
    @Setting(.exampleChecksForUpdates) private var checksForUpdates
    @Setting(.exampleTheme) private var theme
    @Setting(.exampleEditor) private var editor

    var body: some View {
        Toggle("Check for updates", isOn: $checksForUpdates)
        Picker("Theme", selection: $theme) {
            ForEach(ExampleTheme.allCases, id: \.self) { theme in
                Text(theme.rawValue).tag(theme)
            }
        }
        Toggle("Show line numbers", isOn: $editor.showsLineNumbers)
        Stepper("Tab width: \(editor.tabWidth)", value: $editor.tabWidth, in: 2...8)
    }
}

private struct BindableStoreExample: View {
    @Bindable var store: SettingsStore
    @Bindable var model: ExampleSettingsModel

    var body: some View {
        Toggle("Check for updates", isOn: $store[.exampleChecksForUpdates])
        Toggle("Check for updates", isOn: $model.checksForUpdates)
        Toggle("Check for updates", isOn: store.binding(for: .exampleChecksForUpdates))
    }
}

private struct SettingsStoreEnvironmentExample: View {
    let store: SettingsStore

    var body: some View {
        SettingPropertyExample()
            .settingsStore(store)
    }
}
