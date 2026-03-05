import SwiftUI
import SwiftData
import AVFoundation

/// 閱讀器主視圖：全螢幕沉浸式閱讀，工具列點擊切換顯示/隱藏
struct ReaderView: View {
    @Bindable var book: Book
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(TTSService.self) private var ttsService
    @Query private var allSettings: [UserSettings]

    @State private var showToolbars = true
    @State private var showSettings = false
    @State private var showChapterList = false
    @State private var showNarratorPlayer = false
    @State private var currentChapterIndex: Int = 0
    @State private var visibleParagraphIndex: Int = 0
    @State private var nowPlayingService = NowPlayingService()
    @State private var hasSetupNowPlaying = false

    // MARK: - Derived

    private var settings: UserSettings {
        allSettings.first ?? UserSettings()
    }

    private var theme: ReadingTheme {
        settings.readingTheme
    }

    private var currentChapter: Chapter? {
        let sorted = book.sortedChapters
        guard currentChapterIndex >= 0, currentChapterIndex < sorted.count else { return nil }
        return sorted[currentChapterIndex]
    }

    private var currentParagraphs: [String] {
        guard let chapter = currentChapter else { return [] }
        let content = book.content.substringWithUTF16Range(
            start: chapter.startOffset,
            end: chapter.endOffset
        ) ?? ""
        return content.paragraphs()
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            // 閱讀背景
            theme.backgroundColor.ignoresSafeArea()

            // 閱讀內容
            ScrollReaderView(
                paragraphs: currentParagraphs,
                theme: theme,
                fontSize: settings.fontSize,
                lineSpacing: settings.lineSpacing,
                fontFamily: settings.fontFamily,
                highlightedParagraphIndex: ttsService.isPlaying ? ttsService.currentParagraphIndex : nil,
                visibleParagraphIndex: $visibleParagraphIndex
            )
            .onTapGesture {
                withAnimation(NNAnimation.toolbarToggle) {
                    showToolbars.toggle()
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
            .ignoresSafeArea(edges: .vertical)
        }
        .navigationBarHidden(true)
        .statusBarHidden(!showToolbars)
        .onAppear {
            currentChapterIndex = book.lastReadChapter
            visibleParagraphIndex = book.lastReadOffset
            ttsService.currentBookId = book.id

            if allSettings.isEmpty {
                modelContext.insert(UserSettings())
            }

            setupNowPlaying()
        }
        .onDisappear {
            saveProgress()
            ttsService.stop()
            ttsService.currentBookId = nil
            nowPlayingService.clearNowPlaying()
        }
        .onChange(of: visibleParagraphIndex) { _, _ in
            saveProgressDebounced()
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
        }
        .sheet(isPresented: $showNarratorPlayer) {
            NarratorPlayerView(
                book: book,
                chapterTitle: currentChapter?.title ?? ""
            )
        }
        .sheet(isPresented: $showChapterList) {
            ChapterListSheet(
                chapters: book.sortedChapters,
                currentChapterIndex: currentChapterIndex
            ) { selectedIndex in
                jumpToChapter(selectedIndex)
                showChapterList = false
            }
        }
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

                // 目錄按鈕
                Button {
                    showChapterList = true
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
            .background(theme.toolbarStyle)

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
            .background(theme.toolbarStyle)
            .animation(NNAnimation.toolbarToggle, value: ttsService.hasContent)
        }
    }

    // 章節滑桿（含章節名稱與章節計數）
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

    // TTS 控制列：⏮  ▶/❚❚  ⏭ ··········· ⚙
    // 播放鍵居中為主視覺焦點，設定齒輪靠右次要
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

            // 設定（次要視覺重量，靠右）
            Button {
                showSettings = true
            } label: {
                Image(systemName: NNSymbol.settings)
                    .font(.system(size: 17))
                    .foregroundStyle(theme.secondaryTextColor)
                    .frame(width: NNSpacing.minTouchTarget, height: NNSpacing.minTouchTarget)
            }
            .accessibilityLabel("設定")
            .padding(.leading, NNSpacing.xs)
        }
        .padding(.horizontal, NNSpacing.lg)
    }

    // MARK: - TTS Control

    private func toggleTTS() {
        if ttsService.isPlaying {
            ttsService.pause()
            nowPlayingService.updateNowPlaying(
                bookTitle: book.title,
                chapterTitle: currentChapter?.title ?? "",
                paragraphIndex: ttsService.currentParagraphIndex,
                totalParagraphs: currentParagraphs.count,
                isPlaying: false
            )
        } else {
            if !ttsService.isPaused {
                ttsService.loadChapter(paragraphs: currentParagraphs, startAt: visibleParagraphIndex)
                setupTTSChapterFinished()
            }
            ttsService.play()
            nowPlayingService.updateNowPlaying(
                bookTitle: book.title,
                chapterTitle: currentChapter?.title ?? "",
                paragraphIndex: ttsService.currentParagraphIndex,
                totalParagraphs: currentParagraphs.count,
                isPlaying: true
            )
        }
    }

    private func setupTTSChapterFinished() {
        ttsService.onChapterFinished = { [self] in
            if currentChapterIndex < book.sortedChapters.count - 1 {
                jumpToChapter(currentChapterIndex + 1)
                ttsService.loadChapter(paragraphs: currentParagraphs, startAt: 0)
                setupTTSChapterFinished()
                ttsService.play()
                nowPlayingService.updateNowPlaying(
                    bookTitle: book.title,
                    chapterTitle: currentChapter?.title ?? "",
                    paragraphIndex: 0,
                    totalParagraphs: currentParagraphs.count,
                    isPlaying: true
                )
            }
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

    private func jumpToChapter(_ index: Int) {
        guard index >= 0, index < book.sortedChapters.count else { return }
        let wasPlaying = ttsService.isPlaying
        ttsService.stop()
        currentChapterIndex = index
        visibleParagraphIndex = 0
        if wasPlaying {
            ttsService.loadChapter(paragraphs: currentParagraphs, startAt: 0)
            setupTTSChapterFinished()
            ttsService.play()
        }
        saveProgress()
    }

    // MARK: - Progress

    private func saveProgressDebounced() {
        book.lastReadChapter = currentChapterIndex
        book.lastReadOffset  = visibleParagraphIndex
        book.dateLastRead    = Date()
        updateReadingProgress()
    }

    private func saveProgress() {
        book.lastReadChapter = currentChapterIndex
        book.lastReadOffset  = visibleParagraphIndex
        book.dateLastRead    = Date()
        updateReadingProgress()
    }

    private func updateReadingProgress() {
        let totalChapters = book.sortedChapters.count
        guard totalChapters > 0 else { return }
        let chapterProgress = Double(currentChapterIndex) / Double(totalChapters)
        let withinChapter   = currentParagraphs.isEmpty ? 0.0 :
            Double(visibleParagraphIndex) / Double(currentParagraphs.count) / Double(totalChapters)
        book.readingProgress = min(chapterProgress + withinChapter, 1.0)
    }
}
