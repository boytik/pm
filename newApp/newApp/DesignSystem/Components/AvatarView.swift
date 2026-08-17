//
//  AvatarView.swift
//  Alpha Academy
//

import SwiftUI

/// The learner's mark. Three forms, one shape.
///
/// Initials are derived from the callsign rather than the raw name — "Echo
/// Victor" gives "EV", which keeps even the default avatar on-theme.
struct AvatarView: View {
    let profile: UserProfile
    var size: CGFloat = 44
    /// Rendering into a PDF cannot reach the shared store, so the image is
    /// injectable.
    var photoOverride: UIImage?

    @ObservedObject private var store = AvatarStore.shared

    private var photo: UIImage? { photoOverride ?? store.image }

    private var initials: String {
        let source = profile.callsign.isEmpty ? profile.name : profile.callsign
        let letters = source
            .components(separatedBy: CharacterSet.whitespaces)
            .compactMap { $0.first }
            .prefix(2)
        let text = String(letters).uppercased()
        return text.isEmpty ? "AA" : text
    }

    var body: some View {
        ZStack {
            switch profile.avatar.kind {
            case .photo:
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                } else {
                    // Photo was chosen but the file is gone. Fall back rather
                    // than showing an empty hole.
                    fill
                    initialsLabel
                }

            case .symbol:
                fill
                Image(systemName: profile.avatar.symbolName)
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundColor(profile.avatar.tint.color)

            case .initials:
                fill
                initialsLabel
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle().strokeBorder(profile.avatar.tint.color.opacity(0.35), lineWidth: 1)
        )
        .accessibilityHidden(true)
    }

    private var fill: some View {
        profile.avatar.tint.color.opacity(0.16)
    }

    private var initialsLabel: some View {
        // Serif initials, same face as the letter glyph — the avatar belongs
        // to the same typographic family as the thing being taught.
        Text(initials)
            .font(AppFont.glyph(size * 0.44))
            .foregroundColor(profile.avatar.tint.color)
    }
}
