//
//  VoiceCoach.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 27.03.26.
//

import AVFoundation
import Combine

/// Голосовой ассистент, который элегантно приглушает фоновую музыку (Spotify, Apple Music)
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
            // .playback - позволяет звучать даже в silent mode
            // .mixWithOthers - не выключает музыку на фоне
            // .duckOthers - автоматически приглушает фоновую музыку во время нашей речи
            try audioSession.setCategory(
                .playback,
                mode: .spokenAudio, // Оптимизировано для голоса
                options: [.duckOthers, .mixWithOthers]
            )
        } catch {
            print("VoiceCoach: Failed to configure AVAudioSession - \(error)")
        }
    }
    
    /// Произносит новую фразу, прерывая текущую
    func speak(_ text: String) {
        // Если уже говорим — прерываем немедленно
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        // Активируем сессию перед началом речи
        try? audioSession.setActive(true)
        
        let utterance = AVSpeechUtterance(string: text)
        // Используем текущий язык устройства
        utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        
        synthesizer.speak(utterance)
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Деактивируем сессию, чтобы вернуть громкость фоновой музыке на 100%
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
