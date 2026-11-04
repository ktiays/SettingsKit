# SettingsKit

A SwiftUI settings interface for macOS with a searchable sidebar, navigation history, and type-safe persistence.

Requires **macOS 26+**, **Swift 6.4+**, and **Xcode 27+** with the macOS 27 SDK. No external dependencies.

## Installation

Add [SettingsKit](https://github.com/ktiays/SettingsKit) through Xcode's **File → Add Package Dependencies**, then add the `SettingsKit` product to your app target.

## Usage

Define your sidebar sections and provide their content:

```swift
import SettingsKit
import SwiftUI

enum SettingsSectionID: Hashable {
    case general
    case appearance
}

@main
struct ExampleApp: App {
    @State private var followsSystemAppearance = true

    private let groups: [SettingsGroup<SettingsSectionID>] = [
        SettingsGroup("Application", id: "application", sections: [
            SettingsSection("General", id: .general, systemImage: "gearshape"),
            SettingsSection("Appearance", id: .appearance, systemImage: "paintpalette"),
        ]),
    ]

    var body: some Scene {
        SettingsWindow(groups: groups) { section in
            switch section {
            case .general:
                Section("Application") {
                    LabeledContent("Version", value: "1.0")
                }
            case .appearance:
                Section("Appearance") {
                    Toggle("Follow system appearance", isOn: $followsSystemAppearance)
                }
            }
        }
    }
}
```

SettingsKit supplies the grouped `Form`, sidebar search, and Back and Forward controls. Content can include standard controls and custom SwiftUI views. `SettingsWindow` also installs the Settings command (⌘,).

For nested pages, use value-based `NavigationLink`s with the `destinationTitle` and `destinationContent` parameters. Each window maintains its own navigation history.

To embed settings in an existing scene, use `SettingsView` and install `SettingsNavigationCommands` with the scene's `.commands` modifier.

## Persistence

Define a typed key and use `@Setting` to bind a control to its stored value:

```swift
extension SettingKey where Value == Bool {
    static var checksForUpdates: Self {
        Self("general.checksForUpdates", defaultValue: true)
    }
}

struct GeneralSettingsContent: View {
    @Setting(.checksForUpdates) private var checksForUpdates

    var body: some View {
        Toggle("Check for updates", isOn: $checksForUpdates)
    }
}
```

Settings use `UserDefaults.standard` by default. To use SQLite, in-memory storage, or a custom `SettingsStorage` implementation, pass a `SettingsStore` through `.settingsStore(_:)` on a scene or view.

Raw-value enumerations can conform to `SettingValue`; custom Codable models can conform to `CodableSettingValue`.

## Example

The [example app](Examples/SettingsKitExample) demonstrates nested navigation, custom appearance controls, and UserDefaults and SQLite storage. Run it from a checkout:

```sh
./script/build_and_run.sh
```
