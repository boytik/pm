//
//  SessionContainerView.swift
//  Alpha Academy
//
//  One cover, two stages. The summary renders inside the same cover so
//  the tab bar never flashes between the last answer and the debrief.
//

import SwiftUI

struct SessionContainerView: View {
    let mode: TrainingMode
    let onFinish: (SessionResult) -> Void

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var engine: SessionEngine

    @State private var showExitConfirm = false
    @State private var backgroundedAt: Date?

    /// The engine is built once, from a snapshot taken at presentation
    /// time. The caller passes the alphabet and progress explicitly rather
    /// than reaching for the environment, because @EnvironmentObject is not
    /// available inside init.
    init(
        mode: TrainingMode,
        alphabet: PhoneticAlphabet,
        progress: [String: LetterProgress],
        goalMinutes: Int,
        onFinish: @escaping (SessionResult) -> Void
    ) {
        self.mode = mode
        self.onFinish = onFinish
        _engine = StateObject(
            wrappedValue: SessionEngine(
                mode: mode,
                alphabet: alphabet,
                progress: progress,
                goalMinutes: goalMinutes
            )
        )
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                if engine.stage == .running {
                    SessionHUD(engine: engine) { attemptExit() }
                    modeView
                        // Without this the VStack shrinks to fit and the
                        // whole session floats in the middle of the screen.
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    SessionSummaryView(
                        result: engine.makeResult(),
                        unlocked: store.pendingAchievements,
                        rankUp: store.pendingRankUp
                    ) {
                        onFinish(engine.makeResult())
                        dismiss()
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onAppear { Haptics.shared.prepare() }
        .onDisappear { SpeechService.shared.stop() }
        .confirmationDialog("End this session?", isPresented: $showExitConfirm) {
            Button("End session", role: .destructive) {
                // A partial result still carries real practice data —
                // throwing it away because someone tapped close is worse
                // than recording a short session.
                engine.finish()
            }
            Button("Keep going", role: .cancel) {}
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                if let backgroundedAt {
                    engine.extendDeadline(by: Date().timeIntervalSince(backgroundedAt))
                    self.backgroundedAt = nil
                }
            default:
                backgroundedAt = Date()
                SpeechService.shared.stop()
            }
        }
    }

    @ViewBuilder
    private var modeView: some View {
        switch mode {
        case .study:
            StudyCardsView(engine: engine)
        case .letterToWord, .wordToLetter, .speed, .dailyDrill:
            QuizView(engine: engine)
        case .encode:
            EncodeStringView(engine: engine)
        case .decode:
            DecodeByEarView(engine: engine)
        }
    }

    private func attemptExit() {
        if engine.stage == .summary || engine.index == 0 {
            dismiss()
        } else {
            showExitConfirm = true
        }
    }
}

// MARK: - HUD

struct SessionHUD: View {
    @ObservedObject var engine: SessionEngine
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: Theme.Space.s) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.ink2)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close session")

                Spacer()

                if engine.mode == .speed {
                    Text("\(engine.correctCount) correct")
                        .font(AppFont.mono(13, relativeTo: .footnote))
                        .monospacedDigit()
                        .foregroundColor(Theme.ink2)
                } else {
                    Text("\(min(engine.index + 1, engine.questions.count)) / \(engine.questions.count)")
                        .font(AppFont.mono(13, relativeTo: .footnote))
                        .monospacedDigit()
                        .foregroundColor(Theme.ink2)
                }

                Spacer()

                Group {
                    if let remaining = engine.remainingSeconds {
                        // The timer rides its own amber chip, as in the
                        // reference. It is the loudest small element on the
                        // screen because running out of time is the point.
                        Text(timeString(remaining))
                            .font(AppFont.timer)
                            .monospacedDigit()
                            .foregroundColor(Theme.onPaper)
                            .padding(.horizontal, 10)
                            .frame(height: 26)
                            .background(Capsule().fill(timerFill(remaining)))
                            // Never let VoiceOver re-announce every tick.
                            .accessibilityHidden(true)
                    } else {
                        Color.clear
                    }
                }
                // Height matters: an unconstrained Color.clear is infinitely
                // flexible vertically and stretches the whole HUD row.
                .frame(width: 62, height: 44)
            }

            LinearMeter(
                fraction: engine.remainingSeconds.map { $0 / 60 } ?? engine.progressFraction,
                height: 3,
                fill: engine.remainingSeconds == nil ? Theme.blueBright : Theme.amberFill
            )
        }
        .padding(.horizontal, Theme.Space.m)
        .padding(.bottom, Theme.Space.s)
    }

    private func timeString(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// The chip warms toward the end of the run. Colour is the only signal —
    /// nothing pulses, flashes, or grows.
    private func timerFill(_ remaining: Double) -> Color {
        if remaining < 5 { return Theme.negative }
        if remaining < 10 { return Theme.amber }
        return Theme.amberFill
    }
}
