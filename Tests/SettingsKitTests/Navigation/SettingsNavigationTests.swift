import Testing
@testable import SettingsKit

private enum TestSection: Hashable {
    case general, appearance, network, unavailable
}

private enum TestDestination: Hashable {
    case about, storage
}

@MainActor
@Suite("Settings Navigation")
struct SettingsNavigationTests {
    private typealias Navigation = SettingsNavigation<TestSection, TestDestination>
    private typealias Location = SettingsLocation<TestSection, TestDestination>

    private func makeNavigation(initial: TestSection = .general) -> Navigation {
        Navigation(sections: [.general, .appearance, .network], initialSection: initial)
    }

    @Test func selectsTheRequestedInitialSection() {
        let navigation = makeNavigation(initial: .appearance)
        #expect(navigation.location == Location(section: .appearance))
        #expect(!navigation.canGoBack)
        #expect(!navigation.canGoForward)
    }

    @Test func fallsBackFromAnUnavailableInitialSection() {
        let navigation = makeNavigation(initial: .unavailable)
        #expect(navigation.location?.section == .general)
    }

    @Test func supportsAnEmptyCatalog() {
        let navigation = Navigation(sections: [])
        navigation.goBack()
        navigation.goForward()
        navigation.push(.about)
        navigation.select(.general)
        #expect(navigation.location == nil)
        #expect(navigation.history.isEmpty)
        #expect(navigation.currentIndex == nil)
        #expect(!navigation.canGoBack)
        #expect(!navigation.canGoForward)
    }

    @Test func restoresTheSectionAndCompleteDetailPath() {
        let navigation = makeNavigation()
        navigation.push(.about)
        navigation.push(.storage)
        navigation.select(.network)
        navigation.goBack()
        #expect(navigation.location == Location(section: .general, path: [.about, .storage]))
        #expect(navigation.canGoForward)
        navigation.goBack()
        #expect(navigation.location == Location(section: .general, path: [.about]))
        navigation.goForward()
        navigation.goForward()
        #expect(navigation.location == Location(section: .network))
        #expect(navigation.history.count == 4)
    }

    @Test func truncatesForwardHistoryAfterNewNavigation() {
        let navigation = makeNavigation()
        navigation.push(.about)
        navigation.select(.network)
        let removedEntry = navigation.history.last!
        navigation.goBack()
        navigation.select(.appearance)
        #expect(!navigation.canGoForward)
        #expect(navigation.history.map(\.location.section) == [.general, .general, .appearance])
        navigation.go(to: removedEntry)
        #expect(navigation.location?.section == .appearance)
    }

    @Test func reselectingASectionPreservesItsDetailPath() {
        let navigation = makeNavigation()
        navigation.push(.about)
        navigation.select(.general)
        navigation.setPath([.about], in: .general)
        navigation.navigate(to: Location(section: .general, path: [.about]))
        #expect(navigation.history.count == 2)
        #expect(navigation.location?.path == [.about])
    }

    @Test func rejectsLatePathWritesFromAnInactiveSection() {
        let navigation = makeNavigation()
        navigation.push(.about)
        navigation.select(.network)
        navigation.setPath([], in: .general)
        #expect(navigation.location == Location(section: .network))
        #expect(navigation.history.count == 3)
    }

    @Test func ordersHistoryMenusFromTheCurrentLocation() {
        let navigation = makeNavigation()
        navigation.push(.about)
        navigation.select(.appearance)
        navigation.select(.network)
        navigation.goBack()
        #expect(navigation.backwardHistory.map(\.location.path) == [[.about], []])
        #expect(navigation.forwardHistory.map(\.location.section) == [.network])
    }

    @Test func historyJumpsDoNotAppendEntries() {
        let navigation = makeNavigation()
        navigation.push(.about)
        let about = navigation.history.last!
        navigation.select(.appearance)
        navigation.select(.network)
        navigation.go(to: about)
        #expect(navigation.location == about.location)
        #expect(navigation.history.count == 4)
        #expect(navigation.currentIndex == 1)
    }

    @Test func keepsWindowHistoriesIndependent() {
        let firstWindow = makeNavigation()
        let secondWindow = makeNavigation()
        firstWindow.push(.about)
        secondWindow.go(to: firstWindow.history.last!)
        #expect(secondWindow.location == Location(section: .general))
        #expect(secondWindow.history.count == 1)
        #expect(!secondWindow.canGoBack)
    }

    @Test func recordsAnAtomicCrossSectionLocation() {
        let navigation = makeNavigation()
        navigation.navigate(to: Location(section: .network, path: [.about, .storage]))
        #expect(navigation.history.count == 2)
        #expect(navigation.location == Location(section: .network, path: [.about, .storage]))
    }

    @Test func ignoresUnavailableDestinations() {
        let navigation = makeNavigation()
        navigation.select(.unavailable)
        navigation.navigate(to: Location(section: .unavailable, path: [.about]))
        #expect(navigation.location == Location(section: .general))
        #expect(navigation.history.count == 1)
    }

    @Test func removingOtherSectionsPreservesTheCurrentEntry() {
        let navigation = makeNavigation()
        navigation.select(.appearance)
        navigation.select(.network)
        let current = navigation.history.last!
        navigation.updateSections([.general, .network])
        #expect(navigation.history.count == 2)
        #expect(navigation.history.last?.id == current.id)
        #expect(navigation.currentIndex == 1)
        #expect(navigation.location?.section == .network)
    }

    @Test func removingTheCurrentSectionRestoresAnEarlierEntry() {
        let navigation = makeNavigation()
        navigation.push(.about)
        navigation.select(.appearance)
        navigation.updateSections([.general, .network])
        #expect(navigation.location == Location(section: .general, path: [.about]))
        #expect(navigation.history.count == 2)
    }

    @Test func removingTheFirstEntryCanRestoreForwardHistory() {
        let navigation = makeNavigation()
        navigation.select(.network)
        navigation.goBack()
        navigation.updateSections([.network])
        #expect(navigation.location == Location(section: .network))
        #expect(navigation.currentIndex == 0)
        #expect(navigation.history.count == 1)
    }

    @Test func emptyingAndRepopulatingTheCatalogSelectsAValidSection() {
        let navigation = makeNavigation()
        let oldEntry = navigation.history[0]
        navigation.updateSections([])
        #expect(navigation.location == nil)
        #expect(navigation.currentIndex == nil)
        navigation.updateSections([.network, .appearance])
        navigation.go(to: oldEntry)
        #expect(navigation.location == Location(section: .network))
        #expect(navigation.history.count == 1)
    }

    @Test func reorderingSectionsDoesNotResetHistory() {
        let navigation = makeNavigation()
        navigation.push(.about)
        let entries = navigation.history
        navigation.updateSections([.network, .general, .appearance, .general])
        #expect(navigation.sections == [.network, .general, .appearance])
        #expect(navigation.history == entries)
        #expect(navigation.location?.path == [.about])
    }

    @Test func aDetailPopParticipatesInGlobalHistory() {
        let navigation = makeNavigation()
        navigation.push(.about)
        navigation.setPath([], in: .general)
        navigation.goBack()
        #expect(navigation.location == Location(section: .general, path: [.about]))
        #expect(navigation.history.count == 3)
    }
}
