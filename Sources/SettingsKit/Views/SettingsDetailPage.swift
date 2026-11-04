import SwiftUI

struct SettingsDetailPage<SectionID: Hashable, Destination: Hashable, Content: View>: View {
    let title: String
    let edgeStyle: ScrollEdgeEffectStyle
    let navigation: SettingsNavigation<SectionID, Destination>
    let historyTitle: (SettingsLocation<SectionID, Destination>) -> String
    @ContentBuilder let content: () -> Content

    var body: some View {
        Form(content: content)
            .formStyle(.grouped)
            .scrollEdgeEffectStyle(edgeStyle, for: .top)
            .navigationBarBackButtonHidden(true)
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    SettingsHistoryControls(navigation: navigation, title: historyTitle)
                }
            }
            .accessibilityIdentifier("settings.detail")
    }
}
