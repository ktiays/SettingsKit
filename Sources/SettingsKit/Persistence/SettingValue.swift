import Foundation

/// The backend-neutral representation of a persisted setting value.
///
/// Storage backends persist only these primitive representations. Types that
/// conform to ``SettingValue`` convert themselves to and from a representation,
/// so a backend never needs to know about application-defined types.
public enum SettingRepresentation: Sendable, Hashable {
    /// A Boolean value.
    case bool(Bool)

    /// A signed integer value.
    case integer(Int)

    /// A double-precision floating-point value.
    case double(Double)

    /// A string value.
    case string(String)

    /// An arbitrary binary value.
    case data(Data)
}

/// A type whose values a settings store can persist.
///
/// Conforming types convert their values to a ``SettingRepresentation`` that
/// every ``SettingsStorage`` backend can persist, and restore values from that
/// representation.
///
/// SettingsKit provides conformances for `Bool`, `Int`, `Double`, `Float`,
/// `String`, `Data`, `Date`, `URL`, and `Optional`, and for arrays, sets, and
/// dictionaries of codable setting values, which persist as encoded JSON. Raw-representable types
/// whose raw value conforms to `SettingValue` receive a default implementation,
/// so an enumeration only needs to declare its conformance:
///
/// ```swift
/// enum ColorSchemePreference: String, SettingValue {
///     case automatic
///     case light
///     case dark
/// }
/// ```
///
/// To persist a structured model as a single setting, conform it to
/// ``CodableSettingValue`` instead.
public protocol SettingValue: Sendable {
    /// Creates a value from its persisted representation.
    ///
    /// Return `nil` when the representation does not describe a valid value,
    /// for example after an incompatible change to the persisted format. The
    /// settings store then provides the setting's default value.
    ///
    /// - Parameter settingRepresentation: The representation read from storage.
    init?(settingRepresentation: SettingRepresentation)

    /// The representation to persist for this value.
    ///
    /// A `nil` representation indicates the absence of a value, such as
    /// `Optional.none`. The settings store removes the persisted value, so the
    /// setting subsequently reads its key's default value.
    ///
    /// - Throws: An error if the value cannot be converted to a representation.
    var settingRepresentation: SettingRepresentation? { get throws }
}

/// A codable type that a settings store persists as encoded JSON.
///
/// Conform structured models to this protocol to persist them under a single
/// setting key. Views can then bind to individual properties through the
/// projected binding of a ``Setting`` property:
///
/// ```swift
/// struct EditorPreferences: CodableSettingValue {
///     var showsLineNumbers = true
///     var tabWidth = 4
/// }
///
/// @Setting(.editorPreferences) private var editor
/// Toggle("Show line numbers", isOn: $editor.showsLineNumbers)
/// ```
///
/// Values that fail to decode, for example because of an incompatible change
/// to the type, are replaced by the setting's default value. Implement
/// `init(from:)` with `decodeIfPresent(_:forKey:)` to tolerate added properties.
public protocol CodableSettingValue: SettingValue, Codable {
}

extension CodableSettingValue {
    public init?(settingRepresentation: SettingRepresentation) {
        let data: Data
        switch settingRepresentation {
        case .string(let string):
            data = Data(string.utf8)
        case .data(let value):
            data = value
        default:
            return nil
        }
        guard let value = try? JSONDecoder().decode(Self.self, from: data) else {
            return nil
        }
        self = value
    }

    public var settingRepresentation: SettingRepresentation? {
        get throws {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return .string(String(decoding: try encoder.encode(self), as: UTF8.self))
        }
    }
}

extension SettingValue where Self: RawRepresentable, RawValue: SettingValue {
    public init?(settingRepresentation: SettingRepresentation) {
        guard let rawValue = RawValue(settingRepresentation: settingRepresentation) else {
            return nil
        }
        self.init(rawValue: rawValue)
    }

    public var settingRepresentation: SettingRepresentation? {
        get throws {
            try rawValue.settingRepresentation
        }
    }
}

// MARK: - Standard Conformances

extension Bool: SettingValue {
    public init?(settingRepresentation: SettingRepresentation) {
        switch settingRepresentation {
        case .bool(let value):
            self = value
        case .integer(0):
            self = false
        case .integer(1):
            self = true
        default:
            return nil
        }
    }

    public var settingRepresentation: SettingRepresentation? {
        .bool(self)
    }
}

extension Int: SettingValue {
    public init?(settingRepresentation: SettingRepresentation) {
        switch settingRepresentation {
        case .integer(let value):
            self = value
        case .double(let value):
            guard let exact = Int(exactly: value) else {
                return nil
            }
            self = exact
        default:
            return nil
        }
    }

    public var settingRepresentation: SettingRepresentation? {
        .integer(self)
    }
}

extension Double: SettingValue {
    public init?(settingRepresentation: SettingRepresentation) {
        switch settingRepresentation {
        case .double(let value):
            self = value
        case .integer(let value):
            self = Double(value)
        default:
            return nil
        }
    }

    public var settingRepresentation: SettingRepresentation? {
        .double(self)
    }
}

extension Float: SettingValue {
    public init?(settingRepresentation: SettingRepresentation) {
        guard let value = Double(settingRepresentation: settingRepresentation) else {
            return nil
        }
        self = Float(value)
    }

    public var settingRepresentation: SettingRepresentation? {
        .double(Double(self))
    }
}

extension String: SettingValue {
    public init?(settingRepresentation: SettingRepresentation) {
        guard case .string(let value) = settingRepresentation else {
            return nil
        }
        self = value
    }

    public var settingRepresentation: SettingRepresentation? {
        .string(self)
    }
}

extension Data: SettingValue {
    public init?(settingRepresentation: SettingRepresentation) {
        guard case .data(let value) = settingRepresentation else {
            return nil
        }
        self = value
    }

    public var settingRepresentation: SettingRepresentation? {
        .data(self)
    }
}

extension Date: SettingValue {
    /// Creates a date from a representation of its interval since the
    /// reference date, January 1, 2001, in UTC.
    public init?(settingRepresentation: SettingRepresentation) {
        guard let interval = TimeInterval(settingRepresentation: settingRepresentation) else {
            return nil
        }
        self.init(timeIntervalSinceReferenceDate: interval)
    }

    /// The interval since the reference date, January 1, 2001, in UTC.
    public var settingRepresentation: SettingRepresentation? {
        .double(timeIntervalSinceReferenceDate)
    }
}

extension URL: SettingValue {
    public init?(settingRepresentation: SettingRepresentation) {
        guard case .string(let string) = settingRepresentation, let url = URL(string: string) else {
            return nil
        }
        self = url
    }

    public var settingRepresentation: SettingRepresentation? {
        .string(absoluteString)
    }
}

extension Optional: SettingValue where Wrapped: SettingValue {
    public init?(settingRepresentation: SettingRepresentation) {
        guard let value = Wrapped(settingRepresentation: settingRepresentation) else {
            return nil
        }
        self = .some(value)
    }

    /// The wrapped value's representation, or `nil` for `Optional.none`.
    ///
    /// Assigning `nil` removes the persisted value, so the setting reads its
    /// key's default value. Use `nil` as the default value of optional settings.
    public var settingRepresentation: SettingRepresentation? {
        get throws {
            try self?.settingRepresentation
        }
    }
}

extension Array: SettingValue where Element: SettingValue & Codable {
}
extension Array: CodableSettingValue where Element: SettingValue & Codable {
}

extension Set: SettingValue where Element: SettingValue & Codable {
}
extension Set: CodableSettingValue where Element: SettingValue & Codable {
}

extension Dictionary: SettingValue where Key: SettingValue & Codable, Value: SettingValue & Codable {
}
extension Dictionary: CodableSettingValue where Key: SettingValue & Codable, Value: SettingValue & Codable {
}
