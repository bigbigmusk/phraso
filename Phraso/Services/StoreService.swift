import Foundation
import StoreKit

/// Phraso Plus 订阅（PRD 18）：
/// 一个 subscription group，月度 + 年度两个产品；
/// 权益以验证后的 StoreKit 交易为准，不信任客户端布尔值。
@MainActor
final class StoreService: ObservableObject {

    static let monthlyId = "com.phraso.plus.monthly"
    static let annualId = "com.phraso.plus.annual"
    static let productIds = [monthlyId, annualId]

    @Published var products: [Product] = []
    @Published var hasPlus = false
    @Published var isLoading = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update: update)
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await Product.products(for: Self.productIds)
            products = loaded.sorted { $0.price < $1.price }
        } catch {
            lastError = "暂时无法加载订阅信息，请稍后再试。"
        }
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            // 购买失败：保留课程位置，展示可理解错误（PRD 23）。
            lastError = "购买没有完成。你的学习进度不受影响，可稍后重试或使用恢复购买。"
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = "恢复购买失败，请检查网络后重试。"
        }
    }

    func refreshEntitlements() async {
        var entitled = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               Self.productIds.contains(transaction.productID),
               transaction.revocationDate == nil {
                entitled = true
            }
        }
        hasPlus = entitled
    }

    private func handle(update: VerificationResult<Transaction>) async {
        if case .verified(let transaction) = update {
            await transaction.finish()
            await refreshEntitlements()
        }
    }

    /// 引擎访问控制：每门语言第 1 个引擎免费（PRD 18 Free 层）。
    func canAccess(engine: SentenceEngine) -> Bool {
        if engine.free { return true }
        if hasPlus { return true }
        #if DEBUG
        if UserDefaults.standard.bool(forKey: AppKeys.debugPlusUnlocked) { return true }
        #endif
        return false
    }
}
