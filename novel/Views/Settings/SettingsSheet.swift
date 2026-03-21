import SwiftUI
import SwiftData
import AVFoundation

/// 閱讀設定面板：暗色卡片式設計，即時預覽
struct SettingsSheet: View {
    let bookId: UUID
    let allParagraphs: [String]
    let synthesisService: BookSynthesisService

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(TTSService.self) private var ttsService
    @Query private var allSettings: [UserSettings]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var serverStatus: ServerStatus = .unknown
    @State private var cachedSystemVoices: [AVSpeechSynthesisVoice] = []

    private var settings: UserSettings {
        if let existing = allSettings.first {
            return existing
        }
        let newSettings = UserSettings()
        modelContext.insert(newSettings)
        return newSettings
    }

    var body: some View {
        ZStack {
            NNColor.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                sheetHeader
                settingsContent
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.large, .medium])
        .presentationDragIndicator(.hidden)
        .presentationBackground(NNColor.appBackground)
        .onAppear {
            if settings.ttsProviderType == .edge {
                checkServerStatus()
            }
            synthesisService.loadStatus(bookId: bookId, paragraphs: allParagraphs)
            cachedSystemVoices = AVSpeechSynthesisVoice.speechVoices()
                .filter { $0.language.hasPrefix("zh-TW") }
                .sorted { $0.name < $1.name }
        }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        VStack(spacing: NNSpacing.xs) {
            Capsule()
                .fill(NNColor.textTertiary.opacity(0.5))
                .frame(width: 36, height: 4)
                .padding(.top, NNSpacing.md)

            HStack {
                Text("設定")
                    .font(NNFont.uiTitle)
                    .foregroundStyle(NNColor.textPrimary)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("完成")
                        .font(NNFont.uiBody)
                        .fontWeight(.medium)
                        .foregroundStyle(NNColor.accentLight)
                }
            }
            .padding(.horizontal, NNSpacing.lg)
            .padding(.bottom, NNSpacing.sm)
        }
    }

    // MARK: - Settings Content

    private var settingsContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: NNSpacing.md) {
                themeSection
                readingModeSection
                fontSection
                layoutSection
                ttsEngineSection

                if settings.ttsProviderType == .edge || settings.ttsProviderType == .azure {
                    synthesisSection
                }
            }
            .padding(.horizontal, NNSpacing.lg)
            .padding(.bottom, NNSpacing.xxl)
        }
    }

    // MARK: - Theme Section

    private var themeSection: some View {
        sectionCard(title: "背景主題", icon: NNSymbol.theme) {
            HStack(spacing: 0) {
                ForEach(ReadingTheme.allCases) { themeOption in
                    let isSelected = settings.theme == themeOption.rawValue

                    Button {
                        withAnimation(reduceMotion ? nil : NNAnimation.micro) {
                            settings.theme = themeOption.rawValue
                        }
                    } label: {
                        VStack(spacing: NNSpacing.sm) {
                            // 主題預覽圓
                            ZStack {
                                Circle()
                                    .fill(themeOption.backgroundColor)
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(
                                                isSelected ? NNColor.accent : NNColor.separator,
                                                lineWidth: isSelected ? 2.5 : 0.5
                                            )
                                    )

                                // 文字色預覽
                                Text("文")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(themeOption.textColor)
                            }

                            Text(themeOption.displayName)
                                .font(NNFont.uiCaption)
                                .foregroundStyle(isSelected ? NNColor.accentLight : NNColor.textSecondary)

                            Text(themeOption.displayDescription)
                                .font(.system(size: 9))
                                .foregroundStyle(NNColor.textTertiary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(themeOption.displayName)主題")
                }
            }
        }
    }

    // MARK: - Reading Mode Section

    private var readingModeSection: some View {
        sectionCard(title: "閱讀模式", icon: "book.pages") {
            HStack(spacing: NNSpacing.sm) {
                readingModeChip(mode: .scroll)
                readingModeChip(mode: .pageCurl)
            }
        }
    }

    private func readingModeChip(mode: ReadingMode) -> some View {
        let isSelected = settings.readingMode == mode
        return Button {
            withAnimation(reduceMotion ? nil : NNAnimation.micro) {
                settings.readingMode = mode
            }
        } label: {
            HStack(spacing: NNSpacing.sm) {
                Image(systemName: mode.iconName)
                    .font(.system(size: 16))
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName)
                        .font(NNFont.uiCaption)
                        .fontWeight(isSelected ? .semibold : .regular)
                    Text(mode.displayDescription)
                        .font(.system(size: 9))
                }
            }
            .foregroundStyle(isSelected ? Color.black.opacity(0.85) : NNColor.textSecondary)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: NNSpacing.minTouchTarget, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? NNColor.accentLight : NNColor.cardBackground)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mode.displayName)閱讀模式")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Font Section

    private var fontSection: some View {
        sectionCard(title: "字型", icon: NNSymbol.font) {
            // 字型大小滑桿
            VStack(spacing: NNSpacing.xs) {
                HStack {
                    Text("字型大小")
                        .font(NNFont.uiBody)
                        .foregroundStyle(NNColor.textPrimary)
                    Spacer()
                    Text("\(Int(settings.fontSize)) pt")
                        .font(NNFont.uiSubheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(NNColor.accentLight)
                        .monospacedDigit()
                }

                HStack(spacing: NNSpacing.sm) {
                    Image(systemName: "textformat.size.smaller")
                        .font(.system(size: 11))
                        .foregroundStyle(NNColor.textTertiary)

                    Slider(
                        value: Binding(
                            get: { settings.fontSize },
                            set: { settings.fontSize = $0 }
                        ),
                        in: 14...32,
                        step: 1
                    )
                    .tint(NNColor.accent)

                    Image(systemName: "textformat.size.larger")
                        .font(.system(size: 14))
                        .foregroundStyle(NNColor.textTertiary)
                }
            }

            Rectangle()
                .fill(NNColor.separator)
                .frame(height: 0.5)

            // 字體選擇
            HStack {
                Text("字體")
                    .font(NNFont.uiBody)
                    .foregroundStyle(NNColor.textPrimary)
                Spacer()
            }

            HStack(spacing: NNSpacing.sm) {
                fontChip(label: "系統預設", value: "System")
                fontChip(label: "PingFang", value: "PingFang TC")
                fontChip(label: "Noto Sans", value: "Noto Sans TC")
            }
        }
    }

    private func fontChip(label: String, value: String) -> some View {
        let isSelected = settings.fontFamily == value
        return Button {
            withAnimation(reduceMotion ? nil : NNAnimation.micro) {
                settings.fontFamily = value
            }
        } label: {
            Text(label)
                .font(NNFont.uiCaption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? Color.black.opacity(0.85) : NNColor.textSecondary)
                .padding(.horizontal, 12)
                .frame(minHeight: NNSpacing.minTouchTarget)
                .background(
                    Capsule()
                        .fill(isSelected ? NNColor.accentLight : NNColor.cardBackground)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label)字體")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Layout Section

    private var layoutSection: some View {
        sectionCard(title: "排版", icon: NNSymbol.lineHeight) {
            // 行距選擇
            HStack {
                Text("行距")
                    .font(NNFont.uiBody)
                    .foregroundStyle(NNColor.textPrimary)
                Spacer()
            }

            HStack(spacing: NNSpacing.sm) {
                ForEach(NNFont.LineSpacing.allCases) { spacing in
                    let isSelected = abs(settings.lineSpacing - spacing.rawValue) < 0.05

                    Button {
                        withAnimation(reduceMotion ? nil : NNAnimation.micro) {
                            settings.lineSpacing = spacing.rawValue
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Text("\(String(format: "%.1f", spacing.rawValue))x")
                                .font(NNFont.uiCaption)
                                .fontWeight(isSelected ? .semibold : .regular)
                            Text(spacing.displayName)
                                .font(.system(size: 9))
                        }
                        .foregroundStyle(isSelected ? Color.black.opacity(0.85) : NNColor.textSecondary)
                        .padding(.horizontal, 12)
                        .frame(minHeight: NNSpacing.minTouchTarget)
                        .background(
                            Capsule()
                                .fill(isSelected ? NNColor.accentLight : NNColor.cardBackground)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(spacing.displayName)行距")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - TTS Engine Section

    private var ttsEngineSection: some View {
        sectionCard(title: "語音朗讀", icon: NNSymbol.speakerWave) {
            // 引擎選擇
            HStack {
                Text("語音引擎")
                    .font(NNFont.uiBody)
                    .foregroundStyle(NNColor.textPrimary)
                Spacer()
            }

            HStack(spacing: NNSpacing.sm) {
                engineChip(label: "Edge TTS", subtitle: "網路", type: .edge)
                engineChip(label: "Azure", subtitle: "雲端", type: .azure)
                engineChip(label: "系統語音", subtitle: "離線", type: .system)
            }

            // 引擎專屬設定
            switch settings.ttsProviderType {
            case .edge:
                edgeTTSSettings
            case .azure:
                azureTTSSettings
            case .system:
                systemTTSSettings
            }

            Rectangle()
                .fill(NNColor.separator)
                .frame(height: 0.5)

            // 語速（共用）
            speedSlider
        }
    }

    private func engineChip(label: String, subtitle: String, type: TTSProviderType) -> some View {
        let isSelected = settings.ttsProviderType == type
        return Button {
            withAnimation(reduceMotion ? nil : NNAnimation.micro) {
                settings.ttsProviderType = type
                ttsService.setProviderType(type)
                if type == .edge {
                    checkServerStatus()
                }
            }
        } label: {
            VStack(spacing: 2) {
                Text(label)
                    .font(NNFont.uiCaption)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text(subtitle)
                    .font(.system(size: 9))
            }
            .foregroundStyle(isSelected ? Color.black.opacity(0.85) : NNColor.textSecondary)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: NNSpacing.minTouchTarget)
            .background(
                Capsule()
                    .fill(isSelected ? NNColor.accentLight : NNColor.cardBackground)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label)語音引擎")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Edge TTS Settings

    private var edgeTTSSettings: some View {
        VStack(alignment: .leading, spacing: NNSpacing.sm) {
            Rectangle()
                .fill(NNColor.separator)
                .frame(height: 0.5)

            // 伺服器位址
            Text("伺服器位址")
                .font(NNFont.uiCaption)
                .foregroundStyle(NNColor.textSecondary)

            HStack(spacing: NNSpacing.sm) {
                TextField("http://192.168.1.100:5050", text: Binding(
                    get: { settings.edgeTTSServerURL ?? "" },
                    set: {
                        let url = $0.isEmpty ? nil : $0
                        settings.edgeTTSServerURL = url
                        ttsService.setEdgeServerURL(url)
                    }
                ))
                .font(NNFont.uiBody)
                .foregroundStyle(NNColor.textPrimary)
                .tint(NNColor.accent)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit { checkServerStatus() }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(NNColor.cardBackground)
                )
            }

            if let error = edgeServerURLError {
                Text(error)
                    .font(NNFont.uiCaption2)
                    .foregroundStyle(.red.opacity(0.8))
            }

            // 連線狀態
            HStack(spacing: NNSpacing.xs) {
                Circle()
                    .fill(serverStatus.color)
                    .frame(width: 7, height: 7)
                Text(serverStatus.description)
                    .font(NNFont.uiCaption2)
                    .foregroundStyle(NNColor.textTertiary)

                Spacer()

                if serverStatus != .checking {
                    Button {
                        checkServerStatus()
                    } label: {
                        Text("測試連線")
                            .font(NNFont.uiCaption2)
                            .foregroundStyle(NNColor.accentLight)
                    }
                }
            }

            Rectangle()
                .fill(NNColor.separator)
                .frame(height: 0.5)

            // 語音選擇
            Text("語音")
                .font(NNFont.uiCaption)
                .foregroundStyle(NNColor.textSecondary)

            HStack(spacing: NNSpacing.sm) {
                edgeVoiceChip(label: "曉辰", id: "zh-TW-HsiaoChenNeural")
                edgeVoiceChip(label: "曉語", id: "zh-TW-HsiaoYuNeural")
                edgeVoiceChip(label: "雲哲", id: "zh-TW-YunJheNeural")
            }
        }
    }

    private func edgeVoiceChip(label: String, id: String) -> some View {
        let isSelected = settings.edgeTTSVoice == id
        return Button {
            settings.edgeTTSVoice = id
            ttsService.setVoice(TTSVoice(id: id, name: "", language: "zh-TW", providerID: "edge"))
        } label: {
            Text(label)
                .font(NNFont.uiCaption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? Color.black.opacity(0.85) : NNColor.textSecondary)
                .padding(.horizontal, 12)
                .frame(minHeight: NNSpacing.minTouchTarget)
                .background(
                    Capsule()
                        .fill(isSelected ? NNColor.accentLight : NNColor.cardBackground)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label)語音")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Azure TTS Settings

    private var azureTTSSettings: some View {
        VStack(alignment: .leading, spacing: NNSpacing.sm) {
            Rectangle()
                .fill(NNColor.separator)
                .frame(height: 0.5)

            // 訂閱金鑰
            Text("訂閱金鑰")
                .font(NNFont.uiCaption)
                .foregroundStyle(NNColor.textSecondary)

            SecureField("貼上 Azure 金鑰", text: Binding(
                get: { settings.azureSubscriptionKey ?? "" },
                set: {
                    let key = $0.isEmpty ? nil : $0
                    settings.azureSubscriptionKey = key
                    ttsService.azureProvider.subscriptionKey = key
                }
            ))
            .font(NNFont.uiBody)
            .foregroundStyle(NNColor.textPrimary)
            .tint(NNColor.accent)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(NNColor.cardBackground)
            )

            // 區域
            Text("區域")
                .font(NNFont.uiCaption)
                .foregroundStyle(NNColor.textSecondary)

            TextField("eastasia", text: Binding(
                get: { settings.azureRegion },
                set: {
                    settings.azureRegion = $0
                    ttsService.azureProvider.region = $0
                }
            ))
            .font(NNFont.uiBody)
            .foregroundStyle(NNColor.textPrimary)
            .tint(NNColor.accent)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(NNColor.cardBackground)
            )

            Rectangle()
                .fill(NNColor.separator)
                .frame(height: 0.5)

            // 語音選擇
            Text("語音")
                .font(NNFont.uiCaption)
                .foregroundStyle(NNColor.textSecondary)

            HStack(spacing: NNSpacing.sm) {
                azureVoiceChip(label: "曉辰", id: "zh-TW-HsiaoChenNeural")
                azureVoiceChip(label: "曉語", id: "zh-TW-HsiaoYuNeural")
                azureVoiceChip(label: "雲哲", id: "zh-TW-YunJheNeural")
            }
        }
    }

    private func azureVoiceChip(label: String, id: String) -> some View {
        let isSelected = settings.azureTTSVoice == id
        return Button {
            settings.azureTTSVoice = id
            ttsService.setVoice(TTSVoice(id: id, name: "", language: "zh-TW", providerID: "azure"))
        } label: {
            Text(label)
                .font(NNFont.uiCaption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? Color.black.opacity(0.85) : NNColor.textSecondary)
                .padding(.horizontal, 12)
                .frame(minHeight: NNSpacing.minTouchTarget)
                .background(
                    Capsule()
                        .fill(isSelected ? NNColor.accentLight : NNColor.cardBackground)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label)語音")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - System TTS Settings

    private var systemTTSSettings: some View {
        VStack(alignment: .leading, spacing: NNSpacing.sm) {
            if !availableSystemVoices.isEmpty {
                Rectangle()
                    .fill(NNColor.separator)
                    .frame(height: 0.5)

                Text("語音")
                    .font(NNFont.uiCaption)
                    .foregroundStyle(NNColor.textSecondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: NNSpacing.sm) {
                        systemVoiceChip(label: "預設", id: "")

                        ForEach(availableSystemVoices, id: \.identifier) { voice in
                            systemVoiceChip(label: voice.name, id: voice.identifier)
                        }
                    }
                }
            }
        }
    }

    private func systemVoiceChip(label: String, id: String) -> some View {
        let currentId = settings.ttsVoiceIdentifier ?? ""
        let isSelected = currentId == id
        return Button {
            settings.ttsVoiceIdentifier = id.isEmpty ? nil : id
            ttsService.setVoice(identifier: id.isEmpty ? nil : id)
        } label: {
            Text(label)
                .font(NNFont.uiCaption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? Color.black.opacity(0.85) : NNColor.textSecondary)
                .padding(.horizontal, 12)
                .frame(minHeight: NNSpacing.minTouchTarget)
                .background(
                    Capsule()
                        .fill(isSelected ? NNColor.accentLight : NNColor.cardBackground)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label)語音")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Speed Slider

    private var speedSlider: some View {
        VStack(spacing: NNSpacing.xs) {
            HStack {
                Text("語速")
                    .font(NNFont.uiBody)
                    .foregroundStyle(NNColor.textPrimary)
                Spacer()
                Text(rateDescription)
                    .font(NNFont.uiSubheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(NNColor.accentLight)
            }

            HStack(spacing: NNSpacing.sm) {
                Text("慢")
                    .font(NNFont.uiCaption)
                    .foregroundStyle(NNColor.textTertiary)

                Slider(
                    value: Binding(
                        get: { settings.ttsRate },
                        set: {
                            settings.ttsRate = $0
                            ttsService.setRate($0)
                        }
                    ),
                    in: 0.3...0.7,
                    step: 0.05
                )
                .tint(NNColor.accent)
                .accessibilityLabel("語速調整")
                .accessibilityValue(rateDescription)

                Text("快")
                    .font(NNFont.uiCaption)
                    .foregroundStyle(NNColor.textTertiary)
            }
        }
    }

    // MARK: - Synthesis Section

    private var synthesisSection: some View {
        sectionCard(title: "離線語音快取", icon: "arrow.down.circle") {
            // 進度
            VStack(alignment: .leading, spacing: NNSpacing.xs) {
                HStack {
                    Text("已合成")
                        .font(NNFont.uiBody)
                        .foregroundStyle(NNColor.textSecondary)
                    Spacer()
                    Text(synthesisProgressLabel)
                        .font(NNFont.uiSubheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(NNColor.accentLight)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(reduceMotion ? nil : NNAnimation.progressUpdate, value: synthesisService.synthesizedCount)
                }

                ProgressView(value: synthesisService.progress)
                    .tint(NNColor.accentLight)
                    .animation(reduceMotion ? nil : .linear(duration: 0.25), value: synthesisService.progress)

                Text(synthesisHintText)
                    .font(NNFont.uiCaption2)
                    .foregroundStyle(NNColor.textTertiary)
            }

            // 操作按鈕
            HStack(spacing: NNSpacing.sm) {
                if synthesisService.isSynthesizing {
                    actionChip(label: "取消合成", icon: "stop.circle", destructive: true) {
                        synthesisService.cancel()
                    }
                } else if synthesisService.isComplete {
                    actionChip(label: "清除快取", icon: "trash", destructive: true) {
                        synthesisService.clearCache(bookId: bookId)
                    }
                } else {
                    actionChip(
                        label: synthesisService.synthesizedCount > 0 ? "繼續合成" : "開始合成全書",
                        icon: "arrow.down.circle",
                        destructive: false
                    ) {
                        startSynthesis()
                    }

                    if synthesisService.synthesizedCount > 0 {
                        actionChip(label: "清除快取", icon: "trash", destructive: true) {
                            synthesisService.clearCache(bookId: bookId)
                        }
                    }
                }
            }
        }
    }

    private func actionChip(label: String, icon: String, destructive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: NNSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(NNFont.uiCaption)
            }
            .foregroundStyle(destructive ? .red.opacity(0.8) : NNColor.accentLight)
            .padding(.horizontal, 12)
            .frame(minHeight: NNSpacing.minTouchTarget)
            .background(
                Capsule()
                    .fill(destructive ? Color.red.opacity(0.12) : NNColor.accent.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Reusable Section Card

    @ViewBuilder
    private func sectionCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: NNSpacing.sm) {
            // Section header
            HStack(spacing: NNSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(NNColor.textTertiary)
                Text(title)
                    .font(NNFont.uiSubheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(NNColor.textSecondary)
            }

            content()
        }
        .padding(NNSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(NNColor.separator, lineWidth: 0.5)
                )
        )
    }

    // MARK: - Computed Properties

    private var edgeServerURLError: String? {
        let urlString = settings.edgeTTSServerURL ?? ""
        guard !urlString.isEmpty else { return nil }
        guard let url = URL(string: urlString),
              let scheme = url.scheme, !scheme.isEmpty,
              let host = url.host, !host.isEmpty,
              url.port != nil else {
            return "格式錯誤，需包含 scheme、host 與 port（如 http://192.168.1.100:5050）"
        }
        return nil
    }

    private var synthesisProgressLabel: String {
        let pct = Int(synthesisService.progress * 100)
        if synthesisService.isComplete { return "100%" }
        if synthesisService.totalCount == 0 { return "0%" }
        return "\(pct)%"
    }

    private var synthesisHintText: String {
        if synthesisService.isSynthesizing {
            return "\(synthesisService.synthesizedCount) / \(synthesisService.totalCount) 段，完成後關閉 app 不會遺失進度"
        } else if synthesisService.isComplete {
            return "全書已合成完成，播放時完全不需等待。"
        } else if synthesisService.synthesizedCount > 0 {
            return "進度已儲存，可隨時繼續合成剩餘部分。"
        } else {
            return "預先合成全書語音，播放時無需等待網路。"
        }
    }

    private func startSynthesis() {
        let s = settings
        let voice = TTSVoice(
            id: s.edgeTTSVoice,
            name: "",
            language: "zh-TW",
            providerID: s.ttsProviderType == .azure ? "azure" : "edge"
        )
        let provider: any TTSProvider = s.ttsProviderType == .azure
            ? ttsService.azureProvider
            : ttsService.edgeProvider

        synthesisService.startSynthesis(
            bookId: bookId,
            paragraphs: allParagraphs,
            provider: provider,
            voice: voice,
            rate: s.ttsRate
        )
    }

    private var rateDescription: String {
        if settings.ttsRate < 0.4 {
            return "較慢"
        } else if settings.ttsRate < 0.55 {
            return "適中"
        } else {
            return "較快"
        }
    }

    private var availableSystemVoices: [AVSpeechSynthesisVoice] { cachedSystemVoices }

    private func checkServerStatus() {
        serverStatus = .checking
        Task {
            let available = await ttsService.edgeProvider.isAvailable()
            serverStatus = available ? .connected : .disconnected
        }
    }
}

// MARK: - Server Status

private enum ServerStatus {
    case unknown
    case checking
    case connected
    case disconnected

    var description: String {
        switch self {
        case .unknown: "尚未測試"
        case .checking: "連線中..."
        case .connected: "已連線"
        case .disconnected: "無法連線"
        }
    }

    var color: Color {
        switch self {
        case .unknown: .gray
        case .checking: .orange
        case .connected: .green
        case .disconnected: .red
        }
    }
}
