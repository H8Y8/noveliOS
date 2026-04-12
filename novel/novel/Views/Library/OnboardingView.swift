import SwiftUI

/// 首次啟動引導頁：三步驟介紹 App 功能
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var currentPage = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pages: [(icon: String, title: String, description: String)] = [
        ("books.vertical", "匯入你的小說", "支援 .txt 格式，Big5 / GBK / UTF-8 自動偵測"),
        ("book.fill", "沉浸閱讀體驗", "四種主題色彩、可調字型大小與行距，支援捲動與翻頁模式"),
        ("waveform", "AI 說書人", "多種語音引擎朗讀，支援背景播放與鎖屏控制"),
    ]

    var body: some View {
        ZStack {
            NNColor.appBackground.ignoresSafeArea()

            VStack(spacing: NNSpacing.xl) {
                Spacer()

                // 圖標
                Image(systemName: pages[currentPage].icon)
                    .font(.system(size: 72, weight: .thin))
                    .foregroundStyle(NNColor.accent)
                    .frame(height: 100)
                    .id(currentPage) // 讓 SwiftUI 重建以觸發 transition

                // 標題 + 描述
                VStack(spacing: NNSpacing.sm) {
                    Text(pages[currentPage].title)
                        .font(NNFont.uiTitle)
                        .foregroundStyle(NNColor.textPrimary)

                    Text(pages[currentPage].description)
                        .font(NNFont.uiBody)
                        .foregroundStyle(NNColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                }
                .id(currentPage)

                Spacer()

                // 頁面指示器
                HStack(spacing: NNSpacing.sm) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? NNColor.accent : NNColor.textTertiary)
                            .frame(width: 8, height: 8)
                    }
                }

                // 按鈕
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                            currentPage += 1
                        }
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "下一步" : "開始使用")
                        .font(NNFont.uiBody)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: NNSpacing.minTouchTarget)
                        .background(NNColor.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, NNSpacing.xl)
                .accessibilityLabel(currentPage < pages.count - 1 ? "下一步" : "開始使用")

                // 跳過按鈕（最後一頁不顯示）
                if currentPage < pages.count - 1 {
                    Button {
                        onFinish()
                    } label: {
                        Text("跳過")
                            .font(NNFont.uiSubheadline)
                            .foregroundStyle(NNColor.textSecondary)
                    }
                    .accessibilityLabel("跳過引導")
                }

                Spacer()
                    .frame(height: NNSpacing.xl)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
