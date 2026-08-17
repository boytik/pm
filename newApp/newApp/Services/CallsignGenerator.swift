//
//  CallsignGenerator.swift
//  Alpha Academy
//
//  Turns a name into a phonetic callsign. This is the app's whole idea
//  demonstrated in three seconds, using the learner's own name.
//

import Foundation

enum CallsignGenerator {

    /// "Evgenij" → "Echo Victor". "Maria Kaur" → "Mike Kilo".
    static func callsign(from name: String, alphabet: PhoneticAlphabet) -> String {
        entries(from: name, alphabet: alphabet)
            .map(\.word)
            .joined(separator: " ")
    }

    /// The same pair as entries, so the speech service can pronounce it.
    static func entries(from name: String, alphabet: PhoneticAlphabet) -> [PhoneticEntry] {
        let letters = initials(from: name)
        return letters.compactMap { alphabet.entry(for: $0) }
    }

    /// One or two letters to build the callsign from.
    static func initials(from name: String) -> [Character] {
        // Folding to Latin ASCII means Cyrillic input works for free:
        // "Евгений" → "Evgenij".
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
