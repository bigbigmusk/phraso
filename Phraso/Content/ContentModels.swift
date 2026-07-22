import Foundation

// MARK: - 内容模型（对应 PRD 15 内容 Schema，随语言包 JSON 下发）

struct LanguagePack: Codable, Identifiable, Hashable {
    let languagePackId: String
    let targetLocale: String
    let displayNameZh: String
    let displayNameNative: String
    let flag: String
    let version: Int
    let romanization: Bool
    let engines: [SentenceEngine]

    var id: String { languagePackId }

    /// 可学习（已上线）的引擎
    var availableEngines: [SentenceEngine] {
        engines.filter { $0.status == .available }
    }
}

enum EngineStatus: String, Codable {
    case available
    case comingSoon = "coming_soon"
}

struct SentenceEngine: Codable, Identifiable, Hashable {
    let engineId: String
    let titleZh: String
    let structureHint: String
    let summaryZh: String
    let status: EngineStatus
    let free: Bool
    let lessons: [Lesson]

    var id: String { engineId }
}

struct Lesson: Codable, Identifiable, Hashable {
    let lessonId: String
    let titleZh: String
    let durationMin: Int
    let objectiveZh: String
    let exercises: [Exercise]

    var id: String { lessonId }
}

enum ExerciseType: String, Codable {
    case warmStart = "warm_start"
    case understand
    case guidedRecall = "guided_recall"
    case assemble
    case speak
    case transfer
}

struct Exercise: Codable, Identifiable, Hashable {
    let exerciseId: String
    let type: ExerciseType
    let promptZh: String?
    let explanationZh: String?
    let canonical: String?
    let romanized: String?
    let blocks: [String]?
    let distractors: [String]?
    let acceptableVariants: [String]?
    let focusTags: [String]?
    let hintZh: String?

    var id: String { exerciseId }
}

// MARK: - 反馈标签（PRD 13：P0 反馈分类）

enum FeedbackTag: String {
    case structureCorrect = "structure_correct"
    case wordOrder = "word_order"
    case missingRequired = "missing_required"
    case pronunciationAttention = "pronunciation_attention"
    case recognitionUncertain = "recognition_uncertain"

    var titleZh: String {
        switch self {
        case .structureCorrect: return "结构正确"
        case .wordOrder: return "词块齐全，顺序还差一点"
        case .missingRequired: return "少了一个必需成分"
        case .pronunciationAttention: return "发音可以再清晰一点"
        case .recognitionUncertain: return "没有听清"
        }
    }

    var adviceZh: String {
        switch self {
        case .structureCorrect: return "你自己组装出来了，继续保持这种思考方式。"
        case .wordOrder: return "再看一眼目标语言的语序，只调整位置就好。"
        case .missingRequired: return "找找缺少的那个成分，其余部分都是对的。"
        case .pronunciationAttention: return "听一遍参考音频，只关注一个音。"
        case .recognitionUncertain: return "可以再说一遍或直接跳过，这不算错误。"
        }
    }

    var systemImage: String {
        switch self {
        case .structureCorrect: return "checkmark.circle.fill"
        case .wordOrder: return "arrow.left.arrow.right.circle.fill"
        case .missingRequired: return "puzzlepiece.fill"
        case .pronunciationAttention: return "waveform.circle.fill"
        case .recognitionUncertain: return "questionmark.circle.fill"
        }
    }
}
