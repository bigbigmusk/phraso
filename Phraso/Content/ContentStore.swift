import Foundation

/// 语言包内容仓库：MVP 阶段从 App 包内加载签名前的 JSON。
/// 架构上按 language_pack_id 寻址，新增语言 = 新增一个通过 QA 的 JSON 包，
/// 不需要修改核心学习流程（PRD 07）。
final class ContentStore {
    static let shared = ContentStore()

    /// 首发四语；追加语言只需在此登记文件名。
    private static let bundledPackFiles = ["fr", "es", "de", "ko"]

    let packs: [LanguagePack]

    private init() {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        var loaded: [LanguagePack] = []
        for file in Self.bundledPackFiles {
            guard let url = Bundle.main.url(forResource: file, withExtension: "json"),
                  let data = try? Data(contentsOf: url) else {
                assertionFailure("缺少语言包资源: \(file).json")
                continue
            }
            do {
                loaded.append(try decoder.decode(LanguagePack.self, from: data))
            } catch {
                assertionFailure("语言包解析失败 \(file).json: \(error)")
            }
        }
        packs = loaded
    }

    func pack(id: String) -> LanguagePack? {
        packs.first { $0.languagePackId == id }
    }

    func engine(packId: String, engineId: String) -> SentenceEngine? {
        pack(id: packId)?.engines.first { $0.engineId == engineId }
    }

    func lesson(packId: String, lessonId: String) -> (SentenceEngine, Lesson)? {
        guard let pack = pack(id: packId) else { return nil }
        for engine in pack.engines {
            if let lesson = engine.lessons.first(where: { $0.lessonId == lessonId }) {
                return (engine, lesson)
            }
        }
        return nil
    }
}
