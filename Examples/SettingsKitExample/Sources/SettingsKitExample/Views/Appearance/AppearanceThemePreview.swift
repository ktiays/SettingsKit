import SwiftUI

struct AppearanceThemePreview: View {
    let settings: AppearanceSettingsState
    let accent: Color
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            if settings.tabStyle == .above, settings.alwaysShowsTabBar {
                tabBar(isVertical: false)
                Divider()
            }
            HStack(spacing: 0) {
                if settings.tabStyle == .leftSide, settings.alwaysShowsTabBar {
                    tabBar(isVertical: true)
                    Divider()
                }
                VStack(alignment: .leading, spacing: 12) {
                    Label(["Overview", "Details", "Options"][selectedTab], systemImage: "paintpalette")
                        .font(.headline)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(accent.opacity(0.2))
                        .frame(height: 12)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.secondary.opacity(0.12))
                        .frame(width: 120, height: 12)
                    Spacer(minLength: 0)
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                if settings.tabStyle == .rightSide, settings.alwaysShowsTabBar {
                    Divider()
                    tabBar(isVertical: true)
                }
            }
        }
        .font(.system(size: settings.textSize))
        .background {
            if settings.interfaceStyle == .glass, settings.usesGlassForPanes {
                RoundedRectangle(cornerRadius: 12).fill(.regularMaterial)
            } else {
                RoundedRectangle(cornerRadius: 12).fill(.background)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12).strokeBorder(.secondary.opacity(0.2), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func tabBar(isVertical: Bool) -> some View {
        let layout = isVertical ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(spacing: 6))
        return layout {
            ForEach(0..<3) { index in
                Button {
                    selectedTab = index
                } label: {
                    HStack(spacing: 6) {
                        if index < Int(settings.tabIconCount) {
                            Image(systemName: ["square.grid.2x2", "list.bullet.rectangle", "slider.horizontal.3"][index])
                        }
                        Text(["Overview", "Details", "Options"][index])
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: isVertical ? .infinity : nil, alignment: .leading)
                    .background(selectedTab == index ? accent.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .accessibilityValue(selectedTab == index ? "Selected" : "Not selected")
            }
            if isVertical {
                Spacer(minLength: 0)
            }
        }
        .padding(10)
        .frame(width: isVertical ? 125 : nil, alignment: .topLeading)
    }
}
