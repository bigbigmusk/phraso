import Foundation
import AVFoundation

/// 参考音频播放。
/// MVP 开发阶段使用系统语音作为“占位参考音频”；PRD 06 明确：
/// 发布包必须替换为母语者录音（按 asset 清单下发），系统语音不进入发布包。
final class AudioService: NSObject, ObservableObject {
    static let shared = AudioService()

    @Published var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()

    override private init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, locale: String, slow: Bool = false) {
        stop()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            // 音频会话失败不阻塞课程；参考句始终有文字可读（PRD 23）。
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: locale)
        // 慢速版本用于跟读，降低语速但不失真（PRD 11）。
        utterance.rate = slow ? 0.32 : 0.48
        utterance.preUtteranceDelay = 0.05
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }
}

extension AudioService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }
}
