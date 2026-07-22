import SwiftUI
import SwiftData

/// 进度页（PRD 14）：优先展示“你能完成什么”——
/// 已掌握的句子引擎、可迁移场景、本周有效学习。
/// 不以连续天数为首屏主指标，不以断签惩罚用户。
struct ProgressHomeView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(AppKeys.currentPackId) private var currentPackId = ""
    @State private var refreshToken = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(languageCards, id: \.pack.id) { card in
                        languageCard(card)
                    }
                    if languageCards.isEmpty {
                        ContentUnavailableView("还没有学习记录", systemImage: "chart.bar", description: Text("完成第一节课后，这里会展示你的能力进度。"))
                    }
                }
                .padding(20)
            }
            .id(refreshToken)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("进度")
            .onAppear { refreshToken += 1 }
        }
    }

    private struct Card {
        let pack: LanguagePack
        let masteredEngines: Int
        let learningEngines: Int
        let totalAvailable: Int
        let completedLessons: Int
        let weeklyLessons: Int
        let weeklyMinutes: Double
        let isCurrent: Bool
    }

    private var languageCards: [Card] {
        ProgressService.addedLanguages(context: context).compactMap { lang in
            guard let pack = ContentStore.shared.pack(id: lang.packId) else { return nil }
            let mastery = ProgressService.allMastery(packId: lang.packId, context: context)
            let weekly = ProgressService.weeklyStats(packId: lang.packId, context: context)
            return Card(
                pack: pack,
                masteredEngines: mastery.filter { $0.state == .stable }.count,
                learningEngines: mastery.filter { $0.state == .learning || $0.state == .needsReview }.count,
                totalAvailable: pack.availableEngines.count,
                completedLessons: ProgressService.completedLessons(packId: lang.packId, context: context).count,
                weeklyLessons: weekly.lessons,
                weeklyMinutes: weekly.minutes,
                isCurrent: lang.packId == currentPackId
            )
        }
    }

    private func languageCard(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(card.pack.flag).font(.title2)
                Text(card.pack.displayNameZh).font(.headline)
                if card.isCurrent {
                    Text("当前")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(PH.greenSoft))
                        .foregroundStyle(PH.greenDark)
                }
                Spacer()
            }

            // 引擎掌握度条
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("句子引擎").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(card.masteredEngines) 稳定 · \(card.learningEngines) 学习中 · 共 \(card.totalAvailable)")
                        .font(.caption)
                        .foregroundStyle(PH.subInk)
                }
                GeometryReader { geo in
                    let total = max(card.totalAvailable, 1)
                    HStack(spacing: 2) {
                        Rectangle().fill(PH.green)
                            .frame(width: geo.size.width * CGFloat(card.masteredEngines) / CGFloat(total))
                        Rectangle().fill(PH.amber)
                            .frame(width: geo.size.width * CGFloat(card.learningEngines) / CGFloat(total))
                        Rectangle().fill(Color(.systemGray5))
                    }
                }
                .frame(height: 8)
                .clipShape(Capsule())
                .accessibilityLabel("\(card.pack.displayNameZh)：\(card.masteredEngines) 个引擎稳定，\(card.learningEngines) 个学习中，共 \(card.totalAvailable) 个")
            }

            HStack(spacing: 12) {
                statTile(value: "\(card.completedLessons)", label: "完成课程")
                statTile(value: "\(card.weeklyLessons)", label: "本周课程")
                statTile(value: "\(Int(card.weeklyMinutes.rounded()))", label: "本周分钟")
            }
        }
        .phCard()
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PH.ink)
            Text(label)
                .font(.caption)
                .foregroundStyle(PH.subInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.tertiarySystemGroupedBackground)))
    }
}
