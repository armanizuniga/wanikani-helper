// On-device Japanese text-to-speech for the easy-mode speaker button. Uses AVSpeechSynthesizer with
// the best installed ja-JP voice — a downloaded Premium/Enhanced Siri voice if the user has one
// (Settings → Accessibility → Spoken Content → Voices), otherwise the built-in compact voice.
import AVFoundation

@MainActor
final class JapaneseSpeaker {
    static let shared = JapaneseSpeaker()

    // Must be retained for the duration of speech, so it lives on the singleton.
    private let synthesizer = AVSpeechSynthesizer()

    private lazy var voice: AVSpeechSynthesisVoice? = {
        let japanese = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "ja-JP" }
        return japanese.max { $0.quality.rawValue < $1.quality.rawValue }
            ?? AVSpeechSynthesisVoice(language: "ja-JP")
    }()

    private init() {}

    func speak(_ text: String) {
        // .playback so the button still works with the silent switch on; duck rather than stop
        // any music the user has playing.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utterance)
    }
}
