import Observation
import SettingsKit
import SwiftUI

enum ColorSchemeOption: String, CaseIterable, Identifiable, SettingValue {
    case automatic
    case light
    case dark

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .automatic:
            "Auto"
        case .light:
            "Light"
        case .dark:
            "Dark"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .automatic:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}

enum InterfaceStyleOption: String, CaseIterable, Identifiable, SettingValue {
    case classic
    case glass

    var id: Self {
        self
    }

    var title: String {
        rawValue.capitalized
    }
}

enum TabStyleOption: String, CaseIterable, Identifiable, SettingValue {
    case above
    case leftSide
    case rightSide

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .above:
            "Above"
        case .leftSide:
            "Left Side"
        case .rightSide:
            "Right Side"
        }
    }

    var symbolName: String {
        switch self {
        case .above:
            "rectangle.topthird.inset.filled"
        case .leftSide:
            "sidebar.left"
        case .rightSide:
            "sidebar.right"
        }
    }
}

extension SettingKey where Value == ColorSchemeOption {
    static var colorScheme: Self {
        Self("appearance.colorScheme", defaultValue: .automatic)
    }
}

extension SettingKey where Value == InterfaceStyleOption {
    static var interfaceStyle: Self {
        Self("appearance.interfaceStyle", defaultValue: .glass)
    }
}

extension SettingKey where Value == TabStyleOption {
    static var tabStyle: Self {
        Self("appearance.tabStyle", defaultValue: .leftSide)
    }
}

extension SettingKey where Value == Bool {
    static var tintsWithTheme: Self {
        Self("appearance.tintsWithTheme", defaultValue: true)
    }

    static var usesGlassForPanes: Self {
        Self("appearance.usesGlassForPanes", defaultValue: true)
    }

    static var alwaysShowsTabBar: Self {
        Self("appearance.alwaysShowsTabBar", defaultValue: true)
    }

    static var checksForUpdatesAutomatically: Self {
        Self("general.checksForUpdatesAutomatically", defaultValue: true)
    }
}

extension SettingKey where Value == Double {
    static var tabIconCount: Self {
        Self("appearance.tabIconCount", defaultValue: 3)
    }

    static var textSize: Self {
        Self("appearance.textSize", defaultValue: 13)
    }
}

/// An observable appearance model whose properties are persisted in a settings store.
@MainActor
@Observable
final class AppearanceSettingsState {
    @ObservationIgnored let store: SettingsStore

    init(store: SettingsStore) {
        self.store = store
    }

    var colorScheme: ColorSchemeOption {
        get {
            store[.colorScheme]
        }
        set {
            store[.colorScheme] = newValue
        }
    }

    var interfaceStyle: InterfaceStyleOption {
        get {
            store[.interfaceStyle]
        }
        set {
            store[.interfaceStyle] = newValue
        }
    }

    var tintsWithTheme: Bool {
        get {
            store[.tintsWithTheme]
        }
        set {
            store[.tintsWithTheme] = newValue
        }
    }

    var usesGlassForPanes: Bool {
        get {
            store[.usesGlassForPanes]
        }
        set {
            store[.usesGlassForPanes] = newValue
        }
    }

    var tabStyle: TabStyleOption {
        get {
            store[.tabStyle]
        }
        set {
            store[.tabStyle] = newValue
        }
    }

    var tabIconCount: Double {
        get {
            store[.tabIconCount]
        }
        set {
            store[.tabIconCount] = newValue
        }
    }

    var alwaysShowsTabBar: Bool {
        get {
            store[.alwaysShowsTabBar]
        }
        set {
            store[.alwaysShowsTabBar] = newValue
        }
    }

    var textSize: Double {
        get {
            store[.textSize]
        }
        set {
            store[.textSize] = newValue
        }
    }
}
