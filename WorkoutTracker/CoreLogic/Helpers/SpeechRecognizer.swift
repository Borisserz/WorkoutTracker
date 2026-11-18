import Foundation
import OSLog
import Speech
import AVFoundation
import Combine

@MainActor
@Observable
final class SpeechRecognizer {
    enum ErrorReason: Equatable {
        case disabledInUITests
        case speechNotAuthorized
        case microphoneRequired
        case unavailableForLocale

        var localizedMessage: String {
            switch self {
            case .disabledInUITests:
                return String(localized: "Speech recognition is disabled in UI tests.")
            case .speechNotAuthorized:
                return String(localized: "Speech recognition isn't authorized. Enable it in Settings.")
            case .microphoneRequired:
                return String(localized: "Microphone access is required for Voice Coach.")
            case .unavailableForLocale:
                return String(localized: "Speech recognition isn't available on this device for your language.")
            }
        }
    }

    var transcript: String = ""
    var isRecording: Bool = false
    var hasPermission: Bool = false
    var errorMessage: String?

    private var audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var hasInstalledTap = false
    /// Lazy: constructing `SFSpeechRecognizer` can present the Speech TCC sheet
    /// when AI Hub is merely tabulated. Only create on mic use.
    private var recognizer: SFSpeechRecognizer?

    init() {
        let speechOK = SFSpeechRecognizer.authorizationStatus() == .authorized
        let micOK: Bool
        if #available(iOS 17.0, *) {
            micOK = AVAudioApplication.shared.recordPermission == .granted
        } else {
            micOK = AVAudioSession.sharedInstance().recordPermission == .granted
        }
        hasPermission = speechOK && micOK
    }

    nonisolated static func isValidAudioFormat(sampleRate: Double, channelCount: AVAudioChannelCount) -> Bool {
        sampleRate > 0 && channelCount > 0
    }

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
            errorMessage = ErrorReason.disabledInUITests.localizedMessage
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let speechStatus = await withCheckedContinuation { cont in
                SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
            }
            let micGranted: Bool = await withCheckedContinuation { cont in
                if #available(iOS 17.0, *) {
                    AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
                } else {
                    AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
                }
            }
            self.hasPermission = (speechStatus == .authorized) && micGranted
            if speechStatus != .authorized {
                self.errorMessage = ErrorReason.speechNotAuthorized.localizedMessage
            } else if !micGranted {
                self.errorMessage = ErrorReason.microphoneRequired.localizedMessage
            } else {
                self.errorMessage = nil
            }
        }
    }

    func startTranscribing() {
        if UITestLaunchConfiguration.isUITestMode {
            errorMessage = ErrorReason.disabledInUITests.localizedMessage
            return
        }
        if recognizer == nil {
            recognizer = Self.makeRecognizer()
        }
        // No recognizer for any supported locale → tell the user, don't fail silently.
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = ErrorReason.unavailableForLocale.localizedMessage
            return
        }
        guard hasPermission else {
            requestPermission()
            return
        }

        stopTranscribing()
        errorMessage = nil
        transcript = ""
        isRecording = true

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.mixWithOthers, .defaultToSpeaker, .allowBluetoothHFP]
            )
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let speechRequest = SFSpeechAudioBufferRecognitionRequest()
            speechRequest.shouldReportPartialResults = true
            self.request = speechRequest

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            guard Self.isValidAudioFormat(sampleRate: recordingFormat.sampleRate, channelCount: recordingFormat.channelCount) else {
                throw NSError(domain: "SpeechRecognizer", code: -1, userInfo: [NSLocalizedDescriptionKey: String(localized: "Couldn't start the microphone. Please try again.")])
            }

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                speechRequest.append(buffer)
            }
            hasInstalledTap = true

            audioEngine.prepare()
            try audioEngine.start()

            task = recognizer.recognitionTask(with: speechRequest) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                    }
                    if error != nil || result?.isFinal == true {
                        self.stopTranscribing()
                    }
                }
            }
        } catch {
            AppLog.speech.error("Error starting microphone: \(error.localizedDescription, privacy: .public)")
            errorMessage = String(localized: "Couldn't start the microphone. Please try again.")
            stopTranscribing()
        }
    }

    func stopTranscribing() {
        audioEngine.stop()
        if hasInstalledTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        request?.endAudio()
        task?.cancel()

        request = nil
        task = nil
        isRecording = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
