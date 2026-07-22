import SwiftUI
import SwiftData

/// 首次使用流程（PRD 09）：
/// 价值主张 → 选语言 → 轻量目标（可跳过）→ 直接进入第一道构句任务。
/// 不在首屏要求注册、订阅或通知权限。
struct OnboardingFlowView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(AppKeys.hasOnboarded) private var hasOnboarded = false
    @AppStorage(AppKeys.currentPackId) private var currentPackId = ""
    @AppStorage(AppKeys.learningGoal) private var learningGoal = ""
    @AppStorage(AppKeys.autoStartFirstLesson) private var autoStartFirstLesson = false

    @State private var step = 0
    @State private var selectedPackId: String?
    @State private var selectedGoal: String?

    private let goals = ["旅行", "工作", "兴趣"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if step > 0 {
                    Button {
                        withAnimation { step -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .foregroundStyle(PH.subInk)
                    }
                    .accessibilityLabel("返回上一步")
                }
                Spacer()
                ProgressView(value: Double(step + 1), total: 3)
                    .tint(PH.green)
                    .frame(width: 120)
                Spacer()
                if step == 2 {
                    Button("跳过") { finish() }
                        .foregroundStyle(PH.subInk)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            TabView(selection: $step) {
                valueProposition.tag(0)
                languagePicker.tag(1)
                goalPicker.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: step)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - 第 1 步：价值主张

    private var valueProposition: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().fill(PH.greenSoft).frame(width: 140, height: 140)
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(PH.green)
            }
            Text("理解结构\n组装句子\n真正开口")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(PH.ink)
            Text("不是背一大堆孤立单词，\n而是先思考、自己构句，再揭晓答案。")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(PH.subInk)
            Spacer()
            Button("开始") { withAnimation { step = 1 } }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
    }

    // MARK: - 第 2 步：选择目标语言

    private var languagePicker: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("你想先学哪门语言？")
                .font(.system(.title, design: .rounded, weight: .bold))
                .padding(.top, 32)
            Text("之后可以随时添加更多语言，进度各自独立。")
                .font(.subheadline)
                .foregroundStyle(PH.subInk)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(ContentStore.shared.packs) { pack in
                    Button {
                        selectedPackId = pack.languagePackId
                    } label: {
                        VStack(spacing: 8) {
                            Text(pack.flag).font(.system(size: 40))
                            Text(pack.displayNameZh).font(.headline).foregroundStyle(PH.ink)
                            Text(pack.displayNameNative).font(.caption).foregroundStyle(PH.subInk)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(selectedPackId == pack.languagePackId ? PH.greenSoft : Color(.secondarySystemGroupedBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(selectedPackId == pack.languagePackId ? PH.green : .clear, lineWidth: 2)
                        )
                    }
                    .accessibilityLabel("\(pack.displayNameZh)，\(selectedPackId == pack.languagePackId ? "已选中" : "未选中")")
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundStyle(PH.amber)
                Text("更多语言即将推出").font(.footnote).foregroundStyle(PH.subInk)
            }

            Spacer()
            Button("继续") { withAnimation { step = 2 } }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selectedPackId == nil)
                .opacity(selectedPackId == nil ? 0.5 : 1)
                .padding(.bottom, 32)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - 第 3 步：轻量目标（仅用于推荐，不锁课程）

    private var goalPicker: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("为什么想学？")
                .font(.system(.title, design: .rounded, weight: .bold))
                .padding(.top, 32)
            Text("只用于推荐内容，不会锁定任何课程。可以跳过。")
                .font(.subheadline)
                .foregroundStyle(PH.subInk)

            ForEach(goals, id: \.self) { goal in
                Button {
                    selectedGoal = goal
                } label: {
                    HStack {
                        Text(goal).font(.headline).foregroundStyle(PH.ink)
                        Spacer()
                        Image(systemName: selectedGoal == goal ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedGoal == goal ? PH.green : PH.subInk.opacity(0.4))
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }
            }

            Spacer()
            Button("进入第一课") { finish() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.bottom, 32)
        }
        .padding(.horizontal, 24)
    }

    private func finish() {
        guard let packId = selectedPackId ?? ContentStore.shared.packs.first?.languagePackId else { return }
        currentPackId = packId
        learningGoal = selectedGoal ?? ""
        ProgressService.ensureLanguageAdded(packId, context: context)
        // 直接进入首个构句任务（激活目标：60 秒内开始第一道练习）。
        autoStartFirstLesson = true
        hasOnboarded = true
    }
}
