import Foundation

/// An immutable location in a settings window's navigation history.
public struct SettingsHistoryEntry<SectionID: Hashable, Destination: Hashable>: Identifiable, Hashable {
    /// A stable identifier that remains valid while the entry is in history.
    public let id: UUID

    /// The complete location that this entry restores.
    public let location: SettingsLocation<SectionID, Destination>

    init(location: SettingsLocation<SectionID, Destination>) {
        id = UUID()
        self.location = location
    }
}

extension SettingsHistoryEntry: Sendable where SectionID: Sendable, Destination: Sendable {
}
