import XCTest
@testable import Phraso

// MARK: - 词块判定（PRD 12）

final class AssembleEvaluatorTests: XCTestCase {

    func testExactMatchIsStructureCorrect() {
        let result = AssembleEvaluator.evaluate(
            chosen: ["Je", "veux", "parler", "français"],
            target: ["Je", "veux", "parler", "français"]
        )
        XCTAssertEqual(result.tag, .structureCorrect)
        XCTAssertTrue(result.conflictIndices.isEmpty)
    }

    func testCaseAndPunctuationDifferencesDoNotFail() {
        // 非核心差异（大小写）不应造成失败（PRD 12）
        let result = AssembleEvaluator.evaluate(
            chosen: ["je", "VEUX", "parler", "français"],
            target: ["Je", "veux", "parler", "français"]
        )
        XCTAssertEqual(result.tag, .structureCorrect)
    }

    func testWrongOrderIsWordOrderWithConflictPositions() {
        let result = AssembleEvaluator.evaluate(
            chosen: ["veux", "Je", "parler", "français"],
            target: ["Je", "veux", "parler", "français"]
        )
        XCTAssertEqual(result.tag, .wordOrder)
        XCTAssertEqual(result.conflictIndices, [0, 1])
    }

    func testMissingBlockIsMissingRequired() {
        let result = AssembleEvaluator.evaluate(
            chosen: ["Je", "parler"],
            target: ["Je", "veux", "parler"]
        )
        XCTAssertEqual(result.tag, .missingRequired)
    }

    func testGermanVerbFinalOrderMatters() {
        // 德语句框：动词必须在句尾
        let wrong = AssembleEvaluator.evaluate(
            chosen: ["Ich", "will", "sprechen", "Deutsch"],
            target: ["Ich", "will", "Deutsch", "sprechen"]
        )
        XCTAssertEqual(wrong.tag, .wordOrder)
    }

    func testKoreanMeaningUnitBlocks() {
        let result = AssembleEvaluator.evaluate(
            chosen: ["한국어로", "말하고 싶어요"],
            target: ["한국어로", "말하고 싶어요"]
        )
        XCTAssertEqual(result.tag, .structureCorrect)
    }

    func testSeededShuffleIsDeterministic() {
        let items = ["a", "b", "c", "d", "e"]
        XCTAssertEqual(
            SeededShuffle.shuffle(items, seed: "fr_want_01_assemble1"),
            SeededShuffle.shuffle(items, seed: "fr_want_01_assemble1")
        )
    }
}

// MARK: - 复习调度（PRD 14）

final class ReviewSchedulerTests: XCTestCase {

    private func makeMastery() -> EngineMastery {
        EngineMastery(packId: "fr_zh-Hans_v1", engineId: "fr_engine_01_want")
    }

    func testTransferSuccessSchedulesOneDayReview() {
        let mastery = makeMastery()
        ReviewScheduler.recordTransferSuccess(mastery)
        XCTAssertEqual(mastery.state, .learning)
        XCTAssertEqual(mastery.intervalDays, 1)
        XCTAssertNotNil(mastery.dueAt)
        XCTAssertGreaterThanOrEqual(mastery.masteryScore, 0.6)
    }

    func testReviewSuccessProgressesThroughIntervals() {
        let mastery = makeMastery()
        ReviewScheduler.recordTransferSuccess(mastery)
        ReviewScheduler.recordReviewSuccess(mastery)
        XCTAssertEqual(mastery.intervalDays, 3)
        ReviewScheduler.recordReviewSuccess(mastery)
        XCTAssertEqual(mastery.intervalDays, 7)
        ReviewScheduler.recordReviewSuccess(mastery)
        XCTAssertEqual(mastery.intervalDays, 14)
        XCTAssertEqual(mastery.state, .stable)
    }

    func testStructureFailureResetsIntervalWithoutZeroingScore() {
        let mastery = makeMastery()
        ReviewScheduler.recordTransferSuccess(mastery)
        ReviewScheduler.recordReviewSuccess(mastery)
        ReviewScheduler.recordStructureFailure(mastery)
        XCTAssertEqual(mastery.state, .needsReview)
        XCTAssertEqual(mastery.intervalDays, 1)
        XCTAssertEqual(mastery.lapses, 1)
        // 不清零：温和降低，不羞辱用户
        XCTAssertGreaterThanOrEqual(mastery.masteryScore, 0.3)
    }

    func testUncertainRecognitionDoesNotLowerMastery() {
        // 识别不确定绝不降低掌握度（PRD 13 / 14）
        let mastery = makeMastery()
        ReviewScheduler.recordTransferSuccess(mastery)
        let scoreBefore = mastery.masteryScore
        let stateBefore = mastery.state
        ReviewScheduler.recordUncertain(mastery)
        XCTAssertEqual(mastery.masteryScore, scoreBefore)
        XCTAssertEqual(mastery.state, stateBefore)
    }
}

// MARK: - 口语转写判定（PRD 13）

final class SpeechEvaluationTests: XCTestCase {

    func testGoodTranscriptIsStructureCorrect() {
        XCTAssertEqual(
            SpeechService.evaluate(transcript: "je veux parler français", canonical: "Je veux parler français."),
            .structureCorrect
        )
    }

    func testEmptyTranscriptIsUncertainNotWrong() {
        // 低置信 / 空转写不得包装成学习者错误
        XCTAssertEqual(
            SpeechService.evaluate(transcript: "", canonical: "Je veux parler français."),
            .recognitionUncertain
        )
    }

    func testPartialMatchIsPronunciationAttention() {
        XCTAssertEqual(
            SpeechService.evaluate(transcript: "je veux", canonical: "Je veux parler français."),
            .pronunciationAttention
        )
    }

    func testUnrelatedTranscriptIsUncertain() {
        XCTAssertEqual(
            SpeechService.evaluate(transcript: "bonjour monsieur", canonical: "Je veux parler français."),
            .recognitionUncertain
        )
    }
}

// MARK: - 内容包完整性（PRD 15 / 16 发布阻断项）

final class ContentPackTests: XCTestCase {

    private func normalizedTokens(_ text: String) -> [String] {
        SpeechService.tokens(of: text)
    }

    func testAllLaunchPacksLoad() {
        let packs = ContentStore.shared.packs
        XCTAssertEqual(packs.count, 4, "首发四语必须全部可解码")
        XCTAssertEqual(Set(packs.map(\.targetLocale)), ["fr-FR", "es-ES", "de-DE", "ko-KR"])
    }

    func testEveryPackHasTwelveEnginesAndFreeFirstEngine() {
        for pack in ContentStore.shared.packs {
            XCTAssertEqual(pack.engines.count, 12, "\(pack.languagePackId) 引擎数量")
            XCTAssertTrue(pack.engines.first?.free ?? false, "\(pack.languagePackId) 第 1 个引擎必须免费")
        }
    }

    func testAvailableEnginesHaveLessons() {
        for pack in ContentStore.shared.packs {
            for engine in pack.availableEngines {
                XCTAssertFalse(engine.lessons.isEmpty, "\(engine.engineId) 标记可用但没有课程")
            }
        }
    }

    func testExerciseIdsAreUniquePerPack() {
        for pack in ContentStore.shared.packs {
            var seen = Set<String>()
            for engine in pack.engines {
                for lesson in engine.lessons {
                    for exercise in lesson.exercises {
                        XCTAssertTrue(seen.insert(exercise.exerciseId).inserted, "重复的 exercise_id: \(exercise.exerciseId)")
                    }
                }
            }
        }
    }

    func testAssembleBlocksMatchCanonical() {
        // 词块拼起来必须与参考答案 token 一致，否则正确组装会被误判（发布阻断项）
        for pack in ContentStore.shared.packs {
            for engine in pack.engines {
                for lesson in engine.lessons {
                    for exercise in lesson.exercises where exercise.type == .assemble || exercise.type == .transfer {
                        guard let blocks = exercise.blocks, let canonical = exercise.canonical else {
                            XCTFail("\(exercise.exerciseId) 缺少 blocks 或 canonical")
                            continue
                        }
                        XCTAssertEqual(
                            normalizedTokens(blocks.joined(separator: " ")),
                            normalizedTokens(canonical),
                            "\(exercise.exerciseId) 词块与参考答案不一致"
                        )
                        for distractor in exercise.distractors ?? [] {
                            XCTAssertFalse(blocks.contains(distractor), "\(exercise.exerciseId) 干扰词块与正确词块重复: \(distractor)")
                        }
                    }
                }
            }
        }
    }

    func testLessonsStartWithThinkingBeforeReveal() {
        // 教学原则：必须先出现任务与思考，再允许揭晓（PRD 03）
        for pack in ContentStore.shared.packs {
            for engine in pack.availableEngines {
                for lesson in engine.lessons {
                    let types = lesson.exercises.map(\.type)
                    XCTAssertTrue(types.contains(.guidedRecall), "\(lesson.lessonId) 缺少引导构句")
                    XCTAssertTrue(types.contains(.transfer), "\(lesson.lessonId) 缺少迁移题")
                    if let recallIndex = types.firstIndex(of: .guidedRecall),
                       let understandIndex = types.firstIndex(of: .understand) {
                        XCTAssertLessThan(understandIndex, recallIndex, "\(lesson.lessonId) 应先理解后构句")
                    }
                    XCTAssertEqual(types.last, .transfer, "\(lesson.lessonId) 迁移题应是最后一步")
                }
            }
        }
    }

    func testKoreanPackProvidesRomanization() {
        guard let ko = ContentStore.shared.packs.first(where: { $0.targetLocale == "ko-KR" }) else {
            return XCTFail("缺少韩语包")
        }
        XCTAssertTrue(ko.romanization)
        for engine in ko.availableEngines {
            for lesson in engine.lessons {
                for exercise in lesson.exercises where exercise.canonical != nil && exercise.type != .warmStart {
                    XCTAssertNotNil(exercise.romanized, "\(exercise.exerciseId) 韩语参考句缺少罗马字辅助")
                }
            }
        }
    }
}
