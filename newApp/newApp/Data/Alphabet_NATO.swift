//
//  Alphabet_NATO.swift
//  Alpha Academy
//
//  ICAO Annex 10, Volume II. In force since 1 March 1956 and used
//  identically by NATO, civil aviation, and maritime radio.
//
//  Note the official spellings: "Alfa" (not Alpha) and "Juliett" (not
//  Juliet). Both are deliberate, so speakers of other languages do not
//  drop the "ph" or the final "t".
//

import Foundation

enum Alphabet_NATO {

    // Explicit type annotations on these literals keep the type checker fast.
    static let letters: [PhoneticEntry] = [
        PhoneticEntry("A", word: "Alfa", respelling: "AL-FAH",
                      mnemonic: "Spelled with an f so it survives every accent — never \"Alpha\" on the radio."),
        PhoneticEntry("B", word: "Bravo", respelling: "BRAH-VOH",
                      mnemonic: "Applause after a job well done."),
        PhoneticEntry("C", word: "Charlie", respelling: "CHAR-LEE",
                      mnemonic: "One of only four words carried over from the old Able Baker set."),
        PhoneticEntry("D", word: "Delta", respelling: "DELL-TAH",
                      mnemonic: "The triangle of land where a river meets the sea."),
        PhoneticEntry("E", word: "Echo", respelling: "ECK-OH",
                      mnemonic: "It comes back to you."),
        PhoneticEntry("F", word: "Foxtrot", respelling: "FOKS-TROT",
                      mnemonic: "A ballroom dance — two long steps, two short."),
        PhoneticEntry("G", word: "Golf", respelling: "GOLF",
                      mnemonic: "One syllable, impossible to mishear."),
        PhoneticEntry("H", word: "Hotel", respelling: "HOH-TELL",
                      mnemonic: "Stress the second syllable: hoh-TELL."),
        PhoneticEntry("I", word: "India", respelling: "IN-DEE-AH",
                      mnemonic: "Three clear syllables so it never collides with Echo."),
        PhoneticEntry("J", word: "Juliett", respelling: "JEW-LEE-ETT",
                      mnemonic: "Two t's, so French speakers still pronounce the ending."),
        PhoneticEntry("K", word: "Kilo", respelling: "KEY-LOH",
                      mnemonic: "A thousand of something."),
        PhoneticEntry("L", word: "Lima", respelling: "LEE-MAH",
                      mnemonic: "The capital of Peru — LEE-mah, not LYE-mah."),
        PhoneticEntry("M", word: "Mike", respelling: "MIKE",
                      mnemonic: "Short for microphone, and short on the air."),
        PhoneticEntry("N", word: "November", respelling: "NO-VEM-BER",
                      mnemonic: "The month, and the prefix on every US-registered aircraft."),
        PhoneticEntry("O", word: "Oscar", respelling: "OSS-CAH",
                      mnemonic: "The gold statuette."),
        PhoneticEntry("P", word: "Papa", respelling: "PAH-PAH",
                      mnemonic: "Stress the second syllable: pah-PAH."),
        PhoneticEntry("Q", word: "Quebec", respelling: "KEH-BECK",
                      mnemonic: "The Canadian province — the q is silent, it is keh-BECK."),
        PhoneticEntry("R", word: "Romeo", respelling: "ROW-ME-OH",
                      mnemonic: "Shakespeare's, and unmistakable at three syllables."),
        PhoneticEntry("S", word: "Sierra", respelling: "SEE-AIR-RAH",
                      mnemonic: "A mountain range."),
        PhoneticEntry("T", word: "Tango", respelling: "TANG-GO",
                      mnemonic: "The other dance in the alphabet."),
        PhoneticEntry("U", word: "Uniform", respelling: "YOU-NEE-FORM",
                      mnemonic: "ICAO also accepts OO-NEE-FORM for non-English speakers."),
        PhoneticEntry("V", word: "Victor", respelling: "VIK-TAH",
                      mnemonic: "The winner — and one of the four Able Baker survivors."),
        PhoneticEntry("W", word: "Whiskey", respelling: "WISS-KEY",
                      mnemonic: "Spelled the Irish way, with an e."),
        PhoneticEntry("X", word: "X-ray", respelling: "ECKS-RAY",
                      mnemonic: "Say both halves — \"ecks\" alone sounds like \"S\"."),
        PhoneticEntry("Y", word: "Yankee", respelling: "YANG-KEY",
                      mnemonic: "Hard g in the middle: yang-KEY."),
        PhoneticEntry("Z", word: "Zulu", respelling: "ZOO-LOO",
                      mnemonic: "Also the name for UTC — \"1400 Zulu\".")
    ]

    /// Aviation numerals. The written form and the spoken form deliberately
    /// differ for 3, 4, 5 and 9 — that gap is one of the most useful things
    /// in this app, so `spokenOverride` drives the audio while `word` is
    /// what the learner types.
    static let digits: [PhoneticEntry] = [
        PhoneticEntry("0", kind: .digit, word: "Zero", respelling: "ZE-RO",
                      mnemonic: "Always \"zero\", never \"oh\" — \"oh\" is a letter."),
        PhoneticEntry("1", kind: .digit, word: "One", respelling: "WUN",
                      mnemonic: "Clipped to one syllable: wun.",
                      spokenOverride: "Wun"),
        PhoneticEntry("2", kind: .digit, word: "Two", respelling: "TOO",
                      mnemonic: "Plain, but never say \"to\" or \"too\" in place of it."),
        PhoneticEntry("3", kind: .digit, word: "Three", respelling: "TREE",
                      mnemonic: "Said \"tree\" — the th sound does not survive radio static.",
                      spokenOverride: "Tree"),
        PhoneticEntry("4", kind: .digit, word: "Four", respelling: "FOW-ER",
                      mnemonic: "Stretched to two syllables so it cannot be heard as \"for\".",
                      spokenOverride: "Fower"),
        PhoneticEntry("5", kind: .digit, word: "Five", respelling: "FIFE",
                      mnemonic: "Said \"fife\" so the v does not blur into \"nine\".",
                      spokenOverride: "Fife"),
        PhoneticEntry("6", kind: .digit, word: "Six", respelling: "SIX",
                      mnemonic: "Already distinct — left alone."),
        PhoneticEntry("7", kind: .digit, word: "Seven", respelling: "SEV-EN",
                      mnemonic: "Two clear syllables."),
        PhoneticEntry("8", kind: .digit, word: "Eight", respelling: "AIT",
                      mnemonic: "One syllable: ait."),
        PhoneticEntry("9", kind: .digit, word: "Nine", respelling: "NIN-ER",
                      mnemonic: "Said \"niner\" so it is never confused with the German \"nein\".",
                      spokenOverride: "Niner")
    ]

    static let alphabet = PhoneticAlphabet(
        id: .nato,
        displayName: "NATO / ICAO",
        subtitle: "The international aviation and maritime standard",
        provenance: "ICAO Annex 10, Volume II — in force since 1 March 1956",
        letters: letters,
        digits: digits
    )
}
