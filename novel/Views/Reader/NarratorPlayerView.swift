import SwiftUI
import SwiftData
import AVFoundation

// MARK: - Sleep Timer Option

enum SleepTimerOption: String, CaseIterable, Identifiable {
    case off   = "off"
    case min15 = "15min"
    case min30 = "30min"
    case min45 = "45min"
    case min60 = "60min"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off:   "關閉"
        case .min15: "15分"
        case .min30: "30分"
        case .min45: "45分"
        case .min60: "60分"
        }
    }

    var minutes: Int? {
        switch self {
        case .off:   nil
        case .min15: 15
        case .min30: 30
        case .min45: 45
        case .min60: 60
        }
    }
}

// MARK: - NarratorPlayerView

/// TTS 說書人完整控制面板
/// 從閱讀器底部上滑展開，視覺語言致敬音樂播放器，融入閱讀氣質
struct NarratorPlayerView: View {
    let book: Book
    let chapterTitle: String
    let allParagraphs: [String]
    let synthesisService: BookSynthesisService

    @Environment(TTSService.self) private var ttsService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allSettings: [UserSettings]

    @State private var selectedSleepTimer: SleepTimerOption = .off
    @State private var timerDisplayTask: Task<Void, Never>?
    @State private var remainingSeconds: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var settings: UserSettings { allSettings.first ?? UserSettings() }

    private var microAnimation: Animation? { reduceMotion ? nil : NNAnimation.micro }

    // 書庫封面同色系（hash 對應，與 BookCardView 呼應）
    private var coverPalette: (Color, Color) {
        let index = abs(book.title.hashValue) % NNColor.coverPalettes.count
        return NNColor.coverPalettes[index]
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            dynamicBackground

            VStack(spacing: 0) {
                dragHandle

                ScrollView(showsIndicators: false) {
                    VStack(spacing: NNSpacing.lg) {
                        bookHeader
                        paragraphPreview
                        mainControls
                        Divider().background(.white.opacity(0.12))
                        speedControl
                        voiceControl
                        synthesisSection
                        sleepTimerControl
                    }
                    .padding(.horizontal, NNSpacing.lg)
                    .padding(.bottom, NNSpacing.xxl)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            syncSleepTimerState()
            synthesisService.loadStatus(bookId: book.id, paragraphs: allParagraphs)
        }
        .onDisappear { timerDisplayTask?.cancel() }
        .onChange(of: ttsService.sleepTimerEndDate) { _, _ in startTimerCountdown() }
    }

    // MARK: - Background（動態模糊背景，與書庫封面同色系）

    private var dynamicBackground: some View {
        ZStack {
            LinearGradient(
                colors: [coverPalette.0, coverPalette.1],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .scaleEffect(2.2)
            .blur(radius: 90)

            Color.black.opacity(0.80)
        }
        .ignoresSafeArea()
    }

    // MARK: - Drag Handle

    private var dragHandle: some View {
        VStack(spacing: NNSpacing.xs) {
            Capsule()
                .fill(.white.opacity(0.25))
                .frame(width: 36, height: 4)
                .padding(.top, NNSpacing.md)

            // 計時器剩餘時間（有計時器時才顯示）
            if selectedSleepTimer != .off && remainingSeconds > 0 {
                HStack(spacing: NNSpacing.xs) {
                    Image(systemName: NNSymbol.sleepTimer)
                        .font(.system(size: 11))
                    Text(formattedRemaining)
                        .font(NNFont.uiCaption2)
                        .monospacedDigit()
                }
                .foregroundStyle(NNColor.accentLight)
                .transition(.opacity)
                .accessibilityLabel("睡眠計時器剩餘 \(remainingSeconds / 60) 分 \(remainingSeconds % 60) 秒")
            }
        }
        .padding(.bottom, NNSpacing.sm)
        .animation(reduceMotion ? nil : NNAnimation.micro, value: remainingSeconds)
    }

    // MARK: - Book Header

    private var bookHeader: some View {
        VStack(spacing: NNSpacing.xs) {
            Text(book.title)
                .font(NNFont.uiTitle)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(chapterTitle.isEmpty ? "—" : chapterTitle)
                .font(NNFont.uiBody)
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
        }
        .padding(.top, NNSpacing.xs)
    }

    // MARK: - Paragraph Preview

    private var paragraphPreview: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                )

            VStack(alignment: .leading, spacing: NNSpacing.sm) {
                // 狀態標籤
                HStack(spacing: NNSpacing.xs) {
                    if ttsService.isPlaying {
                        Image(systemName: "waveform")
                            .font(.system(size: 11))
                            .foregroundStyle(NNColor.accentLight)
                            .symbolEffect(.variableColor.iterative, options: .repeating)
                        Text("朗讀中")
                            .font(NNFont.uiCaption2)
                            .foregroundStyle(NNColor.accentLight)
                    } else {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.35))
                        Text(ttsService.isPaused ? "已暫停" : "尚未開始")
                            .font(NNFont.uiCaption2)
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
                .animation(microAnimation, value: ttsService.isPlaying)

                // 段落文字預覽
                Text(
                    ttsService.currentParagraphText.isEmpty
                        ? "點擊播放按鈕開始朗讀"
                        : ttsService.currentParagraphText
                )
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(ttsService.currentParagraphText.isEmpty ? 0.3 : 0.82))
                .lineLimit(5)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(NNAnimation.ttsHighlight, value: ttsService.currentParagraphIndex)
            }
            .padding(NNSpacing.md)
        }
        .frame(minHeight: 130)
    }

    // MARK: - Main Controls（⏮  ◯▶/❚❚◯  ⏭）

    private var mainControls: some View {
        HStack(spacing: 0) {
            // 上一段
            Button {
                ttsService.previousParagraph()
            } label: {
                Image(systemName: NNSymbol.previous)
                    .font(.system(size: 30))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 64, height: 64)
            }
            .accessibilityLabel("上一段")

            Spacer()

            // 播放 / 暫停（80pt 圓形按鈕，主視覺焦點）
            Button {
                if ttsService.isPlaying { ttsService.pause() }
                else { ttsService.play() }
            } label: {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.14))
                        .frame(width: 84, height: 84)
                    Circle()
                        .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                        .frame(width: 84, height: 84)
                    Image(systemName: ttsService.isPlaying ? NNSymbol.pause : NNSymbol.play)
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(.white)
                        .offset(x: ttsService.isPlaying ? 0 : 2)
                        .contentTransition(.symbolEffect(.replace))
                        .animation(microAnimation, value: ttsService.isPlaying)
                }
            }
            .accessibilityLabel(ttsService.isPlaying ? "暫停" : "播放")

            Spacer()

            // 下一段
            Button {
                ttsService.nextParagraph()
            } label: {
                Image(systemName: NNSymbol.next)
                    .font(.system(size: 30))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 64, height: 64)
            }
            .accessibilityLabel("下一段")
        }
        .padding(.horizontal, NNSpacing.sm)
        .padding(.vertical, NNSpacing.xs)
    }

    // MARK: - Speed Control

    private var speedControl: some View {
        sectionCard {
            HStack {
                Image(systemName: NNSymbol.speedometer)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
                Text("朗讀語速")
                    .font(NNFont.uiBody)
                    .foregroundStyle(.white)
                Spacer()
                Text(speedLabel)
                    .font(NNFont.uiSubheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(NNColor.accentLight)
            }

            HStack(spacing: NNSpacing.sm) {
                Text("慢")
                    .font(NNFont.uiCaption)
                    .foregroundStyle(.white.opacity(0.4))

                Slider(
                    value: Binding(
                        get: { Double(settings.ttsRate) },
                        set: {
                            settings.ttsRate = Float($0)
                            ttsService.setRate(Float($0))
                        }
                    ),
                    in: 0.3...0.7,
                    step: 0.025
                )
                .tint(NNColor.accent)
                .accessibilityLabel("朗讀語速")
                .accessibilityValue(speedLabel)

                Text("快")
                    .font(NNFont.uiCaption)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    private var speedLabel: String {
        switch settings.ttsRate {
        case ..<0.38: "慢速"
        case ..<0.46: "偏慢"
        case ..<0.55: "適中"
        case ..<0.63: "偏快"
        default:       "快速"
        }
    }

    // MARK: - Voice Control

    private var voiceControl: some View {
        sectionCard {
            HStack {
                Image(systemName: NNSymbol.speakerWave)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
                Text("語音選擇")
                    .font(NNFont.uiBody)
                    .foregroundStyle(.white)
                Spacer()
            }

            if availableVoices.isEmpty {
                Text("未找到中文語音。請前往「設定 → 輔助使用 → 語音內容」下載語音。")
                    .font(NNFont.uiCaption)
                    .foregroundStyle(.white.opacity(0.4))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: NNSpacing.sm) {
                        chipButton(
                            label: "預設",
                            isSelected: (settings.ttsVoiceIdentifier ?? "").isEmpty
                        ) {
                            settings.ttsVoiceIdentifier = nil
                            ttsService.setVoice(identifier: nil)
                        }

                        ForEach(availableVoices, id: \.identifier) { voice in
                            chipButton(
                                label: voice.name,
                                isSelected: settings.ttsVoiceIdentifier == voice.identifier
                            ) {
                                settings.ttsVoiceIdentifier = voice.identifier
                                ttsService.setVoice(identifier: voice.identifier)
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
    }

    private var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("zh-TW") }
            .sorted { $0.name < $1.name }
    }

    // MARK: - Synthesis Section

    @ViewBuilder
    private var synthesisSection: some View {
        if settings.ttsProviderType == .edge || settings.ttsProviderType == .azure {
            sectionCard {
                // Header
                HStack {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.55))
                    Text("離線語音快取")
                        .font(NNFont.uiBody)
                        .foregroundStyle(.white)
                    Spacer()
                    Text(synthesisStatusLabel)
                        .font(NNFont.uiCaption2)
                        .foregroundStyle(synthesisStatusColor)
                        .animation(NNAnimation.micro, value: synthesisService.isComplete)
                }

                // Progress bar（合成中才顯示）
                if synthesisService.isSynthesizing {
                    VStack(alignment: .leading, spacing: NNSpacing.xs) {
                        ProgressView(value: synthesisService.progress)
                            .tint(NNColor.accentLight)
                            .animation(NNAnimation.micro, value: synthesisService.progress)
                        Text("\(synthesisService.synthesizedCount) / \(synthesisService.totalCount) 段")
                            .font(NNFont.uiCaption2)
                            .foregroundStyle(.white.opacity(0.45))
                            .monospacedDigit()
                    }
                } else if synthesisService.isComplete {
                    Text("全書已合成，播放時不需等待網路。")
                        .font(NNFont.uiCaption)
                        .foregroundStyle(.white.opacity(0.45))
                } else if synthesisService.synthesizedCount > 0 {
                    Text("已合成 \(synthesisService.synthesizedCount) / \(synthesisService.totalCount) 段，可繼續合成剩餘部分。")
                        .font(NNFont.uiCaption)
                        .foregroundStyle(.white.opacity(0.45))
                }

                // Action buttons
                HStack(spacing: NNSpacing.sm) {
                    if synthesisService.isSynthesizing {
                        chipButton(label: "取消", isSelected: false) {
                            synthesisService.cancel()
                        }
                    } else if synthesisService.isComplete {
                        chipButton(label: "清除快取", isSelected: false) {
                            synthesisService.clearCache(bookId: book.id)
                        }
                    } else {
                        chipButton(
                            label: synthesisService.synthesizedCount > 0 ? "繼續合成" : "開始合成全書",
                            isSelected: true
                        ) {
                            startSynthesis()
                        }
                        if synthesisService.synthesizedCount > 0 {
                            chipButton(label: "清除快取", isSelected: false) {
                                synthesisService.clearCache(bookId: book.id)
                            }
                        }
                    }
                }
            }
        }
    }

    private var synthesisStatusLabel: String {
        if synthesisService.isSynthesizing  { return "合成中…" }
        if synthesisService.isComplete      { return "已完成" }
        if synthesisService.synthesizedCount > 0 { return "部分完成" }
        return "尚未開始"
    }

    private var synthesisStatusColor: Color {
        if synthesisService.isComplete      { return NNColor.accentLight }
        if synthesisService.isSynthesizing  { return .white.opacity(0.6) }
        if synthesisService.synthesizedCount > 0 { return .orange.opacity(0.8) }
        return .white.opacity(0.35)
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
            bookId: book.id,
            paragraphs: allParagraphs,
            provider: provider,
            voice: voice,
            rate: s.ttsRate
        )
    }

    // MARK: - Sleep Timer Control

    private var sleepTimerControl: some View {
        sectionCard {
            HStack {
                Image(systemName: NNSymbol.sleepTimer)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
                Text("睡眠計時器")
                    .font(NNFont.uiBody)
                    .foregroundStyle(.white)
                Spacer()
                if selectedSleepTimer != .off {
                    Text("再次點擊取消")
                        .font(NNFont.uiCaption2)
                        .foregroundStyle(.white.opacity(0.35))
                }
            }

            HStack(spacing: NNSpacing.sm) {
                ForEach(SleepTimerOption.allCases) { option in
                    chipButton(
                        label: option.displayName,
                        isSelected: selectedSleepTimer == option
                    ) {
                        if selectedSleepTimer == option && option != .off {
                            // 再次點擊：取消計時器
                            selectedSleepTimer = .off
                            ttsService.setSleepTimer(minutes: nil)
                        } else {
                            selectedSleepTimer = option
                            ttsService.setSleepTimer(minutes: option.minutes)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Reusable Components

    @ViewBuilder
    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: NNSpacing.sm) {
            content()
        }
        .padding(NNSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                )
        )
    }

    private func chipButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(NNFont.uiCaption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? Color.black.opacity(0.85) : .white.opacity(0.75))
                .padding(.horizontal, 12)
                .frame(minHeight: NNSpacing.minTouchTarget)
                .background(
                    Capsule()
                        .fill(isSelected ? NNColor.accentLight : Color.white.opacity(0.12))
                        .animation(microAnimation, value: isSelected)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Sleep Timer Countdown

    private var formattedRemaining: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func syncSleepTimerState() {
        // 啟動時同步 UI 狀態（從外部可能已設定計時器）
        if let endDate = ttsService.sleepTimerEndDate {
            let remaining = Int(endDate.timeIntervalSinceNow)
            if remaining > 0 {
                remainingSeconds = remaining
                let matchedOption = SleepTimerOption.allCases.first {
                    guard let mins = $0.minutes else { return false }
                    return abs(remaining - mins * 60) < 120
                } ?? .off
                selectedSleepTimer = matchedOption
                startTimerCountdown()
            }
        }
    }

    private func startTimerCountdown() {
        timerDisplayTask?.cancel()
        guard let endDate = ttsService.sleepTimerEndDate else {
            remainingSeconds = 0
            return
        }
        timerDisplayTask = Task {
            while !Task.isCancelled {
                let remaining = Int(endDate.timeIntervalSinceNow)
                if remaining <= 0 {
                    remainingSeconds = 0
                    selectedSleepTimer = .off
                    break
                }
                remainingSeconds = remaining
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
}
