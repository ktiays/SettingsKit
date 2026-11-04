import Testing
@testable import SettingsKit

@Suite("Settings Catalog")
struct SettingsCatalogTests {
    private var catalog: SettingsCatalog<String> {
        SettingsCatalog(groups: [
            SettingsGroup(id: "empty", sections: []),
            SettingsGroup(id: "main", sections: [
                SettingsSection("General", id: "general", keywords: ["Software Update"]),
                SettingsSection("Appearance", id: "appearance", keywords: ["Theme", "Color"]),
            ]),
            SettingsGroup("Connectivity", id: "connectivity", sections: [
                SettingsSection("Wi-Fi", id: "wifi"),
                SettingsSection("Network", id: "network"),
            ], isInitiallyExpanded: false),
        ])
    }

    @Test func preservesDestinationOrderAndOmitsEmptyGroups() {
        #expect(catalog.sectionIDs == ["general", "appearance", "wifi", "network"])
        #expect(catalog.filteredGroups(matching: "").map(\.id) == ["main", "connectivity"])
    }

    @Test func searchesLocalizedTitlesWithoutCaseSensitivity() {
        let groups = catalog.filteredGroups(matching: "WI-FI")
        #expect(groups.map(\.id) == ["connectivity"])
        #expect(groups.flatMap(\.sections).map(\.id) == ["wifi"])
        #expect(groups[0].isInitiallyExpanded == false)
    }

    @Test func searchesAdditionalKeywords() {
        #expect(catalog.filteredGroups(matching: "theme").flatMap(\.sections).map(\.id) == ["appearance"])
        #expect(catalog.filteredGroups(matching: "software").flatMap(\.sections).map(\.id) == ["general"])
    }

    @Test func matchingAGroupIncludesAllItsDestinations() {
        #expect(catalog.filteredGroups(matching: "Connectivity").flatMap(\.sections).map(\.id) == ["wifi", "network"])
    }

    @Test func handlesWhitespaceAndNoResults() {
        #expect(catalog.filteredGroups(matching: "  \n").flatMap(\.sections).count == 4)
        #expect(catalog.filteredGroups(matching: "missing setting").isEmpty)
        #expect(catalog["appearance"]?.title == "Appearance")
        #expect(catalog["missing"] == nil)
    }
}
