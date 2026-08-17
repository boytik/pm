//
//  RootView.swift
//  Alpha Academy
//

import SwiftUI
import UIKit

struct RootView: View {
    @StateObject private var store = AppStore()
    @StateObject private var router = AppRouter()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            switch router.phase {
            case .splash:
                SplashView().transition(.opacity)
            case .onboarding:
                OnboardingFlowView().transition(.opacity)
            case .main:
                MainTabView().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: router.phase)
        .environmentObject(store)
        .environmentObject(router)
        .tint(Theme.accent)
        .task {
            #if DEBUG
            if DebugSelfCheck.isRequested { DebugSelfCheck.run(on: store) }
            #endif
            // Hold the splash briefly so it does not flash and vanish, then
            // route on whether onboarding is done.
            try? await Task.sleep(nanoseconds: 900_000_000)
            store.refreshStreakIfNeeded()
            router.phase = store.profile.hasOnboarded ? .main : .onboarding
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var router: AppRouter

    init() {
        // The default translucent material fights the paper background,
        // and the hairline rule replaces the default blur shadow.
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.surface)
        appearance.shadowColor = UIColor(Theme.rule)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $router.selectedTab) {
            ForEach(AppTab.allCases) { tab in
                content(for: tab)
                    .tag(tab)
                    .tabItem { Label(tab.title, systemImage: tab.symbolName) }
            }
        }
    }

    @ViewBuilder
    private func content(for tab: AppTab) -> some View {
        switch tab {
        case .home:     HomeView()
        case .learn:    LearnView()
        case .practice: PracticeHubView()
        case .progress: ProgressDashboardView()
        case .chart:    ChartReferenceView()
        }
    }
}
