import Foundation
import AVFoundation
import Speech

/// 语音练习能力分层（PRD 13）：
/// L0 参考音频 + 自评（完全离线，无麦克风也能完成课程）
/// L1 端侧转写 + 目标词检查（设备支持时优先；不上传原始录音）
/// 原始录音不落盘、不上传；识别结束即丢弃。
@MainActor
final class SpeechService: ObservableObject {

    enum Availability {
        case unknown
        case available          // 可录音可转写（L1）
        case selfAssessOnly     // 无识别能力或权限被拒 → 听读 + 自评（L0）
    }

    enum RecordingState: Equatable {
        case idle
        case recording
        case processing
        case finished(FeedbackTag, transcript: String)
    }

    @Published var availability: Availability = .unknown
    @Published var state: RecordingState = .idle

    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var latestTranscript = ""
    private var targetCanonical = ""

    /// 仅在用户第一次点击录音时调用（PRD 09：权限时机）。
    func preparePermissions(locale: String) async {
        let micGranted = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        guard micGranted else {
            availability = .selfAssessOnly
            return
        }

        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            availability = .selfAssessOnly
            return
        }

        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale))
        guard let recognizer, recognizer.isAvailable else {
            availability = .selfAssessOnly
            return
        }
        self.recognizer = recognizer
        availability = .available
    }

    func startRecording(canonical: String) {
        guard availability == .available, let recognizer else { return }
        stopEverything()
        targetCanonical = canonical
        latestTranscript = ""

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            // 端侧优先：设备支持时不把语音发往服务器（PRD 13 / 21）。
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }
            self.request = request

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.request?.append(buffer)
            }

            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let result {
                        self.latestTranscript = result.bestTranscription.formattedString
                    }
                    if error != nil, self.state == .processing {
                        self.finishEvaluation()
                    }
                }
            }

            audioEngine.prepare()
            try audioEngine.start()
            state = .recording
        } catch {
            stopEverything()
            availability = .selfAssessOnly
            state = .idle
        }
    }

    func stopRecording() {
        guard state == .recording else { return }
        state = .processing
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        // 给识别器短暂时间产出最终结果，然后本机判定并丢弃转写。
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            if self.state == .processing {
                self.finishEvaluation()
            }
        }
    }

    func reset() {
        stopEverything()
        state = .idle
    }

    private func finishEvaluation() {
        task?.cancel()
        task = nil
        request = nil
        let tag = Self.evaluate(transcript: latestTranscript, canonical: targetCanonical)
        state = .finished(tag, transcript: latestTranscript)
    }

    private func stopEverything() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        task?.cancel()
        task = nil
        request = nil
    }

    /// 转写与目标句的宽松比对：
    /// 只检查关键结构是否出现，可懂度优先，不以逐字符相同为标准（PRD 12）。
    /// 低置信 / 空转写一律判为 recognition_uncertain，绝不包装成学习者错误。
    nonisolated static func evaluate(transcript: String, canonical: String) -> FeedbackTag {
        let heard = tokens(of: transcript)
        let target = tokens(of: canonical)
        guard !target.isEmpty else { return .recognitionUncertain }
        guard !heard.isEmpty else { return .recognitionUncertain }

        let matched = target.filter { heard.contains($0) }
        let ratio = Double(matched.count) / Double(target.count)

        if ratio >= 0.7 { return .structureCorrect }
        if ratio >= 0.4 { return .pronunciationAttention }
        return .recognitionUncertain
    }

    nonisolated static func tokens(of text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(.nonBaseCharacters).inverted)
            .filter { !$0.isEmpty }
    }
}
