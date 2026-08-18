//
//  WebRetryView.swift
//  Alpha Academy
//
//  Shown only when the saved page has failed and the one rebuild attempt is
//  spent. Web mode is a permanent decision, so this is a way back onto the page
//  rather than a door into the native trainer.
//

import SwiftUI

struct WebRetryView: View {
    let retry: () -> Void

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            Spacer()

            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(Theme.ink2)
                .frame(width: 116, height: 116)
                .cardSurface(radius: Theme.Radius.card)

            Text("NO CONNECTION")
                .font(.title3.weight(.semibold))
                .tracking(4)
                .foregroundColor(Theme.ink)

            Rectangle()
                .fill(Theme.track)
                .frame(width: 120, height: Theme.hairline)

            Text("Check your network and try again.")
                .font(.caption)
                .tracking(1.6)
                .foregroundColor(Theme.ink2)
                .multilineTextAlignment(.center)

            Spacer()

            // The only action on the screen, so it is the screen's one hot button.
            PrimaryButton(title: "Try Again", systemImage: "arrow.clockwise", action: retry)
                .padding(.horizontal, Theme.Space.xl)
                .padding(.bottom, Theme.Space.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
        .padding(.top, Theme.Space.xxl)
    }
}
