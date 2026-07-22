import Foundation

/// 词块题判定（PRD 12）：
/// 比较 token / 语法槽序列，不使用简单字符串全等；
/// 标点、大小写等非核心差异不造成失败。
enum AssembleEvaluator {

    struct Result {
        let tag: FeedbackTag
        /// 与目标不一致的位置（用于突出冲突位置，而非满屏标红）
        let conflictIndices: [Int]
    }

    static func evaluate(chosen: [String], target: [String]) -> Result {
        let normalizedChosen = chosen.map(normalize)
        let normalizedTarget = target.map(normalize)

        if normalizedChosen == normalizedTarget {
            return Result(tag: .structureCorrect, conflictIndices: [])
        }

        let chosenSet = normalizedChosen.reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        let targetSet = normalizedTarget.reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }

        if chosenSet == targetSet {
            // 词块齐全但顺序不对 → 只提示顺序（word_order）。
            let conflicts = zip(normalizedChosen, normalizedTarget).enumerated()
                .filter { $0.element.0 != $0.element.1 }
                .map(\.offset)
            return Result(tag: .wordOrder, conflictIndices: conflicts)
        }

        // 缺少必需成分（missing_required）。
        let conflicts = normalizedChosen.enumerated()
            .filter { index, token in
                index >= normalizedTarget.count || normalizedTarget[index] != token
            }
            .map(\.offset)
        return Result(tag: .missingRequired, conflictIndices: conflicts)
    }

    static func normalize(_ token: String) -> String {
        token.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)
    }
}

/// 确定性洗牌：同一道题每次进入顺序一致，避免“重进换题”的作弊感，
/// 也让 UI 测试可复现。
enum SeededShuffle {
    static func shuffle<T>(_ items: [T], seed: String) -> [T] {
        var generator = SplitMix64(seed: UInt64(truncatingIfNeeded: stableHash(seed)))
        return items.shuffled(using: &generator)
    }

    private static func stableHash(_ text: String) -> Int {
        var hash = 5381
        for byte in text.utf8 {
            hash = ((hash << 5) &+ hash) &+ Int(byte)
        }
        return hash
    }
}

struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
