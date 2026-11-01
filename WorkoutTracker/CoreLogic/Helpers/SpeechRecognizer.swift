import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
@Observable
final class SpeechRecognizer {
    var transcript: String = ""
    var isRecording: Bool = false
    var hasPermission: Bool = false
    var errorMessage: String?

    private var audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    /// Lazy: constructing `SFSpeechRecognizer` can present the Speech TCC sheet
    /// when AI Hub is merely tabulated. Only create on mic use.
    private var recognizer: SFSpeechRecognizer?

    init() {}

    private static func makeRecognizer() -> SFSpeechRecognizer? {
        // Follow the device locale instead of forcing ru-RU, so Voice Coach
        // works for every user. Fall back to the system default, then en-US.
        // SFSpeechRecognizer(locale:) returns nil if the locale is unsupported.
        if let r = SFSpeechRecognizer(locale: Locale.current) { return r }   // 1) device locale
        if let r = SFSpeechRecognizer() { return r }                         // 2) system default
        return SFSpeechRecognizer(locale: Locale(identifier: "en-US"))       // 3) last resort
    }

    func requestPermission() {
        // Maestro / UITestMode: never present Speech or Microphone sheets.
        if UITestLaunchConfiguration.isUITestMode {
            hasPermission = false
            errorMessage = "Speech recognition is disabled in UI tests."
            return
        }
        SFSpeechRecognizer.requestAuthorization { authStatus in
            Task { @MainActor in
                self.hasPermission = (authStatus == .authorized)
                if authStatus != .authorized {
                    self.errorMessage = "Speech recognition isn't authorized. Enable it in Settings."
                }
            }
        }

        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            Task { @MainActor in
                if !granted {
                    self.hasPermission = false
                    self.errorMessage = "Microphone access is required for Voice Coach."
                }
            }
        }
    }

    func startTranscribing() {
        if UITestLaunchConfiguration.isUITestMode {
            errorMessage = "Speech recognition is disabled in UI tests."
            return
        }
        if recognizer == nil {
            recognizer = Self.makeRecognizer()
        }
        // No recognizer for any supported locale → tell the user, don't fail silently.
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition isn't available on this device for your language."
            return
        }
        guard hasPermission else {
            requestPermission()
            return
        }

        errorMessage = nil
        transcript = ""
        isRecording = true

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            request = SFSpeechAudioBufferRecognitionRequest()
            guard let request = request else { return }
            request.shouldReportPartialResults = true

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.request?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            task = recognizer.recognitionTask(with: request) { result, error in
                if let result = result {
                    self.transcript = result.bestTranscription.formattedString
                }

                if error != nil || result?.isFinal == true {
                    self.stopTranscribing()
                }
            }
        } catch {
            print("Error starting microphone: \(error)")
            errorMessage = "Couldn't start the microphone. Please try again."
            stopTranscribing()
        }
    }

    func stopTranscribing() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()

        request = nil
        task = nil
        isRecording = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
