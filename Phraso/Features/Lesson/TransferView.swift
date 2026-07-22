import SwiftUI

/// 结构迁移（PRD 03 Transfer）：
/// 只改变一个维度（人物 / 时间 / 否定 / 场景），检测是否真正理解。
/// 首次无提示成功 = 掌握判定的必要条件（PRD 14 真实性）。
struct TransferView: View {
    let pack: LanguagePack
    let exercise: Exercise
    /// 回调参数：是否在不看提示的情况下一次成功
    let onFinish: (Bool) -> Void

    @State private var chosen: [String] = []
    @State private var available: [String] = []
    @State private var feedback: AssembleEvaluator.Result?
    @State private var solved = false
    @State private var usedHint = false
    @State private var attempts = 0
    @State private var showHint = false

    private var targetBlocks: [String] { exercise.blocks ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Label("迁移：同一个结构，新的场景", systemImage: "arrow.triangle.branch")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(PH.purple)

                    if let prompt = exercise.promptZh {
                        Text(prompt)
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(PH.ink)
                    }

                    answerArea
                    blockTray

                    if showHint, let hint = exercise.hintZh {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill").foregroundStyle(PH.amber)
                            Text(hint).font(.subheadline).foregroundStyle(PH.subInk)
                        }
                    }

                    if let feedback {
                        FeedbackBanner(tag: feedback.tag)
                    }

                    if solved {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(exercise.canonical ?? "")
                                .font(.system(.title2, design: .rounded, weight: .semibold))
                                .foregroundStyle(PH.greenDark)
                            if let romanized = exercise.romanized {
                                Text(romanized).font(.subheadline).foregroundStyle(PH.subInk)
                            }
                            AudioButtons(text: exercise.canonical ?? "", locale: pack.targetLocale)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(PH.greenSoft))
                    }
                }
                .padding(24)
            }
            bottomBar
        }
        .onAppear {
            chosen = []
            feedback = nil
            solved = false
            let all = targetBlocks + (exercise.distractors ?? [])
            available = SeededShuffle.shuffle(all, seed: exercise.exerciseId)
        }
    }

    private var answerArea: some View {
        FlowLayout(spacing: 8) {
            if chosen.isEmpty {
                Text("用词块组装迁移后的句子")
                    .font(.subheadline)
                    .foregroundStyle(PH.subInk.opacity(0.7))
                    .padding(.vertical, 10)
            } else {
                ForEach(Array(chosen.enumerated()), id: \.offset) { index, block in
                    BlockChip(
                        text: block,
                        style: solved ? .correct : (feedback?.conflictIndices.contains(index) == true ? .conflict : .chosen)
                    ) {
                        guard !solved else { return }
                        feedback = nil
                        available.append(chosen.remove(at: index))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(PH.purple.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [6]))
        )
    }

    private var blockTray: some View {
        FlowLayout(spacing: 10) {
            ForEach(Array(available.enumerated()), id: \.offset) { index, block in
                BlockChip(text: block, style: .tray) {
                    guard !solved else { return }
                    feedback = nil
                    chosen.append(available.remove(at: index))
                }
            }
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 10) {
            if solved {
                Button("完成本课") { onFinish(attempts == 1 && !usedHint) }
                    .buttonStyle(PrimaryButtonStyle(color: PH.purple))
            } else {
                if exercise.hintZh != nil && !showHint {
                    Button("只提示变量") {
                        usedHint = true
                        withAnimation { showHint = true }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                Button("检查") {
                    attempts += 1
                    let result = AssembleEvaluator.evaluate(chosen: chosen, target: targetBlocks)
                    feedback = result
                    if result.tag == .structureCorrect {
                        withAnimation { solved = true }
                        AudioService.shared.speak(exercise.canonical ?? "", locale: pack.targetLocale)
                    }
                }
                .buttonStyle(PrimaryButtonStyle(color: PH.purple))
                .disabled(chosen.isEmpty)
                .opacity(chosen.isEmpty ? 0.5 : 1)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }
}
