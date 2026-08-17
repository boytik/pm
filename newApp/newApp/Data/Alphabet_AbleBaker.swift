//
//  Alphabet_AbleBaker.swift
//  Alpha Academy
//
//  The Joint Army/Navy Phonetic Alphabet, used by Allied forces and
//  aviation from 1941 until ICAO replaced it in 1956.
//
//  Only Charlie, Mike, Victor and X-ray survived into the modern set —
//  which makes this a genuinely interesting second alphabet rather than
//  a reskin of the first.
//

import Foundation

enum Alphabet_AbleBaker {

    static let letters: [PhoneticEntry] = [
        PhoneticEntry("A", word: "Able", respelling: "AY-BUL",
                      mnemonic: "The set is named after its first two words: Able Baker."),
        PhoneticEntry("B", word: "Baker", respelling: "BAY-KER",
                      mnemonic: "The other half of the name."),
        PhoneticEntry("C", word: "Charlie", respelling: "CHAR-LEE",
                      mnemonic: "Survivor — still Charlie in the modern NATO set."),
        PhoneticEntry("D", word: "Dog", respelling: "DOG",
                      mnemonic: "Short and blunt, the way wartime radio liked it."),
        PhoneticEntry("E", word: "Easy", respelling: "EE-ZEE",
                      mnemonic: "Easy Company, of Band of Brothers fame."),
        PhoneticEntry("F", word: "Fox", respelling: "FOKS",
                      mnemonic: "Later stretched into NATO's Foxtrot."),
        PhoneticEntry("G", word: "George", respelling: "JORJ",
                      mnemonic: "Also RAF slang for the autopilot."),
        PhoneticEntry("H", word: "How", respelling: "HOW",
                      mnemonic: "One of several everyday words in this set."),
        PhoneticEntry("I", word: "Item", respelling: "EYE-TEM",
                      mnemonic: "Iwo Jima's Item Pocket took its name from it."),
        PhoneticEntry("J", word: "Jig", respelling: "JIG",
                      mnemonic: "A lively dance — the third dance in these alphabets."),
        PhoneticEntry("K", word: "King", respelling: "KING",
                      mnemonic: "Shared with the police set."),
        PhoneticEntry("L", word: "Love", respelling: "LUV",
                      mnemonic: "Surprisingly warm for a military alphabet."),
        PhoneticEntry("M", word: "Mike", respelling: "MIKE",
                      mnemonic: "Survivor — unchanged in NATO."),
        PhoneticEntry("N", word: "Nan", respelling: "NAN",
                      mnemonic: "Sometimes given as Nectar in naval usage."),
        PhoneticEntry("O", word: "Oboe", respelling: "OH-BOH",
                      mnemonic: "Also the name of an RAF blind-bombing system."),
        PhoneticEntry("P", word: "Peter", respelling: "PEE-TER",
                      mnemonic: "Shared with the Western Union set."),
        PhoneticEntry("Q", word: "Queen", respelling: "KWEEN",
                      mnemonic: "Shared with the police set."),
        PhoneticEntry("R", word: "Roger", respelling: "RAH-JER",
                      mnemonic: "This is why \"Roger\" came to mean \"received\"."),
        PhoneticEntry("S", word: "Sugar", respelling: "SHUG-AR",
                      mnemonic: "Shared with the Western Union set."),
        PhoneticEntry("T", word: "Tare", respelling: "TAIR",
                      mnemonic: "The weight of an empty container."),
        PhoneticEntry("U", word: "Uncle", respelling: "UNK-UL",
                      mnemonic: "Shared with the police set."),
        PhoneticEntry("V", word: "Victor", respelling: "VIK-TER",
                      mnemonic: "Survivor — still Victor in NATO."),
        PhoneticEntry("W", word: "William", respelling: "WIL-YAM",
                      mnemonic: "Shared with the police set."),
        PhoneticEntry("X", word: "X-ray", respelling: "EKS-RAY",
                      mnemonic: "Survivor — still X-ray in NATO."),
        PhoneticEntry("Y", word: "Yoke", respelling: "YOHK",
                      mnemonic: "The control column of an aircraft."),
        PhoneticEntry("Z", word: "Zebra", respelling: "ZEE-BRA",
                      mnemonic: "Naval \"Condition Zebra\" means every hatch sealed.")
    ]

    /// Wartime numeral pronunciation was less standardised than ICAO's.
    /// "Niner" was already in use; the rest are read plainly.
    static let digits: [PhoneticEntry] = [
        PhoneticEntry("0", kind: .digit, word: "Zero", respelling: "ZEE-RO",
                      mnemonic: "Never \"oh\" — that rule is older than ICAO."),
        PhoneticEntry("1", kind: .digit, word: "One", respelling: "WUN",
                      mnemonic: "Read plainly.", spokenOverride: "Wun"),
        PhoneticEntry("2", kind: .digit, word: "Two", respelling: "TOO",
                      mnemonic: "Read plainly."),
        PhoneticEntry("3", kind: .digit, word: "Three", respelling: "THREE",
                      mnemonic: "Kept its th, unlike the later ICAO \"tree\"."),
        PhoneticEntry("4", kind: .digit, word: "Four", respelling: "FOR",
                      mnemonic: "One syllable here, two in ICAO."),
        PhoneticEntry("5", kind: .digit, word: "Five", respelling: "FIVE",
                      mnemonic: "Kept its v, unlike the later ICAO \"fife\"."),
        PhoneticEntry("6", kind: .digit, word: "Six", respelling: "SIX",
                      mnemonic: "Unchanged in every set."),
        PhoneticEntry("7", kind: .digit, word: "Seven", respelling: "SEV-EN",
                      mnemonic: "Unchanged in every set."),
        PhoneticEntry("8", kind: .digit, word: "Eight", respelling: "AYT",
                      mnemonic: "Read plainly."),
        PhoneticEntry("9", kind: .digit, word: "Nine", respelling: "NIN-ER",
                      mnemonic: "\"Niner\" predates ICAO — it is a wartime habit.",
                      spokenOverride: "Niner")
    ]

    static let alphabet = PhoneticAlphabet(
        id: .ableBaker,
        displayName: "Able Baker",
        subtitle: "The WWII Allied military and aviation set",
        provenance: "Joint Army/Navy Phonetic Alphabet — in service 1941–1956",
        letters: letters,
        digits: digits
    )
}
