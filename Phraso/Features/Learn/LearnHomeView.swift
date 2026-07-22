import SwiftUI
import SwiftData

/// Learn 首页（PRD 10）：
/// 1 当前语言与快速切换  2 继续学习卡  3 今日复习  4 句子引擎路径  5 添加语言。
struct LearnHomeView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: StoreService
    @AppStorage(AppKeys.currentPackId) private var currentPackId = ""
    @AppStorage(AppKeys.autoStartFirstLesson) private var autoStartFirstLesson = false

    @State private var showSwitcher = false
    @State private var activeLesson: LessonLaunch?
    @State private var showPaywall = false
    @State private var refreshToken = 0

    private var pack: LanguagePack? {
        ContentStore.shared.pack(id: currentPackId) ?? ContentStore.shared.packs.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if let pack {
                    content(for: pack)
                } else {
                    ContentUnavailableView("暂无语言包", systemImage: "globe", description: Text("请重新安装应用或联系支持。"))
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Phraso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let pack {
                        // 当前目标语言持续可见，点击打开 Language Switcher（PRD 08）。
                        Button {
                            showSwitcher = true
                        } label: {
                            HStack(spacing: 6) {
                                Text(pack.flag)
                                Text(pack.displayNameZh).font(.subheadline.weight(.semibold))
                                Image(systemName: "chevron.down").font(.caption2)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(PH.greenSoft))
                            .foregroundStyle(PH.greenDark)
                        }
                        .accessibilityLabel("当前语言\(pack.displayNameZh)，点击切换语言")
                    }
                }
            }
            .sheet(isPresented: $showSwitcher) {
                LanguageSwitcherView()
                    .presentationDetents([.medium, .large])
            }
            .fullScreenCover(item: $activeLesson, onDismiss: { refreshToken += 1 }) { launch in
                LessonPlayerView(pack: launch.pack, engine: launch.engine, lesson: launch.lesson, startIndex: launch.startIndex)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .onAppear {
                if currentPackId.isEmpty, let first = ContentStore.shared.packs.first {
                    currentPackId = first.languagePackId
                }
                if let pack { ProgressService.ensureLanguageAdded(pack.languagePackId, context: context) }
                // 引导结束后直接进入第一道构句练习（PRD 09 激活目标）。
                if autoStartFirstLesson, let pack,
                   let (engine, lesson, stage) = ProgressService.continueTarget(pack: pack, context: context) {
                    autoStartFirstLesson = false
                    activeLesson = LessonLaunch(pack: pack, engine: engine, lesson: lesson, startIndex: stage)
                }
            }
        }
    }

    @ViewBuilder
    private func content(for pack: LanguagePack) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                continueCard(for: pack)
                reviewCard(for: pack)
                enginePath(for: pack)
            }
            .padding(20)
        }
        .id(refreshToken)
    }

    // MARK: - 继续学习卡

    @ViewBuilder
    private func continueCard(for pack: LanguagePack) -> some View {
        if let (engine, lesson, stage) = ProgressService.continueTarget(pack: pack, context: context) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(engine.titleZh, systemImage: "gearshape.2.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(PH.greenDark)
                    Spacer()
                    Text("约 \(lesson.durationMin) 分钟")
                        .font(.caption)
                        .foregroundStyle(PH.subInk)
                }
                Text(lesson.titleZh)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(PH.ink)
                if stage > 0 {
                    Text("上次停在第 \(stage + 1) 步，可以从安全节点继续。")
                        .font(.footnote)
                        .foregroundStyle(PH.subInk)
                }
                Button(stage > 0 ? "继续学习" : "开始学习") {
                    launch(pack: pack, engine: engine, lesson: lesson, stage: stage)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .phCard()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("这门语言的已上线课程都完成了 🎉")
                    .font(.headline)
                Text("保持复习，或添加一门新语言。")
                    .font(.footnote)
                    .foregroundStyle(PH.subInk)
            }
            .phCard()
        }
    }

    // MARK: - 今日复习（仅在有到期项目时出现）

    @ViewBuilder
    private func reviewCard(for pack: LanguagePack) -> some View {
        let due = ProgressService.dueReviews(packId: pack.languagePackId, context: context)
        if !due.isEmpty {
            NavigationLink {
                ReviewSessionView(pack: pack)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2)
                        .foregroundStyle(PH.amber)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("今日复习").font(.headline).foregroundStyle(PH.ink)
                        Text("\(due.count) 个结构到期 · 预计 2–5 分钟")
                            .font(.footnote)
                            .foregroundStyle(PH.subInk)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(PH.subInk)
                }
                .phCard()
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 句子引擎路径

    private func enginePath(for pack: LanguagePack) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("句子引擎路径")
                .font(.system(.title3, design: .rounded, weight: .bold))

            ForEach(Array(pack.engines.enumerated()), id: \.element.id) { index, engine in
                EnginePathRow(
                    pack: pack,
                    engine: engine,
                    index: index,
                    locked: !store.canAccess(engine: engine),
                    onStart: { lesson, stage in
                        launch(pack: pack, engine: engine, lesson: lesson, stage: stage)
                    },
                    onLockedTap: { showPaywall = true }
                )
            }

            // 添加语言位于路径末端，不抢占主行动（PRD 10）。
            Button {
                showSwitcher = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill").foregroundStyle(PH.green)
                    Text("添加新语言").font(.headline).foregroundStyle(PH.greenDark)
                    Spacer()
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(PH.greenSoft))
            }
        }
    }

    private func launch(pack: LanguagePack, engine: SentenceEngine, lesson: Lesson, stage: Int) {
        activeLesson = LessonLaunch(pack: pack, engine: engine, lesson: lesson, startIndex: stage)
    }
}

struct LessonLaunch: Identifiable {
    let pack: LanguagePack
    let engine: SentenceEngine
    let lesson: Lesson
    let startIndex: Int
    var id: String { lesson.lessonId }
}

/// 引擎路径的一行：Locked / Available / In progress / Mastered / Coming soon。
struct EnginePathRow: View {
    @Environment(\.modelContext) private var context
    let pack: LanguagePack
    let engine: SentenceEngine
    let index: Int
    let locked: Bool
    let onStart: (Lesson, Int) -> Void
    let onLockedTap: () -> Void

    var body: some View {
        let state = rowState

        Button {
            switch state {
            case .comingSoon:
                break
            case .locked:
                onLockedTap()
            default:
                if let lesson = engine.lessons.first {
                    let stage = ProgressService.lessonRecord(packId: pack.languagePackId, lessonId: lesson.lessonId, context: context)?.stageIndex ?? 0
                    onStart(lesson, stage)
                }
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(state.badgeBackground).frame(width: 44, height: 44)
                    Image(systemName: state.badgeIcon)
                        .foregroundStyle(state.badgeForeground)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(index + 1). \(engine.titleZh)")
                        .font(.headline)
                        .foregroundStyle(state == .comingSoon ? PH.subInk : PH.ink)
                    Text(state == .comingSoon ? "即将推出" : engine.structureHint)
                        .font(.footnote)
                        .foregroundStyle(PH.subInk)
                        .lineLimit(1)
                }
                Spacer()
                Text(state.label)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(state.badgeBackground))
                    .foregroundStyle(state.badgeForeground)
            }
            .phCard()
            .opacity(state == .comingSoon ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(engine.titleZh)，状态：\(state.label)")
    }

    private var rowState: EngineRowState {
        if engine.status == .comingSoon { return .comingSoon }
        if locked { return .locked }
        let mastery = ProgressService.mastery(packId: pack.languagePackId, engineId: engine.engineId, context: context)
        if let mastery, mastery.state == .stable || (mastery.state == .learning && mastery.masteryScore >= 0.6) {
            return mastery.state == .stable ? .mastered : .inProgressMastered
        }
        let anyStarted = engine.lessons.contains { lesson in
            ProgressService.lessonRecord(packId: pack.languagePackId, lessonId: lesson.lessonId, context: context) != nil
        }
        return anyStarted ? .inProgress : .available
    }
}

enum EngineRowState: Equatable {
    case locked, available, inProgress, inProgressMastered, mastered, comingSoon

    var label: String {
        switch self {
        case .locked: return "Plus"
        case .available: return "可开始"
        case .inProgress: return "进行中"
        case .inProgressMastered: return "复习中"
        case .mastered: return "已掌握"
        case .comingSoon: return "即将推出"
        }
    }

    var badgeIcon: String {
        switch self {
        case .locked: return "lock.fill"
        case .available: return "play.fill"
        case .inProgress: return "ellipsis"
        case .inProgressMastered: return "clock.arrow.circlepath"
        case .mastered: return "checkmark"
        case .comingSoon: return "hourglass"
        }
    }

    var badgeBackground: Color {
        switch self {
        case .locked: return PH.purple.opacity(0.15)
        case .available: return PH.blue.opacity(0.15)
        case .inProgress, .inProgressMastered: return PH.amber.opacity(0.18)
        case .mastered: return PH.greenSoft
        case .comingSoon: return Color(.systemGray5)
        }
    }

    var badgeForeground: Color {
        switch self {
        case .locked: return PH.purple
        case .available: return PH.blue
        case .inProgress, .inProgressMastered: return PH.amber
        case .mastered: return PH.greenDark
        case .comingSoon: return PH.subInk
        }
    }
}
