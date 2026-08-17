//
//  LearnView.swift
//  Alpha Academy
//
//  Learn is a browser; Practice is a session runner. This tab pushes, it
//  never presents a session.
//

import SwiftUI

struct LearnView: View {
    @EnvironmentObject private var store: AppStore
    @State private var path: [PhoneticEntry] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.xl) {
                    header

                    MasteryGridView(
                        alphabet: store.activeAlphabet,
                        progress: store.progressMap()
                    ) { entry in
                        path.append(entry)
                    }
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.vertical, Theme.Space.l)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Learn")
            .navigationDestination(for: PhoneticEntry.self) { entry in
                LetterDetailView(entry: entry)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text(store.activeAlphabet.displayName)
                .font(.headline)
                .foregroundColor(Theme.ink)
            Text(store.activeAlphabet.subtitle)
                .font(.footnote)
                .foregroundColor(Theme.inkSecondary)
            Text("Tap any letter to study it. Fill height shows how well you know it.")
                .font(.caption)
                .foregroundColor(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.l)
        .cardSurface()
    }
}

struct LetterDetailView: View {
    let entry: PhoneticEntry
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Space.xl) {
                LetterCardView(
                    entry: entry,
                    masteryLevel: store.progress(for: entry.symbol).level
                ) {
                    SpeechService.shared.speak(entry, rate: store.profile.speechRate)
                }

                statsBlock
            }
            .padding(Theme.Space.l)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statsBlock: some View {
        let progress = store.progress(for: entry.symbol)
        return VStack(alignment: .leading, spacing: Theme.Space.m) {
            SectionHeader(title: "Your record")
            HStack(spacing: Theme.Space.m) {
                StatTile(value: "\(progress.correct)", label: "Correct")
                StatTile(value: "\(progress.wrong)", label: "Missed")
            }
            HStack(spacing: Theme.Space.m) {
                StatTile(
                    value: "\(progress.level)/\(LetterProgress.maxLevel)",
                    label: "Level"
                )
                StatTile(
                    value: progress.answered == 0
                        ? "—"
                        : "\(Int(progress.accuracy * 100))%",
                    label: "Accuracy"
                )
            }
        }
    }
}
