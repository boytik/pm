//
//  ChartReferenceView.swift
//  Alpha Academy
//
//  The cheat sheet. Must be scannable in one second while on a call, so
//  it is a real table — fixed-height rows, hairline rules, no card chrome.
//

import SwiftUI

struct ChartReferenceView: View {
    @EnvironmentObject private var store: AppStore
    @State private var query = ""

    private var alphabet: PhoneticAlphabet { store.activeAlphabet }

    private func filtered(_ entries: [PhoneticEntry]) -> [PhoneticEntry] {
        guard !query.isEmpty else { return entries }
        let needle = query.uppercased()
        return entries.filter {
            $0.symbol.contains(needle)
                || $0.word.uppercased().contains(needle)
                || $0.respelling.contains(needle)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    section("Letters", entries: filtered(alphabet.letters))
                    section("Numbers", entries: filtered(alphabet.digits))
                    section("Symbols", entries: filtered(alphabet.punctuation))

                    Text(alphabet.provenance)
                        .font(.caption2)
                        .foregroundColor(Theme.inkSecondary)
                        .padding(.horizontal, Theme.Space.l)
                        .padding(.vertical, Theme.Space.xl)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .searchable(text: $query, prompt: "Search letter or word")
            .navigationTitle("Chart")
            .toolbar { alphabetMenu }
        }
    }

    @ViewBuilder
    private func section(_ title: String, entries: [PhoneticEntry]) -> some View {
        if !entries.isEmpty {
            Section {
                ForEach(entries) { entry in
                    row(entry)
                    Rectangle()
                        .fill(Theme.rule)
                        .frame(height: Theme.hairline)
                        .padding(.leading, Theme.Space.l)
                }
            } header: {
                HStack {
                    Text(title).sectionHeaderStyle()
                    Spacer()
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.vertical, Theme.Space.s)
                .background(Theme.background)
            }
        }
    }

    private func row(_ entry: PhoneticEntry) -> some View {
        let level = store.progress(for: entry.symbol).level

        return Button {
            SpeechService.shared.speak(entry, rate: store.profile.speechRate)
        } label: {
            HStack(spacing: Theme.Space.m) {
                Text(entry.symbol)
                    .font(.system(.title3, design: .serif))
                    .foregroundColor(Theme.ink)
                    .frame(width: 30, alignment: .leading)

                Text(entry.word)
                    .font(.body)
                    .foregroundColor(Theme.ink)

                Spacer(minLength: Theme.Space.s)

                Text(entry.respelling)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(Theme.inkSecondary)
                    .lineLimit(1)

                if entry.kind != .punctuation {
                    LinearMeter(
                        fraction: Double(level) / Double(LetterProgress.maxLevel),
                        height: 4
                    )
                    .frame(width: 26)
                }
            }
            .padding(.horizontal, Theme.Space.l)
            .frame(minHeight: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(entry.symbol), \(entry.word), pronounced \(entry.respelling)"
        )
        .accessibilityHint("Double tap to hear it")
    }

    private var alphabetMenu: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Picker("Alphabet", selection: Binding(
                    get: { store.activeAlphabetID },
                    set: { store.setAlphabet($0) }
                )) {
                    ForEach(AlphabetCatalog.all) { option in
                        Text(option.displayName).tag(option.id)
                    }
                }
            } label: {
                Text(store.activeAlphabet.displayName)
                    .font(.subheadline)
            }
        }
    }
}
