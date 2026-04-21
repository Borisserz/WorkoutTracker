

import AVFoundation
import Combine

@MainActor
final class VoiceCoach: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {

    private let synthesizer = AVSpeechSynthesizer()
    private let audioSession = AVAudioSession.sharedInstance()

    override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
    }

    private func setupAudioSession() {
           do {
               let isDuckingEnabled = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.voiceCoachDucking.rawValue)

               var options: AVAudioSession.CategoryOptions = [.mixWithOthers]

               if isDuckingEnabled {
                   options.insert(.duckOthers)
               }

               try audioSession.setCategory(
                   .playback,
                   mode: .spokenAudio, 
                   options: options
               )
           } catch {
               print("VoiceCoach: Failed to configure AVAudioSession - \(error)")
           }
       }

    func speak(_ text: String) {

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        try? audioSession.setActive(true)

        let utterance = AVSpeechUtterance(string: text)

        utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0

        synthesizer.speak(utterance)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {

        Task { @MainActor in
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
