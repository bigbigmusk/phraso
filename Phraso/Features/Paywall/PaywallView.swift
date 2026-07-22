import SwiftUI
import StoreKit

/// Phraso Plus 付费墙（PRD 18）：
/// 明确显示价格、周期、自动续期、恢复购买、条款与隐私链接。
/// 只在用户完成免费价值体验后展示，不在首次打开或第一道练习前强制订阅。
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: StoreService

    @State private var selectedProductId: String = StoreService.annualId

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    featureList
                    productPicker
                    if let error = store.lastError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(PH.attention)
                            .multilineTextAlignment(.center)
                    }
                    purchaseButton
                    footerLinks
                }
                .padding(24)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark").foregroundStyle(PH.subInk)
                    }
                    .accessibilityLabel("关闭付费墙")
                }
            }
            .onChange(of: store.hasPlus) { _, hasPlus in
                if hasPlus { dismiss() }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(PH.greenSoft).frame(width: 96, height: 96)
                Image(systemName: "sparkles").font(.system(size: 40)).foregroundStyle(PH.green)
            }
            Text("Phraso Plus")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text("解锁全部句子引擎，把一个结构用到更多真实场景。")
                .font(.subheadline)
                .foregroundStyle(PH.subInk)
                .multilineTextAlignment(.center)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(icon: "gearshape.2.fill", text: "全部课程与句子引擎（四门语言持续更新）")
            featureRow(icon: "clock.arrow.circlepath", text: "完整结构化复习队列")
            featureRow(icon: "arrow.down.circle.fill", text: "离线语言包")
            featureRow(icon: "icloud.fill", text: "跨设备进度同步")
        }
        .phCard()
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(PH.green).frame(width: 28)
            Text(text).font(.subheadline).foregroundStyle(PH.ink)
            Spacer()
        }
    }

    private var productPicker: some View {
        VStack(spacing: 10) {
            if store.products.isEmpty {
                // 产品未加载（如无网络 / 未配置 StoreKit）时的可理解状态。
                VStack(spacing: 8) {
                    ProgressView()
                    Text("正在加载订阅选项…")
                        .font(.footnote)
                        .foregroundStyle(PH.subInk)
                }
                .padding(.vertical, 12)
            } else {
                ForEach(store.products, id: \.id) { product in
                    productRow(product)
                }
            }
        }
    }

    private func productRow(_ product: Product) -> some View {
        let isAnnual = product.id == StoreService.annualId
        let selected = selectedProductId == product.id
        return Button {
            selectedProductId = product.id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isAnnual ? "年度订阅" : "月度订阅")
                        .font(.headline)
                        .foregroundStyle(PH.ink)
                    Text("\(product.displayPrice) / \(isAnnual ? "年" : "月")，自动续期，可随时取消")
                        .font(.caption)
                        .foregroundStyle(PH.subInk)
                }
                Spacer()
                if isAnnual {
                    Text("推荐")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(PH.amber.opacity(0.2)))
                        .foregroundStyle(PH.amber)
                }
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? PH.green : PH.subInk.opacity(0.4))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? PH.green : .clear, lineWidth: 2)
            )
        }
    }

    private var purchaseButton: some View {
        VStack(spacing: 10) {
            Button("开始订阅") {
                if let product = store.products.first(where: { $0.id == selectedProductId }) {
                    Task { await store.purchase(product) }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(store.products.isEmpty)
            .opacity(store.products.isEmpty ? 0.5 : 1)

            Button("恢复购买") {
                Task { await store.restore() }
            }
            .font(.subheadline)
            .foregroundStyle(PH.greenDark)
        }
    }

    private var footerLinks: some View {
        VStack(spacing: 8) {
            Text("订阅将自动续期，可在系统设置中随时取消。确认购买后将向你的 Apple 账户收费。")
                .font(.caption2)
                .foregroundStyle(PH.subInk)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Link("使用条款", destination: URL(string: "https://phraso.app/terms")!)
                Link("隐私政策", destination: URL(string: "https://phraso.app/privacy")!)
            }
            .font(.caption)
            .foregroundStyle(PH.blue)
        }
    }
}
