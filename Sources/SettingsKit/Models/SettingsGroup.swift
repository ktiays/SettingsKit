/// A titled or untitled group of settings destinations in the sidebar.
public struct SettingsGroup<SectionID: Hashable>: Identifiable {
    /// A stable identifier that is unique across sidebar groups.
    public let id: String

    /// The localized group title, or `nil` for an untitled group.
    public let title: String?

    /// The destinations in their sidebar display order.
    public let sections: [SettingsSection<SectionID>]

    /// Whether a titled group displays an expansion control.
    public let isCollapsible: Bool

    /// The initial expansion state, before the user changes it.
    public let isInitiallyExpanded: Bool

    /// Creates a sidebar group.
    ///
    /// Untitled groups remain expanded. Searching temporarily expands matching
    /// groups without replacing their user-selected expansion state.
    public init(
        _ title: String? = nil,
        id: String,
        sections: [SettingsSection<SectionID>],
        isCollapsible: Bool = true,
        isInitiallyExpanded: Bool = true
    ) {
        self.id = id
        self.title = title
        self.sections = sections
        self.isCollapsible = isCollapsible
        self.isInitiallyExpanded = isInitiallyExpanded
    }

    func filteringSections(_ predicate: (SettingsSection<SectionID>) -> Bool) -> Self {
        Self(
            title,
            id: id,
            sections: sections.filter(predicate),
            isCollapsible: isCollapsible,
            isInitiallyExpanded: isInitiallyExpanded
        )
    }
}
