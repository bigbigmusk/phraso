import SwiftUI
import SwiftData

/// Review 一级页（PRD 08 / 14）：到期结构、快速复习。
/// 无复习时显示下一次预计时间，不制造焦虑。
struct ReviewHomeView: View {
    @Environment(\.modelContext) private var context
    @State private var refreshToken = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(languageSections, id: \.pack.id) { section in
                        reviewSection(section)
                    }
                    if languageSections.allSatisfy({ $0.due.isEmpty }) {
                        emptyState
                    }
                }
                .padding(20)
            }
            .id(refreshToken)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("复习")
            .onAppear { refreshToken += 1 }
        }
    }

    private struct Section {
        let pack: LanguagePack
        let due: [EngineMastery]
        let nextDue: Date?
    }

    private var languageSections: [Section] {
        ProgressService.addedLanguages(context: context).compactMap { lang in
            guard let pack = ContentStore.shared.pack(id: lang.packId) else { return nil }
            let due = ProgressService.dueReviews(packId: lang.packId, context: context)
            let nextDue = ProgressService.allMastery(packId: lang.packId, context: context)
                .compactMap(\.dueAt)
                .filter { $0 > .now }
                .min()
            return Section(pack: pack, due: due, nextDue: nextDue)
        }
    }

    @ViewBuilder
    private func reviewSection(_ section: Section) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(section.pack.flag)
                Text(section.pack.displayNameZh).font(.headline)
                Spacer()
                if !section.due.isEmpty {
                    Text("\(section.due.count) 项到期")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(PH.amber.opacity(0.18)))
                        .foregroundStyle(PH.amber)
                }
            }

            if section.due.isEmpty {
                if let nextDue = section.nextDue {
                    Text("暂无到期项目。下次复习：\(nextDue.formatted(.relative(presentation: .named)))")
                        .font(.subheadline)
                        .foregroundStyle(PH.subInk)
                } else {
                    Text("完成一节课并通过迁移题后，这里会安排复习。")
                        .font(.subheadline)
                        .foregroundStyle(PH.subInk)
                }
            } else {
                ForEach(section.due, id: \.persistentModelID) { mastery in
                    if let engine = ContentStore.shared.engine(packId: section.pack.languagePackId, engineId: mastery.engineId) {
                        HStack {
                            Image(systemName: mastery.state == .needsReview ? "exclamationmark.arrow.circlepath" : "clock.arrow.circlepath")
                                .foregroundStyle(mastery.state == .needsReview ? PH.attention : PH.amber)
                            Text(engine.titleZh).font(.subheadline)
                            Spacer()
                        }
                    }
                }
                NavigationLink {
                    ReviewSessionView(pack: section.pack)
                } label: {
                    Text("开始复习（约 \(min(section.due.count * 1 + 1, 5)) 分钟）")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(PH.green))
                        .foregroundStyle(.white)
                }
            }
        }
        .phCard()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 40))
                .foregroundStyle(PH.subInk.opacity(0.5))
            Text("今天没有需要复习的内容")
                .font(.headline)
            Text("按结构掌握度安排复习，不制造打卡压力。")
                .font(.footnote)
                .foregroundStyle(PH.subInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

/// 快速复习会话（PRD 14）：3–7 题；先主动回忆，再提供词块。
/// 复习题复用引擎课程中的迁移/组装练习。
struct ReviewSessionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let pack: LanguagePack

    @State private var queue: [(EngineMastery, Exercise)] = []
    @State private var index = 0
    @State private var finishedCount = 0
    @State private var loaded = false

    var body: some View {
        Group {
            if !loaded {
                ProgressView()
            } else if index < queue.count {
                let (mastery, exercise) = queue[index]
                VStack(spacing: 0) {
                    HStack {
                        Text("复习 \(index + 1) / \(queue.count)")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(PH.subInk)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    TransferView(pack: pack, exercise: exercise) { firstTry in
                        if firstTry {
                            ReviewScheduler.recordReviewSuccess(mastery)
                        } else {
                            ReviewScheduler.recordStructureFailure(mastery)
                        }
                        try? context.save()
                        finishedCount += 1
                        index += 1
                    }
                    .id(exercise.exerciseId + String(index))
                }
            } else {
                completionView
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("快速复习")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: buildQueue)
    }

    private func buildQueue() {
        guard !loaded else { return }
        var built: [(EngineMastery, Exercise)] = []
        // 先复习 needs_review，再按到期时间；每次 3–7 题（PRD 14）。
        let due = ProgressService.dueReviews(packId: pack.languagePackId, context: context)
            .sorted { lhs, rhs in
                if (lhs.state == .needsReview) != (rhs.state == .needsReview) {
                    return lhs.state == .needsReview
                }
                return (lhs.dueAt ?? .distantPast) < (rhs.dueAt ?? .distantPast)
            }
        for mastery in due.prefix(7) {
            guard let engine = ContentStore.shared.engine(packId: pack.languagePackId, engineId: mastery.engineId) else { continue }
            let reviewables = engine.lessons.flatMap(\.exercises)
                .filter { $0.type == .transfer || $0.type == .assemble }
            if let exercise = reviewables.last {
                built.append((mastery, exercise))
            }
        }
        queue = built
        loaded = true
    }

    private var completionView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(PH.green)
            Text("复习完成")
                .font(.system(.title, design: .rounded, weight: .bold))
            Text("完成 \(finishedCount) 项。下一次复习会根据表现自动安排。")
                .font(.subheadline)
                .foregroundStyle(PH.subInk)
            Spacer()
            Button("返回") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
    }
}
