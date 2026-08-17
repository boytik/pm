//
//  Typography.swift
//  Alpha Academy
//
//  The type scale carries the primer / flight-chart metaphor:
//  serif for the letter itself, rounded for the code word, monospaced
//  small caps for the pronunciation key.
//

import SwiftUI

enum AppFont {

    /// The hero glyph on a letter card.
    static func hero(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    /// The code word beneath the glyph ("Alfa").
    static let codeWord = Font.system(.title, design: .rounded).weight(.semibold)

    /// A smaller code word for grid cells and answer buttons.
    static let codeWordCompact = Font.system(.headline, design: .rounded)

    /// Pronunciation key ("AL-FAH"). Always uppercased and tracked out.
    static let respelling = Font.system(.subheadline, design: .monospaced)

    /// Section headers — tracked caps, primer style.
    static let sectionHeader = Font.system(.caption, design: .default).weight(.semibold)

    /// Large numerals in stat tiles.
    static let statValue = Font.system(.title2, design: .rounded).weight(.semibold)
}

extension Text {
    /// Pronunciation key styling: uppercase, tracked, secondary ink.
    func respellingStyle() -> some View {
        self
            .font(AppFont.respelling)
            .tracking(1.5)
            .foregroundColor(Theme.inkSecondary)
    }

    /// Tracked caps used for section headers throughout the app.
    func sectionHeaderStyle() -> some View {
        self
            .font(AppFont.sectionHeader)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundColor(Theme.inkSecondary)
    }
}
