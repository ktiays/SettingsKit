import SwiftUI

struct SettingsSidebar<SectionID: Hashable, Destination: Hashable>: View {
    let catalog: SettingsCatalog<SectionID>
    let navigation: SettingsNavigation<SectionID, Destination>
    let searchText: String
    @State private var expandedGroups: Set<String> = []
    @State private var knownGroups: Set<String> = []

    var body: some View {
        List(selection: selection) {
            ForEach(catalog.filteredGroups(matching: searchText)) { group in
                if let title = group.title, group.isCollapsible {
                    SwiftUI.Section(isExpanded: expansion(for: group)) {
                        rows(in: group)
                    } header: {
                        Text(title)
                    }
                } else if let title = group.title {
                    SwiftUI.Section(title) {
                        rows(in: group)
                    }
                } else {
                    SwiftUI.Section {
                        rows(in: group)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .toolbar(removing: .sidebarToggle)
        .accessibilityIdentifier("settings.sidebar")
        .overlay {
            if !searchText.isEmpty, catalog.filteredGroups(matching: searchText).isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: catalog.groups.map(\.id), initial: true) { _, identifiers in
            let current = Set(identifiers)
            expandedGroups.formIntersection(current)
            for group in catalog.groups where !knownGroups.contains(group.id) && group.isInitiallyExpanded {
                expandedGroups.insert(group.id)
            }
            knownGroups = current
            revealSelection()
        }
        .onChange(of: navigation.location?.section) { _, _ in
            revealSelection()
        }
    }

    private var selection: Binding<SectionID?> {
        Binding {
            navigation.location?.section
        } set: { section in
            if let section {
                navigation.select(section)
            }
        }
    }

    private func rows(in group: SettingsGroup<SectionID>) -> some View {
        ForEach(group.sections) { section in
            Label {
                Text(section.title)
            } icon: {
                if let symbol = section.systemImage {
                    if let color = section.iconColor {
                        Image(systemName: symbol)
                            .foregroundStyle(.white)
                            .frame(width: 25, height: 25)
                            .background(color, in: RoundedRectangle(cornerRadius: 6))
                    } else {
                        Image(systemName: symbol)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .tag(section.id)
            .padding(.vertical, 3)
        }
    }

    private func expansion(for group: SettingsGroup<SectionID>) -> Binding<Bool> {
        Binding {
            !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || expandedGroups.contains(group.id)
        } set: { isExpanded in
            guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }
            if isExpanded {
                expandedGroups.insert(group.id)
            } else {
                expandedGroups.remove(group.id)
            }
        }
    }

    private func revealSelection() {
        guard
            let selection = navigation.location?.section,
            let group = catalog.groups.first(where: {
                $0.sections.contains {
                    $0.id == selection
                }
            })
        else {
            return
        }
        expandedGroups.insert(group.id)
    }
}
