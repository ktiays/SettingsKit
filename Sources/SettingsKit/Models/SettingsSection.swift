import SwiftUI

/// A top-level destination displayed in the settings sidebar.
public struct SettingsSection<ID: Hashable>: Identifiable {
    /// The stable identifier used for selection and navigation history.
    public let id: ID

    /// The localized display title, supplied by the application.
    public let title: String

    /// An optional SF Symbol name for the sidebar icon.
    public let systemImage: String?

    /// An optional background color for a white, rounded-square sidebar icon.
    public let iconColor: Color?

    /// Additional localized terms that make this destination searchable.
    public let keywords: [String]

    /// Creates a sidebar destination with a stable identifier.
    ///
    /// - Parameters:
    ///   - title: The localized display title.
    ///   - id: An identifier that is unique across all sidebar groups.
    ///   - systemImage: An optional SF Symbol name.
    ///   - iconColor: The icon background color, or `nil` for a standard symbol.
    ///   - keywords: Additional localized search terms.
    public init(
        _ title: String,
        id: ID,
        systemImage: String? = nil,
        iconColor: Color? = nil,
        keywords: [String] = []
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.iconColor = iconColor
        self.keywords = keywords
    }

    func matches(_ query: String) -> Bool {
        title.localizedCaseInsensitiveContains(query)
            || keywords.contains {
                $0.localizedCaseInsensitiveContains(query)
            }
    }
}
