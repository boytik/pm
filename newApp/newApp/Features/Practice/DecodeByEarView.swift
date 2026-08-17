//
//  DecodeByEarView.swift
//  Alpha Academy
//

import SwiftUI

struct DecodeByEarView: View {
    @ObservedObject var engine: SessionEngine
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var speech = SpeechService.shared

    @State private var input = ""
    @State private var revealed = false
    @FocusState private var isFocused: Bool

    private var question: Question? { engine.currentQuestion }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Space.xl) {
                if let question {
                    if let subtitle = question.promptSubtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundColor(Theme.ink2)
                            .multilineTextAlignment(.center)
                    }

                    // The play control sits above the field: focusing the
                    // field first would put the keyboard over it while the
                    // learner is still listening.
                    playControl(question)

                    field

                    if let feedback = engine.feedback {
                        diff(expected: feedback.correctAnswer)
                    } else {
                        PrimaryButton(title: "Check answer", isEnabled: !input.isEmpty) {
                            isFocused = false
                            engine.submitTranscription(input)
                        }

                        // Without this the mode is unusable for deaf and
                        // hard-of-hearing learners.
                        Button("Show the sequence") {
                            revealed = true
                        }
                        .font(.footnote)
                        .foregroundColor(Theme.ink2)

                        if revealed {
                            Text(question.promptText)
                                .font(.system(.body, design: .monospaced))
                                .tracking(2)
                                .foregroundColor(Theme.ink2)
                        }
                    }
                }
            }
            .padding(Theme.Space.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: engine.index) { _ in
            input = ""
            revealed = false
        }
        .onChange(of: engine.feedback) { feedback in
            guard feedback != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                engine.advance()
            }
        }
    }

    private func playControl(_ question: Question) -> some View {
        VStack(spacing: Theme.Space.s) {
            Button {
                if speech.isSpeaking {
                    speech.stop()
                } else {
                    if engine.sequenceProgress.isEmpty { engine.registerReplay() }
                    speech.speak(question.speechEntries, rate: store.profile.speechRate)
                }
            } label: {
                Image(systemName: speech.isSpeaking ? "pause.fill" : "play.fill")
                    .font(.system(size: 30))
                    .foregroundColor(Theme.blue)
                    .frame(width: 96, height: 96)
                    .overlay(
                        Circle().strokeBorder(Theme.track, lineWidth: 1.5)
                    )
            }
            .accessibilityLabel("Play sequence")

            Text(engine.replayCount == 0
                 ? "Tap to listen"
                 : "Replays used: \(engine.replayCount)")
                .font(.caption)
                .foregroundColor(Theme.ink2)
        }
    }

    private var field: some View {
        TextField("What did you hear?", text: $input)
            .textFieldStyle(.plain)
            .font(.system(.title3, design: .monospaced))
            .multilineTextAlignment(.center)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .keyboardType(.asciiCapable)
            .submitLabel(.done)
            .focused($isFocused)
            .padding(Theme.Space.m)
            .cardSurface()
            .disabled(engine.feedback != nil)
    }

    /// A per-character diff is the most instructive feedback in the app —
    /// worth far more than a bare "Wrong".
    private func diff(expected: String) -> some View {
        let expectedChars = Array(expected.uppercased())
        let givenChars = Array(StringNormalizer.canonical(input))

        return VStack(spacing: Theme.Space.s) {
            Text(engine.feedback?.isCorrect == true ? "Correct" : "Not quite")
                .font(.headline)
                .foregroundColor(engine.feedback?.isCorrect == true ? Theme.positive : Theme.negative)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Space.xs) {
                    ForEach(Array(expectedChars.enumerated()), id: \.offset) { index, character in
                        let matched = index < givenChars.count && givenChars[index] == character
                        VStack(spacing: 2) {
                            Text(String(character))
                                .font(.system(.title3, design: .monospaced))
                                .foregroundColor(matched ? Theme.positive : Theme.negative)
                            if !matched {
                                Text(index < givenChars.count ? String(givenChars[index]) : "–")
                                    .font(.caption2.monospaced())
                                    .foregroundColor(Theme.ink2)
                            }
                        }
                        .frame(minWidth: 20)
                    }
                }
            }
        }
        .padding(Theme.Space.l)
        .frame(maxWidth: .infinity)
        .cardSurface()
    }
}
