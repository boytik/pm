//
//  EncodeStringView.swift
//  Alpha Academy
//
//  The core-skill screen: spell a real string, in order.
//

import SwiftUI

struct EncodeStringView: View {
    @ObservedObject var engine: SessionEngine
    @Environment(\.dynamicTypeSize) private var typeSize

    private var question: Question? { engine.currentQuestion }
    private var position: Int { engine.sequenceProgress.count }

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            if let question {
                header(question)
                target(question)
                tape
                Spacer(minLength: 0)
                options(question)
            }
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.bottom, Theme.Space.l)
        .onChange(of: engine.feedback) { feedback in
            guard let feedback, let question else { return }
            let finished = engine.sequenceProgress.count >= question.expected.count
            let delay = feedback.isCorrect ? 0.5 : 0.9
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if finished {
                    engine.advance()
                } else {
                    engine.clearFeedback()
                }
            }
        }
    }

    // MARK: - Pieces

    private func header(_ question: Question) -> some View {
        VStack(spacing: Theme.Space.xs) {
            if let subtitle = question.promptSubtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundColor(Theme.ink2)
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// Each character is its own view so the cursor can underline exactly
    /// one of them. A single Text with an AttributedString would lose the
    /// per-glyph geometry.
    private func target(_ question: Question) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Space.xs) {
                    ForEach(Array(question.promptText.enumerated()), id: \.offset) { index, character in
                        VStack(spacing: 4) {
                            Text(String(character))
                                .font(.system(.title2, design: .monospaced).weight(.medium))
                                .foregroundColor(color(at: index))
                            Rectangle()
                                .fill(index == position ? Theme.blue : Color.clear)
                                .frame(height: 2)
                        }
                        .frame(minWidth: 22)
                        .id(index)
                    }
                }
                .padding(.horizontal, Theme.Space.s)
            }
            .padding(.vertical, Theme.Space.m)
            .cardSurface()
            // Keeping the cursor on screen is the thing that breaks first
            // on long strings like an email address.
            .onChange(of: position) { newValue in
                withAnimation { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
    }

    private func color(at index: Int) -> Color {
        if index < position { return Theme.positive }
        if index == position { return Theme.ink }
        return Theme.ink2
    }

    private var tape: some View {
        Text(engine.sequenceProgress.joined(separator: " · "))
            .font(.system(.footnote, design: .monospaced))
            .foregroundColor(Theme.ink2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(2)
            .animation(.easeOut(duration: 0.2), value: engine.sequenceProgress.count)
    }

    @ViewBuilder
    private func options(_ question: Question) -> some View {
        if position < question.sequenceOptions.count {
            let pool = question.sequenceOptions[position]
            let columns = typeSize.isAccessibilitySize
                ? [GridItem(.flexible())]
                : [GridItem(.flexible()), GridItem(.flexible())]

            LazyVGrid(columns: columns, spacing: Theme.Space.m) {
                ForEach(pool, id: \.self) { option in
                    AnswerOptionButton(
                        title: option,
                        state: state(for: option, question: question)
                    ) {
                        engine.submitSequence(option: option)
                    }
                }
            }
        }
    }

    private func state(for option: String, question: Question) -> AnswerState {
        guard let feedback = engine.feedback else { return .idle }
        let expected = position > 0 && position <= question.expected.count
            ? question.expected[position - 1]
            : ""
        if option == expected { return feedback.isCorrect ? .correct : .revealedCorrect }
        return feedback.isCorrect ? .disabled : .wrong
    }
}
