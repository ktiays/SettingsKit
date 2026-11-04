import SwiftUI

struct SettingsHistoryControls<SectionID: Hashable, Destination: Hashable>: View {
    let navigation: SettingsNavigation<SectionID, Destination>
    let title: (SettingsLocation<SectionID, Destination>) -> String

    var body: some View {
        ControlGroup {
            Menu {
                ForEach(navigation.backwardHistory) { entry in
                    Button(title(entry.location)) {
                        navigation.go(to: entry)
                    }
                }
            } label: {
                Image(systemName: "chevron.backward")
            } primaryAction: {
                navigation.goBack()
            }
            .menuIndicator(.hidden)
            .disabled(!navigation.canGoBack)
            .help("Go Back")
            .accessibilityLabel("Go Back")
            .accessibilityIdentifier("settings.back")

            Menu {
                ForEach(navigation.forwardHistory) { entry in
                    Button(title(entry.location)) {
                        navigation.go(to: entry)
                    }
                }
            } label: {
                Image(systemName: "chevron.forward")
            } primaryAction: {
                navigation.goForward()
            }
            .menuIndicator(.hidden)
            .disabled(!navigation.canGoForward)
            .help("Go Forward")
            .accessibilityLabel("Go Forward")
            .accessibilityIdentifier("settings.forward")
        }
        .controlGroupStyle(.navigation)
    }
}
