//
//  Typography.swift
//  Alpha Academy
//
//  Two bundled families, one system family, three jobs.
//
//    Instrument Serif — the letter glyph, and nothing else.
//    IBM Plex Mono    — every numeral the user reads, plus the pronunciation
//                       key and the encode target string.
//    SF Pro (system)  — interface, headings and body, so Dynamic Type
//                       behaves natively.
//
//  Both bundled faces are OFL. Attribution lives in Settings → About.
//

import SwiftUI

enum AppFont {

    private enum Name {
        static let serif = "InstrumentSerif-Regular"
        static let mono = "IBMPlexMono-Regular"
        static let monoSemibold = "IBMPlexMono-SemiBold"
    }

    // MARK: - The letter

    /// The hero glyph on the light plate, and the glyph in mastery tiles.
    /// Nothing else uses the serif.
    static func glyph(_ size: CGFloat) -> Font {
        .custom(Name.serif, fixedSize: size)
    }

    // MARK: - Numerals

    /// Every number the user reads. `relativeTo` keeps Dynamic Type working
    /// while `monospacedDigit` guarantees a ticking value never shifts layout.
    static func mono(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(Name.mono, size: size, relativeTo: style)
    }

    static func monoSemibold(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(Name.monoSemibold, size: size, relativeTo: style)
    }

    /// Big readouts: XP, score, the correct/total pair on the debrief.
    static let bigNumber = monoSemibold(34, relativeTo: .largeTitle)
    /// Values in a stat row.
    static let statValue = monoSemibold(15, relativeTo: .subheadline)
    /// The Speed Mode timer, on its amber chip.
    static let timer = monoSemibold(15, relativeTo: .subheadline)
    /// Pronunciation key, e.g. "BRAH-VOH".
    static let respelling = mono(13, relativeTo: .footnote)
    /// The string being encoded or decoded.
    static let target = mono(20, relativeTo: .title3)

    // MARK: - Interface

    static let screenTitle = Font.system(size: 26, weight: .semibold)
    static let cardHeading = Font.system(.headline)
    /// The code word under the glyph. Uppercased and tracked at the call site.
    static let codeWord = Font.system(size: 19, weight: .semibold)
    static let codeWordCompact = Font.system(.headline)
    static let microLabel = Font.system(size: 10, weight: .semibold)
}

extension Text {
    /// Tracked uppercase micro-label. Always sits above its value.
    func microLabelStyle(_ color: Color = Theme.ink3) -> some View {
        self
            .font(AppFont.microLabel)
            .tracking(1.3)
            .textCase(.uppercase)
            .foregroundColor(color)
    }

    /// Pronunciation key styling.
    func respellingStyle(_ color: Color = Theme.onPaper2) -> some View {
        self
            .font(AppFont.respelling)
            .tracking(1.5)
            .foregroundColor(color)
    }

    /// The code word beneath the glyph.
    func codeWordStyle(_ color: Color = Theme.onPaper) -> some View {
        self
            .font(AppFont.codeWord)
            .tracking(3)
            .textCase(.uppercase)
            .foregroundColor(color)
    }
}

// Kept so existing call sites keep compiling; forwards to the new style.
extension Text {
    func sectionHeaderStyle() -> some View { microLabelStyle() }
}
