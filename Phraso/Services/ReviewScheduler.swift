import Foundation
import SwiftData

/// 复习调度（PRD 14）：
/// 首次成功迁移 → 约 1 天后复习；随后 3、7、14 天。
/// 结构错误提高优先级；识别不确定不降低掌握度。
enum ReviewScheduler {

    static let intervals = [1, 3, 7, 14]

    /// 课内迁移题首次成功：进入 learning 并安排首次复习。
    static func recordTransferSuccess(_ mastery: EngineMastery) {
        mastery.masteryScore = max(mastery.masteryScore, 0.6)
        mastery.state = .learning
        mastery.intervalDays = intervals[0]
        mastery.dueAt = date(afterDays: intervals[0])
        mastery.lastReviewedAt = .now
    }

    /// 到期复习成功：间隔进位，达到最长间隔后视为 stable。
    static func recordReviewSuccess(_ mastery: EngineMastery) {
        let currentIndex = intervals.firstIndex(of: mastery.intervalDays) ?? -1
        let nextIndex = min(currentIndex + 1, intervals.count - 1)
        mastery.intervalDays = intervals[nextIndex]
        mastery.dueAt = date(afterDays: intervals[nextIndex])
        mastery.masteryScore = min(1, mastery.masteryScore + 0.15)
        mastery.state = nextIndex == intervals.count - 1 ? .stable : .learning
        mastery.lastReviewedAt = .now
    }

    /// 结构性错误：回到最短间隔并标记需要复习。不羞辱、不扣分清零。
    static func recordStructureFailure(_ mastery: EngineMastery) {
        mastery.lapses += 1
        mastery.intervalDays = intervals[0]
        mastery.dueAt = date(afterDays: intervals[0])
        mastery.masteryScore = max(0.3, mastery.masteryScore - 0.2)
        mastery.state = .needsReview
        mastery.lastReviewedAt = .now
    }

    /// 识别不确定：只顺延，不改变掌握度（PRD 13 / 14）。
    static func recordUncertain(_ mastery: EngineMastery) {
        mastery.dueAt = date(afterDays: max(1, mastery.intervalDays))
        mastery.lastReviewedAt = .now
    }

    private static func date(afterDays days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: .now) ?? .now
    }
}
