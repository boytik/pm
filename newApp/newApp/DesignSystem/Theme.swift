import SwiftUI
import UIKit

enum Theme {
    static let bg = Color(hex: 0x11162C)

    static let surface = Color(hex: 0x1C2137)

    static let surfaceDeep = Color(hex: 0x061944)

    static let surfaceDeepAlt = Color(hex: 0x14264E)

    static let tabBar = Color(hex: 0x0D1021)

    static let chipNeutral = Color(hex: 0x282D41)

    static let paper = Color(hex: 0xB6CCFB)

    static let hot = Color(hex: 0xD26A05)
    static let hotPressed = Color(hex: 0xB35309)

    static let blue = Color(hex: 0x2459F5)

    static let blueBright = Color(hex: 0x448DFF)

    static let glow = Color(hex: 0x1B3A71)

    static let positive = Color(hex: 0x77D2B4)
    static let negative = Color(hex: 0xF0616B)
    static let amber = Color(hex: 0xEFC26A)

    static let amberFill = Color(hex: 0xFFE047)

    static let track = Color(hex: 0x2B3350)

    static let ink = Color(hex: 0xF2F5FF)
    static let ink2 = Color(hex: 0x8B90AB)
    static let ink3 = Color(hex: 0x6A6F85)
    static let onPaper = Color(hex: 0x0B1220)
    static let onPaper2 = Color(hex: 0x3C4A6B)

    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let block: CGFloat = 14
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let tile: CGFloat = 9
        static let button: CGFloat = 14
        static let card: CGFloat = 20
        static let tabBar: CGFloat = 28
    }

    static let tabBarClearance: CGFloat = 98

    static let hairline: CGFloat = 1
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension View {
    func cardSurface(
        radius: CGFloat = Theme.Radius.card,
        fill: Color = Theme.surface
    ) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
        )
    }

    func deepSurface(radius: CGFloat = Theme.Radius.card) -> some View {
        cardSurface(radius: radius, fill: Theme.surfaceDeep)
    }

    func paperSurface(radius: CGFloat = Theme.Radius.card) -> some View {
        cardSurface(radius: radius, fill: Theme.paper)
    }
}
