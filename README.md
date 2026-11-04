# SettingsKit

A SwiftUI settings window for macOS, with a grouped Form, a searchable grouped sidebar, and window-scoped navigation history.

Requires Xcode 27 or later with the macOS 27 SDK and Swift 6.4 or later. The minimum deployment target is macOS 26. The package has no external dependencies.

## Create a settings window

Add the `SettingsKit` library product to your application. Define stable identifiers and the sidebar groups, then provide the content for each section:

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

    private var groups: [SettingsGroup<SettingsSectionID>] {
        [
            SettingsGroup("Application", id: "application", sections: [
                SettingsSection("General", id: .general, systemImage: "gearshape"),
                SettingsSection("Appearance", id: .appearance, systemImage: "paintpalette",
                                keywords: ["Theme", "Color Scheme"]),
            ]),
        ]
    }

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

`SettingsWindow` uses a SwiftUI `Window` scene. It installs the Settings command with Command-Comma and opens the same window when invoked again. The default scene identifier is `"settings"`; pass `id:` to change it and use `@Environment(\.openWindow)` to open that scene programmatically. Launch visibility, placement, and other scene behavior remain configurable through SwiftUI scene modifiers.

## Customize Form content

SettingsKit uses SwiftUI's native `@ContentBuilder`, provided by the Xcode 27 SDK. It supports conditionals, switches, loops, standard controls, and arbitrary custom SwiftUI views. Both top-level and nested pages use the system builder directly.

Provide the **contents** of a Form. SettingsKit supplies the grouped Form, scrolling, navigation title, and history controls for every page. For example:

```swift
@ContentBuilder
var appearanceContent: some View {
    Section {
        CustomAppearancePicker(selection: $appearance)
            .padding(.vertical, 8)
        Toggle("Tint with theme", isOn: $tintsWithTheme)
    } header: {
        Text("Appearance")
    } footer: {
        Text("Choose how the application appears.")
    }
}
```

The runnable example includes a custom row with appearance thumbnails, selection rings, two groups of choices, and an adaptive horizontal or vertical layout. It also includes toggles, a segmented picker, a slider, and a live preview in standard Form sections.

Keep values that must survive page navigation in application-owned state above the page views, or persist them with a settings store as described in [Persist settings](#persist-settings).

## Navigate between pages

Define a `Hashable` destination type and supply `destinationTitle` and `destinationContent`. Standard value-based `NavigationLink` instances participate in global history:

```swift
enum SettingsPage: Hashable {
    case about
    case storage

    var title: String {
        switch self {
        case .about:
            "About"
        case .storage:
            "Storage"
        }
    }
}

// Inside an App's scene body, using the groups from the first example:
SettingsWindow(
    groups: groups,
    destinationTitle: { (page: SettingsPage) in
        page.title
    }
) { section in
    switch section {
    case .general:
        Section {
            NavigationLink("About", value: SettingsPage.about)
        }
    case .appearance:
        appearanceContent
    }
} destinationContent: { page in
    switch page {
    case .about:
        Section("Information") {
            LabeledContent("Version", value: "1.0")
            NavigationLink("Storage", value: SettingsPage.storage)
        }
    case .storage:
        Section("Storage") {
            LabeledContent("Available", value: "384 GB")
        }
    }
}
```

Read the window's navigation state from a descendant view for programmatic navigation:

```swift
@Environment(SettingsNavigation<SettingsSectionID, SettingsPage>.self)
private var navigation

// Select a section, push a page, or navigate to a complete location.
navigation.select(.appearance)
navigation.push(.about)
navigation.navigate(to: SettingsLocation(section: .general, path: [.about, .storage]))
```

Back and Forward restore both the selected section and its complete detail path. New navigation discards forward history. Reselecting the current section preserves its path, and repeated navigation to the same location adds no entry. Navigation to an unavailable section is ignored.

The toolbar uses the system navigation control group. Click an arrow to navigate one entry; press and hold it to choose a history entry. Command-Left Bracket and Command-Right Bracket navigate the focused settings window. Each `SettingsView` owns an independent history.

Use the configured destination type for value-based links. A view-based `NavigationLink(destination:)`, or a separate navigation stack inside custom content, has its own navigation behavior and does not record typed destinations in this history.

## Persist settings

SettingsKit separates *what* is persisted from *where* it is persisted:

- `SettingValue` describes types eligible for persistence. Each value converts to and from a `SettingRepresentation`: a Boolean, integer, double, string, or data value that every backend can store.
- `SettingKey<Value>` names a setting and provides its default value.
- `SettingsStorage` is the backend protocol. SettingsKit includes `UserDefaultsSettingsStorage`, `SQLiteSettingsStorage`, and `InMemorySettingsStorage`.
- `SettingsStore` is an observable, type-safe interface over a backend. Observation is tracked per key, so a view updates only when a setting it reads changes.

### Define values and keys

`Bool`, `Int`, `Double`, `Float`, `String`, `Data`, `Date`, `URL`, and `Optional` conform to `SettingValue`, as do arrays, sets, and dictionaries of codable setting values. An enumeration with a raw value only needs to declare the conformance. A codable model conforms to `CodableSettingValue` and is persisted as JSON under a single key:

```swift
enum ColorSchemePreference: String, SettingValue {
    case automatic, light, dark
}

struct EditorPreferences: CodableSettingValue {
    var showsLineNumbers = true
    var tabWidth = 4
}

extension SettingKey where Value == ColorSchemePreference {
    static var colorScheme: Self {
        Self("appearance.colorScheme", defaultValue: .automatic)
    }
}

extension SettingKey where Value == EditorPreferences {
    static var editor: Self {
        Self("editor.preferences", defaultValue: EditorPreferences())
    }
}

extension SettingKey where Value == String? {
    static var fontName: Self {
        Self("editor.fontName")
    }
}
```

A missing value, or one that is no longer valid for its type, reads as the key's default value. Assigning `nil` to an optional setting removes the persisted value.

### Bind settings to views

The `Setting` property wrapper reads the store from the environment. Its projected value is a binding, and dynamic member lookup binds individual properties of a codable model:

```swift
struct EditorSettingsContent: View {
    @Setting(.colorScheme) private var colorScheme
    @Setting(.editor) private var editor

    var body: some View {
        Picker("Appearance", selection: $colorScheme) {
            Text("Automatic").tag(ColorSchemePreference.automatic)
            Text("Light").tag(ColorSchemePreference.light)
            Text("Dark").tag(ColorSchemePreference.dark)
        }
        Toggle("Show line numbers", isOn: $editor.showsLineNumbers)
        Stepper("Tab width: \(editor.tabWidth)", value: $editor.tabWidth, in: 2...8)
    }
}
```

The environment store defaults to `SettingsStore.standard`, which uses `UserDefaults.standard`. Supply another store to a scene or view hierarchy:

```swift
let store = SettingsStore(storage: try SQLiteSettingsStorage(url: databaseURL))

SettingsWindow(groups: groups) { section in
    // ...
}
.settingsStore(store)
```

A store can also be bound directly with `@Bindable var store: SettingsStore` and `$store[.colorScheme]`, or with `store.binding(for: .colorScheme)`.

An observable model can expose settings as computed properties. Views that use `@Bindable` with the model observe the underlying store:

```swift
@Observable
final class EditorSettings {
    @ObservationIgnored private let store: SettingsStore

    init(store: SettingsStore) {
        self.store = store
    }

    var colorScheme: ColorSchemePreference {
        get {
            store[.colorScheme]
        }
        set {
            store[.colorScheme] = newValue
        }
    }
}
```

The key subscript logs failures and falls back to default values. Use `value(for:)`, `setValue(_:for:)`, and `resetValue(for:)` to handle storage errors.

### Choose a backend

- `UserDefaultsSettingsStorage(defaults:keyPrefix:)` maps representations to property list types. It observes changes made through any `UserDefaults` instance in the process, but not changes made by other processes.
- `SQLiteSettingsStorage(location:tableName:)` stores each setting as a typed row in a key-value table, using write-ahead logging. Pass `.file(url)` or `.inMemory`. Share one instance between stores so that they observe each other's changes.
- `InMemorySettingsStorage` is suitable for previews and tests.

### Implement a custom backend

Conform a type to `SettingsStorage` and implement `value(forKey:)`, `setValue(_:forKey:)`, and `removeValue(forKey:)`. Implementations must be thread-safe. A store caches values it reads, so report changes made outside the store by implementing `observeChanges(_:)`. `SettingsStorageChangeNotifier` manages the handlers:

```swift
final class FileSettingsStorage: SettingsStorage {
    private let values: Mutex<[String: SettingRepresentation]>
    private let notifier = SettingsStorageChangeNotifier()

    // ...

    func setValue(_ value: SettingRepresentation, forKey key: String) throws {
        values.withLock {
            $0[key] = value
        }
        try save()
        notifier.notifyObservers(of: .keys([key]))
    }

    func observeChanges(
        _ handler: @escaping @Sendable (SettingsStorageChange) -> Void
    ) -> SettingsStorageObservation {
        notifier.observeChanges(handler)
    }
}
```

Report `.all` when the backend cannot identify the changed keys. Call the notifier outside of any lock that the backend's other methods acquire.

## Configure the sidebar and scrolling

- `SettingsGroup` supports titled, untitled, collapsible, and initially collapsed groups. Empty groups are omitted. Selecting a section through navigation expands its group.
- Search matches group titles, section titles, and optional section keywords. Matching groups expand temporarily while searching, preserving the user's expansion choices when search is cleared.
- Group identifiers must be unique; section identifiers must be unique across the entire sidebar. Use stable identifiers rather than display titles. Titles and search keywords are localized strings supplied by the application.
- Updating the groups preserves navigation entries for available sections. Removing the current section restores the nearest earlier available entry, then the first remaining entry or first available section. An empty catalog clears history and displays an empty state.
- `sidebarEdgeStyle` and `detailEdgeStyle` independently configure the top scroll edge effect using SwiftUI's `ScrollEdgeEffectStyle`. Both default to `.automatic`; `.soft` and `.hard` are available. Native List, Form, search, and toolbar layout provide the system scrolling behavior.

The window starts at 940 × 700 points and supports resizing down to 760 × 540 points. Custom rows should adapt to the available detail width, for example with `ViewThatFits`.

## Use an existing scene

Place `SettingsView` inside an existing `Window`, `WindowGroup`, or SwiftUI `Settings` scene. Its content and destination initializers match `SettingsWindow`:

```swift
Settings {
    SettingsView(groups: groups) { section in
        // Return this section's Form rows and sections.
        Text(String(describing: section))
    }
}
.commands {
    SettingsNavigationCommands()
}
```

`SettingsNavigationCommands` installs Back and Forward for the focused settings view. `SettingsWindow` already includes these commands and its Settings command; install the navigation commands once when using `SettingsView` directly.

## Run the example and tests

From the repository root:

```sh
./script/build_and_run.sh
swift test
```

The Run action in Codex invokes the same script. It builds the independent example package against the local library, stages `dist/SettingsKitExample.app`, and launches it. Optional modes are `--debug`, `--logs`, `--telemetry`, and `--verify`.

The example's **Example** menu opens an additional settings window and offers compact and default window sizes. Use it to explore independent histories, sidebar groups and search, nested pages, and custom Form content. The main window persists the appearance settings and the automatic update preference in user defaults; the additional window persists them in an SQLite database in Application Support. Other sample values are in memory.

Tests cover navigation restoration, branching, history jumps, independent windows, stale path updates, catalog changes, sidebar search, setting value conversion, per-key observation, and the UserDefaults and SQLite backends. Public API fixtures also compile the section-only and typed-destination builders and the persistence bindings.

Relevant Apple documentation: [ContentBuilder migration](https://developer.apple.com/documentation/technotes/tn3211-resolving-swiftui-source-incompatibilities-for-state-and-contentbuilder), [Window](https://developer.apple.com/documentation/swiftui/window), [NavigationStack](https://developer.apple.com/documentation/swiftui/navigationstack), [navigation control group style](https://developer.apple.com/documentation/swiftui/controlgroupstyle/navigation), and [ScrollEdgeEffectStyle](https://developer.apple.com/documentation/swiftui/scrolledgeeffectstyle).
