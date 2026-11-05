import AppKit
import SwiftUI
import Testing

@testable import SettingsKit

@MainActor
@Suite("Settings Layout", .serialized)
struct SettingsLayoutTests {
    @Test(arguments: [660.0, 720.0, 760.0, 940.0])
    func fitsTheProposedWidth(width: Double) {
        let groups = [
            SettingsGroup(
                id: "application",
                sections: [
                    SettingsSection("General", id: "general", systemImage: "gearshape"),
                    SettingsSection("Editor", id: "editor", systemImage: "curlybraces"),
                ])
        ]

        expectContentFits(width: width, groups: groups)
    }

    @Test(arguments: [660.0, 720.0])
    func fitsTheProposedWidthWithoutSections(width: Double) {
        expectContentFits(width: width, groups: [])
    }

    private func expectContentFits(width: Double, groups: [SettingsGroup<String>]) {
        _ = NSApplication.shared
        let content = SettingsView(groups: groups) { _ in
            Section("Display") {
                Toggle("Show line numbers", isOn: .constant(true))
                Toggle(isOn: .constant(true)) {
                    Text("Show bracket scope guide")
                    Text("A vertical line marks the lines between the brackets around the caret.")
                }
            }
        }
        let controller = NSHostingController(rootView: content)
        let proposedSize = CGSize(width: width, height: 640)
        let fittedSize = controller.sizeThatFits(in: proposedSize)

        #expect(fittedSize.width == proposedSize.width)
        #expect(fittedSize.height == proposedSize.height)
    }
}
