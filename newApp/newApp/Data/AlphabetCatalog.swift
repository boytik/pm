import Foundation

enum AlphabetCatalog {
    static let all: [PhoneticAlphabet] = [
        Alphabet_NATO.alphabet,
        Alphabet_AbleBaker.alphabet,
        Alphabet_LawEnforcement.alphabet
    ]

    static func alphabet(_ id: AlphabetID) -> PhoneticAlphabet {
        switch id {
        case .nato:            return Alphabet_NATO.alphabet
        case .ableBaker:       return Alphabet_AbleBaker.alphabet
        case .lawEnforcement:  return Alphabet_LawEnforcement.alphabet
        }
    }

    static let trainableSymbols: [String] =
        (UnicodeScalar("A").value...UnicodeScalar("Z").value)
            .compactMap { UnicodeScalar($0).map { String(Character($0)) } }
        + (0...9).map(String.init)

    static let trainableCount = trainableSymbols.count
}
