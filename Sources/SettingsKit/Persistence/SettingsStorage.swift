import Synchronization

/// A backend that persists setting representations by key.
///
/// SettingsKit provides ``UserDefaultsSettingsStorage``,
/// ``SQLiteSettingsStorage``, and ``InMemorySettingsStorage``. Conform a custom
/// type to persist settings elsewhere, such as in a configuration file or a
/// synchronized key-value store.
///
/// A ``SettingsStore`` caches the values it reads. To keep that cache current
/// when values change outside the store, for example through another store or
/// another process, implement ``observeChanges(_:)`` and report each change.
/// ``SettingsStorageChangeNotifier`` manages observers for custom backends.
///
/// Implementations must be safe to call from any thread, and must not call
/// change handlers while holding a lock that their other methods acquire.
public protocol SettingsStorage: Sendable {
    /// Returns the representation persisted for a key.
    ///
    /// - Parameter key: The setting name.
    /// - Returns: The persisted representation, or `nil` if none exists.
    /// - Throws: An error if the backend cannot read the value.
    func value(forKey key: String) throws -> SettingRepresentation?

    /// Persists a representation for a key, replacing any existing value.
    ///
    /// - Parameters:
    ///   - value: The representation to persist.
    ///   - key: The setting name.
    /// - Throws: An error if the backend cannot write the value.
    func setValue(_ value: SettingRepresentation, forKey key: String) throws

    /// Removes the representation persisted for a key, if any.
    ///
    /// - Parameter key: The setting name.
    /// - Throws: An error if the backend cannot remove the value.
    func removeValue(forKey key: String) throws

    /// Registers a handler that the backend calls after persisted values change.
    ///
    /// The backend may call the handler on any thread. The default
    /// implementation never calls the handler.
    ///
    /// - Parameter handler: The closure to call with each change.
    /// - Returns: An observation that unregisters the handler when cancelled
    ///   or deinitialized.
    func observeChanges(
        _ handler: @escaping @Sendable (SettingsStorageChange) -> Void
    ) -> SettingsStorageObservation
}

extension SettingsStorage {
    public func observeChanges(
        _ handler: @escaping @Sendable (SettingsStorageChange) -> Void
    ) -> SettingsStorageObservation {
        SettingsStorageObservation {
        }
    }
}

/// A description of persisted values that changed in a settings storage.
public enum SettingsStorageChange: Sendable, Hashable {
    /// The values for the specified keys changed.
    case keys(Set<String>)

    /// Any persisted value may have changed.
    case all
}

/// A registration for settings storage change notifications.
///
/// The registration ends when you call ``cancel()`` or when the observation
/// is deinitialized.
public final class SettingsStorageObservation: Sendable {
    private let cancellation: Mutex<(@Sendable () -> Void)?>

    /// Creates an observation that performs a closure when it ends.
    ///
    /// - Parameter cancellation: The closure that unregisters the observer.
    ///   It runs at most once.
    public init(cancellation: @escaping @Sendable () -> Void) {
        self.cancellation = Mutex(cancellation)
    }

    /// Ends the registration. Subsequent calls have no effect.
    public func cancel() {
        let cancellation = cancellation.withLock {
            $0.take()
        }
        cancellation?()
    }

    deinit {
        cancel()
    }
}

/// A thread-safe collection of change handlers for a settings storage backend.
///
/// Custom ``SettingsStorage`` implementations can return the result of
/// ``observeChanges(_:)`` from their own `observeChanges(_:)` method and call
/// ``notifyObservers(of:)`` after each change, outside of any internal lock.
public final class SettingsStorageChangeNotifier: Sendable {
    private struct State {
        var nextIdentifier = 0
        var handlers: [Int: @Sendable (SettingsStorageChange) -> Void] = [:]
    }

    private let state = Mutex(State())

    /// Creates a notifier without registered handlers.
    public init() {
    }

    /// Registers a handler for subsequent changes.
    ///
    /// - Parameter handler: The closure to call with each change.
    /// - Returns: An observation that unregisters the handler.
    public func observeChanges(
        _ handler: @escaping @Sendable (SettingsStorageChange) -> Void
    ) -> SettingsStorageObservation {
        let identifier = state.withLock { state in
            let identifier = state.nextIdentifier
            state.nextIdentifier += 1
            state.handlers[identifier] = handler
            return identifier
        }
        return SettingsStorageObservation { [weak self] in
            self?.state.withLock { state in
                state.handlers[identifier] = nil
            }
        }
    }

    /// Calls every registered handler with a change.
    ///
    /// - Parameter change: The change to report.
    public func notifyObservers(of change: SettingsStorageChange) {
        let handlers = state.withLock { state in
            Array(state.handlers.values)
        }
        for handler in handlers {
            handler(change)
        }
    }
}

/// An error that a built-in settings storage backend reports.
public enum SettingsStorageError: Error, Hashable {
    /// The value persisted for a key has a type that settings storage cannot represent.
    case unsupportedValue(key: String)
}
