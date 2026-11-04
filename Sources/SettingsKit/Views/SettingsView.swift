import SwiftUI

/// A native sidebar and grouped-Form settings interface.
///
/// The content builders provide the rows and sections inside each page's Form.
/// They accept arbitrary custom SwiftUI views alongside standard controls.
/// Use stable, unique group and section identifiers. Keep preference values in
/// a ``SettingsStore`` or in application-owned state above the page views when
/// they must survive navigation.
///
/// By default, the view owns its navigation state. To select sections from
/// elsewhere in the app, such as a button in another window that opens
/// settings at a particular section, create a ``SettingsNavigation`` and pass
/// it to ``init(groups:navigation:sidebarEdgeStyle:detailEdgeStyle:destinationTitle:content:destinationContent:)``.
@MainActor
public struct SettingsView<SectionID: Hashable, Destination: Hashable, Content: View, DestinationContent: View>: View {
    private let catalog: SettingsCatalog<SectionID>
    private let destinationTitle: (Destination) -> String
    private let content: (SectionID) -> Content
    private let destinationContent: (Destination) -> DestinationContent
    private let sidebarEdgeStyle: ScrollEdgeEffectStyle
    private let detailEdgeStyle: ScrollEdgeEffectStyle
    private let providedNavigation: SettingsNavigation<SectionID, Destination>?
    @State private var ownedNavigation: SettingsNavigation<SectionID, Destination>
    @State private var searchText = ""

    private var navigation: SettingsNavigation<SectionID, Destination> {
        providedNavigation ?? ownedNavigation
    }

    /// Creates settings content with typed detail destinations.
    ///
    /// - Parameters:
    ///   - groups: Sidebar groups with unique group and section identifiers.
    ///   - initialSection: The initial selection, defaulting to the first section.
    ///   - sidebarEdgeStyle: The sidebar's top scroll edge treatment.
    ///   - detailEdgeStyle: Each detail Form's top scroll edge treatment.
    ///   - destinationTitle: The localized title of each detail destination.
    ///   - content: Custom Form content for each top-level section.
    ///   - destinationContent: Custom Form content for each detail destination.
    public init(
        groups: [SettingsGroup<SectionID>],
        initialSection: SectionID? = nil,
        sidebarEdgeStyle: ScrollEdgeEffectStyle = .automatic,
        detailEdgeStyle: ScrollEdgeEffectStyle = .automatic,
        destinationTitle: @escaping (Destination) -> String,
        @ContentBuilder content: @escaping (SectionID) -> Content,
        @ContentBuilder destinationContent: @escaping (Destination) -> DestinationContent
    ) {
        self.init(
            groups: groups,
            providedNavigation: nil,
            initialSection: initialSection,
            sidebarEdgeStyle: sidebarEdgeStyle,
            detailEdgeStyle: detailEdgeStyle,
            destinationTitle: destinationTitle,
            content: content,
            destinationContent: destinationContent
        )
    }

    /// Creates settings content with typed detail destinations whose
    /// navigation state the caller owns.
    ///
    /// The view displays and updates the location of `navigation`, so changes
    /// made through it elsewhere, such as ``SettingsNavigation/select(_:)``,
    /// take effect in the view. The navigation state, including its history,
    /// outlives the view, for example when a settings window is closed and
    /// reopened. The view keeps the navigation's sections in sync with
    /// `groups`. Use each navigation object for at most one view at a time.
    ///
    /// - Parameters:
    ///   - groups: Sidebar groups with unique group and section identifiers.
    ///   - navigation: The navigation state to display and update.
    ///   - sidebarEdgeStyle: The sidebar's top scroll edge treatment.
    ///   - detailEdgeStyle: Each detail Form's top scroll edge treatment.
    ///   - destinationTitle: The localized title of each detail destination.
    ///   - content: Custom Form content for each top-level section.
    ///   - destinationContent: Custom Form content for each detail destination.
    public init(
        groups: [SettingsGroup<SectionID>],
        navigation: SettingsNavigation<SectionID, Destination>,
        sidebarEdgeStyle: ScrollEdgeEffectStyle = .automatic,
        detailEdgeStyle: ScrollEdgeEffectStyle = .automatic,
        destinationTitle: @escaping (Destination) -> String,
        @ContentBuilder content: @escaping (SectionID) -> Content,
        @ContentBuilder destinationContent: @escaping (Destination) -> DestinationContent
    ) {
        self.init(
            groups: groups,
            providedNavigation: navigation,
            initialSection: nil,
            sidebarEdgeStyle: sidebarEdgeStyle,
            detailEdgeStyle: detailEdgeStyle,
            destinationTitle: destinationTitle,
            content: content,
            destinationContent: destinationContent
        )
    }

    private init(
        groups: [SettingsGroup<SectionID>],
        providedNavigation: SettingsNavigation<SectionID, Destination>?,
        initialSection: SectionID?,
        sidebarEdgeStyle: ScrollEdgeEffectStyle,
        detailEdgeStyle: ScrollEdgeEffectStyle,
        destinationTitle: @escaping (Destination) -> String,
        content: @escaping (SectionID) -> Content,
        destinationContent: @escaping (Destination) -> DestinationContent
    ) {
        let catalog = SettingsCatalog(groups: groups)
        self.catalog = catalog
        self.destinationTitle = destinationTitle
        self.content = content
        self.destinationContent = destinationContent
        self.sidebarEdgeStyle = sidebarEdgeStyle
        self.detailEdgeStyle = detailEdgeStyle
        self.providedNavigation = providedNavigation
        // Unused when the caller provides navigation, which SwiftUI may
        // construct on every initialization; creating it is inexpensive.
        _ownedNavigation = State(initialValue: SettingsNavigation(
            sections: providedNavigation == nil ? catalog.sectionIDs : [],
            initialSection: initialSection
        ))
    }

    public var body: some View {
        NavigationSplitView {
            SettingsSidebar(catalog: catalog, navigation: navigation, searchText: searchText)
                .scrollEdgeEffectStyle(sidebarEdgeStyle, for: .top)
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        } detail: {
            if let section = navigation.location?.section, let metadata = catalog[section] {
                detailColumn(for: section, title: metadata.title)
            } else {
                ContentUnavailableView("No Settings Available", systemImage: "gearshape")
                    .navigationTitle("Settings")
            }
        }
        .navigationSplitViewStyle(.balanced)
        .searchable(text: $searchText, placement: .sidebar)
        .environment(navigation)
        .focusedSceneValue(\.settingsNavigationActions, SettingsNavigationActions(
            canGoBack: navigation.canGoBack,
            canGoForward: navigation.canGoForward,
            goBack: {
                navigation.goBack()
            },
            goForward: {
                navigation.goForward()
            }
        ))
        .frame(minWidth: 760, minHeight: 540)
        .onChange(of: catalog.sectionIDs, initial: true) { _, identifiers in
            navigation.updateSections(identifiers)
        }
    }

    private func detailColumn(for section: SectionID, title: String) -> some View {
        NavigationStack(path: pathBinding(in: section)) {
            SettingsDetailPage(
                title: title,
                edgeStyle: detailEdgeStyle,
                navigation: navigation,
                historyTitle: historyTitle
            ) {
                content(section)
            }
            .navigationDestination(for: Destination.self) { destination in
                SettingsDetailPage(
                    title: destinationTitle(destination),
                    edgeStyle: detailEdgeStyle,
                    navigation: navigation,
                    historyTitle: historyTitle
                ) {
                    destinationContent(destination)
                }
            }
        }
        .id(section)
    }

    private func pathBinding(in section: SectionID) -> Binding<[Destination]> {
        Binding {
            navigation.location?.section == section ? navigation.location?.path ?? [] : []
        } set: { path in
            navigation.setPath(path, in: section)
        }
    }

    private func historyTitle(_ location: SettingsLocation<SectionID, Destination>) -> String {
        location.path.last.map(destinationTitle) ?? catalog[location.section]?.title ?? "Settings"
    }
}

extension SettingsView where Destination == Never, DestinationContent == EmptyView {
    /// Creates settings content that navigates between sidebar sections only.
    public init(
        groups: [SettingsGroup<SectionID>],
        initialSection: SectionID? = nil,
        sidebarEdgeStyle: ScrollEdgeEffectStyle = .automatic,
        detailEdgeStyle: ScrollEdgeEffectStyle = .automatic,
        @ContentBuilder content: @escaping (SectionID) -> Content
    ) {
        self.init(
            groups: groups,
            initialSection: initialSection,
            sidebarEdgeStyle: sidebarEdgeStyle,
            detailEdgeStyle: detailEdgeStyle,
            destinationTitle: unavailableSettingsDestination,
            content: content,
            destinationContent: unavailableSettingsDestination
        )
    }

    /// Creates settings content that navigates between sidebar sections only,
    /// with navigation state that the caller owns.
    ///
    /// - Parameters:
    ///   - groups: Sidebar groups with unique group and section identifiers.
    ///   - navigation: The navigation state to display and update.
    ///   - sidebarEdgeStyle: The sidebar's top scroll edge treatment.
    ///   - detailEdgeStyle: Each detail Form's top scroll edge treatment.
    ///   - content: Custom Form content for each top-level section.
    public init(
        groups: [SettingsGroup<SectionID>],
        navigation: SettingsNavigation<SectionID, Never>,
        sidebarEdgeStyle: ScrollEdgeEffectStyle = .automatic,
        detailEdgeStyle: ScrollEdgeEffectStyle = .automatic,
        @ContentBuilder content: @escaping (SectionID) -> Content
    ) {
        self.init(
            groups: groups,
            navigation: navigation,
            sidebarEdgeStyle: sidebarEdgeStyle,
            detailEdgeStyle: detailEdgeStyle,
            destinationTitle: unavailableSettingsDestination,
            content: content,
            destinationContent: unavailableSettingsDestination
        )
    }
}
