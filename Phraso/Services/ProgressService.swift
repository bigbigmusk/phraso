import Foundation
import SwiftData

/// 进度读写的统一入口。所有查询都以 packId 为边界，
/// 保证多语言进度、复习与下载互不干扰（PRD 07 / 14）。
enum ProgressService {

    // MARK: - 语言

    static func ensureLanguageAdded(_ packId: String, context: ModelContext) {
        let descriptor = FetchDescriptor<LanguageProgress>(
            predicate: #Predicate { $0.packId == packId }
        )
        if let existing = try? context.fetch(descriptor), !existing.isEmpty { return }
        context.insert(LanguageProgress(packId: packId))
        try? context.save()
    }

    static func languageProgress(_ packId: String, context: ModelContext) -> LanguageProgress? {
        let descriptor = FetchDescriptor<LanguageProgress>(
            predicate: #Predicate { $0.packId == packId }
        )
        return (try? context.fetch(descriptor))?.first
    }

    static func addedLanguages(context: ModelContext) -> [LanguageProgress] {
        let descriptor = FetchDescriptor<LanguageProgress>(sortBy: [SortDescriptor(\.addedAt)])
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - 课程

    static func lessonRecord(packId: String, lessonId: String, context: ModelContext) -> LessonRecord? {
        let descriptor = FetchDescriptor<LessonRecord>(
            predicate: #Predicate { $0.packId == packId && $0.lessonId == lessonId }
        )
        return (try? context.fetch(descriptor))?.first
    }

    static func upsertLessonProgress(packId: String, lessonId: String, stageIndex: Int, context: ModelContext) {
        if let record = lessonRecord(packId: packId, lessonId: lessonId, context: context) {
            if record.status != .complete {
                record.stageIndex = stageIndex
                record.status = .inProgress
            }
        } else {
            context.insert(LessonRecord(packId: packId, lessonId: lessonId, stageIndex: stageIndex))
        }
        if let lang = languageProgress(packId, context: context) {
            lang.lastLessonId = lessonId
        }
        try? context.save()
    }

    static func completeLesson(packId: String, lessonId: String, minutes: Double, context: ModelContext) {
        let record = lessonRecord(packId: packId, lessonId: lessonId, context: context)
            ?? {
                let new = LessonRecord(packId: packId, lessonId: lessonId)
                context.insert(new)
                return new
            }()
        record.status = .complete
        record.completedAt = .now
        context.insert(StudyEvent(packId: packId, kind: "lesson", minutes: minutes))
        try? context.save()
    }

    static func completedLessons(packId: String, context: ModelContext) -> [LessonRecord] {
        let complete = LessonStatus.complete.rawValue
        let descriptor = FetchDescriptor<LessonRecord>(
            predicate: #Predicate { $0.packId == packId && $0.statusRaw == complete }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 下一步学习目标：优先未完成的进行中课程，其次第一节未开始的课。
    static func continueTarget(pack: LanguagePack, context: ModelContext) -> (SentenceEngine, Lesson, Int)? {
        let completed = Set(completedLessons(packId: pack.languagePackId, context: context).map(\.lessonId))
        for engine in pack.availableEngines {
            for lesson in engine.lessons where !completed.contains(lesson.lessonId) {
                let stage = lessonRecord(packId: pack.languagePackId, lessonId: lesson.lessonId, context: context)?.stageIndex ?? 0
                return (engine, lesson, stage)
            }
        }
        return nil
    }

    // MARK: - 掌握度

    static func mastery(packId: String, engineId: String, context: ModelContext) -> EngineMastery? {
        let descriptor = FetchDescriptor<EngineMastery>(
            predicate: #Predicate { $0.packId == packId && $0.engineId == engineId }
        )
        return (try? context.fetch(descriptor))?.first
    }

    static func ensureMastery(packId: String, engineId: String, context: ModelContext) -> EngineMastery {
        if let existing = mastery(packId: packId, engineId: engineId, context: context) {
            return existing
        }
        let new = EngineMastery(packId: packId, engineId: engineId)
        context.insert(new)
        try? context.save()
        return new
    }

    static func dueReviews(packId: String, context: ModelContext) -> [EngineMastery] {
        let now = Date.now
        let descriptor = FetchDescriptor<EngineMastery>(
            predicate: #Predicate { $0.packId == packId && $0.dueAt != nil && $0.dueAt! <= now }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func allMastery(packId: String, context: ModelContext) -> [EngineMastery] {
        let descriptor = FetchDescriptor<EngineMastery>(
            predicate: #Predicate { $0.packId == packId }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - 每周统计

    static func weeklyStats(packId: String, context: ModelContext) -> (lessons: Int, minutes: Double) {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let descriptor = FetchDescriptor<StudyEvent>(
            predicate: #Predicate { $0.packId == packId && $0.date >= weekAgo }
        )
        let events = (try? context.fetch(descriptor)) ?? []
        let lessons = events.filter { $0.kind == "lesson" }.count
        return (lessons, events.reduce(0) { $0 + $1.minutes })
    }

    // MARK: - 危险操作（设置里明确区分，PRD 08）

    /// 重置单门语言进度；不影响其他语言。
    static func resetLanguage(_ packId: String, context: ModelContext) {
        for record in (try? context.fetch(FetchDescriptor<LessonRecord>(predicate: #Predicate { $0.packId == packId }))) ?? [] {
            context.delete(record)
        }
        for mastery in (try? context.fetch(FetchDescriptor<EngineMastery>(predicate: #Predicate { $0.packId == packId }))) ?? [] {
            context.delete(mastery)
        }
        for event in (try? context.fetch(FetchDescriptor<StudyEvent>(predicate: #Predicate { $0.packId == packId }))) ?? [] {
            context.delete(event)
        }
        if let lang = languageProgress(packId, context: context) {
            lang.lastLessonId = nil
        }
        try? context.save()
    }

    /// 删除全部本机数据（用于删除账户 / 抹掉数据）。
    static func eraseAll(context: ModelContext) {
        try? context.delete(model: LessonRecord.self)
        try? context.delete(model: EngineMastery.self)
        try? context.delete(model: StudyEvent.self)
        try? context.delete(model: LanguageProgress.self)
        try? context.save()
    }
}
