//
//  AppRouter.swift
//  Alpha Academy
//

import Combine
import SwiftUI

enum AppPhase {
    case splash
    case onboarding
    case main
}

/// Named `AppTab` rather than `Tab` so it never collides with SwiftUI's
/// own `Tab` type.
enum AppTab: String, Hashable, CaseIterable, Identifiable {
    case home
    case learn
    case practice
    case progress
    case chart

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:     return "Home"
        case .learn:    return "Learn"
        case .practice: return "Practice"
        case .progress: return "Progress"
        case .chart:    return "Chart"
        }
    }

    var symbolName: String {
        switch self {
        case .home:     return "house"
        case .learn:    return "book.closed"
        case .practice: return "target"
        case .progress: return "chart.bar"
        case .chart:    return "tablecells"
        }
    }
}

final class AppRouter: ObservableObject {
    @Published var phase: AppPhase = .splash
    @Published var selectedTab: AppTab = .home

    init() {
        #if DEBUG
        // Lets QA launch straight into a given tab:
        //   xcrun simctl launch --setenv AA_INITIAL_TAB=chart booted <bundle-id>
        if let raw = ProcessInfo.processInfo.environment["AA_INITIAL_TAB"],
           let tab = AppTab(rawValue: raw) {
            selectedTab = tab
        }
        #endif
    }
}
