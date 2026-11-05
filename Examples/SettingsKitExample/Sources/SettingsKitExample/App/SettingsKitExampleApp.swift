import AppKit
import SettingsKit
import SwiftUI

@main
struct SettingsKitExampleApp: App {
    @NSApplicationDelegateAdaptor(ExampleApplicationDelegate.self) private var applicationDelegate
    @State private var appearance = AppearanceSettingsState(store: .standard)

    var body: some Scene {
        SettingsWindow(
            id: "example-settings",
            groups: ExampleSection.groups,
            initialSection: .appearance,
            destinationTitle: { (destination: ExampleDestination) in
                destination.title
            }
        ) { section in
            ExampleSectionContent(section: section, appearance: appearance)
        } destinationContent: { destination in
            ExampleDestinationContent(destination: destination)
        }
        .defaultLaunchBehavior(.presented)
        .commands {
            ExampleWindowCommands()
        }

        Window("Additional Settings", id: "additional-settings") {
            AdditionalSettingsView()
        }
        .defaultSize(width: 940, height: 700)
        .windowToolbarStyle(.unified)
        .defaultLaunchBehavior(.suppressed)
    }
}

/// The settings store for the additional window, persisted in an SQLite database.
@MainActor
private let additionalSettingsStore: SettingsStore = {
    let url = URL.applicationSupportDirectory
        .appending(path: "SettingsKitExample", directoryHint: .isDirectory)
        .appending(path: "AdditionalSettings.sqlite")
    do {
        return SettingsStore(storage: try SQLiteSettingsStorage(url: url))
    } catch {
        return SettingsStore(storage: InMemorySettingsStorage())
    }
}()

private struct AdditionalSettingsView: View {
    @State private var appearance = AppearanceSettingsState(store: additionalSettingsStore)

    var body: some View {
        SettingsView(
            groups: ExampleSection.groups,
            initialSection: .general,
            destinationTitle: { (destination: ExampleDestination) in
                destination.title
            }
        ) { section in
            ExampleSectionContent(section: section, appearance: appearance)
        } destinationContent: { destination in
            ExampleDestinationContent(destination: destination)
        }
        .settingsStore(additionalSettingsStore)
    }
}

private struct ExampleWindowCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("Example") {
            Button("Open Additional Settings Window") {
                openWindow(id: "additional-settings")
            }
            Divider()
            Button("Use Compact Window Size") {
                NSApp.keyWindow?.setContentSize(NSSize(width: 660, height: 720))
            }
            Button("Use Default Window Size") {
                NSApp.keyWindow?.setContentSize(NSSize(width: 940, height: 700))
            }
        }
    }
}

@MainActor
private final class ExampleApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
