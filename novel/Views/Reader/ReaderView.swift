import SwiftUI
import SwiftData
import AVFoundation

/// 閱讀器主視圖：管理工具列、設定、章節導航與 TTS 控制
struct ReaderView: View {
    @Bindable var book: Book
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(TTSService.self) private var ttsService
    @Query private var allSettings: [UserSettings]

    @State private var showToolbars = true
    @State private var showSettings = false
    @State private var showChapterList = false
    @State private var currentChapterIndex: Int = 0
    @State private var visibleParagraphIndex: Int = 0
    @State private var nowPlayingService = NowPlayingService()
    @State private var hasSetupNowPlaying = false

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

    var body: some View {
        ZStack {
            // 背景
            theme.backgroundColor
                .ignoresSafeArea()

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
                withAnimation(.easeInOut(duration: 0.2)) {
                    showToolbars.toggle()
                }
            }

            // 工具列覆蓋層
            if showToolbars {
                VStack {
                    topToolbar
                    Spacer()
                    bottomToolbar
                }
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(!showToolbars)
        .onAppear {
            currentChapterIndex = book.lastReadChapter
            visibleParagraphIndex = book.lastReadOffset
            ttsService.currentBookId = book.id

            // 確保有 UserSettings
            if allSettings.isEmpty {
                let newSettings = UserSettings()
                modelContext.insert(newSettings)
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

    // MARK: - 上方工具列
    private var topToolbar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundStyle(theme.textColor)
            }
            .accessibilityLabel("返回")

            Spacer()

            Text(currentChapter?.title ?? book.title)
                .font(.subheadline)
                .foregroundStyle(theme.textColor)
                .lineLimit(1)

            Spacer()

            Button {
                showChapterList = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title3)
                    .foregroundStyle(theme.textColor)
            }
            .accessibilityLabel("目錄")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(theme.toolbarStyle)
    }

    // MARK: - 下方工具列
    private var bottomToolbar: some View {
        VStack(spacing: 12) {
            // 章節進度滑桿
            if book.sortedChapters.count > 1 {
                HStack {
                    Text("\(currentChapterIndex + 1)")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryTextColor)
                    Slider(
                        value: Binding(
                            get: { Double(currentChapterIndex) },
                            set: { jumpToChapter(Int($0)) }
                        ),
                        in: 0...Double(max(book.sortedChapters.count - 1, 1)),
                        step: 1
                    )
                    .tint(theme.textColor.opacity(0.6))
                    Text("\(book.sortedChapters.count)")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryTextColor)
                }
                .padding(.horizontal, 16)
            }

            // TTS 控制列
            HStack(spacing: 32) {
                Button {
                    ttsService.previousParagraph()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                        .foregroundStyle(theme.textColor)
                }
                .accessibilityLabel("上一段")

                Button {
                    toggleTTS()
                } label: {
                    Image(systemName: ttsService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundStyle(theme.textColor)
                }
                .accessibilityLabel(ttsService.isPlaying ? "暫停" : "播放")

                Button {
                    ttsService.nextParagraph()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                        .foregroundStyle(theme.textColor)
                }
                .accessibilityLabel("下一段")

                Spacer()

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundStyle(theme.textColor)
                }
                .accessibilityLabel("設定")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .padding(.vertical, 12)
        .background(theme.toolbarStyle)
    }

    // MARK: - TTS 控制

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
                ttsService.loadChapter(
                    paragraphs: currentParagraphs,
                    startAt: visibleParagraphIndex
                )
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
            // 自動跳到下一章
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
            onPlay: { toggleTTS() },
            onPause: { toggleTTS() },
            onNextTrack: { ttsService.nextParagraph() },
            onPreviousTrack: { ttsService.previousParagraph() }
        )
    }

    // MARK: - 章節導航

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

    // MARK: - 進度儲存

    private var saveTask: Task<Void, Never>? {
        get { nil }
        set { }
    }

    private func saveProgressDebounced() {
        // 簡單的節流：直接儲存（SwiftData 會批次處理）
        book.lastReadChapter = currentChapterIndex
        book.lastReadOffset = visibleParagraphIndex
        book.dateLastRead = Date()

        // 計算整體進度
        let totalChapters = book.sortedChapters.count
        if totalChapters > 0 {
            let chapterProgress = Double(currentChapterIndex) / Double(totalChapters)
            let withinChapterProgress = currentParagraphs.isEmpty ? 0 :
                Double(visibleParagraphIndex) / Double(currentParagraphs.count) / Double(totalChapters)
            book.readingProgress = min(chapterProgress + withinChapterProgress, 1.0)
        }
    }

    private func saveProgress() {
        book.lastReadChapter = currentChapterIndex
        book.lastReadOffset = visibleParagraphIndex
        book.dateLastRead = Date()

        let totalChapters = book.sortedChapters.count
        if totalChapters > 0 {
            let chapterProgress = Double(currentChapterIndex) / Double(totalChapters)
            let withinChapterProgress = currentParagraphs.isEmpty ? 0 :
                Double(visibleParagraphIndex) / Double(currentParagraphs.count) / Double(totalChapters)
            book.readingProgress = min(chapterProgress + withinChapterProgress, 1.0)
        }
    }
}
