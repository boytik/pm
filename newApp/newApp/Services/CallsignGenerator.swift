import Foundation

enum CallsignGenerator {
    static func callsign(from name: String, alphabet: PhoneticAlphabet) -> String {
        entries(from: name, alphabet: alphabet)
            .map(\.word)
            .joined(separator: " ")
    }

    static func entries(from name: String, alphabet: PhoneticAlphabet) -> [PhoneticEntry] {
        let letters = initials(from: name)
        return letters.compactMap { alphabet.entry(for: $0) }
    }

    static func initials(from name: String) -> [Character] {
        let folded = name
            .applyingTransform(StringTransform("Any-Latin; Latin-ASCII"), reverse: false)
            ?? name

        let tokens = folded
            .uppercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }

        guard let first = tokens.first else { return [] }

        if tokens.count >= 2, let second = tokens[1].first, let head = first.first {
            return [head, second]
        }

        let characters = Array(first)
        if characters.count >= 2 { return [characters[0], characters[1]] }
        if let single = characters.first { return [single, single] }
        return []
    }
}
