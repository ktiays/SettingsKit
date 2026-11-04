/// A sidebar selection and the complete detail path beneath it.
public struct SettingsLocation<SectionID: Hashable, Destination: Hashable>: Hashable {
    /// The top-level settings destination.
    public var section: SectionID

    /// The ordered detail destinations above the section's root page.
    public var path: [Destination]

    /// Creates a location suitable for an atomic cross-section navigation.
    public init(section: SectionID, path: [Destination] = []) {
        self.section = section
        self.path = path
    }
}

extension SettingsLocation: Sendable where SectionID: Sendable, Destination: Sendable {
}
