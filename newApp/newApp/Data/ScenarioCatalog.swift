//
//  ScenarioCatalog.swift
//  Alpha Academy
//
//  Realistic strings to spell out. These are the difference between a
//  flashcard app and a trainer: the skill is reading a whole booking
//  reference aloud without being asked to repeat it.
//

import Foundation

enum ScenarioCatalog {

    static let all: [ScenarioSet] = [flight, hotel, email, serial, document, tracking]

    static func set(for category: ScenarioCategory) -> ScenarioSet {
        all.first { $0.category == category } ?? flight
    }

    // MARK: - Sets

    static let flight = ScenarioSet(
        id: "flight.iata",
        category: .flight,
        title: "Flight Numbers",
        detail: "Airline code plus flight number, as read at the gate.",
        contextLine: "Read your flight number back to the gate agent.",
        samples: ["BA117", "LH441", "AF1680", "KL1234", "EK202", "SQ317",
                  "QF9", "UA900", "AA100", "TK1979", "DL42", "IB6250"],
        patterns: ["AA###", "AA##", "AA####"],
        difficulty: 1
    )

    static let hotel = ScenarioSet(
        id: "hotel.booking",
        category: .hotel,
        title: "Hotel Bookings",
        detail: "Confirmation references from booking systems.",
        contextLine: "Give the front desk your confirmation number.",
        samples: ["BK7291", "HTL4482", "RES9013", "CNF2274", "MRT8801",
                  "BKG3390", "AX7742", "QN5518"],
        patterns: ["AA####", "AAA####", "AA##AA"],
        difficulty: 2
    )

    static let email = ScenarioSet(
        id: "email.address",
        category: .email,
        title: "Email Addresses",
        detail: "Where mis-hearing one letter costs you the whole message.",
        contextLine: "Spell out your email address over the phone.",
        samples: ["j.reid@mail.com", "m_kaur@work.net", "a-lopez@post.org",
                  "t.okafor@mail.com", "s_novak@work.net", "r.haddad@post.org"],
        patterns: [],
        difficulty: 3
    )

    static let serial = ScenarioSet(
        id: "serial.device",
        category: .serial,
        title: "Serial Numbers",
        detail: "Device and warranty codes read to a support agent.",
        contextLine: "Read the serial number from the back of the device.",
        samples: ["C02XK1FZ", "F4H9L2QW", "DNQP7731", "X1C88AR4",
                  "SN44BT19", "MZ7KD003"],
        patterns: ["A##AA#AA", "AA######", "A#A##AA#"],
        difficulty: 3
    )

    static let document = ScenarioSet(
        id: "document.passport",
        category: .document,
        title: "Passport & Documents",
        detail: "Document series and numbers, letter by letter.",
        contextLine: "Read your document number to the desk.",
        samples: ["P7734512", "AB1234567", "NL9920034", "GB4471028",
                  "ID55710", "DL8830921"],
        patterns: ["A#######", "AA#######"],
        difficulty: 2
    )

    static let tracking = ScenarioSet(
        id: "tracking.parcel",
        category: .tracking,
        title: "Tracking Codes",
        detail: "Parcel tracking references, usually long and mixed.",
        contextLine: "Give the courier your tracking reference.",
        samples: ["1Z999AA10123", "RR123456789", "CP441920377",
                  "EE887712340", "LX9910022"],
        patterns: ["AA#########", "#A###AA#####"],
        difficulty: 3
    )

    // MARK: - Generation

    /// Expands one pattern into a concrete string.
    /// `A` = letter, `#` = digit, `?` = alphanumeric, anything else literal.
    static func expand(
        pattern: String,
        using generator: inout some RandomNumberGenerator
    ) -> String {
        let letters = Array("ABCDEFGHIJKLMNPQRSTUVWXYZ")   // no O, avoids 0/O
        let digits = Array("123456789")                    // no 0, same reason
        var out = ""
        for token in pattern {
            switch token {
            case "A": out.append(letters.randomElement(using: &generator) ?? "A")
            case "#": out.append(digits.randomElement(using: &generator) ?? "1")
            case "?":
                let pool = letters + digits
                out.append(pool.randomElement(using: &generator) ?? "A")
            default: out.append(token)
            }
        }
        return out
    }

    /// One string from a set: curated samples and generated patterns mixed,
    /// with `exclude` filtered out so the same reference does not repeat.
    static func string(
        from set: ScenarioSet,
        exclude: [String] = [],
        using generator: inout some RandomNumberGenerator
    ) -> String {
        let fresh = set.samples.filter { !exclude.contains($0) }
        let pool = fresh.isEmpty ? set.samples : fresh

        // Patterns keep the pool from ever running dry.
        if !set.patterns.isEmpty, Bool.random(using: &generator) {
            let pattern = set.patterns.randomElement(using: &generator) ?? set.patterns[0]
            return expand(pattern: pattern, using: &generator)
        }
        return pool.randomElement(using: &generator) ?? "BK7291"
    }
}
