/// A typed key that identifies a persisted setting and provides its default value.
///
/// Declare keys as static properties in a constrained extension, so call sites
/// can refer to them with leading-dot syntax:
///
/// ```swift
/// extension SettingKey where Value == Bool {
///     static var showsLineNumbers: Self {
///         Self("editor.showsLineNumbers", defaultValue: true)
///     }
/// }
///
/// @Setting(.showsLineNumbers) private var showsLineNumbers
/// ```
///
/// Two keys are equal when their names are equal. Use each name for exactly
/// one value type and default value.
public struct SettingKey<Value: SettingValue>: Sendable, Hashable {
    /// The name under which storage backends persist the value.
    public let name: String

    /// The value a setting reads when no valid value is persisted.
    public let defaultValue: Value

    /// Creates a setting key.
    ///
    /// - Parameters:
    ///   - name: A stable name that is unique within the settings storage.
    ///   - defaultValue: The value to read when no valid value is persisted.
    public init(_ name: String, defaultValue: Value) {
        self.name = name
        self.defaultValue = defaultValue
    }

    /// Creates a key for an optional setting whose default value is `nil`.
    ///
    /// - Parameter name: A stable name that is unique within the settings storage.
    public init<Wrapped>(_ name: String) where Value == Wrapped? {
        self.init(name, defaultValue: nil)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.name == rhs.name
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}
