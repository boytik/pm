//
//  Alphabet_LawEnforcement.swift
//  Alpha Academy
//
//  The APCO / LAPD radio alphabet used by US police and dispatch.
//
//  Agencies vary — APCO has revised its recommendation more than once and
//  individual departments still differ on a few letters. The app labels
//  this set "APCO / LAPD" rather than claiming a single national standard.
//

import Foundation

enum Alphabet_LawEnforcement {

    static let letters: [PhoneticEntry] = [
        PhoneticEntry("A", word: "Adam", respelling: "AD-AM",
                      mnemonic: "\"Adam units\" are two-officer patrol cars in LAPD radio code."),
        PhoneticEntry("B", word: "Boy", respelling: "BOY",
                      mnemonic: "Short and hard to mishear over a car radio."),
        PhoneticEntry("C", word: "Charles", respelling: "CHARLZ",
                      mnemonic: "The full name here, not NATO's Charlie."),
        PhoneticEntry("D", word: "David", respelling: "DAY-VID",
                      mnemonic: "This set uses given names almost throughout."),
        PhoneticEntry("E", word: "Edward", respelling: "ED-WERD",
                      mnemonic: "Two clear syllables."),
        PhoneticEntry("F", word: "Frank", respelling: "FRANK",
                      mnemonic: "Shared with the Western Union set."),
        PhoneticEntry("G", word: "George", respelling: "JORJ",
                      mnemonic: "Also in the Able Baker set."),
        PhoneticEntry("H", word: "Henry", respelling: "HEN-REE",
                      mnemonic: "Shared with the Western Union set."),
        PhoneticEntry("I", word: "Ida", respelling: "EYE-DAH",
                      mnemonic: "Chosen for its long opening vowel."),
        PhoneticEntry("J", word: "John", respelling: "JON",
                      mnemonic: "One syllable, unmistakable."),
        PhoneticEntry("K", word: "King", respelling: "KING",
                      mnemonic: "Also in the Able Baker set."),
        PhoneticEntry("L", word: "Lincoln", respelling: "LINK-UN",
                      mnemonic: "The president, not the city."),
        PhoneticEntry("M", word: "Mary", respelling: "MAIR-EE",
                      mnemonic: "Not Mike — this set avoids NATO's short words."),
        PhoneticEntry("N", word: "Nora", respelling: "NOR-AH",
                      mnemonic: "Some agencies use Nancy instead."),
        PhoneticEntry("O", word: "Ocean", respelling: "OH-SHUN",
                      mnemonic: "One of the few non-names in the set."),
        PhoneticEntry("P", word: "Paul", respelling: "PAWL",
                      mnemonic: "One syllable, opens wide."),
        PhoneticEntry("Q", word: "Queen", respelling: "KWEEN",
                      mnemonic: "Also in the Able Baker set."),
        PhoneticEntry("R", word: "Robert", respelling: "ROB-ERT",
                      mnemonic: "Not Roger — Roger already means \"received\"."),
        PhoneticEntry("S", word: "Sam", respelling: "SAM",
                      mnemonic: "Short form, unlike Able Baker's Sugar."),
        PhoneticEntry("T", word: "Tom", respelling: "TOM",
                      mnemonic: "Some agencies use Thomas in full."),
        PhoneticEntry("U", word: "Union", respelling: "YOON-YUN",
                      mnemonic: "One of the few non-names in the set."),
        PhoneticEntry("V", word: "Victor", respelling: "VIK-TER",
                      mnemonic: "The one word shared by all three alphabets in this app."),
        PhoneticEntry("W", word: "William", respelling: "WIL-YAM",
                      mnemonic: "Also in the Able Baker set."),
        PhoneticEntry("X", word: "X-ray", respelling: "EKS-RAY",
                      mnemonic: "No good name starts with X."),
        PhoneticEntry("Y", word: "Young", respelling: "YUNG",
                      mnemonic: "A surname rather than a given name."),
        PhoneticEntry("Z", word: "Zebra", respelling: "ZEE-BRA",
                      mnemonic: "Also in the Able Baker set.")
    ]

    /// Dispatch reads numbers plainly — no "niner", no "tree". That contrast
    /// with the NATO set is itself worth teaching.
    static let digits: [PhoneticEntry] = [
        PhoneticEntry("0", kind: .digit, word: "Zero", respelling: "ZEE-RO",
                      mnemonic: "Plain reading, unlike aviation."),
        PhoneticEntry("1", kind: .digit, word: "One", respelling: "WUN",
                      mnemonic: "Plain reading."),
        PhoneticEntry("2", kind: .digit, word: "Two", respelling: "TOO",
                      mnemonic: "Plain reading."),
        PhoneticEntry("3", kind: .digit, word: "Three", respelling: "THREE",
                      mnemonic: "Keeps its th — dispatch is not fighting engine noise."),
        PhoneticEntry("4", kind: .digit, word: "Four", respelling: "FOR",
                      mnemonic: "One syllable, unlike ICAO's \"fower\"."),
        PhoneticEntry("5", kind: .digit, word: "Five", respelling: "FIVE",
                      mnemonic: "Keeps its v, unlike ICAO's \"fife\"."),
        PhoneticEntry("6", kind: .digit, word: "Six", respelling: "SIX",
                      mnemonic: "Unchanged in every set."),
        PhoneticEntry("7", kind: .digit, word: "Seven", respelling: "SEV-EN",
                      mnemonic: "Unchanged in every set."),
        PhoneticEntry("8", kind: .digit, word: "Eight", respelling: "AYT",
                      mnemonic: "Plain reading."),
        PhoneticEntry("9", kind: .digit, word: "Nine", respelling: "NINE",
                      mnemonic: "Just \"nine\" — \"niner\" is an aviation habit.")
    ]

    static let alphabet = PhoneticAlphabet(
        id: .lawEnforcement,
        displayName: "Law Enforcement",
        subtitle: "The set used by US police and dispatch",
        provenance: "APCO Project 14 / LAPD radio alphabet — usage varies by agency",
        letters: letters,
        digits: digits
    )
}
