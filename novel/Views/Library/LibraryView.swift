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
            .toolbarColorScheme(.dark, for: .navigationBar)
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
                }
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
                importErrorMessage = "無法存取所選檔案"
                showImportError = true
                return
            }

            isImporting = true
            let fileName = url.lastPathComponent
            let title = url.deletingPathExtension().lastPathComponent

            Task.detached(priority: .userInitiated) {
                do {
                    let data = try Data(contentsOf: url)
                    url.stopAccessingSecurityScopedResource()

                    guard let content = EncodingDetector.decodeString(from: data) else {
                        await MainActor.run {
                            self.importErrorMessage = "無法辨識檔案編碼，請確認檔案為文字格式"
                            self.showImportError = true
                            self.isImporting = false
                        }
                        return
                    }

                    guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        await MainActor.run {
                            self.importErrorMessage = "檔案內容為空"
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
                        try? self.modelContext.save()
                        self.isImporting = false
                    }

                } catch {
                    await MainActor.run {
                        self.importErrorMessage = "讀取檔案時發生錯誤：\(error.localizedDescription)"
                        self.showImportError = true
                        self.isImporting = false
                    }
                }
            }

        case .failure(let error):
            importErrorMessage = "選取檔案失敗：\(error.localizedDescription)"
            showImportError = true
        }
    }

    // MARK: - Delete

    private func deleteBook(_ book: Book) {
        modelContext.delete(book)
    }
}
