import Foundation
import SwiftUI

enum RankTier: String, Codable, CaseIterable, Identifiable, Hashable {
    case cadet
    case operatorTier
    case instructor
    case wingCommander

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cadet:         return "Cadet"
        case .operatorTier:  return "Operator"
        case .instructor:    return "Instructor"
        case .wingCommander: return "Wing Commander"
        }
    }

    var threshold: Int {
        switch self {
        case .cadet:         return 0
        case .operatorTier:  return 1_500
        case .instructor:    return 6_000
        case .wingCommander: return 15_000
        }
    }

    var insigniaMarks: Int {
        switch self {
        case .cadet:         return 1
        case .operatorTier:  return 2
        case .instructor:    return 3
        case .wingCommander: return 4
        }
    }

    static func forXP(_ xp: Int) -> RankTier {
        allCases.last { xp >= $0.threshold } ?? .cadet
    }

    var next: RankTier? {
        guard let index = Self.allCases.firstIndex(of: self),
              index + 1 < Self.allCases.count else { return nil }
        return Self.allCases[index + 1]
    }
}

enum AvatarKind: String, Codable, Hashable {
    case initials
    case symbol
    case photo
}

enum AvatarTint: String, Codable, CaseIterable, Identifiable, Hashable {
    case blue
    case amber
    case positive
    case hot
    case ink

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue:     return Theme.blue
        case .amber:    return Theme.amber
        case .positive: return Theme.positive
        case .hot:      return Theme.hot
        case .ink:      return Theme.ink2
        }
    }
}

struct AvatarConfig: Codable, Hashable {
    var kind: AvatarKind = .initials
    var symbolName: String = "paperplane.fill"
    var tint: AvatarTint = .blue

    static let symbolChoices: [String] = [
        "paperplane.fill", "airplane", "antenna.radiowaves.left.and.right",
        "dot.radiowaves.left.and.right", "waveform", "mic.fill",
        "headphones", "binoculars.fill", "safari.fill", "map.fill",
        "shippingbox.fill", "ticket.fill", "graduationcap.fill", "book.fill",
        "bolt.fill", "target", "flag.fill", "star.fill"
    ]
}

struct UserProfile: Codable, Hashable {
    var name: String = ""
    var avatar = AvatarConfig()

    var callsign: String = ""
    var preferredAlphabet: AlphabetID = .nato
    var dailyGoalMinutes: Int = 10
    var hasOnboarded: Bool = false

    var streakDays: Int = 0
    var longestStreak: Int = 0
    var lastPracticeDay: Date?
    var lastDrillDate: Date?

    var xp: Int = 0
    var unlockedAchievements: Set<String> = []

    var remindersEnabled: Bool = false
    var reminderTime: Date = UserProfile.defaultReminderTime

    var speechRate: Double = 0.48

    var autoSpeakInStudy: Bool = false

    var rank: RankTier { RankTier.forXP(xp) }

    var rankProgress: Double {
        let current = rank
        guard let next = current.next else { return 1 }
        let span = next.threshold - current.threshold
        guard span > 0 else { return 1 }
        return min(1, max(0, Double(xp - current.threshold) / Double(span)))
    }

    var xpIntoRank: Int { xp - rank.threshold }
    var xpForNextRank: Int? { rank.next.map { $0.threshold - rank.threshold } }

    static var defaultReminderTime: Date {
        Calendar.current.date(from: DateComponents(hour: 8, minute: 30)) ?? Date()
    }
}
