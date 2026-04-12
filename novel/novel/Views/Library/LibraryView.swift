import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 書庫主頁：2 欄卡片格局，深色底，支援匯入 / 刪除 / 重新命名
struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TTSService.self) private var ttsService
    @Query(sort: \Book.dateLastRead, order: .reverse) private var books: [Book]

    @State private var showFileImporter = false
    @State private var showImportError  = false
    @State private var importErrorMessage = ""
    @State private var bookToRename: Book?
    @State private var renameText       = ""
    @State private var showRenameAlert  = false
    @State private var isImporting      = false
    @State private var showOnboarding   = !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
    @State private var deleteTrigger    = false

    /// 檔案大小上限（100 MB），超過會警告使用者
    private static let fileSizeLimitBytes: Int = 100 * 1024 * 1024
    /// 檔案大小建議值（50 MB），超過會顯示提醒
    private static let fileSizeWarningBytes: Int = 50 * 1024 * 1024

    private let columns = [
        GridItem(.flexible(), spacing: NNSpacing.cardSpacing),
        GridItem(.flexible(), spacing: NNSpacing.cardSpacing)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                NNColor.appBackground.ignoresSafeArea()

                if books.isEmpty {
                    emptyStateView
                } else {
                    bookGridView
                }
            }
            .navigationTitle("書庫")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(NNColor.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showFileImporter = true
                    } label: {
                        Image(systemName: NNSymbol.importFile)
                            .foregroundStyle(NNColor.accent)
                            .imageScale(.medium)
                    }
                    .accessibilityLabel("匯入小說")
                    .disabled(isImporting)
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result: result)
            }
            .alert("匯入失敗", isPresented: $showImportError) {
                Button("確定", role: .cancel) {}
            } message: {
                Text(importErrorMessage)
            }
            .alert("重新命名", isPresented: $showRenameAlert) {
                TextField("書名", text: $renameText)
                Button("取消", role: .cancel) {}
                Button("確定") {
                    if let book = bookToRename, !renameText.isEmpty {
                        book.title = renameText
                    }
                }
            } message: {
                Text("請輸入新的書名")
            }
            .navigationDestination(for: Book.self) { book in
                ReaderView(book: book)
            }
        }
        // 匯入中遮罩放在 NavigationStack 外層，避免導航轉場時殘留
        .overlay {
            if isImporting {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: NNSpacing.md) {
                        ProgressView()
                            .tint(NNColor.accent)
                            .scaleEffect(1.2)
                        Text("匯入中…")
                            .font(NNFont.uiBody)
                            .foregroundStyle(NNColor.textPrimary)
                    }
                    .padding(NNSpacing.xl)
                    .background(
                        RoundedRectangle(cornerRadius: NNSpacing.cardCornerRadius)
                            .fill(NNColor.cardBackground)
                    )
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isImporting)
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                showOnboarding = false
            }
        }
    }

    // MARK: - Book Grid

    private var bookGridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: NNSpacing.cardSpacing) {
                ForEach(Array(books.enumerated()), id: \.element.id) { index, book in
                    NavigationLink(value: book) {
                        BookCardView(
                            book: book,
                            isPlaying: ttsService.currentBookId == book.id && ttsService.isPlaying,
                            appearIndex: index
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isImporting)
                    .contextMenu {
                        Button {
                            bookToRename = book
                            renameText   = book.title
                            showRenameAlert = true
                        } label: {
                            Label("重新命名", systemImage: NNSymbol.renameBook)
                        }

                        Divider()

                        Button(role: .destructive) {
                            deleteBook(book)
                        } label: {
                            Label("刪除", systemImage: NNSymbol.deleteBook)
                        }
                    }
                }
            }
            .padding(NNSpacing.md)
            .sensoryFeedback(.warning, trigger: deleteTrigger)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: NNSpacing.lg) {
            Spacer()

            Image(systemName: "books.vertical")
                .font(.system(size: 60, weight: .thin))
                .foregroundStyle(NNColor.textTertiary)

            VStack(spacing: NNSpacing.sm) {
                Text("書架是空的")
                    .font(NNFont.uiTitle)
                    .foregroundStyle(NNColor.textPrimary)

                Text("匯入 .txt 格式的小說\n開始你的閱讀之旅")
                    .font(NNFont.uiBody)
                    .foregroundStyle(NNColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showFileImporter = true
            } label: {
                HStack(spacing: NNSpacing.sm) {
                    Image(systemName: NNSymbol.importFile)
                    Text("匯入小說")
                        .fontWeight(.medium)
                }
                .font(NNFont.uiBody)
                .foregroundStyle(.white)
                .padding(.horizontal, NNSpacing.xl)
                .frame(minHeight: NNSpacing.minTouchTarget)
                .background(NNColor.accent)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel("匯入小說")

            Spacer()
            Spacer()
        }
        .padding(NNSpacing.xl)
    }

    // MARK: - File Import

    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                importErrorMessage = String(localized: "無法存取所選檔案")
                showImportError = true
                return
            }

            isImporting = true
            let fileName = url.lastPathComponent
            let title = url.deletingPathExtension().lastPathComponent

            Task.detached(priority: .userInitiated) {
                do {
                    // Item 2: 檔案大小檢查
                    let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
                    let fileSize = resourceValues.fileSize ?? 0

                    if fileSize > Self.fileSizeLimitBytes {
                        url.stopAccessingSecurityScopedResource()
                        await MainActor.run {
                            self.importErrorMessage = String(localized: "檔案大小超過 100 MB，請選擇較小的檔案")
                            self.showImportError = true
                            self.isImporting = false
                        }
                        return
                    }

                    let data = try Data(contentsOf: url)
                    url.stopAccessingSecurityScopedResource()

                    if fileSize > Self.fileSizeWarningBytes {
                        #if DEBUG
                        print("⚠️ 匯入檔案較大（\(fileSize / 1024 / 1024) MB），可能影響效能")
                        #endif
                    }

                    guard let content = EncodingDetector.decodeString(from: data) else {
                        await MainActor.run {
                            self.importErrorMessage = String(localized: "無法辨識檔案編碼，請確認檔案為文字格式")
                            self.showImportError = true
                            self.isImporting = false
                        }
                        return
                    }

                    guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        await MainActor.run {
                            self.importErrorMessage = String(localized: "檔案內容為空")
                            self.showImportError = true
                            self.isImporting = false
                        }
                        return
                    }

                    // 章節解析在背景完成（CPU 密集）
                    let chapters = ChapterParser.parseChapters(from: content)

                    await MainActor.run {
                        let book = Book(title: title, fileName: fileName, content: content)
                        book.chapters = chapters
                        for chapter in chapters { chapter.book = book }
                        self.modelContext.insert(book)
                        // Item 1: 錯誤處理——匯入儲存失敗時通知使用者
                        do {
                            try self.modelContext.save()
                        } catch {
                            self.importErrorMessage = String(localized: "儲存書籍時發生錯誤：\(error.localizedDescription)")
                            self.showImportError = true
                        }
                        self.isImporting = false
                    }

                } catch {
                    await MainActor.run {
                        self.importErrorMessage = String(localized: "讀取檔案時發生錯誤：\(error.localizedDescription)")
                        self.showImportError = true
                        self.isImporting = false
                    }
                }
            }

        case .failure(let error):
            importErrorMessage = String(localized: "選取檔案失敗：\(error.localizedDescription)")
            showImportError = true
        }
    }

    // MARK: - Delete

    private func deleteBook(_ book: Book) {
        deleteTrigger.toggle()
        modelContext.delete(book)
    }
}
