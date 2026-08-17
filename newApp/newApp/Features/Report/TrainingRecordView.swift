//
//  TrainingRecordView.swift
//  Alpha Academy
//
//  The page that becomes the shared PDF.
//
//  It is the light counterpart of the app, not a screenshot of it. In this
//  design system `paper` is the printed artefact, so the exported record is
//  the plate at full-page size. A dark PDF would also be miserable to print.
//

import SwiftUI

/// Print-only extensions of the palette. Documented in DESIGN.md — these are
/// the only colours that exist outside the on-screen system.
enum PrintTheme {
    static let page = Color(hex: 0xF3F6FC)
    static let plate = Color(hex: 0xB6CCFB)
    static let ink = Color(hex: 0x0B1220)
    static let ink2 = Color(hex: 0x3C4A6B)
    static let ink3 = Color(hex: 0x8592B0)
    static let rule = Color(hex: 0xC7D3E8)
    static let accent = Color(hex: 0x1F49C4)
    static let track = Color(hex: 0xD9E1F2)
}

struct TrainingRecordView: View {

    struct Model {
        let callsign: String
        let name: String
        let rank: String
        let xp: Int
        let masteryPercent: Int
        let accuracyPercent: Int
        let streakDays: Int
        let sessions: Int
        let practiceMinutes: Int
        let alphabetName: String
        let provenance: String
        let entries: [PhoneticEntry]
        let levels: [String: Int]
        let modeRows: [(title: String, percent: Int)]
        let achievementsUnlocked: Int
        let achievementsTotal: Int
        let dateText: String
        let avatarProfile: UserProfile
        let avatarPhoto: UIImage?
    }

    let model: Model

    /// A4 at 72 dpi.
    static let pageSize = CGSize(width: 595, height: 842)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle().fill(PrintTheme.rule).frame(height: 1)
            identity
            stats
            mastery
            if !model.modeRows.isEmpty { modes }
            Spacer(minLength: 12)
            // The printed sheet is also a cheat sheet. The real moment of
            // use is mid-phone-call, so a record you can pin to a monitor
            // is worth more than a page of white space.
            referenceStrip
            Spacer(minLength: 0)
            footer
        }
        .padding(40)
        .frame(width: Self.pageSize.width, height: Self.pageSize.height)
        .background(PrintTheme.page)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Text("A")
                .font(AppFont.glyph(38))
                .foregroundColor(PrintTheme.ink)
                .frame(width: 46, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(PrintTheme.plate)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("ALPHA ACADEMY")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(3)
                    .foregroundColor(PrintTheme.ink)
                Text("TRAINING RECORD")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(PrintTheme.ink3)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("ISSUED")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1.4)
                    .foregroundColor(PrintTheme.ink3)
                Text(model.dateText)
                    .font(AppFont.mono(12))
                    .foregroundColor(PrintTheme.ink2)
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - Identity

    private var identity: some View {
        HStack(spacing: 16) {
            AvatarView(
                profile: model.avatarProfile,
                size: 62,
                photoOverride: model.avatarPhoto
            )

            VStack(alignment: .leading, spacing: 4) {
                if !model.callsign.isEmpty {
                    Text(model.callsign)
                        .font(.system(size: 30, weight: .semibold))
                        .tracking(2)
                        .foregroundColor(PrintTheme.ink)
                }
                HStack(spacing: 8) {
                    Text(model.rank.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.6)
                        .foregroundColor(PrintTheme.accent)
                    Text("·").foregroundColor(PrintTheme.ink3)
                    Text(model.alphabetName)
                        .font(.system(size: 11))
                        .foregroundColor(PrintTheme.ink2)
                }
                if !model.name.isEmpty {
                    Text(model.name)
                        .font(.system(size: 11))
                        .foregroundColor(PrintTheme.ink3)
                }
            }
            Spacer()
        }
        .padding(.vertical, 20)
    }

    // MARK: - Stats

    private var stats: some View {
        HStack(spacing: 10) {
            statCell("Mastery", "\(model.masteryPercent)%")
            statCell("Accuracy", "\(model.accuracyPercent)%")
            statCell("Streak", "\(model.streakDays)d")
            statCell("Sessions", "\(model.sessions)")
            statCell("XP", "\(model.xp)")
        }
        .padding(.bottom, 24)
    }

    private func statCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .semibold))
                .tracking(1.3)
                .foregroundColor(PrintTheme.ink3)
            Text(verbatim: value)
                .font(AppFont.monoSemibold(19))
                .foregroundColor(PrintTheme.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(PrintTheme.rule, lineWidth: 1)
        )
    }

    // MARK: - Mastery grid

    /// The signature of the whole document: 36 cells filling from the bottom.
    private var mastery: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Alphabet mastery")

            // 13 columns lays the 26 letters out as exactly two rows, with
            // the ten digits on a third. 12 would wrap Y and Z onto the
            // digit row.
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 13),
                spacing: 6
            ) {
                ForEach(model.entries) { entry in
                    let level = model.levels[entry.symbol] ?? 0
                    let fraction = Double(level) / Double(LetterProgress.maxLevel)
                    ZStack {
                        PrintTheme.track
                        GeometryReader { proxy in
                            Rectangle()
                                .fill(PrintTheme.accent)
                                .frame(height: proxy.size.height * fraction)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        }
                        Text(entry.symbol)
                            .font(AppFont.glyph(15))
                            .foregroundColor(fraction >= 0.6 ? .white : PrintTheme.ink2)
                    }
                    .frame(height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        }
        .padding(.bottom, 24)
    }

    // MARK: - Per-mode accuracy

    private var modes: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Accuracy by mode")
            ForEach(model.modeRows, id: \.title) { row in
                HStack(spacing: 12) {
                    Text(row.title)
                        .font(.system(size: 11))
                        .foregroundColor(PrintTheme.ink2)
                        .frame(width: 130, alignment: .leading)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(PrintTheme.track)
                            Capsule()
                                .fill(PrintTheme.accent)
                                .frame(width: proxy.size.width * Double(row.percent) / 100)
                        }
                    }
                    .frame(height: 6)

                    Text(verbatim: "\(row.percent)%")
                        .font(AppFont.mono(11))
                        .foregroundColor(PrintTheme.ink2)
                        .frame(width: 34, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Reference strip

    private var referenceStrip: some View {
        let letters = model.entries.filter { $0.kind == .letter }
        let columns = 3
        let perColumn = Int(ceil(Double(letters.count) / Double(columns)))

        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("\(model.alphabetName) reference")

            HStack(alignment: .top, spacing: 18) {
                ForEach(0..<columns, id: \.self) { column in
                    let slice = letters.dropFirst(column * perColumn).prefix(perColumn)
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(slice)) { entry in
                            HStack(spacing: 8) {
                                Text(entry.symbol)
                                    .font(AppFont.glyph(13))
                                    .foregroundColor(PrintTheme.ink)
                                    .frame(width: 12, alignment: .leading)
                                Text(entry.word)
                                    .font(.system(size: 10))
                                    .foregroundColor(PrintTheme.ink2)
                                Spacer(minLength: 0)
                                Text(entry.respelling)
                                    .font(AppFont.mono(8))
                                    .foregroundColor(PrintTheme.ink3)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        HStack(spacing: 8) {
            Text(text.uppercased())
                .font(.system(size: 8, weight: .semibold))
                .tracking(1.3)
                .foregroundColor(PrintTheme.ink3)
            Rectangle().fill(PrintTheme.rule).frame(height: 1)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle().fill(PrintTheme.rule).frame(height: 1)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.provenance)
                        .font(.system(size: 9))
                        .foregroundColor(PrintTheme.ink3)
                    Text(verbatim: "\(model.practiceMinutes) minutes practised · \(model.achievementsUnlocked) of \(model.achievementsTotal) achievements")
                        .font(.system(size: 9))
                        .foregroundColor(PrintTheme.ink3)
                }
                Spacer()
                Text("ALPHA ACADEMY")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1.6)
                    .foregroundColor(PrintTheme.ink3)
            }
        }
        .padding(.top, 16)
    }
}
