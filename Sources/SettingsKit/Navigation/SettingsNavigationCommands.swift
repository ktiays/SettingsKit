import SwiftUI

/// Adds Back and Forward commands for the focused settings window.
///
/// `SettingsWindow` installs these commands automatically. When embedding
/// `SettingsView` in another scene, add them with the scene's `commands` modifier.
@MainActor
public struct SettingsNavigationCommands: Commands {
    @FocusedValue(\.settingsNavigationActions) private var actions

    /// Creates navigation commands that follow the focused settings view.
    public init() {
    }

    public var body: some Commands {
        CommandGroup(after: .sidebar) {
            Button("Back") {
                actions?.goBack()
            }
            .keyboardShortcut("[", modifiers: .command)
            .disabled(actions?.canGoBack != true)
            Button("Forward") {
                actions?.goForward()
            }
            .keyboardShortcut("]", modifiers: .command)
            .disabled(actions?.canGoForward != true)
        }
    }
}

struct SettingsNavigationActions {
    let canGoBack: Bool
    let canGoForward: Bool
    let goBack: @MainActor () -> Void
    let goForward: @MainActor () -> Void
}

private struct SettingsNavigationActionsKey: FocusedValueKey {
    typealias Value = SettingsNavigationActions
}

extension FocusedValues {
    var settingsNavigationActions: SettingsNavigationActions? {
        get {
            self[SettingsNavigationActionsKey.self]
        }
        set {
            self[SettingsNavigationActionsKey.self] = newValue
        }
    }
}
