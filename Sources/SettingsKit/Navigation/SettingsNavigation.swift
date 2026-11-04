import Observation

/// The in-memory navigation state for one settings view or window.
///
/// `SettingsView` creates and injects this object into its content's environment.
/// Read it with `@Environment(SettingsNavigation<SectionID, Destination>.self)`
/// to select sections or navigate programmatically. Standard `NavigationLink`
/// values of type `Destination` participate in the same history.
@MainActor
@Observable
public final class SettingsNavigation<SectionID: Hashable, Destination: Hashable> {
    /// The available section identifiers, in sidebar order.
    public private(set) var sections: [SectionID]

    /// The complete history, including entries after the current position.
    public private(set) var history: [SettingsHistoryEntry<SectionID, Destination>]

    /// The current history position, or `nil` when no sections are available.
    public private(set) var currentIndex: Int?

    /// Creates independent navigation state for a settings window.
    ///
    /// An unavailable initial section falls back to the first available section.
    /// An empty section collection starts without a selected location.
    public init(sections: [SectionID], initialSection: SectionID? = nil) {
        var seen: Set<SectionID> = []
        let availableSections = sections.filter {
            seen.insert($0).inserted
        }
        self.sections = availableSections
        let selection = initialSection.flatMap {
            seen.contains($0) ? $0 : nil
        } ?? availableSections.first
        if let selection {
            history = [SettingsHistoryEntry(location: SettingsLocation(section: selection))]
            currentIndex = 0
        } else {
            history = []
            currentIndex = nil
        }
    }

    /// The current complete location, or `nil` for an empty settings catalog.
    public var location: SettingsLocation<SectionID, Destination>? {
        currentIndex.map {
            history[$0].location
        }
    }

    /// Whether a previous history entry is available.
    public var canGoBack: Bool {
        currentIndex.map {
            $0 > 0
        } ?? false
    }

    /// Whether a subsequent history entry is available.
    public var canGoForward: Bool {
        currentIndex.map {
            $0 + 1 < history.count
        } ?? false
    }

    /// Previous entries ordered from nearest to oldest.
    public var backwardHistory: [SettingsHistoryEntry<SectionID, Destination>] {
        guard let currentIndex else {
            return []
        }
        return Array(history.prefix(currentIndex).reversed())
    }

    /// Subsequent entries ordered from nearest to newest.
    public var forwardHistory: [SettingsHistoryEntry<SectionID, Destination>] {
        guard let currentIndex else {
            return []
        }
        return Array(history.dropFirst(currentIndex + 1))
    }

    /// Selects another section's root page.
    ///
    /// Reselecting the current section preserves its detail path. Selecting an
    /// unavailable section has no effect.
    public func select(_ section: SectionID) {
        guard location?.section != section else {
            return
        }
        navigate(to: SettingsLocation(section: section))
    }

    /// Pushes a detail destination and records the resulting complete location.
    public func push(_ destination: Destination) {
        guard var location else {
            return
        }
        location.path.append(destination)
        navigate(to: location)
    }

    /// Replaces the current detail path and records the resulting location.
    ///
    /// Updates from an inactive section are ignored, including late writes from
    /// a navigation stack that SwiftUI is removing after a section change.
    public func setPath(_ path: [Destination], in section: SectionID) {
        guard location?.section == section else {
            return
        }
        navigate(to: SettingsLocation(section: section, path: path))
    }

    /// Navigates atomically to a section and detail path.
    ///
    /// New navigation removes forward history. Duplicate locations and
    /// unavailable sections have no effect.
    public func navigate(to destination: SettingsLocation<SectionID, Destination>) {
        guard sections.contains(destination.section), destination != location else {
            return
        }
        if let currentIndex {
            history.removeSubrange((currentIndex + 1)..<history.endIndex)
        }
        history.append(SettingsHistoryEntry(location: destination))
        currentIndex = history.count - 1
    }

    /// Restores the previous complete location without appending history.
    public func goBack() {
        guard canGoBack, let currentIndex else {
            return
        }
        self.currentIndex = currentIndex - 1
    }

    /// Restores the next complete location without appending history.
    public func goForward() {
        guard canGoForward, let currentIndex else {
            return
        }
        self.currentIndex = currentIndex + 1
    }

    /// Restores an entry that still belongs to this window's history.
    ///
    /// Entries removed by a new navigation branch, or obtained from another
    /// window, are ignored.
    public func go(to entry: SettingsHistoryEntry<SectionID, Destination>) {
        guard let index = history.firstIndex(where: {
            $0.id == entry.id
        }) else {
            return
        }
        currentIndex = index
    }

    /// Updates available sections and removes history for unavailable sections.
    ///
    /// The current entry is retained when possible. Otherwise, the nearest
    /// preceding retained entry is selected, followed by the first retained
    /// entry or the first available section. An empty catalog clears history.
    public func updateSections(_ sections: [SectionID]) {
        var available: Set<SectionID> = []
        let updated = sections.filter {
            available.insert($0).inserted
        }
        guard updated != self.sections else {
            return
        }
        let currentID = currentIndex.map {
            history[$0].id
        }
        let precedingID = currentIndex.flatMap { index in
            history.prefix(index + 1).last {
                available.contains($0.location.section)
            }?.id
        }
        let retained = history.filter {
            available.contains($0.location.section)
        }
        self.sections = updated
        history = retained
        if let index = retained.firstIndex(where: {
            $0.id == currentID
        }) {
            currentIndex = index
        } else if let index = retained.firstIndex(where: {
            $0.id == precedingID
        }) {
            currentIndex = index
        } else if !retained.isEmpty {
            currentIndex = 0
        } else if let first = updated.first {
            history = [SettingsHistoryEntry(location: SettingsLocation(section: first))]
            currentIndex = 0
        } else {
            currentIndex = nil
        }
    }
}
