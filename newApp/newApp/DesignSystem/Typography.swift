import SwiftUI

enum AppFont {
    private enum Name {
        static let serif = "InstrumentSerif-Regular"
        static let mono = "IBMPlexMono-Regular"
        static let monoSemibold = "IBMPlexMono-SemiBold"
    }

    static func glyph(_ size: CGFloat) -> Font {
        .custom(Name.serif, fixedSize: size)
    }

    static func mono(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(Name.mono, size: size, relativeTo: style)
    }

    static func monoSemibold(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(Name.monoSemibold, size: size, relativeTo: style)
    }

    static let bigNumber = monoSemibold(34, relativeTo: .largeTitle)

    static let statValue = monoSemibold(15, relativeTo: .subheadline)

    static let timer = monoSemibold(15, relativeTo: .subheadline)

    static let respelling = mono(13, relativeTo: .footnote)

    static let target = mono(20, relativeTo: .title3)

    static let screenTitle = Font.system(size: 26, weight: .semibold)
    static let cardHeading = Font.system(.headline)

    static let codeWord = Font.system(size: 19, weight: .semibold)
    static let codeWordCompact = Font.system(.headline)
    static let microLabel = Font.system(size: 10, weight: .semibold)
}

extension Text {
    func microLabelStyle(_ color: Color = Theme.ink3) -> some View {
        self
            .font(AppFont.microLabel)
            .tracking(1.3)
            .textCase(.uppercase)
            .foregroundColor(color)
    }

    func respellingStyle(_ color: Color = Theme.onPaper2) -> some View {
        self
            .font(AppFont.respelling)
            .tracking(1.5)
            .foregroundColor(color)
    }

    func codeWordStyle(_ color: Color = Theme.onPaper) -> some View {
        self
            .font(AppFont.codeWord)
            .tracking(3)
            .textCase(.uppercase)
            .foregroundColor(color)
    }
}

extension Text {
    func sectionHeaderStyle() -> some View { microLabelStyle() }
}
