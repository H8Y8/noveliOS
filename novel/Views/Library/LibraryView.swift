import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 書庫主頁：顯示所有已匯入書籍，支援匯入、刪除、重新命名
struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.dateLastRead, order: .reverse) private var books: [Book]

    @State private var showFileImporter = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    @State private var bookToRename: Book?
    @State private var renameText = ""
    @State private var showRenameAlert = false

    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty {
                    emptyStateView
                } else {
                    bookListView
                }
            }
            .navigationTitle("小說說書器")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showFileImporter = true
                    } label: {
                        Image(systemName: "plus")
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
        }
    }

    // MARK: - 空狀態
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("尚無書籍", systemImage: "book.closed")
        } description: {
            Text("點擊右上角 + 匯入 .txt 小說檔案")
        } actions: {
            Button("匯入小說") {
                showFileImporter = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - 書籍列表
    private var bookListView: some View {
        List {
            ForEach(books) { book in
                NavigationLink(value: book) {
                    BookCardView(book: book)
                }
                .contextMenu {
                    Button {
                        bookToRename = book
                        renameText = book.title
                        showRenameAlert = true
                    } label: {
                        Label("重新命名", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        deleteBook(book)
                    } label: {
                        Label("刪除", systemImage: "trash")
                    }
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    deleteBook(books[index])
                }
            }
        }
    }

    // MARK: - 匯入處理
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                importErrorMessage = "無法存取所選檔案"
                showImportError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                guard let content = EncodingDetector.decodeString(from: data) else {
                    importErrorMessage = "無法辨識檔案編碼，請確認檔案為文字格式"
                    showImportError = true
                    return
                }

                guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    importErrorMessage = "檔案內容為空"
                    showImportError = true
                    return
                }

                // 從檔名取得書名（去除副檔名）
                let title = url.deletingPathExtension().lastPathComponent

                let book = Book(title: title, fileName: url.lastPathComponent, content: content)

                // 解析章節
                let chapters = ChapterParser.parseChapters(from: content)
                book.chapters = chapters
                for chapter in chapters {
                    chapter.book = book
                }

                modelContext.insert(book)
                try modelContext.save()

            } catch {
                importErrorMessage = "讀取檔案時發生錯誤：\(error.localizedDescription)"
                showImportError = true
            }

        case .failure(let error):
            importErrorMessage = "選取檔案失敗：\(error.localizedDescription)"
            showImportError = true
        }
    }

    // MARK: - 刪除書籍
    private func deleteBook(_ book: Book) {
        modelContext.delete(book)
    }
}
