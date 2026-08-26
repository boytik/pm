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

            PrimaryButton(title: "Try Again", systemImage: "arrow.clockwise", action: retry)
                .padding(.horizontal, Theme.Space.xl)
                .padding(.bottom, Theme.Space.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
        .padding(.top, Theme.Space.xxl)
    }
}
