import SwiftUI
import SwiftData
import AVFoundation

/// 閱讀器主視圖：全書連貫捲動，章節目錄用於跳轉定位
struct ReaderView: View {
    @Bindable var book: Book
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(TTSService.self) private var ttsService
    @Query private var allSettings: [UserSettings]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showToolbars = true
    @State private var showSettings = false
    @State private var showChapterList = false
    @State private var showNarratorPlayer = false
    @State private var visibleParagraphIndex: Int = 0
    @State private var scrollCommand: ScrollCommand? = nil
    @State private var nowPlayingService = NowPlayingService()
    @State private var synthesisService = BookSynthesisService()
    @State private var hasSetupNowPlaying = false

    // 全書段落快取（非同步建立，避免主執行緒阻塞）
    @State private var cachedAllParagraphs: [String] = []
    // 各章節在全書段落列表中的起始索引
    @State private var cachedChapterStartIndices: [Int] = []
    // 快取就緒前禁止儲存進度，防止覆蓋已存的閱讀位置
    @State private var isReadyToSaveProgress = false
    // 翻頁模式分頁快取
    @State private var cachedPages: [[Int]] = []
    @State private var readerSize: CGSize = .zero
    // saveProgress debounce
    @State private var saveProgressTask: Task<Void, Never>?

    // MARK: - Derived

    private var settings: UserSettings {
        allSettings.first ?? UserSettings()
    }

    private var theme: ReadingTheme {
        settings.readingTheme
    }

    /// 根據目前可見段落索引，動態計算當前所在章節
    private var currentChapterIndex: Int {
        guard !cachedChapterStartIndices.isEmpty else { return 0 }
        var result = 0
        for (i, startIdx) in cachedChapterStartIndices.enumerated() {
            if startIdx <= visibleParagraphIndex {
                result = i
            } else {
                break
            }
        }
        return result
    }

    private var currentChapter: Chapter? {
        let sorted = book.sortedChapters
        guard currentChapterIndex >= 0, currentChapterIndex < sorted.count else { return nil }
        return sorted[currentChapterIndex]
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            // 閱讀背景
            theme.backgroundColor.ignoresSafeArea()

            // 閱讀內容（依設定切換捲動 / 翻頁模式）
            if settings.readingMode == .pageCurl && !cachedPages.isEmpty {
                PageReaderView(
                    paragraphs: cachedAllParagraphs,
                    pages: cachedPages,
                    theme: theme,
                    fontSize: settings.fontSize,
                    lineSpacing: settings.lineSpacing,
                    fontFamily: settings.fontFamily,
                    highlightedParagraphIndex: ttsService.isPlaying ? ttsService.currentParagraphIndex : nil,
                    visibleParagraphIndex: $visibleParagraphIndex,
                    scrollCommand: $scrollCommand,
                    onTap: {
                        withAnimation(reduceMotion ? nil : NNAnimation.toolbarToggle) {
                            showToolbars.toggle()
                        }
                    }
                )
            } else {
                ScrollReaderView(
                    paragraphs: cachedAllParagraphs,
                    theme: theme,
                    fontSize: settings.fontSize,
                    lineSpacing: settings.lineSpacing,
                    fontFamily: settings.fontFamily,
                    highlightedParagraphIndex: ttsService.isPlaying ? ttsService.currentParagraphIndex : nil,
                    visibleParagraphIndex: $visibleParagraphIndex,
                    scrollCommand: $scrollCommand
                )
                .onTapGesture {
                    withAnimation(NNAnimation.toolbarToggle) {
                        showToolbars.toggle()
                    }
                }
            }

            // 工具列（各自獨立 transition）
            VStack {
                if showToolbars {
                    topToolbar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
                if showToolbars {
                    bottomToolbar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // 章節目錄側欄（右側滑入半透明側欄）
            if showChapterList {
                chapterSidebarOverlay
            }
        }
        .overlay {
            GeometryReader { geo in
                Color.clear
                    .onAppear { readerSize = geo.size }
                    .onChange(of: geo.size) { _, newSize in
                        readerSize = newSize
                        recomputePages()
                    }
            }
            .allowsHitTesting(false)
        }
        .navigationBarHidden(true)
        .statusBarHidden(!showToolbars)
        .onAppear {
            ttsService.currentBookId = book.id

            if allSettings.isEmpty {
                modelContext.insert(UserSettings())
            }

            restoreTTSProviderSettings()
            setupNowPlaying()

            // 非同步建立快取，避免主執行緒阻塞造成 UI 凍結
            let savedOffset = book.lastReadOffset
            let content = book.content
            let chapterData = book.sortedChapters.map {
                (startOffset: $0.startOffset, endOffset: $0.endOffset)
            }

            Task.detached(priority: .userInitiated) {
                let (paragraphs, indices) = Self.buildCacheInBackground(
                    content: content,
                    chapterData: chapterData
                )
                await MainActor.run {
                    cachedAllParagraphs = paragraphs
                    cachedChapterStartIndices = indices
                    visibleParagraphIndex = savedOffset
                    // 快取就緒後才允許滾動到儲存位置
                    if savedOffset > 0 && savedOffset < paragraphs.count {
                        scrollCommand = ScrollCommand(index: savedOffset)
                    }
                    isReadyToSaveProgress = true
                    recomputePages()
                    // 從磁碟讀取合成進度，供工具列按鈕顯示正確狀態
                    synthesisService.loadStatus(bookId: book.id, paragraphs: paragraphs)
                }
            }
        }
        .onDisappear {
            saveProgress()
            ttsService.stop()
            ttsService.currentBookId = nil
            nowPlayingService.removeRemoteCommands()
            nowPlayingService.clearNowPlaying()
        }
        .onChange(of: visibleParagraphIndex) { _, _ in
            guard isReadyToSaveProgress else { return }
            saveProgressDebounced()
        }
        .onChange(of: settings.fontSize) { _, _ in recomputePages() }
        .onChange(of: settings.lineSpacing) { _, _ in recomputePages() }
        .onChange(of: settings.fontFamily) { _, _ in recomputePages() }
        .onChange(of: settings.pageMode) { _, _ in recomputePages() }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(
                bookId: book.id,
                allParagraphs: cachedAllParagraphs,
                synthesisService: synthesisService
            )
        }
        .sheet(isPresented: $showNarratorPlayer) {
            NarratorPlayerView(
                book: book,
                chapterTitle: currentChapter?.title ?? "",
                allParagraphs: cachedAllParagraphs,
                synthesisService: synthesisService
            )
        }
        // ChapterListSheet 改為 ZStack 內的側欄 overlay（見 chapterSidebarOverlay）
    }

    // MARK: - Top Toolbar

    private var topToolbar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // 返回按鈕（44pt 觸控目標）
                Button {
                    dismiss()
                } label: {
                    Image(systemName: NNSymbol.back)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(theme.textColor)
                        .frame(width: NNSpacing.minTouchTarget, height: NNSpacing.minTouchTarget)
                }
                .accessibilityLabel("返回")

                Spacer()

                // 章節標題
                Text(currentChapter?.title ?? book.title)
                    .font(NNFont.uiSubheadline)
                    .foregroundStyle(theme.secondaryTextColor)
                    .lineLimit(1)
                    .padding(.horizontal, NNSpacing.sm)

                Spacer()

                // 設定按鈕
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: NNSymbol.settings)
                        .font(.system(size: 17))
                        .foregroundStyle(theme.secondaryTextColor)
                        .frame(width: NNSpacing.minTouchTarget, height: NNSpacing.minTouchTarget)
                }
                .accessibilityLabel("設定")

                // 全書合成按鈕（僅 Edge / Azure 引擎）
                if settings.ttsProviderType == .edge || settings.ttsProviderType == .azure {
                    Button {
                        if synthesisService.isSynthesizing {
                            synthesisService.cancel()
                        } else if !synthesisService.isComplete {
                            triggerSynthesis()
                        }
                    } label: {
                        ZStack {
                            if synthesisService.isSynthesizing {
                                ProgressView(value: synthesisService.progress)
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.65)
                                    .tint(theme.textColor)
                            } else {
                                Image(systemName: synthesisService.isComplete
                                      ? "checkmark.circle.fill"
                                      : "arrow.down.circle")
                                    .font(.system(size: 17))
                                    .foregroundStyle(synthesisService.isComplete
                                                     ? theme.textColor.opacity(0.5)
                                                     : theme.textColor)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                        }
                        .frame(width: NNSpacing.minTouchTarget, height: NNSpacing.minTouchTarget)
                        .animation(reduceMotion ? nil : NNAnimation.micro, value: synthesisService.isSynthesizing)
                        .animation(reduceMotion ? nil : NNAnimation.micro, value: synthesisService.isComplete)
                    }
                    .accessibilityLabel(
                        synthesisService.isSynthesizing ? "取消合成" :
                        synthesisService.isComplete     ? "已完成合成" : "合成全書語音"
                    )
                }

                // 目錄按鈕
                Button {
                    withAnimation(reduceMotion ? nil : NNAnimation.sidebarSlide) {
                        showChapterList = true
                    }
                } label: {
                    Image(systemName: NNSymbol.chapterList)
                        .font(.system(size: 17))
                        .foregroundStyle(theme.textColor)
                        .frame(width: NNSpacing.minTouchTarget, height: NNSpacing.minTouchTarget)
                }
                .accessibilityLabel("目錄")
            }
            .padding(.horizontal, NNSpacing.sm)
            .frame(height: NNSpacing.toolbarHeight)
            .background(theme.toolbarStyle, ignoresSafeAreaEdges: .top)

            // 向下漸層——工具列自然融入文字區域，避免硬邊界
            LinearGradient(
                colors: [theme.backgroundColor.opacity(0.5), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 24)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        VStack(spacing: 0) {
            // 向上漸層
            LinearGradient(
                colors: [.clear, theme.backgroundColor.opacity(0.75)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 32)
            .allowsHitTesting(false)

            VStack(spacing: NNSpacing.xs) {
                // 章節進度滑桿（有多章節時才顯示）
                if book.sortedChapters.count > 1 {
                    chapterSlider
                }

                // 迷你播放條（TTS 有內容時才顯示）
                if ttsService.hasContent {
                    miniPlayerStrip
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // TTS 控制列
                ttsControlRow
            }
            .padding(.top, NNSpacing.xs)
            .padding(.bottom, NNSpacing.sm)
            .background(theme.toolbarStyle, ignoresSafeAreaEdges: .bottom)
            .animation(reduceMotion ? nil : NNAnimation.toolbarToggle, value: ttsService.hasContent)
        }
    }

    // 章節滑桿：反映目前所在章節，拖動即跳章
    private var chapterSlider: some View {
        VStack(spacing: 3) {
            Text(currentChapter?.title ?? "")
                .font(NNFont.uiCaption)
                .foregroundStyle(theme.secondaryTextColor)
                .lineLimit(1)

            HStack(spacing: NNSpacing.xs) {
                Text("\(currentChapterIndex + 1)")
                    .font(NNFont.uiCaption2)
                    .foregroundStyle(theme.secondaryTextColor)
                    .monospacedDigit()
                    .frame(minWidth: 24, alignment: .trailing)

                Slider(
                    value: Binding(
                        get: { Double(currentChapterIndex) },
                        set: { jumpToChapter(Int($0)) }
                    ),
                    in: 0...Double(max(book.sortedChapters.count - 1, 1)),
                    step: 1
                )
                .tint(theme.textColor.opacity(0.45))
                .accessibilityLabel("章節進度")
                .accessibilityValue("第 \(currentChapterIndex + 1) 章，共 \(book.sortedChapters.count) 章")
                .onChange(of: currentChapterIndex) { _, _ in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }

                Text("\(book.sortedChapters.count)")
                    .font(NNFont.uiCaption2)
                    .foregroundStyle(theme.secondaryTextColor)
                    .monospacedDigit()
                    .frame(minWidth: 24, alignment: .leading)
            }
            .padding(.horizontal, NNSpacing.md)
        }
    }

    // 迷你播放條：當前段落文字預覽 + 點擊展開完整說書人面板
    private var miniPlayerStrip: some View {
        Button {
            showNarratorPlayer = true
        } label: {
            HStack(spacing: NNSpacing.sm) {
                Image(systemName: ttsService.isPlaying ? "waveform" : "pause.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ttsService.isPlaying ? NNColor.accent : theme.secondaryTextColor)
                    .frame(width: 16)
                    .symbolEffect(.variableColor.iterative,
                                  options: ttsService.isPlaying ? .repeating : .nonRepeating)
                    .contentTransition(.symbolEffect(.replace))
                    .animation(NNAnimation.micro, value: ttsService.isPlaying)

                Text(ttsService.currentParagraphText.isEmpty
                     ? "點擊展開說書人"
                     : ttsService.currentParagraphText)
                    .font(NNFont.uiCaption)
                    .foregroundStyle(theme.secondaryTextColor)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.secondaryTextColor)
            }
            .padding(.horizontal, NNSpacing.lg)
            .frame(height: 34)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("展開說書人控制面板")
        .overlay(Rectangle().fill(theme.separatorColor).frame(height: 0.5), alignment: .top)
    }

    // TTS 控制列：⏮  ▶/❚❚  ⏭（置中對稱）
    private var ttsControlRow: some View {
        HStack(spacing: 0) {
            // 上一段
            Button {
                ttsService.previousParagraph()
            } label: {
                Image(systemName: NNSymbol.previous)
                    .font(.system(size: 20))
                    .foregroundStyle(theme.textColor)
                    .frame(width: NNSpacing.ttsSecondaryButtonSize,
                           height: NNSpacing.ttsSecondaryButtonSize)
            }
            .accessibilityLabel("上一段")

            Spacer()

            // 播放 / 暫停（主要按鈕，52pt 觸控面積）
            Button {
                toggleTTS()
            } label: {
                Image(systemName: ttsService.isPlaying ? NNSymbol.pause : NNSymbol.play)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(theme.textColor)
                    .frame(width: NNSpacing.ttsButtonSize, height: NNSpacing.ttsButtonSize)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(ttsService.isPlaying ? "暫停" : "播放")

            Spacer()

            // 下一段
            Button {
                ttsService.nextParagraph()
            } label: {
                Image(systemName: NNSymbol.next)
                    .font(.system(size: 20))
                    .foregroundStyle(theme.textColor)
                    .frame(width: NNSpacing.ttsSecondaryButtonSize,
                           height: NNSpacing.ttsSecondaryButtonSize)
            }
            .accessibilityLabel("下一段")
        }
        .padding(.horizontal, NNSpacing.lg)
    }

    // MARK: - Chapter Sidebar Overlay

    /// 右側滑入半透明目錄側欄
    private var chapterSidebarOverlay: some View {
        ZStack(alignment: .trailing) {
            // 暗色遮罩（點擊關閉側欄）
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(reduceMotion ? nil : NNAnimation.sidebarSlide) {
                        showChapterList = false
                    }
                }
                .transition(.opacity)

            // 側欄面板（螢幕寬度 82%）
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Spacer()
                    ChapterListSheet(
                        chapters: book.sortedChapters,
                        currentChapterIndex: currentChapterIndex,
                        onChapterSelected: { index in
                            withAnimation(.easeOut(duration: 0.25)) {
                                showChapterList = false
                            }
                            jumpToChapter(index)
                        },
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.25)) {
                                showChapterList = false
                            }
                        }
                    )
                    .frame(width: geo.size.width * 0.82)
                }
            }
            .transition(.move(edge: .trailing))
        }
        .animation(reduceMotion ? nil : NNAnimation.sidebarSlide, value: showChapterList)
    }

    // MARK: - Paragraph Cache

    /// 在背景執行緒建立段落快取（純值型別運算，不存取 SwiftData model）
    private static func buildCacheInBackground(
        content: String,
        chapterData: [(startOffset: Int, endOffset: Int)]
    ) -> ([String], [Int]) {
        let lines = content.components(separatedBy: "\n")

        var paragraphs: [String] = []
        var paragraphUTF16Offsets: [Int] = []
        var currentUTF16Offset = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                paragraphs.append(trimmed)
                paragraphUTF16Offsets.append(currentUTF16Offset)
            }
            currentUTF16Offset += line.utf16.count + 1
        }

        // 將每個章節的 UTF-16 startOffset 映射到段落索引
        var startIndices: [Int] = []
        for chapter in chapterData {
            let idx = paragraphUTF16Offsets.firstIndex(where: { $0 >= chapter.startOffset }) ?? 0
            startIndices.append(idx)
        }

        return (paragraphs, startIndices)
    }

    // MARK: - TTS Control

    private func toggleTTS() {
        if ttsService.isPlaying {
            ttsService.pause()
            nowPlayingService.updateNowPlaying(
                bookTitle: book.title,
                chapterTitle: currentChapter?.title ?? "",
                paragraphIndex: ttsService.currentParagraphIndex,
                totalParagraphs: cachedAllParagraphs.count,
                isPlaying: false
            )
        } else {
            if !ttsService.isPaused {
                // 從目前可見段落開始朗讀全書
                ttsService.loadChapter(paragraphs: cachedAllParagraphs, startAt: visibleParagraphIndex)
            }
            ttsService.play()
            nowPlayingService.updateNowPlaying(
                bookTitle: book.title,
                chapterTitle: currentChapter?.title ?? "",
                paragraphIndex: ttsService.currentParagraphIndex,
                totalParagraphs: cachedAllParagraphs.count,
                isPlaying: true
            )
        }
    }

    /// 從 UserSettings 恢復 TTS 引擎設定
    private func restoreTTSProviderSettings() {
        let s = settings
        ttsService.setProviderType(s.ttsProviderType)
        ttsService.setEdgeServerURL(s.edgeTTSServerURL)
        ttsService.setRate(s.ttsRate)

        switch s.ttsProviderType {
        case .edge:
            ttsService.setVoice(TTSVoice(id: s.edgeTTSVoice, name: "", language: "zh-TW", providerID: "edge"))
        case .system:
            ttsService.setVoice(identifier: s.ttsVoiceIdentifier)
        case .azure:
            break
        }
    }

    private func setupNowPlaying() {
        guard !hasSetupNowPlaying else { return }
        hasSetupNowPlaying = true

        nowPlayingService.setupRemoteCommands(
            onPlay:          { toggleTTS() },
            onPause:         { toggleTTS() },
            onNextTrack:     { ttsService.nextParagraph() },
            onPreviousTrack: { ttsService.previousParagraph() }
        )
    }

    // MARK: - Chapter Navigation

    /// 跳至指定章節（設定捲動指令，TTS 若播放中則從新位置繼續）
    private func jumpToChapter(_ index: Int) {
        guard index >= 0, index < cachedChapterStartIndices.count else { return }
        let targetParagraph = cachedChapterStartIndices[index]
        let wasPlaying = ttsService.isPlaying

        ttsService.stop()
        visibleParagraphIndex = targetParagraph
        scrollCommand = ScrollCommand(index: targetParagraph)

        if wasPlaying {
            ttsService.loadChapter(paragraphs: cachedAllParagraphs, startAt: targetParagraph)
            ttsService.play()
        }
        saveProgress()
    }

    // MARK: - Synthesis

    private func triggerSynthesis() {
        let s = settings
        guard s.ttsProviderType == .edge || s.ttsProviderType == .azure else { return }
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
            paragraphs: cachedAllParagraphs,
            provider: provider,
            voice: voice,
            rate: s.ttsRate
        )
    }

    // MARK: - Pagination (翻頁模式)

    /// 根據目前設定與可用空間重新計算分頁（背景執行，避免阻塞主執行緒）
    private func recomputePages() {
        guard settings.readingMode == .pageCurl,
              !cachedAllParagraphs.isEmpty,
              readerSize.width > 0, readerSize.height > 0 else {
            cachedPages = []
            return
        }

        let topZone = NNSpacing.toolbarHeight + 28 + NNSpacing.md      // 100pt
        let bottomZone = NNSpacing.bottomToolbarHeight + 32 + NNSpacing.md // 148pt
        let pageNumberZone: CGFloat = 24
        let textWidth = readerSize.width - NNSpacing.readerHorizontal * 2
        let textHeight = readerSize.height - topZone - bottomZone - pageNumberZone

        guard textHeight > 0 else { return }

        // 捕獲值以在背景執行
        let paragraphs = cachedAllParagraphs
        let fontSize = settings.fontSize
        let lineSpacing = settings.lineSpacing
        let fontFamily = settings.fontFamily
        let size = CGSize(width: textWidth, height: textHeight)

        Task.detached(priority: .userInitiated) {
            let pages = PaginationEngine.paginate(
                paragraphs: paragraphs,
                fontSize: fontSize,
                lineSpacing: lineSpacing,
                fontFamily: fontFamily,
                availableSize: size
            )
            await MainActor.run { cachedPages = pages }
        }
    }

    // MARK: - Progress

    /// 去抖動儲存進度：500ms 內多次呼叫只執行最後一次
    private func saveProgressDebounced() {
        saveProgressTask?.cancel()
        saveProgressTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            saveProgress()
        }
    }

    private func saveProgress() {
        // lastReadOffset 現在儲存全書段落索引（非章節內索引）
        book.lastReadOffset  = visibleParagraphIndex
        book.lastReadChapter = currentChapterIndex
        book.dateLastRead    = Date()
        updateReadingProgress()
    }

    private func updateReadingProgress() {
        let total = cachedAllParagraphs.count
        guard total > 0 else { return }
        book.readingProgress = min(Double(visibleParagraphIndex) / Double(total), 1.0)
    }
}
