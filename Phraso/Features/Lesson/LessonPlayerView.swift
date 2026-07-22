import SwiftUI
import SwiftData

/// 课程播放器（PRD 11）：专注模式，隐藏底部导航；
/// 进度按教学阶段显示；退出自动保存到最近题目边界。
struct LessonPlayerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let pack: LanguagePack
    let engine: SentenceEngine
    let lesson: Lesson
    let startIndex: Int

    @State private var index: Int
    @State private var showExitDialog = false
    @State private var completed = false
    @State private var transferSucceededFirstTry = false
    @State private var startedAt = Date.now

    init(pack: LanguagePack, engine: SentenceEngine, lesson: Lesson, startIndex: Int = 0) {
        self.pack = pack
        self.engine = engine
        self.lesson = lesson
        self.startIndex = startIndex
        _index = State(initialValue: min(startIndex, max(lesson.exercises.count - 1, 0)))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
            if completed {
                LessonCompleteView(
                    pack: pack,
                    engine: engine,
                    lesson: lesson,
                    transferSucceeded: transferSucceededFirstTry,
                    onDone: { dismiss() }
                )
            } else if lesson.exercises.indices.contains(index) {
                exerciseView(lesson.exercises[index])
                    .id(lesson.exercises[index].exerciseId)
            }
        }
        .background(Color(.systemGroupedBackground))
        .confirmationDialog("要退出这节课吗？", isPresented: $showExitDialog, titleVisibility: .visible) {
            Button("保存并退出", role: .destructive) {
                saveProgress()
                dismiss()
            }
            Button("继续学习", role: .cancel) {}
        } message: {
            Text("进度已保存到当前题目，下次可以从这里继续。")
        }
        .onAppear {
            ProgressService.upsertLessonProgress(
                packId: pack.languagePackId,
                lessonId: lesson.lessonId,
                stageIndex: index,
                context: context
            )
        }
    }

    // MARK: - 顶栏：退出 + 阶段进度

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                if completed { dismiss() } else { showExitDialog = true }
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(PH.subInk)
                    .padding(8)
            }
            .accessibilityLabel("退出课程")

            // 阶段化进度：不用精确百分比制造赶时间感（PRD 11）。
            HStack(spacing: 4) {
                ForEach(0..<lesson.exercises.count, id: \.self) { i in
                    Capsule()
                        .fill(i < index || completed ? PH.green : (i == index ? PH.amber : Color(.systemGray4)))
                        .frame(height: 5)
                }
            }
            .accessibilityLabel("课程进度，第 \(index + 1) 步，共 \(lesson.exercises.count) 步")

            Text(stageLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PH.subInk)
                .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var stageLabel: String {
        guard lesson.exercises.indices.contains(index), !completed else { return "完成" }
        switch lesson.exercises[index].type {
        case .warmStart: return "热身"
        case .understand: return "理解"
        case .guidedRecall: return "构句"
        case .assemble: return "组装"
        case .speak: return "开口"
        case .transfer: return "迁移"
        }
    }

    // MARK: - 练习分发

    @ViewBuilder
    private func exerciseView(_ exercise: Exercise) -> some View {
        switch exercise.type {
        case .warmStart, .understand:
            UnderstandCardView(pack: pack, exercise: exercise, onContinue: advance)
        case .guidedRecall:
            GuidedRecallView(pack: pack, exercise: exercise, onContinue: { _ in advance() })
        case .assemble:
            AssembleView(pack: pack, exercise: exercise, onContinue: advance)
        case .speak:
            SpeakExerciseView(pack: pack, exercise: exercise, onContinue: advance)
        case .transfer:
            TransferView(pack: pack, exercise: exercise) { firstTrySuccess in
                transferSucceededFirstTry = firstTrySuccess
                advance()
            }
        }
    }

    private func advance() {
        AudioService.shared.stop()
        if index + 1 < lesson.exercises.count {
            index += 1
            saveProgress()
        } else {
            finishLesson()
        }
    }

    private func saveProgress() {
        ProgressService.upsertLessonProgress(
            packId: pack.languagePackId,
            lessonId: lesson.lessonId,
            stageIndex: index,
            context: context
        )
    }

    private func finishLesson() {
        let minutes = min(Date.now.timeIntervalSince(startedAt) / 60, Double(lesson.durationMin))
        ProgressService.completeLesson(
            packId: pack.languagePackId,
            lessonId: lesson.lessonId,
            minutes: max(minutes, 1),
            context: context
        )
        let mastery = ProgressService.ensureMastery(packId: pack.languagePackId, engineId: engine.engineId, context: context)
        // “掌握”必须来自无直接提示的迁移成功（PRD 14 真实性）。
        if transferSucceededFirstTry || mastery.state != .new {
            ReviewScheduler.recordTransferSuccess(mastery)
        } else {
            mastery.state = .learning
            mastery.masteryScore = max(mastery.masteryScore, 0.4)
            mastery.dueAt = Calendar.current.date(byAdding: .day, value: 1, to: .now)
            mastery.intervalDays = 1
        }
        try? context.save()
        completed = true
    }
}

/// 结课页（PRD 11 Review 阶段）：总结结构、告知复习安排。
struct LessonCompleteView: View {
    let pack: LanguagePack
    let engine: SentenceEngine
    let lesson: Lesson
    let transferSucceeded: Bool
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().fill(PH.greenSoft).frame(width: 120, height: 120)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(PH.green)
            }
            Text("你自己组装出来了")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(PH.ink)
            VStack(spacing: 8) {
                Text("本课结构：\(engine.structureHint)")
                    .font(.headline)
                    .foregroundStyle(PH.greenDark)
                Text(transferSucceeded
                     ? "迁移题一次成功，明天会安排一次简短复习来巩固。"
                     : "这个结构已进入学习队列，明天复习时再试一次迁移。")
                    .font(.subheadline)
                    .foregroundStyle(PH.subInk)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            Spacer()
            Button("完成") { onDone() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
    }
}
