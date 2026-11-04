import SettingsKit
import SwiftUI

enum ExampleSection: String, Hashable {
    case general
    case appearance
    case desktop
    case notifications
    case sound
    case focus
    case screenTime
    case wiFi
    case bluetooth
    case network
    case privacy
    case passwords
    case users
    case accessibility
    case controlCenter
    case displays
    case keyboard
    case mouse
    case trackpad
    case printers
    case battery
    case dateAndTime
    case language
    case sharing

    @MainActor
    static var groups: [SettingsGroup<Self>] {
        [
            SettingsGroup("Application", id: "application", sections: [
                SettingsSection("General", id: .general, systemImage: "gearshape", iconColor: .gray),
                SettingsSection("Appearance", id: .appearance, systemImage: "paintpalette", iconColor: .blue,
                                keywords: ["Theme", "Color Scheme", "Tabs"]),
                SettingsSection("Desktop & Dock", id: .desktop, systemImage: "dock.rectangle", iconColor: .indigo),
            ]),
            SettingsGroup("Connectivity", id: "connectivity", sections: [
                SettingsSection("Wi-Fi", id: .wiFi, systemImage: "wifi", iconColor: .blue,
                                keywords: ["Wireless"]),
                SettingsSection("Bluetooth", id: .bluetooth, systemImage: "antenna.radiowaves.left.and.right", iconColor: .blue),
                SettingsSection("Network", id: .network, systemImage: "network", iconColor: .blue),
            ]),
            SettingsGroup("Notifications", id: "notifications", sections: [
                SettingsSection("Notifications", id: .notifications, systemImage: "bell.badge", iconColor: .red),
                SettingsSection("Sound", id: .sound, systemImage: "speaker.wave.2", iconColor: .pink),
                SettingsSection("Focus", id: .focus, systemImage: "moon", iconColor: .purple),
                SettingsSection("Screen Time", id: .screenTime, systemImage: "hourglass", iconColor: .indigo),
            ]),
            SettingsGroup("Privacy & Security", id: "privacy", sections: [
                SettingsSection("Privacy & Security", id: .privacy, systemImage: "hand.raised", iconColor: .blue),
                SettingsSection("Passwords", id: .passwords, systemImage: "key", iconColor: .gray),
                SettingsSection("Users & Groups", id: .users, systemImage: "person.2", iconColor: .gray),
            ], isInitiallyExpanded: false),
            SettingsGroup("Hardware", id: "hardware", sections: [
                SettingsSection("Accessibility", id: .accessibility, systemImage: "accessibility", iconColor: .blue),
                SettingsSection("Control Center", id: .controlCenter, systemImage: "switch.2", iconColor: .gray),
                SettingsSection("Displays", id: .displays, systemImage: "display", iconColor: .blue),
                SettingsSection("Keyboard", id: .keyboard, systemImage: "keyboard", iconColor: .gray),
                SettingsSection("Mouse", id: .mouse, systemImage: "computermouse", iconColor: .gray),
                SettingsSection("Trackpad", id: .trackpad, systemImage: "rectangle.and.hand.point.up.left", iconColor: .gray),
                SettingsSection("Printers & Scanners", id: .printers, systemImage: "printer", iconColor: .gray),
                SettingsSection("Battery", id: .battery, systemImage: "battery.100percent", iconColor: .green),
            ]),
            SettingsGroup(id: "system", sections: [
                SettingsSection("Date & Time", id: .dateAndTime, systemImage: "clock", iconColor: .gray),
                SettingsSection("Language & Region", id: .language, systemImage: "globe", iconColor: .blue),
                SettingsSection("Sharing", id: .sharing, systemImage: "folder", iconColor: .blue),
            ]),
        ]
    }
}

enum ExampleDestination: Hashable {
    case about
    case storage
    case networkDetails

    var title: String {
        switch self {
        case .about:
            "About"
        case .storage:
            "Storage"
        case .networkDetails:
            "Network Details"
        }
    }
}
