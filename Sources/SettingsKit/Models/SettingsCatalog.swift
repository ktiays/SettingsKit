import Foundation

struct SettingsCatalog<SectionID: Hashable> {
    let groups: [SettingsGroup<SectionID>]
    private let sectionsByID: [SectionID: SettingsSection<SectionID>]

    init(groups: [SettingsGroup<SectionID>]) {
        precondition(Set(groups.map(\.id)).count == groups.count, "Settings group identifiers must be unique.")
        let sections = groups.flatMap(\.sections)
        precondition(Set(sections.map(\.id)).count == sections.count, "Settings section identifiers must be unique.")
        self.groups = groups
        sectionsByID = Dictionary(uniqueKeysWithValues: sections.map {
            ($0.id, $0)
        })
    }

    var sectionIDs: [SectionID] {
        groups.flatMap(\.sections).map(\.id)
    }

    subscript(id: SectionID) -> SettingsSection<SectionID>? {
        sectionsByID[id]
    }

    func filteredGroups(matching searchText: String) -> [SettingsGroup<SectionID>] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return groups.compactMap { group in
            let matchesGroup = group.title?.localizedCaseInsensitiveContains(query) == true
            let filtered = group.filteringSections {
                query.isEmpty || matchesGroup || $0.matches(query)
            }
            return filtered.sections.isEmpty ? nil : filtered
        }
    }
}
