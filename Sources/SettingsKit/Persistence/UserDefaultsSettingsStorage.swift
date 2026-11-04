import Foundation
import Synchronization

/// A settings storage backend that persists values in user defaults.
///
/// Representations map to property list types: Booleans, integers, and
/// doubles are stored as numbers, strings as strings, and data as data. Values
/// written directly to user defaults with those types, or as dates, are read
/// back as the corresponding representation.
///
/// Arrays and dictionaries written directly to user defaults, for example by
/// `UserDefaults.set(_:forKey:)` before an app adopted SettingsKit, are read as
/// a string representation of their JSON encoding when they contain only
/// strings, numbers, Booleans, arrays, and dictionaries with string keys. This
/// is the representation of arrays, sets, dictionaries, and other
/// ``CodableSettingValue`` types, so their persisted values remain readable.
/// Writing such a setting replaces the property list value with the encoded
/// JSON string.
///
/// The backend reports changes made through any `UserDefaults` instance in the
/// current process. It does not observe changes made by other processes.
//
// `UserDefaults` is documented as thread-safe but is not annotated as
// `Sendable`. Every other stored property is immutable and `Sendable`.
public final class UserDefaultsSettingsStorage: SettingsStorage, @unchecked Sendable {
    /// The user defaults database that persists values.
    public let defaults: UserDefaults

    /// The prefix prepended to every setting name to form a defaults key.
    public let keyPrefix: String

    private let notifier: SettingsStorageChangeNotifier
    private let notificationObserver: Mutex<(any NSObjectProtocol)?>

    /// Creates a backend that persists values in a user defaults database.
    ///
    /// - Parameters:
    ///   - defaults: The user defaults database. The default is `.standard`.
    ///   - keyPrefix: A prefix for every defaults key, such as `"Settings."`.
    public init(defaults: UserDefaults = .standard, keyPrefix: String = "") {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
        let notifier = SettingsStorageChangeNotifier()
        self.notifier = notifier
        // The notification does not identify the changed keys, and an
        // instance for the same suite may post it, so any change in the
        // process triggers a refresh of cached values.
        let observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: nil
        ) { _ in
            notifier.notifyObservers(of: .all)
        }
        notificationObserver = Mutex(observer)
    }

    /// Creates a backend that persists values in a named user defaults suite.
    ///
    /// - Parameters:
    ///   - suiteName: The name of the defaults suite, such as an app group identifier.
    ///   - keyPrefix: A prefix for every defaults key.
    /// - Returns: `nil` if the suite name is not valid for user defaults.
    public convenience init?(suiteName: String, keyPrefix: String = "") {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return nil
        }
        self.init(defaults: defaults, keyPrefix: keyPrefix)
    }

    deinit {
        notificationObserver.withLock {
            if let observer = $0 {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    public func value(forKey key: String) throws -> SettingRepresentation? {
        guard let object = defaults.object(forKey: keyPrefix + key) else {
            return nil
        }
        switch object {
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .bool(number.boolValue)
            }
            if CFNumberIsFloatType(number) {
                return .double(number.doubleValue)
            }
            return .integer(number.intValue)
        case let string as String:
            return .string(string)
        case let data as Data:
            return .data(data)
        case let date as Date:
            return .double(date.timeIntervalSinceReferenceDate)
        case is [Any], is [String: Any]:
            guard JSONSerialization.isValidJSONObject(object),
                  let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else {
                throw SettingsStorageError.unsupportedValue(key: key)
            }
            return .string(String(decoding: data, as: UTF8.self))
        default:
            throw SettingsStorageError.unsupportedValue(key: key)
        }
    }

    public func setValue(_ value: SettingRepresentation, forKey key: String) {
        let defaultsKey = keyPrefix + key
        switch value {
        case .bool(let value):
            defaults.set(value, forKey: defaultsKey)
        case .integer(let value):
            defaults.set(value, forKey: defaultsKey)
        case .double(let value):
            defaults.set(value, forKey: defaultsKey)
        case .string(let value):
            defaults.set(value, forKey: defaultsKey)
        case .data(let value):
            defaults.set(value, forKey: defaultsKey)
        }
    }

    public func removeValue(forKey key: String) {
        defaults.removeObject(forKey: keyPrefix + key)
    }

    public func observeChanges(
        _ handler: @escaping @Sendable (SettingsStorageChange) -> Void
    ) -> SettingsStorageObservation {
        notifier.observeChanges(handler)
    }
}
