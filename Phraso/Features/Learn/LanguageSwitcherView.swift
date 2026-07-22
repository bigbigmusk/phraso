import SwiftUI
import SwiftData

/// 语言切换器（PRD 08）：两次点击完成切换——
/// 点击当前语言 → 选择另一门语言。每门语言的进度完全独立。
struct LanguageSwitcherView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppKeys.currentPackId) private var currentPackId = ""

    var body: some View {
        NavigationStack {
            List {
                Section("我的语言") {
                    ForEach(addedPacks) { pack in
                        row(for: pack, added: true)
                    }
                }
                if !notAddedPacks.isEmpty {
                    Section("添加语言") {
                        ForEach(notAddedPacks) { pack in
                            row(for: pack, added: false)
                        }
                    }
                }
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles").foregroundStyle(PH.amber)
                        Text("更多原创语言包即将推出")
                            .font(.footnote)
                            .foregroundStyle(PH.subInk)
                    }
                }
            }
            .navigationTitle("切换语言")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var addedIds: Set<String> {
        Set(ProgressService.addedLanguages(context: context).map(\.packId))
    }

    private var addedPacks: [LanguagePack] {
        ContentStore.shared.packs.filter { addedIds.contains($0.languagePackId) }
    }

    private var notAddedPacks: [LanguagePack] {
        ContentStore.shared.packs.filter { !addedIds.contains($0.languagePackId) }
    }

    private func row(for pack: LanguagePack, added: Bool) -> some View {
        Button {
            ProgressService.ensureLanguageAdded(pack.languagePackId, context: context)
            currentPackId = pack.languagePackId
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Text(pack.flag).font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pack.displayNameZh).font(.headline).foregroundStyle(PH.ink)
                    Text(pack.displayNameNative).font(.caption).foregroundStyle(PH.subInk)
                }
                Spacer()
                if pack.languagePackId == currentPackId {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(PH.green)
                } else if !added {
                    Image(systemName: "plus.circle").foregroundStyle(PH.blue)
                }
            }
        }
        .accessibilityLabel("\(pack.displayNameZh)\(pack.languagePackId == currentPackId ? "，当前语言" : "")")
    }
}
