//
//  CoreComponents.swift
//  Alpha Academy
//
//  Shared building blocks. Depth comes from tone separation plus a
//  hairline rule — there are no shadows anywhere in this app.
//

import SwiftUI
import UIKit

// MARK: - Section header

/// Tracked caps plus a rule that runs to the trailing edge. The
/// chart-legend rule is what ties the screens together visually.
struct SectionHeader: View {
    let title: String
    var trailingText: String?

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            Text(title).sectionHeaderStyle()
            Rectangle()
                .fill(Theme.rule)
                .frame(height: Theme.hairline)
            if let trailingText {
                Text(trailingText)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(Theme.inkSecondary)
            }
        }
    }
}

// MARK: - Buttons

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.s) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundColor(isEnabled ? Theme.background : Theme.inkSecondary)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                    .fill(isEnabled ? Theme.accent : Theme.surfaceSunken)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                    .strokeBorder(isEnabled ? Color.clear : Theme.rule, lineWidth: Theme.hairline)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isEnabled)
    }
}

struct SecondaryButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.s) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundColor(Theme.accent)
            .cardSurface(radius: Theme.Radius.small)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Meters

/// A bar that can be continuous or ticked. The ticked variant reads as a
/// scale rather than a loading bar, which is what mastery needs.
struct LinearMeter: View {
    let fraction: Double
    var height: CGFloat = 6
    var fill: Color = Theme.accent
    var segments: Int?

    var body: some View {
        GeometryReader { proxy in
            if let segments, segments > 0 {
                let gap = Theme.Space.xs
                let width = (proxy.size.width - gap * CGFloat(segments - 1)) / CGFloat(segments)
                let filled = Int((Double(segments) * fraction).rounded())
                HStack(spacing: gap) {
                    ForEach(0..<segments, id: \.self) { index in
                        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                            .fill(index < filled ? fill : Theme.rule)
                            .frame(width: width)
                    }
                }
            } else {
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.rule)
                    Capsule()
                        .fill(fill)
                        .frame(width: proxy.size.width * min(1, max(0, fraction)))
                }
            }
        }
        .frame(height: height)
    }
}

/// Butt line caps, not round: a dial reads as an instrument, a rounded
/// ring reads as a consumer progress spinner.
struct ProgressRing: View {
    let fraction: Double
    var lineWidth: CGFloat = 6
    var diameter: CGFloat = 72
    var fill: Color = Theme.accent

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.rule, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0, fraction)))
                .stroke(fill, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                .rotationEffect(.degrees(-90))
            Text("\(Int((fraction * 100).rounded()))%")
                .font(.system(.subheadline, design: .rounded).weight(.semibold).monospacedDigit())
                .foregroundColor(Theme.ink)
        }
        .frame(width: diameter, height: diameter)
    }
}

// MARK: - Stat tile

struct StatTile: View {
    let value: String
    let label: String
    var caption: String?
    var symbolName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            HStack(spacing: Theme.Space.xs) {
                if let symbolName {
                    Image(systemName: symbolName)
                        .font(.caption)
                        .foregroundColor(Theme.inkSecondary)
                }
                Text(label).sectionHeaderStyle()
            }
            Text(value)
                .font(AppFont.statValue.monospacedDigit())
                .foregroundColor(Theme.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundColor(Theme.inkSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.l)
        .cardSurface()
    }
}

// MARK: - Empty state (iOS 16 has no ContentUnavailableView)

struct EmptyStateView: View {
    let symbolName: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Theme.Space.m) {
            Image(systemName: symbolName)
                .font(.system(size: 36))
                .foregroundColor(Theme.inkSecondary.opacity(0.6))
            Text(title)
                .font(.headline)
                .foregroundColor(Theme.ink)
            Text(message)
                .font(.footnote)
                .foregroundColor(Theme.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.xxl)
        .padding(.horizontal, Theme.Space.l)
    }
}

// MARK: - Rank insignia

/// Rank is communicated by geometry, never by colour — coloured tiers are
/// the most game-like thing this app could do.
struct RankInsigniaView: View {
    let rank: RankTier
    var size: CGFloat = 18

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<rank.insigniaMarks, id: \.self) { _ in
                Chevron()
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: size * 0.7, height: size * 0.45)
            }
        }
        .accessibilityHidden(true)
    }

    private struct Chevron: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            return path
        }
    }
}

// MARK: - Haptics

/// Generators are stored, not built at fire time: constructing one per tap
/// costs ~50 ms of Taptic warm-up and the first tap of every question
/// feels dead.
final class Haptics {
    static let shared = Haptics()

    private let impact = UIImpactFeedbackGenerator(style: .light)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    private init() {}

    func prepare() {
        impact.prepare()
        notification.prepare()
        selection.prepare()
    }

    func correct() {
        impact.impactOccurred()
        impact.prepare()
    }

    func wrong() {
        notification.notificationOccurred(.error)
        notification.prepare()
    }

    /// The only .success in the app, which is what makes it mean something.
    func sessionComplete() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    func select() {
        selection.selectionChanged()
        selection.prepare()
    }
}
