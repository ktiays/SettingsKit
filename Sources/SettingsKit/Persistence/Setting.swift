import SwiftUI

/// A property wrapper that reads and writes a persisted setting from a view.
///
/// The wrapper uses the settings store from the environment unless you supply
/// one explicitly. The view updates when the setting changes, including
/// changes made through another view, model, or store that shares the backend.
///
/// ```swift
/// struct EditorSettingsContent: View {
///     @Setting(.showsLineNumbers) private var showsLineNumbers
///     @Setting(.editorPreferences) private var editor
///
///     var body: some View {
///         Toggle("Show line numbers", isOn: $showsLineNumbers)
///         Stepper("Tab width: \(editor.tabWidth)", value: $editor.tabWidth, in: 2...8)
///     }
/// }
/// ```
///
/// Provide a store to a view hierarchy with ``SwiftUI/View/settingsStore(_:)``.
@MainActor
@propertyWrapper
public struct Setting<Value: SettingValue>: DynamicProperty {
    @Environment(\.settingsStore) private var environmentStore

    private let key: SettingKey<Value>
    private let explicitStore: SettingsStore?

    /// Creates a property that reads and writes a setting.
    ///
    /// - Parameters:
    ///   - key: The setting key.
    ///   - store: The store to use, or `nil` to use the store from the environment.
    public init(_ key: SettingKey<Value>, store: SettingsStore? = nil) {
        self.key = key
        self.explicitStore = store
    }

    /// The store that this property reads and writes.
    public var store: SettingsStore {
        explicitStore ?? environmentStore
    }

    /// The current value of the setting.
    public var wrappedValue: Value {
        get {
            store[key]
        }
        nonmutating set {
            store[key] = newValue
        }
    }

    /// A binding to the setting's value.
    ///
    /// Use dynamic member lookup on the binding to bind individual properties
    /// of a ``CodableSettingValue`` model.
    public var projectedValue: Binding<Value> {
        store.binding(for: key)
    }
}

extension EnvironmentValues {
    /// The settings store that ``Setting`` properties use by default.
    ///
    /// The default value is ``SettingsStore/standard``.
    @Entry public var settingsStore: SettingsStore = .standard
}

extension View {
    /// Sets the settings store for ``Setting`` properties in this view hierarchy.
    ///
    /// - Parameter store: The store to use.
    /// - Returns: A view that uses the specified settings store.
    public func settingsStore(_ store: SettingsStore) -> some View {
        environment(\.settingsStore, store)
    }
}

extension Scene {
    /// Sets the settings store for ``Setting`` properties in this scene.
    ///
    /// - Parameter store: The store to use.
    /// - Returns: A scene that uses the specified settings store.
    public func settingsStore(_ store: SettingsStore) -> some Scene {
        environment(\.settingsStore, store)
    }
}
