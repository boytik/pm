import AVFoundation
import Combine
import Foundation

final class SpeechService: NSObject, ObservableObject {
    static let shared = SpeechService()

    @Published private(set) var isSpeaking = false

    @Published private(set) var spokenIndex: Int?

    private let synthesizer = AVSpeechSynthesizer()
    private var queue: [PhoneticEntry] = []
    private var voice: AVSpeechSynthesisVoice?
    private var sessionActive = false
    private var deactivateWork: DispatchWorkItem?

    private override init() {
        super.init()
        synthesizer.delegate = self
        voice = Self.preferredVoice()
    }

    private static func preferredVoice() -> AVSpeechSynthesisVoice? {
        if let voice = AVSpeechSynthesisVoice(language: "en-US") { return voice }
        let english = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
        return english.first { $0.quality != .default } ?? english.first
    }

    func setVoice(identifier: String?) {
        if let identifier, let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            self.voice = voice
        } else {
            self.voice = Self.preferredVoice()
        }
    }

    static var englishVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { $0.name < $1.name }
    }

    func speak(_ entry: PhoneticEntry, rate: Double = 0.48) {
        speak([entry], rate: rate)
    }

    func speak(_ entries: [PhoneticEntry], rate: Double = 0.48, gap: TimeInterval = 0.35) {
        guard !entries.isEmpty else { return }
        activateSessionIfNeeded()
        queue = entries
        spokenIndex = nil

        for (index, entry) in entries.enumerated() {
            let utterance = AVSpeechUtterance(string: entry.speechText)
            utterance.voice = voice
            utterance.rate = Float(rate)
            utterance.pitchMultiplier = 1.0
            utterance.volume = 1.0

            utterance.postUtteranceDelay = index == entries.count - 1 ? 0 : gap
            synthesizer.speak(utterance)
        }
    }

    func spell(_ string: String, alphabet: PhoneticAlphabet, rate: Double = 0.48) {
        speak(alphabet.spell(string), rate: rate)
    }

    func replay(rate: Double = 0.48, gap: TimeInterval = 0.35) {
        let entries = queue
        synthesizer.stopSpeaking(at: .immediate)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.speak(entries, rate: rate, gap: gap)
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        spokenIndex = nil
        scheduleDeactivate()
    }

    private func activateSessionIfNeeded() {
        deactivateWork?.cancel()
        deactivateWork = nil
        guard !sessionActive else { return }

        let session = AVAudioSession.sharedInstance()

        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        sessionActive = true
    }

    private func scheduleDeactivate() {
        deactivateWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.sessionActive, !self.synthesizer.isSpeaking else { return }
            try? AVAudioSession.sharedInstance()
                .setActive(false, options: [.notifyOthersOnDeactivation])
            self.sessionActive = false
        }
        deactivateWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didStart utterance: AVSpeechUtterance
    ) {
        MainActor.assumeIsolated {
            isSpeaking = true
            if let index = queue.firstIndex(where: { $0.speechText == utterance.speechString }) {
                spokenIndex = index
            }
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        MainActor.assumeIsolated {
            guard !synthesizer.isSpeaking else { return }
            isSpeaking = false
            spokenIndex = nil
            scheduleDeactivate()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        MainActor.assumeIsolated {
            isSpeaking = false
            spokenIndex = nil
        }
    }
}
