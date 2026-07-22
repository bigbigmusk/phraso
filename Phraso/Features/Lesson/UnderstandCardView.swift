import SwiftUI

/// 热身 / 理解卡（PRD 03 Understand 阶段）：
/// 用母语提示和最少解释建立心智模型。
struct UnderstandCardView: View {
    let pack: LanguagePack
    let exercise: Exercise
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label(
                    exercise.type == .warmStart ? "本课目标" : "理解一个新零件",
                    systemImage: exercise.type == .warmStart ? "flag.fill" : "lightbulb.fill"
                )
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PH.amber)

                if let explanation = exercise.explanationZh {
                    Text(explanation)
                        .font(.title3)
                        .foregroundStyle(PH.ink)
                        .lineSpacing(6)
                }

                if let canonical = exercise.canonical {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(canonical)
                            .font(.system(.title2, design: .rounded, weight: .semibold))
                            .foregroundStyle(PH.greenDark)
                        if let romanized = exercise.romanized {
                            Text(romanized)
                                .font(.subheadline)
                                .foregroundStyle(PH.subInk)
                        }
                        AudioButtons(text: canonical, locale: pack.targetLocale)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(PH.greenSoft))
                }

                if let hint = exercise.hintZh {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill").foregroundStyle(PH.blue)
                        Text(hint).font(.subheadline).foregroundStyle(PH.subInk)
                    }
                }
                Spacer(minLength: 20)
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            Button("继续") { onContinue() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
    }
}

/// 参考音频控制：播放、慢速一次、文字始终可见（PRD 11 / 23）。
struct AudioButtons: View {
    let text: String
    let locale: String

    var body: some View {
        HStack(spacing: 12) {
            Button {
                AudioService.shared.speak(text, locale: locale)
            } label: {
                Label("播放", systemImage: "speaker.wave.2.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color(.secondarySystemGroupedBackground)))
            }
            Button {
                AudioService.shared.speak(text, locale: locale, slow: true)
            } label: {
                Label("慢速", systemImage: "tortoise.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color(.secondarySystemGroupedBackground)))
            }
        }
        .foregroundStyle(PH.greenDark)
    }
}
