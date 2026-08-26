import SwiftUI

struct AvatarView: View {
    let profile: UserProfile
    var size: CGFloat = 44

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
        Text(initials)
            .font(AppFont.glyph(size * 0.44))
            .foregroundColor(profile.avatar.tint.color)
    }
}
