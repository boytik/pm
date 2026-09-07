import SwiftUI

struct RootView: View {
    @StateObject private var store = AppStore()
    @StateObject private var router = AppRouter()

    private var isWebPhase: Bool {
        if case .web = router.phase { return true }
        return false
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            switch router.phase {
            case .splash:
                SplashView().transition(.opacity)
            case .onboarding:
                OnboardingFlowView().transition(.opacity)
            case .main:
                MainTabView().transition(.opacity)
            case .web(let url):
                WebShellView(destination: url).transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: router.phase)
        .environmentObject(store)
        .environmentObject(router)
        .tint(Theme.blue)

        .preferredColorScheme(isWebPhase ? nil : .dark)
        .task {
            #if DEBUG
            if DebugSelfCheck.isRequested { DebugSelfCheck.run(on: store) }
            if DebugPushProbe.isRequested { await DebugPushProbe.run() }

            if ProcessInfo.processInfo.environment["AA_EXPORT_PDF"] == "1" {
                do {
                    let url = try ReportExporter.exportPDF(
                        model: ReportExporter.model(from: store)
                    )
                    print("PDF_EXPORTED \(url.path)")
                } catch {
                    print("PDF_EXPORT_FAILED \(error)")
                }
            }
            #endif

            if case .web(let url) = router.phase {
                #if DEBUG
                print("WEB route: WEB (decided earlier) → \(url.absoluteString)")
                #endif

                await TrackingAuthorization.requestIfNeeded()
                return
            }

            try? await Task.sleep(nanoseconds: 900_000_000)

            await TrackingAuthorization.requestIfNeeded()

            if WebModeStore.decision == nil, TrackingAuthorization.isResolved {
                switch await WebGate.decide() {
                case .web(let url, let pathID):
                    WebModeStore.commitWeb(destination: url, pathID: pathID)
                    #if DEBUG
                    print("WEB route: WEB (decided now) → \(url.absoluteString)")
                    #endif
                    router.phase = .web(url)
                    return
                case .native:
                    WebModeStore.commitNative()
                }
            }

            store.refreshStreakIfNeeded()
            router.phase = store.profile.hasOnboarded ? .main : .onboarding
            #if DEBUG
            print("WEB route: NATIVE → \(router.phase == .main ? "main" : "onboarding")")
            #endif
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var router: AppRouter
    @ObservedObject private var route = PushRoute.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()

            Group {
                switch router.selectedTab {
                case .home:     HomeView()
                case .learn:    LearnView()
                case .practice: PracticeHubView()
                case .progress: ProgressDashboardView()
                case .chart:    ChartReferenceView()
                }
            }

            FloatingTabBar(selection: $router.selectedTab)
        }

        .sheet(item: pushDestination) { destination in
            PushWebSheet(url: destination.url) { route.consume() }
        }
    }

    private var pushDestination: Binding<PushDestination?> {
        Binding(
            get: { route.pendingURL.map(PushDestination.init) },
            set: { if $0 == nil { route.consume() } }
        )
    }
}

struct FloatingTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                item(tab)
            }
        }
        .frame(height: 74)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.tabBar, style: .continuous)
                .fill(Theme.tabBar)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.tabBar, style: .continuous)
                .strokeBorder(Theme.blueBright.opacity(0.10), lineWidth: Theme.hairline)
        )
        .contentColumn(Theme.Layout.tabBarWidth)
        .padding(.horizontal, Theme.Space.m)
        .padding(.bottom, Theme.Space.m)
    }

    private func item(_ tab: AppTab) -> some View {
        let isOn = selection == tab
        let isCentre = tab == .practice

        return Button {
            guard selection != tab else { return }
            selection = tab
            Haptics.shared.select()
        } label: {
            ZStack {
                if isCentre {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Theme.blueBright.opacity(0.55),
                                    Theme.glow.opacity(0.35),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 26
                            )
                        )
                        .frame(width: 52, height: 52)
                        .offset(y: -6)
                }

                VStack(spacing: 5) {
                    Image(systemName: tab.symbolName)
                        .font(.system(size: 18, weight: .regular))
                    Text(tab.title)
                        .font(.system(size: 11, weight: isOn ? .semibold : .regular))
                }
                .foregroundColor(
                    isOn ? Theme.blueBright : (isCentre ? Theme.blueBright.opacity(0.75) : Theme.ink3)
                )
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}
