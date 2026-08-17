//
//  ScenarioSet.swift
//  Alpha Academy
//

import Foundation

enum ScenarioCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case flight
    case hotel
    case email
    case serial
    case document
    case tracking

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flight:   return "Flight Numbers"
        case .hotel:    return "Hotel Bookings"
        case .email:    return "Email Addresses"
        case .serial:   return "Serial Numbers"
        case .document: return "Passport & Documents"
        case .tracking: return "Tracking Codes"
        }
    }

    var symbolName: String {
        switch self {
        case .flight:   return "airplane"
        case .hotel:    return "bed.double"
        case .email:    return "at"
        case .serial:   return "barcode"
        case .document: return "doc.text"
        case .tracking: return "shippingbox"
        }
    }
}

/// A themed pool of realistic strings to spell out.
struct ScenarioSet: Identifiable, Hashable {
    let id: String
    let category: ScenarioCategory
    let title: String
    /// One line on what this is, shown on the scenario chip.
    let detail: String
    /// The situation line shown above the string during a session.
    let contextLine: String
    /// Hand-checked strings that are always valid.
    let samples: [String]
    /// Generator patterns. `A` = letter, `#` = digit, `?` = alphanumeric.
    /// Anything else is a literal.
    let patterns: [String]
    /// 1…3. Longer, mixed strings score higher.
    let difficulty: Int
}
