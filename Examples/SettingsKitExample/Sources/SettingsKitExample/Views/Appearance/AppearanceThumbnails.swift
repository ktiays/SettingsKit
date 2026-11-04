import SwiftUI

struct ColorSchemeThumbnail: View {
    let option: ColorSchemeOption

    var body: some View {
        ZStack {
            PreviewWallpaper()
            if option == .automatic {
                miniatureWindow(isDark: false)
                miniatureWindow(isDark: true)
                    .mask(DiagonalAppearanceMask())
            } else {
                miniatureWindow(isDark: option == .dark)
            }
        }
        .accessibilityHidden(true)
    }

    private func miniatureWindow(isDark: Bool) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                Circle().fill(.red)
                Circle().fill(.yellow)
                Circle().fill(.green)
                Spacer(minLength: 0)
            }
            .frame(height: 4)

            RoundedRectangle(cornerRadius: 3)
                .fill(isDark ? Color.white.opacity(0.08) : Color.white.opacity(0.9))
                .overlay {
                    RoundedRectangle(cornerRadius: 3).stroke(.primary.opacity(0.12), lineWidth: 0.5)
                }
                .frame(height: 16)

            HStack(spacing: 3) {
                ForEach(0..<2) { _ in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isDark ? Color.white.opacity(0.06) : Color.white.opacity(0.7))
                        .overlay {
                            RoundedRectangle(cornerRadius: 3).stroke(.primary.opacity(0.12), lineWidth: 0.5)
                        }
                }
            }
            .frame(height: 13)
        }
        .padding(5)
        .frame(width: 58, height: 52)
        .background {
            RoundedRectangle(cornerRadius: 7)
                .fill(isDark ? Color(red: 0.025, green: 0.08, blue: 0.13) : Color(red: 0.84, green: 0.9, blue: 0.98))
                .overlay {
                    RoundedRectangle(cornerRadius: 7).stroke(.black.opacity(0.6), lineWidth: 0.5)
                }
        }
        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
    }
}

struct InterfaceStyleThumbnail: View {
    let option: InterfaceStyleOption

    var body: some View {
        ZStack {
            PreviewWallpaper()
            if option == .glass {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Circle().fill(Color.blue.opacity(0.08))
                    }
                    .overlay {
                        Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.7)
                    }
                    .frame(width: 51, height: 51)
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
            } else {
                Circle()
                    .fill(Color(red: 0.02, green: 0.045, blue: 0.065))
                    .overlay {
                        Circle().strokeBorder(.black.opacity(0.8), lineWidth: 1)
                    }
                    .frame(width: 51, height: 51)
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct PreviewWallpaper: View {
    var body: some View {
        Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    Gradient(colors: [Color(red: 0.025, green: 0.35, blue: 0.64), Color(red: 0.01, green: 0.12, blue: 0.27)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height)
                )
            )
            var ribbon = Path()
            ribbon.move(to: CGPoint(x: -size.width * 0.2, y: size.height))
            ribbon.addLine(to: CGPoint(x: size.width * 0.6, y: 0))
            ribbon.addLine(to: CGPoint(x: size.width * 1.1, y: 0))
            ribbon.addLine(to: CGPoint(x: size.width * 0.3, y: size.height))
            ribbon.closeSubpath()
            context.fill(ribbon, with: .color(.cyan.opacity(0.16)))
            var band = Path()
            band.move(to: CGPoint(x: 0, y: size.height * 0.45))
            band.addLine(to: CGPoint(x: size.width * 0.55, y: size.height))
            band.addLine(to: CGPoint(x: size.width, y: size.height * 0.5))
            band.addLine(to: CGPoint(x: size.width, y: size.height * 0.9))
            band.addLine(to: CGPoint(x: size.width * 0.35, y: size.height))
            band.closeSubpath()
            context.fill(band, with: .color(.blue.opacity(0.4)))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.15), lineWidth: 1)
        }
    }
}

private struct DiagonalAppearanceMask: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.width * 0.62, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width * 0.38, y: rect.height))
            path.closeSubpath()
        }
    }
}
