//
//  SettingsComponents.swift
//  Alpha Academy
//
//  A settings screen built from the design system rather than from `Form`.
//  The stock inset-grouped list carries its own greys, separators and corner
//  radii, none of which match this palette, and `.scrollContentBackground`
//  only hides the backdrop — the rows still look like a different app.
//

import SwiftUI

/// A group of rows under a tracked micro-label, drawn as one card with
/// hairline separators between rows.
struct SettingsGroup<Content: View>: View {
    let title: String
    var footer: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            SectionHeader(title: title)

            VStack(spacing: 0) {
                content
            }
            .cardSurface()

            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundColor(Theme.ink3)
                    .padding(.horizontal, Theme.Space.xs)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Hairline between rows, inset past the leading icon so the rows read as a
/// list rather than as stacked boxes.
struct RowDivider: View {
    var inset: CGFloat = Theme.Space.l

    var body: some View {
        Rectangle()
            .fill(Theme.track)
            .frame(height: Theme.hairline)
            .padding(.leading, inset)
    }
}

/// Label, optional value, optional chevron. The workhorse row.
struct SettingsRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    var showsChevron = false
    var tint: Color = Theme.ink
    var action: (() -> Void)?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        let content = HStack(spacing: Theme.Space.m) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(tint == Theme.ink ? Theme.blue : tint)
                    .frame(width: 22)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundColor(tint)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Theme.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: Theme.Space.s)

            trailing

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.track)
            }
        }
        .padding(.horizontal, Theme.Space.l)
        .frame(minHeight: 52)
        .contentShape(Rectangle())

        if let action {
            Button(action: action) { content }
                .buttonStyle(PressableButtonStyle())
        } else {
            content
        }
    }
}

extension SettingsRow where Trailing == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        showsChevron: Bool = false,
        tint: Color = Theme.ink,
        action: (() -> Void)? = nil
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            showsChevron: showsChevron,
            tint: tint,
            action: action,
            trailing: { EmptyView() }
        )
    }
}

/// A value shown at the trailing edge of a row.
struct RowValue: View {
    let text: String
    var isMono = false

    var body: some View {
        Group {
            if isMono {
                Text(verbatim: text)
                    .font(AppFont.mono(14, relativeTo: .subheadline))
                    .monospacedDigit()
            } else {
                Text(text).font(.subheadline)
            }
        }
        .foregroundColor(Theme.ink2)
    }
}

/// A toggle row. The stock `Toggle` label styling fights the palette, so the
/// label is drawn by `SettingsRow` and only the switch comes from the system.
struct SettingsToggleRow: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    @Binding var isOn: Bool

    var body: some View {
        SettingsRow(
            title: title,
            subtitle: subtitle,
            systemImage: systemImage
        ) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Theme.blue)
        }
    }
}

/// Segmented choice drawn as pills, so the selected state uses the accent
/// rather than the system's grey capsule.
struct SettingsSegmentedRow<T: Hashable>: View {
    let title: String
    var systemImage: String?
    let options: [T]
    let label: (T) -> String
    @Binding var selection: T

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack(spacing: Theme.Space.m) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Theme.blue)
                        .frame(width: 22)
                }
                Text(title).font(.body).foregroundColor(Theme.ink)
                Spacer()
            }

            HStack(spacing: Theme.Space.s) {
                ForEach(options, id: \.self) { option in
                    let isOn = option == selection
                    Button {
                        selection = option
                        Haptics.shared.select()
                    } label: {
                        Text(label(option))
                            .font(.subheadline.weight(isOn ? .semibold : .regular))
                            .foregroundColor(isOn ? .white : Theme.ink2)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: Theme.Radius.button,
                                    style: .continuous
                                )
                                .fill(isOn ? Theme.blue : Theme.chipNeutral)
                            )
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.leading, systemImage == nil ? 0 : 34)
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.vertical, Theme.Space.m)
    }
}
