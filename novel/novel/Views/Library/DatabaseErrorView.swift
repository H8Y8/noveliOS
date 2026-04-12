import SwiftUI

/// 資料庫初始化失敗時的降級畫面
struct DatabaseErrorView: View {
    let errorMessage: String

    var body: some View {
        ZStack {
            NNColor.appBackground.ignoresSafeArea()

            VStack(spacing: NNSpacing.lg) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 56, weight: .thin))
                    .foregroundStyle(NNColor.textTertiary)

                VStack(spacing: NNSpacing.sm) {
                    Text("資料庫初始化失敗")
                        .font(NNFont.uiTitle)
                        .foregroundStyle(NNColor.textPrimary)

                    Text("請嘗試重新啟動 App，若問題持續，可能需要重新安裝。")
                        .font(NNFont.uiBody)
                        .foregroundStyle(NNColor.textSecondary)
                        .multilineTextAlignment(.center)

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(NNFont.uiCaption)
                            .foregroundStyle(NNColor.textTertiary)
                            .padding(.top, NNSpacing.sm)
                    }
                }
                .padding(.horizontal, NNSpacing.xl)
            }
        }
        .preferredColorScheme(.dark)
    }
}
