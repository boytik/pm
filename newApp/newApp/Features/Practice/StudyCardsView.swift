//
//  StudyCardsView.swift
//  Alpha Academy
//

import SwiftUI

struct StudyCardsView: View {
    @ObservedObject var engine: SessionEngine
    @EnvironmentObject private var store: AppStore
    @State private var page = 0

    private var entries: [PhoneticEntry] { engine.alphabet.trainable }

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            TabView(selection: $page) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    ScrollView {
                        LetterCardView(
                            entry: entry,
                            masteryLevel: store.progress(for: entry.symbol).level
                        ) {
                            SpeechService.shared.speak(entry, rate: store.profile.speechRate)
                        }
                        .padding(.horizontal, Theme.Space.l)
                        .padding(.bottom, Theme.Space.l)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: Theme.Space.m) {
                SecondaryButton(title: "Review later", systemImage: "arrow.clockwise") {
                    advance()
                }
                PrimaryButton(title: "Got it", systemImage: "checkmark") {
                    advance()
                }
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.bottom, Theme.Space.l)
        }
        .onChange(of: page) { _ in
            guard store.profile.autoSpeakInStudy, page < entries.count else { return }
            SpeechService.shared.speak(entries[page], rate: store.profile.speechRate)
        }
    }

    private func advance() {
        if page < entries.count - 1 {
            withAnimation { page += 1 }
        } else {
            engine.finish()
        }
    }
}
