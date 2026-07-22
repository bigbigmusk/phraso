import Foundation
import SwiftData

// MARK: - 本地进度模型（PRD 07 / 14：进度按 language_pack_id 完全独立）

/// 用户添加过的语言及其偏好；暂停不清空进度。
@Model
final class LanguageProgress {
    @Attribute(.unique) var packId: String
    var addedAt: Date
    var isActive: Bool
    var lastLessonId: String?
    var romanizationEnabled: Bool

    init(packId: String, addedAt: Date = .now, isActive: Bool = true, romanizationEnabled: Bool = true) {
        self.packId = packId
        self.addedAt = addedAt
        self.isActive = isActive
        self.romanizationEnabled = romanizationEnabled
    }
}

enum LessonStatus: String {
    case notStarted = "not_started"
    case inProgress = "in_progress"
    case complete
}

/// 单节课的进度：退出时保存到最近安全节点（题目边界）。
@Model
final class LessonRecord {
    var packId: String
    var lessonId: String
    var statusRaw: String
    var stageIndex: Int
    var completedAt: Date?

    init(packId: String, lessonId: String, status: LessonStatus = .inProgress, stageIndex: Int = 0) {
        self.packId = packId
        self.lessonId = lessonId
        self.statusRaw = status.rawValue
        self.stageIndex = stageIndex
    }

    var status: LessonStatus {
        get { LessonStatus(rawValue: statusRaw) ?? .notStarted }
        set { statusRaw = newValue.rawValue }
    }
}

enum MasteryState: String {
    case new
    case learning
    case stable
    case needsReview = "needs_review"
}

/// 句子引擎掌握度：由迁移题与间隔复习驱动（PRD 14）。
/// “掌握”必须来自至少一次无直接提示的迁移成功。
@Model
final class EngineMastery {
    var packId: String
    var engineId: String
    var stateRaw: String
    var masteryScore: Double
    var intervalDays: Int
    var dueAt: Date?
    var lastReviewedAt: Date?
    var lapses: Int

    init(packId: String, engineId: String) {
        self.packId = packId
        self.engineId = engineId
        self.stateRaw = MasteryState.new.rawValue
        self.masteryScore = 0
        self.intervalDays = 0
        self.lapses = 0
    }

    var state: MasteryState {
        get { MasteryState(rawValue: stateRaw) ?? .new }
        set { stateRaw = newValue.rawValue }
    }

    var isDue: Bool {
        guard let dueAt else { return false }
        return dueAt <= .now
    }
}

/// 轻量学习事件：只存聚合所需字段，不存原始录音或答案全文（PRD 22）。
@Model
final class StudyEvent {
    var packId: String
    var kind: String
    var minutes: Double
    var date: Date

    init(packId: String, kind: String, minutes: Double, date: Date = .now) {
        self.packId = packId
        self.kind = kind
        self.minutes = minutes
        self.date = date
    }
}
