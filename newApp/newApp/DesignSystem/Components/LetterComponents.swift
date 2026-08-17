//
//  LetterComponents.swift
//  Alpha Academy
//

import SwiftUI

// MARK: - Letter card

/// The hero of the app: a primer plate. Large serif glyph, tracked code
/// word, monospaced pronunciation key, double rule.
struct LetterCardView: View {
    let entry: PhoneticEntry
    var masteryLevel: Int = 0
    var showsMnemonic = true
    var onSpeak: (() -> Void)?

    @ScaledMetric(relativeTo: .largeTitle) private var rawGlyph: CGFloat = 108
    @Environment(\.dynamicTypeSize) private var typeSize

    /// At accessibility sizes the glyph *shrinks*. Counter-intuitive, but
    /// correct: the glyph is already the largest thing on screen, and what
    /// the reader needs bigger is the words.
    private var glyphSize: CGFloat {
        typeSize.isAccessibilitySize ? 64 : min(rawGlyph, 150)
    }

    var body: some View {
        VStack(spacing: Theme.Space.m) {
            HStack {
                LinearMeter(
                    fraction: Double(masteryLevel) / Double(LetterProgress.maxLevel),
                    height: 5,
                    segments: LetterProgress.maxLevel
                )
                .frame(width: 68)

                Spacer()

                if let onSpeak {
                    Button(action: onSpeak) {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(Theme.accent)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Play pronunciation")
                }
            }

            doubleRule

            Text(entry.symbol)
                .font(AppFont.hero(glyphSize))
                .foregroundColor(Theme.ink)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(entry.word.uppercased())
                .font(.title2.weight(.semibold))
                .tracking(2)
                .foregroundColor(Theme.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(entry.respelling).respellingStyle()

            if showsMnemonic {
                doubleRule
                Text(entry.mnemonic)
                    .font(.footnote)
                    .foregroundColor(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Space.xl)
        .cardSurface(radius: Theme.Radius.large)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Letter \(entry.symbol). Code word \(entry.word). Pronounced \(entry.respelling)."
        )
        .accessibilityValue("Mastery level \(masteryLevel) of \(LetterProgress.maxLevel)")
    }

    private var doubleRule: some View {
        VStack(spacing: 3) {
            Rectangle().fill(Theme.rule).frame(height: Theme.hairline)
            Rectangle().fill(Theme.rule).frame(height: Theme.hairline)
        }
    }
}

// MARK: - Mastery tile

/// The fill rises from the bottom like liquid in a gauge. That is the
/// spec's "filling sections of the alphabet", and it stays legible across
/// 36 cells in a way a ring per letter would not.
struct MasteryTile: View {
    let symbol: String
    let level: Int
    var isSelected = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var fraction: Double {
        Double(level) / Double(LetterProgress.maxLevel)
    }

    var body: some View {
        ZStack {
            Theme.surfaceSunken

            GeometryReader { proxy in
                Rectangle()
                    .fill(Theme.accent.opacity(0.25 + 0.75 * fraction))
                    .frame(height: proxy.size.height * fraction)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }

            Text(symbol)
                .font(.system(.title3, design: .serif))
                // Computed flip rather than a blend mode: blend modes break
                // in dark mode and under Increase Contrast.
                .foregroundColor(fraction >= 0.6 ? Theme.background : Theme.ink)
        }
        .frame(width: 44, height: 52)
        // clipShape before overlay, or the border loses its outer half-pixel.
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                // strokeBorder insets; stroke would be clipped to half width.
                .strokeBorder(
                    isSelected || level >= LetterProgress.maxLevel ? Theme.accent : Theme.rule,
                    lineWidth: level >= LetterProgress.maxLevel ? 1.5 : Theme.hairline
                )
        )
        .animation(reduceMotion ? nil : .easeOut(duration: 0.45), value: fraction)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(symbol)
        .accessibilityValue("Mastery \(Int(fraction * 100)) percent")
    }
}

/// The alphabet split into named sections, each with its own fill level.
struct MasteryGridView: View {
    let alphabet: PhoneticAlphabet
    let progress: [String: LetterProgress]
    var onSelect: ((PhoneticEntry) -> Void)?

    private struct Section: Identifiable {
        let id: Int
        let title: String
        let entries: [PhoneticEntry]
    }

    private var sections: [Section] {
        let letters = alphabet.letters
        var result: [Section] = []
        let bounds = [(0, 6), (6, 12), (12, 18), (18, 26)]
        let numerals = ["I", "II", "III", "IV"]

        for (index, bound) in bounds.enumerated() where bound.0 < letters.count {
            let slice = Array(letters[bound.0..<min(bound.1, letters.count)])
            guard let first = slice.first, let last = slice.last else { continue }
            // Symbols rather than words: "Section I · A–F" fits on one line
            // beside the rule, where "Alfa–Foxtrot" wraps.
            result.append(
                Section(
                    id: index,
                    title: "Section \(numerals[index]) · \(first.symbol)–\(last.symbol)",
                    entries: slice
                )
            )
        }
        result.append(Section(id: 4, title: "Numbers", entries: alphabet.digits))
        return result
    }

    private func mastery(of entries: [PhoneticEntry]) -> Double {
        guard !entries.isEmpty else { return 0 }
        let total = entries.reduce(0) { $0 + (progress[$1.symbol]?.level ?? 0) }
        return Double(total) / Double(entries.count * LetterProgress.maxLevel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xl) {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    SectionHeader(
                        title: section.title,
                        trailingText: "\(Int(mastery(of: section.entries) * 100))%"
                    )
                    LinearMeter(fraction: mastery(of: section.entries), height: 4)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 44), spacing: Theme.Space.s)],
                        spacing: Theme.Space.s
                    ) {
                        ForEach(section.entries) { entry in
                            let level = progress[entry.symbol]?.level ?? 0
                            if let onSelect {
                                Button { onSelect(entry) } label: {
                                    MasteryTile(symbol: entry.symbol, level: level)
                                }
                                .buttonStyle(PressableButtonStyle())
                            } else {
                                MasteryTile(symbol: entry.symbol, level: level)
                            }
                        }
                    }
                }
            }
        }
    }
}
