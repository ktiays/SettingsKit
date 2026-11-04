import SwiftUI

/// A singleton settings window whose lifecycle is managed by SwiftUI.
///
/// Open the scene with SwiftUI's `openWindow` action and the same identifier.
/// The scene installs the application's Settings command and focused Back and
/// Forward commands. Use `SettingsView` when an existing scene owns the window.
@MainActor
public struct SettingsWindow<SectionID: Hashable, Destination: Hashable, Content: View, DestinationContent: View>: Scene {
    private let title: String
    private let identifier: String
    private let groups: [SettingsGroup<SectionID>]
    private let initialSection: SectionID?
    private let navigation: SettingsNavigation<SectionID, Destination>?
    private let sidebarEdgeStyle: ScrollEdgeEffectStyle
    private let detailEdgeStyle: ScrollEdgeEffectStyle
    private let destinationTitle: (Destination) -> String
    private let content: (SectionID) -> Content
    private let destinationContent: (Destination) -> DestinationContent

    /// Creates a settings window with typed detail destinations.
    ///
    /// The builders provide Form rows and sections, including arbitrary custom
    /// views. Titles are localized strings supplied by the application.
    public init(
        _ title: String = "Settings",
        id: String = "settings",
        groups: [SettingsGroup<SectionID>],
        initialSection: SectionID? = nil,
        sidebarEdgeStyle: ScrollEdgeEffectStyle = .automatic,
        detailEdgeStyle: ScrollEdgeEffectStyle = .automatic,
        destinationTitle: @escaping (Destination) -> String,
        @ContentBuilder content: @escaping (SectionID) -> Content,
        @ContentBuilder destinationContent: @escaping (Destination) -> DestinationContent
    ) {
        self.title = title
        identifier = id
        self.groups = groups
        self.initialSection = initialSection
        navigation = nil
        self.sidebarEdgeStyle = sidebarEdgeStyle
        self.detailEdgeStyle = detailEdgeStyle
        self.destinationTitle = destinationTitle
        self.content = content
        self.destinationContent = destinationContent
    }

    /// Creates a settings window with typed detail destinations whose
    /// navigation state the caller owns.
    ///
    /// Select a section through `navigation` before opening the window with
    /// `openWindow(id:)` to open settings at that section, or while the window
    /// is open to switch to it. The navigation state, including its history,
    /// persists when the window is closed and reopened.
    public init(
        _ title: String = "Settings",
        id: String = "settings",
        groups: [SettingsGroup<SectionID>],
        navigation: SettingsNavigation<SectionID, Destination>,
        sidebarEdgeStyle: ScrollEdgeEffectStyle = .automatic,
        detailEdgeStyle: ScrollEdgeEffectStyle = .automatic,
        destinationTitle: @escaping (Destination) -> String,
        @ContentBuilder content: @escaping (SectionID) -> Content,
        @ContentBuilder destinationContent: @escaping (Destination) -> DestinationContent
    ) {
        self.title = title
        identifier = id
        self.groups = groups
        initialSection = nil
        self.navigation = navigation
        self.sidebarEdgeStyle = sidebarEdgeStyle
        self.detailEdgeStyle = detailEdgeStyle
        self.destinationTitle = destinationTitle
        self.content = content
        self.destinationContent = destinationContent
    }

    public var body: some Scene {
        Window(title, id: identifier) {
            if let navigation {
                SettingsView(
                    groups: groups,
                    navigation: navigation,
                    sidebarEdgeStyle: sidebarEdgeStyle,
                    detailEdgeStyle: detailEdgeStyle,
                    destinationTitle: destinationTitle,
                    content: content,
                    destinationContent: destinationContent
                )
            } else {
                SettingsView(
                    groups: groups,
                    initialSection: initialSection,
                    sidebarEdgeStyle: sidebarEdgeStyle,
                    detailEdgeStyle: detailEdgeStyle,
                    destinationTitle: destinationTitle,
                    content: content,
                    destinationContent: destinationContent
                )
            }
        }
        .defaultSize(width: 940, height: 700)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified)
        .commands {
            SettingsWindowCommands(title: title, identifier: identifier)
            SettingsNavigationCommands()
        }
    }
}

extension SettingsWindow where Destination == Never, DestinationContent == EmptyView {
    /// Creates a settings window that navigates between sidebar sections only.
    public init(
        _ title: String = "Settings",
        id: String = "settings",
        groups: [SettingsGroup<SectionID>],
        initialSection: SectionID? = nil,
        sidebarEdgeStyle: ScrollEdgeEffectStyle = .automatic,
        detailEdgeStyle: ScrollEdgeEffectStyle = .automatic,
        @ContentBuilder content: @escaping (SectionID) -> Content
    ) {
        self.init(
            title,
            id: id,
            groups: groups,
            initialSection: initialSection,
            sidebarEdgeStyle: sidebarEdgeStyle,
            detailEdgeStyle: detailEdgeStyle,
            destinationTitle: unavailableSettingsDestination,
            content: content,
            destinationContent: unavailableSettingsDestination
        )
    }
}

extension SettingsWindow where Destination == Never, DestinationContent == EmptyView {
    /// Creates a settings window that navigates between sidebar sections only,
    /// with navigation state that the caller owns.
    public init(
        _ title: String = "Settings",
        id: String = "settings",
        groups: [SettingsGroup<SectionID>],
        navigation: SettingsNavigation<SectionID, Never>,
        sidebarEdgeStyle: ScrollEdgeEffectStyle = .automatic,
        detailEdgeStyle: ScrollEdgeEffectStyle = .automatic,
        @ContentBuilder content: @escaping (SectionID) -> Content
    ) {
        self.init(
            title,
            id: id,
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

private struct SettingsWindowCommands: Commands {
    let title: String
    let identifier: String
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("\(title)…") {
                openWindow(id: identifier)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
