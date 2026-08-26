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

struct ScenarioSet: Identifiable, Hashable {
    let id: String
    let category: ScenarioCategory
    let title: String

    let detail: String

    let contextLine: String

    let samples: [String]

    let patterns: [String]

    let difficulty: Int
}
