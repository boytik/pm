//
//  Theme.swift
//  Alpha Academy
//
//  Academic / aviation-chart palette. Muted, typographic, precise.
//  Every colour is defined here in both light and dark form so the values
//  are reviewable in one place rather than buried in the asset catalog.
//

import SwiftUI
import UIKit

enum Theme {

    // MARK: - Colour

    /// Warm paper ground the whole app sits on.
    static let background = dynamic(light: 0xF5F2EC, dark: 0x131211)

    /// Cards, rows, and the letter card face.
    static let surface = dynamic(light: 0xFDFBF7, dark: 0x1D1B19)

    /// Slightly recessed surface for grouped rows inside a card.
    static let surfaceSunken = dynamic(light: 0xEFEAE1, dark: 0x24211E)

    /// Primary text.
    static let ink = dynamic(light: 0x1C1B19, dark: 0xEDE9E0)

    /// Secondary text, captions, respellings.
    static let inkSecondary = dynamic(light: 0x6B6862, dark: 0x9A948A)

    /// Hairline borders. The app uses strokes, never soft shadows.
    static let rule = dynamic(light: 0xD8D2C6, dark: 0x34312C)

    /// The single accent — a desaturated chart navy.
    static let accent = dynamic(light: 0x2C4A63, dark: 0x7FA8C9)

    /// Accent wash for fills behind the accent colour.
    static let accentSoft = dynamic(light: 0xE3EAF0, dark: 0x23303B)

    /// "Weak / due for review" amber.
    static let weak = dynamic(light: 0xB8873A, dark: 0xD6A85C)

    /// Correct-answer green. Muted on purpose — no arcade green.
    static let correct = dynamic(light: 0x3E6B4F, dark: 0x6FA37E)

    /// Wrong-answer rust. Muted on purpose — no alarm red.
    static let wrong = dynamic(light: 0xA34E38, dark: 0xC87A62)

    // MARK: - Metrics

    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let small: CGFloat = 8
        static let card: CGFloat = 12
        static let large: CGFloat = 20
    }

    /// Hairline stroke width. One physical pixel on every current device.
    static let hairline: CGFloat = 1

    // MARK: - Helpers

    nonisolated static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

extension UIColor {
    fileprivate convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Shared surface treatment

extension View {
    /// The standard bordered card: warm surface, hairline rule, no shadow.
    func cardSurface(
        radius: CGFloat = Theme.Radius.card,
        fill: Color = Theme.surface
    ) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(fill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Theme.rule, lineWidth: Theme.hairline)
        )
    }
}
