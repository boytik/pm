//
//  UserProfile.swift
//  Alpha Academy
//

import Foundation
import SwiftUI

/// Academic ranks. Ordered; `RankTier.allCases` is the progression.
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

    /// XP required to reach this tier.
    var threshold: Int {
        switch self {
        case .cadet:         return 0
        case .operatorTier:  return 1_500
        case .instructor:    return 6_000
        case .wingCommander: return 15_000
        }
    }

    /// Number of chevrons/bars drawn by the insignia view. Rank is
    /// communicated by geometry, never by colour.
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

/// How the learner's avatar is drawn. The photo itself never lives in this
/// struct — it is a JPEG on disk, because base64 image data inside the state
/// JSON would multiply the file size and get rewritten on every save.
enum AvatarKind: String, Codable, Hashable {
    case initials
    case symbol
    case photo
}

/// Avatar tints are constrained to the palette on purpose. A free colour
/// picker would let the user paint themselves outside the design system.
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

    /// A small curated set, all in the aviation / radio / academy vein so a
    /// chosen icon still reads as part of this app.
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
    /// Derived from `name` through the active alphabet, e.g. "Echo · Victor".
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
    /// 0.4…0.7. `AVSpeechUtteranceDefaultSpeechRate` is 0.5.
    var speechRate: Double = 0.48
    /// Speaking a card the moment it appears surprises people in quiet rooms.
    var autoSpeakInStudy: Bool = false

    var rank: RankTier { RankTier.forXP(xp) }

    /// Progress through the current rank, 0…1. Full bar at the top rank.
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
