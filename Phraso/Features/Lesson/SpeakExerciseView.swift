import SwiftUI

/// 口语练习（PRD 13）：
/// 听参考音频 → 录音（端侧转写）→ 基础反馈。
/// 麦克风被拒绝或识别不可用时降级为听读 + 自评；录音永远可跳过。
struct SpeakExerciseView: View {
    let pack: LanguagePack
    let exercise: Exercise
    let onContinue: () -> Void

    @StateObject private var speech = SpeechService()
    @State private var permissionRequested = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Label("开口，说出完整句子", systemImage: "mic.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(PH.amber)

                    if let prompt = exercise.promptZh {
                        Text(prompt)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(PH.ink)
                    }

                    referenceCard

                    switch speech.availability {
                    case .unknown, .available:
                        recordingArea
                    case .selfAssessOnly:
                        selfAssessArea
                    }
                }
                .padding(24)
            }
            bottomBar
        }
        .onDisappear { speech.reset() }
    }

    // MARK: - 参考句

    private var referenceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(exercise.canonical ?? "")
                .font(.system(.title, design: .rounded, weight: .semibold))
                .foregroundStyle(PH.greenDark)
            if let romanized = exercise.romanized {
                Text(romanized).font(.subheadline).foregroundStyle(PH.subInk)
            }
            AudioButtons(text: exercise.canonical ?? "", locale: pack.targetLocale)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(PH.greenSoft))
    }

    // MARK: - 录音区（L1）

    @ViewBuilder
    private var recordingArea: some View {
        VStack(spacing: 16) {
            switch speech.state {
            case .idle:
                recordButton(title: permissionRequested ? "开始录音" : "点击开始录音", active: false)
                Text("第一次录音时会请求麦克风与语音识别权限。\n跳过录音也可以完成课程。")
                    .font(.footnote)
                    .foregroundStyle(PH.subInk)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            case .recording:
                recordButton(title: "正在录音…点击结束", active: true)
                // 录音状态提供声音之外的可见反馈（PRD 23 VoiceOver/无障碍）。
                Label("录音中", systemImage: "waveform")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PH.coral)
                    .frame(maxWidth: .infinity)
            case .processing:
                ProgressView("正在本机分析…")
                    .frame(maxWidth: .infinity)
            case .finished(let tag, _):
                FeedbackBanner(tag: tag)
                Button("再说一遍") { speech.reset() }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private func recordButton(title: String, active: Bool) -> some View {
        Button {
            Task {
                if speech.availability == .unknown {
                    permissionRequested = true
                    await speech.preparePermissions(locale: pack.targetLocale)
                    guard speech.availability == .available else { return }
                }
                if speech.state == .recording {
                    speech.stopRecording()
                } else {
                    speech.startRecording(canonical: exercise.canonical ?? "")
                }
            }
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(active ? PH.coral : PH.green)
                        .frame(width: 84, height: 84)
                    Image(systemName: active ? "stop.fill" : "mic.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                }
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(PH.subInk)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityLabel(active ? "结束录音" : "开始录音")
    }

    // MARK: - 自评区（L0 降级，PRD 23 关键异常）

    private var selfAssessArea: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle.fill").foregroundStyle(PH.blue)
                Text("当前无法使用录音（权限被拒绝或设备暂不支持该语言的识别）。你可以跟读参考音频，然后自我评估——这不影响课程完成。")
                    .font(.subheadline)
                    .foregroundStyle(PH.subInk)
            }
            HStack(spacing: 10) {
                Button("我说出来了") { onContinue() }
                    .buttonStyle(PrimaryButtonStyle())
                Button("还需要练") {
                    AudioService.shared.speak(exercise.canonical ?? "", locale: pack.targetLocale, slow: true)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    // MARK: - 底栏

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if case .finished = speech.state {
                Button("继续") { onContinue() }
                    .buttonStyle(PrimaryButtonStyle())
            } else if speech.availability != .selfAssessOnly {
                Button("跳过录音") { onContinue() }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }
}
