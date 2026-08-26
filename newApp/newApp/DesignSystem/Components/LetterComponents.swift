import SwiftUI

struct LetterCardView: View {
    let entry: PhoneticEntry
    var masteryLevel: Int = 0
    var showsMnemonic = true
    var onSpeak: (() -> Void)?

    @ScaledMetric(relativeTo: .largeTitle) private var rawGlyph: CGFloat = 120
    @Environment(\.dynamicTypeSize) private var typeSize

    private var glyphSize: CGFloat {
        typeSize.isAccessibilitySize ? 64 : min(rawGlyph, 150)
    }

    var body: some View {
        VStack(spacing: Theme.Space.s) {
            HStack {
                LinearMeter(
                    fraction: Double(masteryLevel) / Double(LetterProgress.maxLevel),
                    height: 4,
                    fill: Theme.blue,
                    segments: LetterProgress.maxLevel
                )
                .frame(width: 64)

                Spacer()

                if let onSpeak {
                    Button(action: onSpeak) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.blue)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Theme.blue.opacity(0.12)))
                    }
                    .accessibilityLabel("Play pronunciation")
                }
            }

            Text(entry.symbol)
                .font(AppFont.glyph(glyphSize))
                .foregroundColor(Theme.onPaper)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

                .frame(height: glyphSize * 0.86)
                .padding(.top, 2)

            Text(entry.word).codeWordStyle()
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(entry.respelling).respellingStyle()

            if showsMnemonic {
                Rectangle()
                    .fill(Theme.onPaper.opacity(0.22))
                    .frame(height: Theme.hairline)
                    .padding(.top, Theme.Space.s)
                Text(entry.mnemonic)
                    .font(.footnote)
                    .foregroundColor(Theme.onPaper2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Space.l)
        .paperSurface()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Letter \(entry.symbol). Code word \(entry.word). Pronounced \(entry.respelling)."
        )
        .accessibilityValue("Mastery level \(masteryLevel) of \(LetterProgress.maxLevel)")
    }
}

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
            Theme.track

            GeometryReader { proxy in
                Rectangle()
                    .fill(Theme.blue)
                    .frame(height: proxy.size.height * fraction)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }

            Text(symbol)
                .font(AppFont.glyph(21))

                .foregroundColor(fraction >= 0.6 ? .white : Theme.ink2)
        }
        .frame(width: 44, height: 46)

        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                .strokeBorder(
                    isSelected ? Theme.blueBright : Color.clear,
                    lineWidth: 1.5
                )
        )
        .animation(reduceMotion ? nil : .easeOut(duration: 0.45), value: fraction)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(symbol)
        .accessibilityValue("Mastery \(Int(fraction * 100)) percent")
    }
}

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
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    SectionHeader(
                        title: section.title,
                        trailingText: "\(Int(mastery(of: section.entries) * 100))%"
                    )
                    LinearMeter(fraction: mastery(of: section.entries), height: 4)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 44), spacing: 7)],
                        spacing: 7
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
