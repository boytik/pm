import SwiftUI

extension Theme {

    enum Layout {

        static let contentWidth: CGFloat = 560

        static let tabBarWidth: CGFloat = 520

        static let sessionHeight: CGFloat = 820
    }
}

extension View {

    func contentColumn(_ width: CGFloat = Theme.Layout.contentWidth) -> some View {
        frame(maxWidth: width)
            .frame(maxWidth: .infinity)
    }
}

private struct AdaptiveNavigationTitle: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content.navigationBarTitleDisplayMode(
            horizontalSizeClass == .regular ? .inline : .large
        )
    }
}

extension View {

    func adaptiveNavigationTitle() -> some View {
        modifier(AdaptiveNavigationTitle())
    }
}
