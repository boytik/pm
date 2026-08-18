//
//  RootView.swift
//  Alpha Academy
//

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
        // The native screens are dark by design. The remote page is not ours:
        // forcing the scheme there both leaks `prefers-color-scheme: dark` into
        // a funnel that may only be styled light, and paints the status bar
        // white over it — unreadable, now that the shell ignores the safe area.
        .preferredColorScheme(isWebPhase ? nil : .dark)
        .task {
            #if DEBUG
            if DebugSelfCheck.isRequested { DebugSelfCheck.run(on: store) }
            if DebugPushProbe.isRequested { await DebugPushProbe.run() }
            // Lets QA inspect the exported record without tapping through:
            //   SIMCTL_CHILD_AA_EXPORT_PDF=1 xcrun simctl launch --console-pty …
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

            // Settled on an earlier launch — `AppRouter.init` already put us in
            // `.web`, and none of the sequencing below applies. The DEBUG hooks
            // stay above this return so `AA_SELF_CHECK` still reports.
            if case .web(let url) = router.phase {
                #if DEBUG
                print("WEB route: WEB (decided earlier) → \(url.absoluteString)")
                #endif
                return
            }

            // Hold the splash briefly so it does not flash and vanish.
            try? await Task.sleep(nanoseconds: 900_000_000)

            // Asked here rather than at launch: the app is reliably `.active` by
            // now, so the system alert actually appears. Keeping it on the splash
            // also keeps it clear of the notification prompt at the end of
            // onboarding — two stacked system alerts read as a shakedown.
            await TrackingAuthorization.requestIfNeeded()

            // Ordering here is structural, not a race to win: the call above
            // does not return until the learner has answered the system alert,
            // and the gate is the next statement in the same task.
            //
            // The status check covers the one case where no alert appeared —
            // a launch that never became `.active`, so `requestIfNeeded` gave
            // up. The decision is once per install; do not spend it on a launch
            // the learner never saw.
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

/// Custom bar rather than SwiftUI's `TabView` chrome: the reference's floating
/// pill with a glowing centre item cannot be expressed through
/// `UITabBarAppearance`, and the system bar would fight the dark field.
struct MainTabView: View {
    @EnvironmentObject private var router: AppRouter

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
                // The glow marks the primary action. Nowhere else in the app.
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
