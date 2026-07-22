import SwiftUI

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

/// Phraso 品牌视觉：清爽的绿色系，活泼但不复制任何竞品的视觉体系。
enum PH {
    static let green = Color(hex: 0x34A853)
    static let greenDark = Color(hex: 0x1E7A3C)
    static let greenSoft = Color(hex: 0xE7F5EB)
    static let ink = Color(hex: 0x1C2321)
    static let subInk = Color(hex: 0x5C6B63)
    static let card = Color(hex: 0xF7FAF7)
    static let amber = Color(hex: 0xF2A33C)
    static let blue = Color(hex: 0x4A7DE2)
    static let coral = Color(hex: 0xE2654A)
    static let purple = Color(hex: 0x8A63D2)

    /// 反馈色：正确 / 提示 / 需注意，配图标使用，从不只靠颜色传达。
    static let correct = Color(hex: 0x2E9E5B)
    static let hint = Color(hex: 0xF2A33C)
    static let attention = Color(hex: 0xD86A5A)
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = PH.green

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(configuration.isPressed ? 0.75 : 1))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(PH.greenSoft.opacity(configuration.isPressed ? 0.6 : 1))
            .foregroundStyle(PH.greenDark)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
            )
    }
}

extension View {
    func phCard() -> some View { modifier(CardBackground()) }
}
