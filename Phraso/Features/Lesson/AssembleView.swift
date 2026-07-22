import SwiftUI

/// 词块组装（PRD 03 Assemble / PRD 12 Block Assemble）：
/// 点选词块构句；判定比较 token 序列；
/// 反馈先确认正确部分，再指出一个改进点，不堆叠红色错误。
struct AssembleView: View {
    let pack: LanguagePack
    let exercise: Exercise
    let onContinue: () -> Void

    @State private var chosen: [String] = []
    @State private var available: [String] = []
    @State private var feedback: AssembleEvaluator.Result?
    @State private var solved = false

    private var targetBlocks: [String] { exercise.blocks ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Label("把词块组装成句子", systemImage: "puzzlepiece.extension.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(PH.amber)

                    if let prompt = exercise.promptZh {
                        Text(prompt)
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(PH.ink)
                    }

                    answerArea
                    blockTray

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
        .onAppear(perform: setup)
    }

    private func setup() {
        chosen = []
        feedback = nil
        solved = false
        let all = targetBlocks + (exercise.distractors ?? [])
        available = SeededShuffle.shuffle(all, seed: exercise.exerciseId)
    }

    // MARK: - 答题区

    private var answerArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(spacing: 8) {
                if chosen.isEmpty {
                    Text("点选下方词块，按顺序组成句子")
                        .font(.subheadline)
                        .foregroundStyle(PH.subInk.opacity(0.7))
                        .padding(.vertical, 10)
                } else {
                    ForEach(Array(chosen.enumerated()), id: \.offset) { index, block in
                        BlockChip(
                            text: block,
                            style: chipStyle(at: index),
                            action: { removeChosen(at: index) }
                        )
                        .accessibilityLabel("已选词块 \(block)，第 \(index + 1) 位，点击移回")
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(PH.green.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [6]))
            )
        }
    }

    private func chipStyle(at index: Int) -> BlockChip.Style {
        guard let feedback, !solved else { return solved ? .correct : .chosen }
        // 只突出冲突位置（PRD 12），不整句标红。
        return feedback.conflictIndices.contains(index) ? .conflict : .chosen
    }

    // MARK: - 词块托盘

    private var blockTray: some View {
        FlowLayout(spacing: 10) {
            ForEach(Array(available.enumerated()), id: \.offset) { index, block in
                BlockChip(text: block, style: .tray) {
                    chooseBlock(at: index)
                }
                .accessibilityLabel("词块 \(block)，点击加入句子")
            }
        }
    }

    private func chooseBlock(at index: Int) {
        guard !solved else { return }
        feedback = nil
        chosen.append(available.remove(at: index))
    }

    private func removeChosen(at index: Int) {
        guard !solved else { return }
        feedback = nil
        available.append(chosen.remove(at: index))
    }

    // MARK: - 底栏

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 10) {
            if solved {
                Button("继续") { onContinue() }
                    .buttonStyle(PrimaryButtonStyle())
            } else {
                Button("检查") {
                    let result = AssembleEvaluator.evaluate(chosen: chosen, target: targetBlocks)
                    feedback = result
                    if result.tag == .structureCorrect {
                        withAnimation { solved = true }
                        AudioService.shared.speak(exercise.canonical ?? "", locale: pack.targetLocale)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(chosen.isEmpty)
                .opacity(chosen.isEmpty ? 0.5 : 1)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }
}

// MARK: - 词块

struct BlockChip: View {
    enum Style { case tray, chosen, conflict, correct }

    let text: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(background)
                .foregroundStyle(foreground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(border, lineWidth: style == .conflict ? 2 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var background: Color {
        switch style {
        case .tray: return Color(.secondarySystemGroupedBackground)
        case .chosen: return PH.blue.opacity(0.12)
        case .conflict: return PH.attention.opacity(0.12)
        case .correct: return PH.greenSoft
        }
    }

    private var foreground: Color {
        switch style {
        case .tray: return PH.ink
        case .chosen: return PH.blue
        case .conflict: return PH.attention
        case .correct: return PH.greenDark
        }
    }

    private var border: Color {
        switch style {
        case .tray: return Color(.systemGray4)
        case .chosen: return PH.blue.opacity(0.4)
        case .conflict: return PH.attention
        case .correct: return PH.green
        }
    }
}

// MARK: - 反馈横幅：图标 + 文字，不只靠颜色（PRD 23）

struct FeedbackBanner: View {
    let tag: FeedbackTag

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: tag.systemImage)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 4) {
                Text(tag.titleZh).font(.headline).foregroundStyle(PH.ink)
                Text(tag.adviceZh).font(.subheadline).foregroundStyle(PH.subInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(color.opacity(0.1)))
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch tag {
        case .structureCorrect: return PH.correct
        case .recognitionUncertain: return PH.blue
        default: return PH.hint
        }
    }
}

// MARK: - 简单流式布局

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
