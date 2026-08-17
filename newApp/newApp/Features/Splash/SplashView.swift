//
//  SplashView.swift
//  Alpha Academy
//

import SwiftUI

struct SplashView: View {
    @State private var appeared = false

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            Spacer()

            Text("A")
                .font(AppFont.glyph(72))
                .foregroundColor(Theme.ink)
                .frame(width: 116, height: 116)
                .cardSurface(radius: Theme.Radius.card)

            Text("ALPHA ACADEMY")
                .font(.title3.weight(.semibold))
                .tracking(4)
                .foregroundColor(Theme.ink)

            Rectangle()
                .fill(Theme.track)
                .frame(width: 120, height: Theme.hairline)

            Text("PHONETIC ALPHABET TRAINER")
                .font(.caption)
                .tracking(1.6)
                .foregroundColor(Theme.ink2)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) { appeared = true }
        }
    }
}
