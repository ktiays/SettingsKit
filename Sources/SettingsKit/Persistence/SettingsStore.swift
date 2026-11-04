import Observation
import os
import Synchronization
import SwiftUI

private let logger = Logger(subsystem: "SettingsKit", category: "Persistence")

/// An observable, type-safe interface to settings persisted in a storage backend.
///
/// A settings store reads and writes values identified by ``SettingKey``
/// instances and converts them through ``SettingValue``. Observation is tracked
/// per key, so a view or model that reads one setting updates only when that
/// setting changes.
///
/// Read and write values with the key subscript, bind controls with
/// ``binding(for:)`` or a `Bindable` store, or use the ``Setting`` property
/// wrapper in views:
///
/// ```swift
/// let store = SettingsStore(storage: try SQLiteSettingsStorage(url: databaseURL))
///
/// store[.showsLineNumbers] = false
///
/// @Bindable var settings = store
/// Toggle("Show line numbers", isOn: $settings[.showsLineNumbers])
/// ```
///
/// An observable model can expose settings as computed properties. Views that
/// bind to the model observe the underlying store:
///
/// ```swift
/// @Observable
/// final class EditorSettings {
///     @ObservationIgnored private let store: SettingsStore
///
///     init(store: SettingsStore) {
///         self.store = store
///     }
///
///     var showsLineNumbers: Bool {
///         get {
///             store[.showsLineNumbers]
///         }
///         set {
///             store[.showsLineNumbers] = newValue
///         }
///     }
/// }
/// ```
///
/// The store caches representations that it reads. When the storage backend
/// reports changes through ``SettingsStorage/observeChanges(_:)``, the store
/// refreshes affected cached values and notifies observers of values that
/// differ.
public final class SettingsStore: Observable, Sendable {
    /// A store backed by the standard user defaults.
    public static let standard = SettingsStore(storage: UserDefaultsSettingsStorage())

    /// The backend that persists this store's values.
    public let storage: any SettingsStorage

    private let registrar = ObservationRegistrar()

    /// Cached representations by key. A `nil` entry records a known absent value.
    private let cache = Mutex<[String: SettingRepresentation?]>([:])

    private let changeObservation = Mutex<SettingsStorageObservation?>(nil)

    /// Creates a store that reads and writes values through a storage backend.
    ///
    /// - Parameter storage: The backend that persists values.
    public init(storage: any SettingsStorage) {
        self.storage = storage
        let observation = storage.observeChanges { [weak self] change in
            self?.refresh(change)
        }
        changeObservation.withLock {
            $0 = observation
        }
    }

    deinit {
        changeObservation.withLock {
            $0?.cancel()
        }
    }

    /// Accesses the value for a setting.
    ///
    /// Reading returns the key's default value when no valid value is
    /// persisted or the storage backend fails. Writing persists the value; a
    /// failed write is logged and the previous value is retained. Use
    /// ``value(for:)`` and ``setValue(_:for:)`` to handle errors.
    public subscript<Value>(key: SettingKey<Value>) -> Value {
        get {
            do {
                return try value(for: key)
            } catch {
                logger.error("Failed to read setting \(key.name, privacy: .public): \(error)")
                return key.defaultValue
            }
        }
        set {
            do {
                try setValue(newValue, for: key)
            } catch {
                logger.error("Failed to write setting \(key.name, privacy: .public): \(error)")
            }
        }
    }

    /// Returns the value for a setting.
    ///
    /// - Parameter key: The setting key.
    /// - Returns: The persisted value, or the key's default value when no
    ///   value is persisted or the persisted representation is not valid for
    ///   the value type.
    /// - Throws: An error that the storage backend reports.
    public func value<Value>(for key: SettingKey<Value>) throws -> Value {
        registrar.access(self, keyPath: Self.observationKeyPath(for: key.name))
        let representation = try representation(forKey: key.name)
        return representation.flatMap {
            Value(settingRepresentation: $0)
        } ?? key.defaultValue
    }

    /// Persists the value for a setting and notifies observers if it changed.
    ///
    /// - Parameters:
    ///   - value: The new value. A value whose representation is `nil`, such
    ///     as `Optional.none`, removes the persisted value.
    ///   - key: The setting key.
    ///
    /// The value replaces a persisted value that the backend cannot read, such
    /// as one of a type that settings storage cannot represent.
    ///
    /// - Throws: An error if the value cannot be represented, or an error that
    ///   the storage backend reports. The store retains the previous value.
    public func setValue<Value>(_ value: Value, for key: SettingKey<Value>) throws {
        try write(try value.settingRepresentation, forKey: key.name)
    }

    /// Removes the persisted value for a setting, restoring its default value.
    ///
    /// This also removes a persisted value that the backend cannot read.
    ///
    /// - Parameter key: The setting key.
    /// - Throws: An error that the storage backend reports.
    public func resetValue<Value>(for key: SettingKey<Value>) throws {
        try write(nil, forKey: key.name)
    }

    /// Returns a binding that reads and writes the value for a setting.
    ///
    /// - Parameter key: The setting key.
    /// - Returns: A binding to the setting's value.
    public func binding<Value>(for key: SettingKey<Value>) -> Binding<Value> {
        Binding {
            self[key]
        } set: { newValue in
            self[key] = newValue
        }
    }

    // MARK: - Caching

    private func representation(forKey key: String) throws -> SettingRepresentation? {
        if let cached = cache.withLock({ $0[key] }) {
            return cached
        }
        let representation = try storage.value(forKey: key)
        return cache.withLock { cache in
            // A concurrent write may have populated the entry first.
            if let cached = cache[key] {
                return cached
            }
            cache[key] = .some(representation)
            return representation
        }
    }

    private func write(_ representation: SettingRepresentation?, forKey key: String) throws {
        // Reads the current value outside the cache lock, because a backend may
        // report changes synchronously from within its own methods. A value
        // that cannot be read, such as one of an unsupported type written by
        // other code, does not prevent replacing or removing it; `nil` here
        // records that the previous value is unknown.
        let previous: SettingRepresentation??
        do {
            previous = .some(try self.representation(forKey: key))
        } catch {
            previous = nil
        }
        if let previous, previous == representation {
            // Writes through anyway, in case the backend changed without
            // reporting it, but observers already have the current value.
            try persist(representation, forKey: key)
            return
        }
        try registrar.withMutation(of: self, keyPath: Self.observationKeyPath(for: key)) {
            // Updates the cache before writing, so the backend's change
            // notification for this write does not report the value again.
            cache.withLock {
                $0[key] = .some(representation)
            }
            do {
                try persist(representation, forKey: key)
            } catch {
                cache.withLock {
                    // An unknown previous value removes the entry, so the
                    // next read consults the backend again.
                    $0[key] = previous
                }
                throw error
            }
        }
    }

    private func persist(_ representation: SettingRepresentation?, forKey key: String) throws {
        if let representation {
            try storage.setValue(representation, forKey: key)
        } else {
            try storage.removeValue(forKey: key)
        }
    }

    private func refresh(_ change: SettingsStorageChange) {
        let keys = cache.withLock { cache -> [String] in
            switch change {
            case .all:
                Array(cache.keys)
            case .keys(let keys):
                keys.filter {
                    cache.keys.contains($0)
                }
            }
        }
        for key in keys {
            let latest: SettingRepresentation?
            do {
                latest = try storage.value(forKey: key)
            } catch {
                logger.error("Failed to refresh setting \(key, privacy: .public): \(error)")
                continue
            }
            let isChanged = cache.withLock { cache in
                cache[key].map {
                    $0 != latest
                } ?? false
            }
            guard isChanged else {
                continue
            }
            registrar.withMutation(of: self, keyPath: Self.observationKeyPath(for: key)) {
                cache.withLock {
                    $0[key] = .some(latest)
                }
            }
        }
    }

    // MARK: - Observation

    /// A per-key identity for observation tracking.
    private subscript(observedSetting name: String) -> String {
        name
    }

    private static func observationKeyPath(for name: String) -> KeyPath<SettingsStore, String> {
        \SettingsStore.[observedSetting: name]
    }
}
