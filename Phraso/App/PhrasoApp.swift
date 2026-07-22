import SwiftUI
import SwiftData

@main
struct PhrasoApp: App {
    @StateObject private var store = StoreService()

    let container: ModelContainer = {
        let schema = Schema([
            LanguageProgress.self,
            LessonRecord.self,
            EngineMastery.self,
            StudyEvent.self,
        ])
        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("无法初始化本地数据库: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @AppStorage(AppKeys.hasOnboarded) private var hasOnboarded = false

    var body: some View {
        if hasOnboarded {
            MainTabView()
        } else {
            OnboardingFlowView()
        }
    }
}

/// 全局 AppStorage key 常量，避免手写字符串出错。
enum AppKeys {
    static let hasOnboarded = "phraso.hasOnboarded"
    static let currentPackId = "phraso.currentPackId"
    static let learningGoal = "phraso.learningGoal"
    static let autoStartFirstLesson = "phraso.autoStartFirstLesson"
    static let appleUserId = "phraso.appleUserId"
    static let debugPlusUnlocked = "phraso.debugPlusUnlocked"
}
