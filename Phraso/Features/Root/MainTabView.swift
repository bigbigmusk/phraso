import SwiftUI

/// 一级导航（PRD 08）：Learn / Review / Progress / Profile，默认进入 Learn。
struct MainTabView: View {
    var body: some View {
        TabView {
            LearnHomeView()
                .tabItem { Label("学习", systemImage: "house.fill") }
            ReviewHomeView()
                .tabItem { Label("复习", systemImage: "clock.arrow.circlepath") }
            ProgressHomeView()
                .tabItem { Label("进度", systemImage: "chart.bar.fill") }
            ProfileView()
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
        }
        .tint(PH.green)
    }
}
