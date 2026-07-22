import SwiftUI

/// 引导构句（PRD 03 / 12 Guided Recall）：
/// 中文任务 → 保留思考停顿 → 学习者先构句 → 再揭晓参考答案。
/// “揭晓”不是第一步；揭晓按钮在预设思考时间后可用，但没有倒计时压力。
struct GuidedRecallView: View {
    let pack: LanguagePack
    let exercise: Exercise
    /// 回调参数：学习者是否自评“说对了”
    let onContinue: (Bool) -> Void

    @State private var revealEnabled = false
    @State private var revealed = false
    @State private var showHint = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Label("先想一想，试着说出这句话", systemImage: "brain.head.profile")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(PH.amber)

                    if let prompt = exercise.promptZh {
                        Text(prompt)
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundStyle(PH.ink)
                    }

                    if !revealed {
                        thinkingArea
                    } else {
                        revealedArea
                    }
                }
                .padding(24)
            }
            bottomBar
        }
    }

    // MARK: - 思考区

    private var thinkingArea: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "ellipsis.bubble")
                    .foregroundStyle(PH.subInk)
                Text("大声说出来，或在心里组装这个句子。")
                    .font(.subheadline)
                    .foregroundStyle(PH.subInk)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(PH.green.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [6]))
            )

            if showHint, let hint = exercise.hintZh {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill").foregroundStyle(PH.amber)
                    Text(hint).font(.subheadline).foregroundStyle(PH.subInk)
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            // 预设思考时间后揭晓可用；不强制倒计时（PRD 11）。
            revealEnabled = false
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                withAnimation { revealEnabled = true }
            }
        }
    }

    // MARK: - 揭晓区

    private var revealedArea: some View {
        VStack(alignment: .leading, spacing: 16) {
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

            if let variants = exercise.acceptableVariants, !variants.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("也可以这样说").font(.caption.weight(.semibold)).foregroundStyle(PH.subInk)
                    ForEach(variants, id: \.self) { variant in
                        Text("· \(variant)").font(.subheadline).foregroundStyle(PH.ink)
                    }
                }
            }

            Text("你刚才说的和参考答案接近吗？")
                .font(.subheadline)
                .foregroundStyle(PH.subInk)
        }
        .onAppear {
            AudioService.shared.speak(exercise.canonical ?? "", locale: pack.targetLocale)
        }
    }

    // MARK: - 底栏

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 10) {
            if !revealed {
                if exercise.hintZh != nil && !showHint {
                    Button("需要一点提示") {
                        withAnimation { showHint = true }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                Button("揭晓参考答案") {
                    withAnimation { revealed = true }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!revealEnabled)
                .opacity(revealEnabled ? 1 : 0.5)
            } else {
                HStack(spacing: 10) {
                    Button("接近，继续") { onContinue(true) }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("再试一次") {
                        withAnimation {
                            revealed = false
                            showHint = false
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }
}
