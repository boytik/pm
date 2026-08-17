//
//  Theme.swift
//  Alpha Academy
//
//  Dark instrument system. See DESIGN.md — this file is the code side of it.
//
//  Two rules that the rest of the app depends on:
//    - Depth comes from tone, never from shadow. A card is lighter or bluer
//      than its field; nothing is ever floated.
//    - Exactly one `hot` element and exactly one `paper` surface per screen.
//

import SwiftUI
import UIKit

enum Theme {

    // MARK: - Surfaces

    /// Page field. Everything sits on this.
    static let bg = Color(hex: 0x11162C)

    /// Standard card. Lighter than the field.
    static let surface = Color(hex: 0x1C2137)

    /// Session surfaces. Deeper and bluer, not darker.
    static let surfaceDeep = Color(hex: 0x061944)

    /// Rows nested inside a deep card.
    static let surfaceDeepAlt = Color(hex: 0x14264E)

    /// Floating tab bar. The darkest thing on screen.
    static let tabBar = Color(hex: 0x0D1021)

    /// Neutral chips and badges.
    static let chipNeutral = Color(hex: 0x282D41)

    /// The one light surface. Letter cards only.
    static let paper = Color(hex: 0xB6CCFB)

    // MARK: - Accents

    /// Flat fill, no gradient, no glow. Exactly one per screen.
    static let hot = Color(hex: 0xD26A05)
    static let hotPressed = Color(hex: 0xB35309)

    /// All other interactivity. Mastery fill.
    static let blue = Color(hex: 0x2459F5)

    /// Active tab item, combo multiplier.
    static let blueBright = Color(hex: 0x448DFF)

    /// Radial glow under the centre tab item. Nowhere else.
    static let glow = Color(hex: 0x1B3A71)

    // MARK: - Semantic (one value per role)

    static let positive = Color(hex: 0x77D2B4)
    static let negative = Color(hex: 0xF0616B)
    static let amber = Color(hex: 0xEFC26A)
    /// Timer chip fill only. Dark text on top.
    static let amberFill = Color(hex: 0xFFE047)
    /// Empty half of every meter, tile and progress bar.
    static let track = Color(hex: 0x2B3350)

    // MARK: - Text

    static let ink = Color(hex: 0xF2F5FF)
    static let ink2 = Color(hex: 0x8B90AB)
    static let ink3 = Color(hex: 0x6A6F85)
    static let onPaper = Color(hex: 0x0B1220)
    static let onPaper2 = Color(hex: 0x3C4A6B)

    // MARK: - Metrics

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

    /// Height of the floating tab bar plus its bottom inset, so scroll
    /// content can clear it.
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

// MARK: - Surface treatments

extension View {
    /// Standard card: lighter than the field, no border, no shadow.
    func cardSurface(
        radius: CGFloat = Theme.Radius.card,
        fill: Color = Theme.surface
    ) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
        )
    }

    /// Session surface: deeper and bluer than the field.
    func deepSurface(radius: CGFloat = Theme.Radius.card) -> some View {
        cardSurface(radius: radius, fill: Theme.surfaceDeep)
    }

    /// The one light surface. Reserved for the letter.
    func paperSurface(radius: CGFloat = Theme.Radius.card) -> some View {
        cardSurface(radius: radius, fill: Theme.paper)
    }
}
