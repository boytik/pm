//
//  QuestionFactory.swift
//  Alpha Academy
//
//  Question generation, deterministic given an injected generator.
//
//  Distractor quality is the whole game here: random distractors make a
//  quiz guessable and kill its teaching value, so they are drawn from the
//  same alphabet and biased towards confusable words.
//

import Foundation

enum QuestionFactory {

    static func make(
        mode: TrainingMode,
        alphabet: PhoneticAlphabet,
        progress: [String: LetterProgress],
        goalMinutes: Int,
        using generator: inout some RandomNumberGenerator
    ) -> [Question] {
        switch mode {
        case .study:
            return alphabet.trainable.map { flashcard($0) }

        case .letterToWord:
            return quizQuestions(
                count: 12, alphabet: alphabet, progress: progress,
                letterToWord: true, using: &generator
            )

        case .wordToLetter:
            return quizQuestions(
                count: 12, alphabet: alphabet, progress: progress,
                letterToWord: false, using: &generator
            )

        case .speed:
            // Speed Mode loops, so it only needs a deep enough pool.
            return quizQuestions(
                count: 60, alphabet: alphabet, progress: progress,
                letterToWord: true, using: &generator
            )

        case .encode:
            return (0..<4).compactMap { _ in
                encodeQuestion(alphabet: alphabet, progress: progress, using: &generator)
            }

        case .decode:
            return (0..<5).compactMap { _ in
                decodeQuestion(alphabet: alphabet, progress: progress, using: &generator)
            }

        case .dailyDrill:
            return dailyDrill(
                alphabet: alphabet, progress: progress,
                goalMinutes: goalMinutes, using: &generator
            )
        }
    }

    // MARK: - Flashcards

    private static func flashcard(_ entry: PhoneticEntry) -> Question {
        Question(
            kind: .flashcard,
            targetSymbols: [entry.symbol],
            promptText: entry.symbol,
            expected: [entry.word]
        )
    }

    // MARK: - Multiple choice

    static func quizQuestions(
        count: Int,
        alphabet: PhoneticAlphabet,
        progress: [String: LetterProgress],
        letterToWord: Bool,
        using generator: inout some RandomNumberGenerator
    ) -> [Question] {
        let symbols = SpacedRepetitionEngine.selectSymbols(
            count: count,
            from: alphabet.trainable.map(\.symbol),
            progress: progress,
            using: &generator
        )

        return symbols.compactMap { symbol in
            guard let entry = alphabet.entry(forSymbol: symbol) else { return nil }
            return letterToWord
                ? chooseWord(entry, alphabet: alphabet, using: &generator)
                : chooseLetter(entry, alphabet: alphabet, using: &generator)
        }
    }

    private static func chooseWord(
        _ entry: PhoneticEntry,
        alphabet: PhoneticAlphabet,
        using generator: inout some RandomNumberGenerator
    ) -> Question {
        var options = [entry.word]
        options.append(contentsOf: distractorWords(for: entry, alphabet: alphabet, using: &generator))
        options.shuffle(using: &generator)

        return Question(
            kind: .chooseWord,
            targetSymbols: [entry.symbol],
            promptText: entry.symbol,
            promptSubtitle: "Which word is this?",
            expected: [entry.word],
            options: options
        )
    }

    private static func chooseLetter(
        _ entry: PhoneticEntry,
        alphabet: PhoneticAlphabet,
        using generator: inout some RandomNumberGenerator
    ) -> Question {
        var options = [entry.symbol]
        let pool = alphabet.trainable
            .filter { $0.symbol != entry.symbol && $0.kind == entry.kind }
            .map(\.symbol)
            .shuffled(using: &generator)
        options.append(contentsOf: pool.prefix(3))
        options.shuffle(using: &generator)

        return Question(
            kind: .chooseLetter,
            targetSymbols: [entry.symbol],
            promptText: entry.word,
            promptSubtitle: "Which letter is this?",
            expected: [entry.symbol],
            options: options
        )
    }

    /// Prefer words that share a first letter or a syllable count — the
    /// difference between a real test and a giveaway.
    private static func distractorWords(
        for entry: PhoneticEntry,
        alphabet: PhoneticAlphabet,
        using generator: inout some RandomNumberGenerator
    ) -> [String] {
        let candidates = alphabet.trainable.filter {
            $0.symbol != entry.symbol && $0.kind == entry.kind
        }

        let sameInitial = candidates.filter { $0.word.first == entry.word.first }
        let similarLength = candidates.filter {
            abs($0.word.count - entry.word.count) <= 1 && $0.word.first != entry.word.first
        }
        let rest = candidates.filter {
            !sameInitial.contains($0) && !similarLength.contains($0)
        }

        var picked: [String] = []
        for group in [sameInitial, similarLength, rest] {
            for candidate in group.shuffled(using: &generator) where picked.count < 3 {
                if !picked.contains(candidate.word) { picked.append(candidate.word) }
            }
            if picked.count >= 3 { break }
        }
        return Array(picked.prefix(3))
    }

    // MARK: - Encode

    static func encodeQuestion(
        alphabet: PhoneticAlphabet,
        progress: [String: LetterProgress],
        set: ScenarioSet? = nil,
        using generator: inout some RandomNumberGenerator
    ) -> Question? {
        let scenario = set ?? ScenarioCatalog.all.randomElement(using: &generator) ?? ScenarioCatalog.flight

        // Best of five draws by how much practice the string actually
        // delivers, so weak letters end up inside real strings.
        var best: (string: String, weight: Double)?
        for _ in 0..<5 {
            let candidate = ScenarioCatalog.string(from: scenario, using: &generator)
            let weight = candidate.reduce(0.0) { total, character in
                let symbol = String(character).uppercased()
                return total + SpacedRepetitionEngine.weight(
                    for: progress[symbol], symbol: symbol, recentlyAsked: []
                )
            }
            if best == nil || weight > best!.weight { best = (candidate, weight) }
        }

        guard let string = best?.string else { return nil }
        let entries = alphabet.spell(string)
        guard !entries.isEmpty else { return nil }

        var optionPools: [[String]] = []
        for entry in entries {
            var options = [entry.word]
            options.append(contentsOf: distractorWords(for: entry, alphabet: alphabet, using: &generator))
            options.shuffle(using: &generator)
            optionPools.append(options)
        }

        return Question(
            kind: .buildSequence,
            targetSymbols: entries.map(\.symbol),
            promptText: string,
            promptSubtitle: scenario.contextLine,
            expected: entries.map(\.word),
            sequenceOptions: optionPools,
            scenarioCategory: scenario.category
        )
    }

    // MARK: - Decode

    static func decodeQuestion(
        alphabet: PhoneticAlphabet,
        progress: [String: LetterProgress],
        set: ScenarioSet? = nil,
        using generator: inout some RandomNumberGenerator
    ) -> Question? {
        let scenario = set ?? ScenarioCatalog.all.randomElement(using: &generator) ?? ScenarioCatalog.flight
        let string = ScenarioCatalog.string(from: scenario, using: &generator)
        let entries = alphabet.spell(string)
        guard !entries.isEmpty else { return nil }

        return Question(
            kind: .transcribe,
            targetSymbols: entries.map(\.symbol),
            promptText: string,
            promptSubtitle: scenario.contextLine,
            expected: [StringNormalizer.canonical(string)],
            speechEntries: entries,
            scenarioCategory: scenario.category
        )
    }

    // MARK: - Daily drill

    /// Weak letters, a few digits, and one real string — sized to the goal.
    static func dailyDrill(
        alphabet: PhoneticAlphabet,
        progress: [String: LetterProgress],
        goalMinutes: Int,
        using generator: inout some RandomNumberGenerator
    ) -> [Question] {
        let letterCount: Int
        switch goalMinutes {
        case ..<8:  letterCount = 8
        case ..<13: letterCount = 14
        default:    letterCount = 20
        }

        var questions = quizQuestions(
            count: letterCount,
            alphabet: alphabet,
            progress: progress,
            letterToWord: true,
            using: &generator
        )

        if let encode = encodeQuestion(alphabet: alphabet, progress: progress, using: &generator) {
            questions.append(encode)
        }
        return questions
    }
}
