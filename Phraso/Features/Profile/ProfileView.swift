import SwiftUI
import SwiftData
import AuthenticationServices

/// Profile（PRD 08 / 19）：账户、订阅、下载、权限、隐私、支持。
/// 设置中明确区分“移除本机下载”“重置该语言进度”“删除账户”。
struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: StoreService
    @AppStorage(AppKeys.appleUserId) private var appleUserId = ""
    @AppStorage(AppKeys.currentPackId) private var currentPackId = ""
    @AppStorage(AppKeys.hasOnboarded) private var hasOnboarded = true

    @State private var showPaywall = false
    @State private var showResetConfirm: LanguagePack?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            List {
                accountSection
                subscriptionSection
                languagesSection
                privacySection
                supportSection
                dangerSection
            }
            .navigationTitle("我的")
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    // MARK: - 账户

    private var accountSection: some View {
        Section("账户") {
            if appleUserId.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("登录以在多台设备间同步进度。不登录也可以继续学习，进度保存在本机。")
                        .font(.footnote)
                        .foregroundStyle(PH.subInk)
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = []
                    } onCompletion: { result in
                        if case .success(let auth) = result,
                           let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                            appleUserId = credential.user
                        }
                    }
                    .frame(height: 44)
                }
                .padding(.vertical, 4)
            } else {
                HStack {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .foregroundStyle(PH.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("已通过 Apple 登录").font(.subheadline.weight(.semibold))
                        Text("进度将在网络可用时同步").font(.caption).foregroundStyle(PH.subInk)
                    }
                    Spacer()
                    Button("退出登录") { appleUserId = "" }
                        .font(.footnote)
                        .foregroundStyle(PH.coral)
                }
            }
        }
    }

    // MARK: - 订阅

    private var subscriptionSection: some View {
        Section("Phraso Plus") {
            if store.hasPlus {
                Label("Plus 已激活：全部课程与完整复习已解锁", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(PH.greenDark)
                    .font(.subheadline)
            } else {
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        Image(systemName: "sparkles").foregroundStyle(PH.amber)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("升级到 Phraso Plus").font(.headline).foregroundStyle(PH.ink)
                            Text("解锁全部句子引擎、完整复习与离线语言包")
                                .font(.caption).foregroundStyle(PH.subInk)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(PH.subInk)
                    }
                }
            }
            Button("恢复购买") {
                Task { await store.restore() }
            }
        }
    }

    // MARK: - 语言与下载

    private var languagesSection: some View {
        Section("我的语言") {
            ForEach(addedPacks) { pack in
                HStack {
                    Text(pack.flag)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pack.displayNameZh).font(.subheadline.weight(.semibold))
                        Text("语言包 v\(pack.version) · 已内置离线内容")
                            .font(.caption).foregroundStyle(PH.subInk)
                    }
                    Spacer()
                    Button("重置进度") { showResetConfirm = pack }
                        .font(.footnote)
                        .foregroundStyle(PH.coral)
                }
            }
            if pack(for: currentPackId)?.romanization == true {
                romanizationToggle
            }
        }
        .confirmationDialog(
            "重置\(showResetConfirm?.displayNameZh ?? "")进度？",
            isPresented: Binding(get: { showResetConfirm != nil }, set: { if !$0 { showResetConfirm = nil } }),
            titleVisibility: .visible
        ) {
            Button("重置该语言全部进度", role: .destructive) {
                if let pack = showResetConfirm {
                    ProgressService.resetLanguage(pack.languagePackId, context: context)
                }
                showResetConfirm = nil
            }
            Button("取消", role: .cancel) { showResetConfirm = nil }
        } message: {
            Text("只影响这一门语言的课程与复习记录，其他语言不受影响。此操作无法撤销。")
        }
    }

    @ViewBuilder
    private var romanizationToggle: some View {
        if let lang = ProgressService.languageProgress(currentPackId, context: context) {
            Toggle(isOn: Binding(
                get: { lang.romanizationEnabled },
                set: { lang.romanizationEnabled = $0; try? context.save() }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("显示罗马字辅助").font(.subheadline)
                    Text("仅作为可关闭的读音辅助").font(.caption).foregroundStyle(PH.subInk)
                }
            }
            .tint(PH.green)
        }
    }

    // MARK: - 隐私

    private var privacySection: some View {
        Section("隐私") {
            VStack(alignment: .leading, spacing: 6) {
                Label("录音默认只在本机处理", systemImage: "lock.shield.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PH.greenDark)
                Text("语音识别优先使用端侧能力；原始录音在生成反馈后即被丢弃，不上传、不用于广告或训练通用模型。")
                    .font(.caption)
                    .foregroundStyle(PH.subInk)
            }
            .padding(.vertical, 4)
            Link(destination: URL(string: "https://phraso.app/privacy")!) {
                Label("隐私政策", systemImage: "hand.raised.fill")
            }
            Link(destination: URL(string: "https://phraso.app/terms")!) {
                Label("使用条款", systemImage: "doc.text.fill")
            }
        }
    }

    // MARK: - 支持

    private var supportSection: some View {
        Section("支持") {
            Link(destination: URL(string: "https://phraso.app/support")!) {
                Label("帮助与反馈", systemImage: "questionmark.circle.fill")
            }
            LabeledContent("版本", value: appVersion)
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Phraso \(version) (MVP)"
    }

    // MARK: - 危险操作

    private var dangerSection: some View {
        Section {
            Button("删除账户与全部数据", role: .destructive) {
                showDeleteConfirm = true
            }
        } footer: {
            Text("删除会移除本机全部学习记录与账户关联。已购订阅由 Apple ID 管理，可随时通过“恢复购买”找回。")
        }
        .confirmationDialog("删除账户与全部数据？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("确认删除", role: .destructive) { deleteEverything() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("学习进度、复习记录和语言设置将被删除且无法恢复。订阅本身需在系统设置中管理。")
        }
    }

    private func deleteEverything() {
        ProgressService.eraseAll(context: context)
        appleUserId = ""
        currentPackId = ""
        UserDefaults.standard.removeObject(forKey: AppKeys.learningGoal)
        hasOnboarded = false
    }

    // MARK: - Helpers

    private var addedPacks: [LanguagePack] {
        ProgressService.addedLanguages(context: context)
            .compactMap { ContentStore.shared.pack(id: $0.packId) }
    }

    private func pack(for id: String) -> LanguagePack? {
        ContentStore.shared.pack(id: id)
    }
}
