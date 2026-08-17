//
//  CommonSymbols.swift
//  Alpha Academy
//
//  Punctuation shared by every alphabet. Needed so email addresses and
//  serial numbers can actually be spelled out. Not mastery-tracked.
//

import Foundation

enum CommonSymbols {
    static let all: [PhoneticEntry] = [
        PhoneticEntry("@", kind: .punctuation, word: "At",
                      respelling: "AT",
                      mnemonic: "Every email address has exactly one."),
        PhoneticEntry(".", kind: .punctuation, word: "Dot",
                      respelling: "DOT",
                      mnemonic: "Say \"dot\", never \"point\", in an address."),
        PhoneticEntry("-", kind: .punctuation, word: "Dash",
                      respelling: "DASH",
                      mnemonic: "\"Hyphen\" works too, but \"dash\" carries further."),
        PhoneticEntry("_", kind: .punctuation, word: "Underscore",
                      respelling: "UN-DER-SCORE",
                      mnemonic: "The one people always forget to mention."),
        PhoneticEntry("/", kind: .punctuation, word: "Slash",
                      respelling: "SLASH",
                      mnemonic: "\"Forward slash\" if there is any doubt."),
        PhoneticEntry(" ", kind: .punctuation, word: "Space",
                      respelling: "SPACE",
                      mnemonic: "Announce it, or the other end runs the words together.")
    ]
}
