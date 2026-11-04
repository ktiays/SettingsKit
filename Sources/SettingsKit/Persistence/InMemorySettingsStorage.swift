import Synchronization

/// A settings storage backend that keeps values in memory.
///
/// Use this backend for previews, tests, and settings that must not outlive
/// the process. Every store that shares an instance observes its changes.
public final class InMemorySettingsStorage: SettingsStorage {
    private let values: Mutex<[String: SettingRepresentation]>
    private let notifier = SettingsStorageChangeNotifier()

    /// Creates an in-memory backend.
    ///
    /// - Parameter values: Initial representations by setting name.
    public init(values: [String: SettingRepresentation] = [:]) {
        self.values = Mutex(values)
    }

    public func value(forKey key: String) -> SettingRepresentation? {
        values.withLock {
            $0[key]
        }
    }

    public func setValue(_ value: SettingRepresentation, forKey key: String) {
        values.withLock {
            $0[key] = value
        }
        notifier.notifyObservers(of: .keys([key]))
    }

    public func removeValue(forKey key: String) {
        values.withLock {
            $0[key] = nil
        }
        notifier.notifyObservers(of: .keys([key]))
    }

    public func observeChanges(
        _ handler: @escaping @Sendable (SettingsStorageChange) -> Void
    ) -> SettingsStorageObservation {
        notifier.observeChanges(handler)
    }
}
