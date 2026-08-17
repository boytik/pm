//
//  PhoneticAlphabet.swift
//  Alpha Academy
//

import Foundation

enum SymbolKind: String, Codable, Hashable {
    case letter
    case digit
    case punctuation
}

/// One row of a phonetic alphabet: the symbol, the code word used to say it
/// aloud, a pronunciation key, and a memory hook.
struct PhoneticEntry: Codable, Identifiable, Hashable {
    /// "A"–"Z", "0"–"9", or a punctuation mark.
    let symbol: String
    let kind: SymbolKind
    /// The written code word, e.g. "Alfa" or "Three".
    let word: String
    /// Taught pronunciation, e.g. "AL-FAH" or "TREE".
    let respelling: String
    /// A short memory hook shown on the study card.
    let mnemonic: String
    /// What to feed the speech synthesiser when it differs from `word`.
    /// Aviation says "Tree" for 3 and "Niner" for 9 — that gap between the
    /// written form and the spoken form is the actual skill being taught.
    let spokenOverride: String?

    init(
        _ symbol: String,
        kind: SymbolKind = .letter,
        word: String,
        respelling: String,
        mnemonic: String,
        spokenOverride: String? = nil
    ) {
        self.symbol = symbol
        self.kind = kind
        self.word = word
        self.respelling = respelling
        self.mnemonic = mnemonic
        self.spokenOverride = spokenOverride
    }

    var id: String { symbol }

    /// What `SpeechService` should actually say.
    var speechText: String { spokenOverride ?? word }
}

enum AlphabetID: String, Codable, CaseIterable, Identifiable, Hashable {
    case nato
    case ableBaker
    case lawEnforcement

    var id: String { rawValue }
}

struct PhoneticAlphabet: Identifiable, Hashable {
    let id: AlphabetID
    let displayName: String
    /// One line on where this set is actually used.
    let subtitle: String
    /// A citable source, printed at the foot of the reference chart. This is
    /// the app's strongest "real educational content" artefact.
    let provenance: String
    let letters: [PhoneticEntry]
    let digits: [PhoneticEntry]

    /// Punctuation is shared across all sets and is not mastery-tracked.
    var punctuation: [PhoneticEntry] { CommonSymbols.all }

    /// The 36 symbols that carry progress.
    var trainable: [PhoneticEntry] { letters + digits }

    /// Everything that can appear in a string to encode or decode.
    var allEntries: [PhoneticEntry] { letters + digits + punctuation }

    func entry(for symbol: Character) -> PhoneticEntry? {
        let key = String(symbol).uppercased()
        return allEntries.first { $0.symbol == key }
    }

    func entry(forSymbol symbol: String) -> PhoneticEntry? {
        allEntries.first { $0.symbol == symbol.uppercased() }
    }

    /// Maps a raw string to the entries needed to spell it out.
    /// Unknown characters are dropped.
    func spell(_ string: String) -> [PhoneticEntry] {
        string.compactMap { entry(for: $0) }
    }
}
