import Foundation

enum SymbolKind: String, Codable, Hashable {
    case letter
    case digit
    case punctuation
}

struct PhoneticEntry: Codable, Identifiable, Hashable {
    let symbol: String
    let kind: SymbolKind

    let word: String

    let respelling: String

    let mnemonic: String

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

    let subtitle: String

    let provenance: String
    let letters: [PhoneticEntry]
    let digits: [PhoneticEntry]

    var punctuation: [PhoneticEntry] { CommonSymbols.all }

    var trainable: [PhoneticEntry] { letters + digits }

    var allEntries: [PhoneticEntry] { letters + digits + punctuation }

    func entry(for symbol: Character) -> PhoneticEntry? {
        let key = String(symbol).uppercased()
        return allEntries.first { $0.symbol == key }
    }

    func entry(forSymbol symbol: String) -> PhoneticEntry? {
        allEntries.first { $0.symbol == symbol.uppercased() }
    }

    func spell(_ string: String) -> [PhoneticEntry] {
        string.compactMap { entry(for: $0) }
    }
}
