//
//  QuizView.swift
//  Alpha Academy
//

import SwiftUI

/// Answer options live in a fixed block at the bottom so they do not shift
/// between questions — a moving target makes thumbs miss.
struct QuizView: View {
    @ObservedObject var engine: SessionEngine
    @EnvironmentObject private var store: AppStore
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var shakeTrigger: CGFloat = 0
    @State private var timer: Timer?

    private var question: Question? { engine.currentQuestion }

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            Spacer(minLength: 0)

            if let question {
                prompt(question)

                if engine.mode == .speed {
                    ComboMeter(combo: engine.combo, score: engine.score)
                }
            }

            Spacer(minLength: 0)

            if let question {
                options(question)
            }
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.bottom, Theme.Space.l)
        .modifier(ShakeEffect(travel: 6, animatableData: shakeTrigger))
        .onAppear(perform: startTimerIfNeeded)
        .onDisappear { timer?.invalidate() }
        .onChange(of: engine.feedback) { feedback in
            guard let feedback else { return }
            if !feedback.isCorrect, !reduceMotion {
                withAnimation(.linear(duration: 0.24)) { shakeTrigger += 1 }
            }
            // Wrong answers hold longer so the revealed word is readable.
            // Speed Mode is the one place where waiting is worse than not
            // learning, so it barely pauses at all.
            let delay: Double = engine.mode == .speed
                ? 0.2
                : (feedback.isCorrect ? 0.65 : 1.2)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                engine.advance()
            }
        }
    }

    // MARK: - Prompt

    @ViewBuilder
    private func prompt(_ question: Question) -> some View {
        VStack(spacing: Theme.Space.m) {
            if let subtitle = question.promptSubtitle {
                Text(subtitle).sectionHeaderStyle()
            }

            if question.kind == .chooseLetter {
                Text(question.promptText.uppercased())
                    .font(.system(size: 44, weight: .semibold))
                    .tracking(3)
                    .foregroundColor(Theme.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            } else {
                Text(question.promptText)
                    .font(AppFont.hero(typeSize.isAccessibilitySize ? 64 : 104))
                    .foregroundColor(Theme.ink)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.xl)
        .cardSurface(radius: Theme.Radius.large)
    }

    // MARK: - Options

    private var columns: [GridItem] {
        typeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
    }

    private func options(_ question: Question) -> some View {
        LazyVGrid(columns: columns, spacing: Theme.Space.m) {
            ForEach(question.options, id: \.self) { option in
                AnswerOptionButton(
                    title: option,
                    state: state(for: option, question: question)
                ) {
                    engine.submit(option: option)
                }
            }
        }
    }

    private func state(for option: String, question: Question) -> AnswerState {
        guard let feedback = engine.feedback else { return .idle }
        let isAnswer = question.expected.first == option
        if isAnswer { return feedback.isCorrect ? .correct : .revealedCorrect }
        return feedback.isCorrect ? .disabled : .wrong
    }

    // MARK: - Speed timer

    private func startTimerIfNeeded() {
        guard engine.mode == .speed else { return }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            engine.tick()
        }
    }
}

// MARK: - Answer option

enum AnswerState {
    case idle
    case correct
    case wrong
    /// "This was the answer" — distinguished by a dash pattern rather than
    /// a new hue, which keeps the palette small.
    case revealedCorrect
    case disabled
}

struct AnswerOptionButton: View {
    let title: String
    var subtitle: String?
    let state: AnswerState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(AppFont.codeWordCompact)
                    .foregroundColor(foreground)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(Theme.inkSecondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, Theme.Space.s)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                    .strokeBorder(border, style: strokeStyle)
            )
            .overlay(alignment: .topTrailing) { glyph }
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(state != .idle)
        .animation(.easeOut(duration: 0.18), value: state)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
    }

    @ViewBuilder
    private var glyph: some View {
        switch state {
        case .correct:
            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundColor(Theme.correct)
                .padding(6)
        case .wrong:
            Image(systemName: "xmark")
                .font(.caption.weight(.bold))
                .foregroundColor(Theme.wrong)
                .padding(6)
        default:
            EmptyView()
        }
    }

    private var background: Color {
        switch state {
        case .correct:  return Theme.correct.opacity(0.12)
        case .wrong:    return Theme.wrong.opacity(0.12)
        default:        return Theme.surface
        }
    }

    private var border: Color {
        switch state {
        case .correct, .revealedCorrect: return Theme.correct
        case .wrong:                     return Theme.wrong
        default:                         return Theme.rule
        }
    }

    private var strokeStyle: StrokeStyle {
        switch state {
        case .revealedCorrect: return StrokeStyle(lineWidth: 2, dash: [4, 3])
        case .correct, .wrong: return StrokeStyle(lineWidth: 2)
        default:               return StrokeStyle(lineWidth: Theme.hairline)
        }
    }

    private var foreground: Color {
        state == .disabled ? Theme.inkSecondary : Theme.ink
    }

    private var accessibilityValue: String {
        switch state {
        case .correct:         return "Correct"
        case .wrong:           return "Incorrect"
        case .revealedCorrect: return "This was the correct answer"
        default:               return ""
        }
    }
}

// MARK: - Combo meter

struct ComboMeter: View {
    let combo: Int
    let score: Int

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            Text("\(score)")
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundColor(Theme.ink)

            LinearMeter(
                fraction: Double(min(combo, 20)) / 20,
                height: 5,
                segments: 5
            )
            .frame(width: 90)

            Text(String(format: "×%.1f", ScoringEngine.multiplier(combo: combo)))
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundColor(Theme.accent)
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.vertical, Theme.Space.s)
        .cardSurface(radius: Theme.Radius.small)
    }
}

// MARK: - Shake

/// Amplitude 6pt: felt, but not comic. 12pt+ reads as a game.
struct ShakeEffect: GeometryEffect {
    var travel: CGFloat = 6
    var shakes: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: travel * sin(animatableData * .pi * shakes),
                y: 0
            )
        )
    }
}
