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
            if let symbol = section.systemImage, let color = section.iconColor {
                Label {
                    Text(section.title)
                } icon: {
                    SettingsSectionIcon(systemImage: symbol, color: color)
                }
                .labelStyle(SettingsSectionLabelStyle())
                .tag(section.id)
            } else {
                Label {
                    Text(section.title)
                } icon: {
                    if let symbol = section.systemImage {
                        Image(systemName: symbol)
                            .foregroundStyle(.secondary)
                    }
                }
                .tag(section.id)
            }
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

/// A white symbol on a colored, rounded square, in the style of the system settings sidebar.
///
/// The symbol is fitted into a fixed box inside the square, so every symbol keeps the same
/// margin from the edges whatever its aspect ratio, and the sidebar does not enlarge it.
private struct SettingsSectionIcon: View {
    let systemImage: String
    let color: Color

    private static let size: CGFloat = 20
    private static let symbolSize: CGFloat = 13
    private static let cornerRadius: CGFloat = 5

    var body: some View {
        Image(systemName: systemImage)
            .resizable()
            .scaledToFit()
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .frame(width: Self.symbolSize, height: Self.symbolSize)
            .frame(width: Self.size, height: Self.size)
            .background {
                // The shadow keeps the icon distinct from a selection highlight of the same color.
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .fill(color.gradient)
                    .shadow(color: .black.opacity(0.3), radius: 1, y: 0.5)
            }
            .accessibilityHidden(true)
    }
}

/// Places a colored section icon and its title with the spacing of the system settings sidebar.
private struct SettingsSectionLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon
            configuration.title
        }
    }
}
