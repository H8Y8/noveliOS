import SwiftUI
import UIKit

/// 翻頁式閱讀內容視圖（UIPageViewController + pageCurl 轉場）
/// 支援左右拖曳翻頁動畫、三區點擊（左翻前頁 / 中央切換工具列 / 右翻下頁）、
/// TTS 高亮自動跳頁、程式化章節跳轉。
struct PageReaderView: UIViewControllerRepresentable {
    let paragraphs: [String]
    let pages: [[Int]]
    let theme: ReadingTheme
    let fontSize: Double
    let lineSpacing: Double
    let fontFamily: String
    let highlightedParagraphIndex: Int?
    @Binding var visibleParagraphIndex: Int
    @Binding var scrollCommand: ScrollCommand?
    let onTap: () -> Void

    // MARK: - Representable

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pvc = UIPageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal,
            options: nil
        )
        pvc.dataSource = context.coordinator
        pvc.delegate = context.coordinator
        pvc.isDoubleSided = false
        pvc.view.backgroundColor = UIColor(theme.backgroundColor)
        context.coordinator.pageViewController = pvc

        // 停用內建的 tap-to-turn 手勢，改用自定義三區點擊
        for recognizer in pvc.gestureRecognizers {
            if recognizer is UITapGestureRecognizer {
                recognizer.isEnabled = false
            }
        }

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        pvc.view.addGestureRecognizer(tap)

        // 設定初始頁
        let initialPage = PaginationEngine.pageIndex(
            forParagraph: visibleParagraphIndex, in: pages
        )
        if let vc = context.coordinator.makeHostingVC(at: initialPage) {
            pvc.setViewControllers([vc], direction: .forward, animated: false)
            context.coordinator.currentPageIndex = initialPage
        }

        return pvc
    }

    func updateUIViewController(_ uiViewController: UIPageViewController, context: Context) {
        let coord = context.coordinator
        let old = coord.parent
        coord.parent = self

        uiViewController.view.backgroundColor = UIColor(theme.backgroundColor)

        // 1. 處理程式化跳轉（章節選擇、恢復進度等）
        if let cmd = scrollCommand, cmd.id != coord.lastHandledScrollCommandId {
            coord.lastHandledScrollCommandId = cmd.id
            let target = PaginationEngine.pageIndex(forParagraph: cmd.index, in: pages)
            navigateTo(page: target, in: uiViewController, coordinator: coord)
            DispatchQueue.main.async { scrollCommand = nil }
            return
        }

        // 2. 處理 TTS 高亮跨頁
        if let hlIdx = highlightedParagraphIndex {
            let target = PaginationEngine.pageIndex(forParagraph: hlIdx, in: pages)
            if target != coord.currentPageIndex {
                navigateTo(page: target, in: uiViewController, coordinator: coord)
                return
            }
        }

        // 3. 分頁結構改變（字型大小 / 行距 / 字體變更）
        if pages != old.pages {
            let target = PaginationEngine.pageIndex(
                forParagraph: visibleParagraphIndex, in: pages
            )
            navigateTo(page: target, in: uiViewController, coordinator: coord, animated: false)
            return
        }

        // 4. 同一頁內容更新（高亮 / 主題切換）
        let highlightChanged = highlightedParagraphIndex != old.highlightedParagraphIndex
        let themeChanged = theme != old.theme
        if highlightChanged || themeChanged {
            if let vc = coord.makeHostingVC(at: coord.currentPageIndex) {
                uiViewController.setViewControllers([vc], direction: .forward, animated: false)
            }
        }
    }

    // MARK: - Navigation Helper

    private func navigateTo(
        page target: Int,
        in pvc: UIPageViewController,
        coordinator: Coordinator,
        animated: Bool = true
    ) {
        guard let vc = coordinator.makeHostingVC(at: target) else { return }
        let direction: UIPageViewController.NavigationDirection =
            target >= coordinator.currentPageIndex ? .forward : .reverse
        pvc.setViewControllers([vc], direction: direction, animated: animated)
        coordinator.currentPageIndex = target
        if target < pages.count {
            visibleParagraphIndex = pages[target].first ?? 0
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject,
                       UIPageViewControllerDataSource,
                       UIPageViewControllerDelegate {
        var parent: PageReaderView
        weak var pageViewController: UIPageViewController?
        var currentPageIndex: Int = 0
        var lastHandledScrollCommandId: UUID?

        init(_ parent: PageReaderView) {
            self.parent = parent
        }

        func makeHostingVC(at pageIndex: Int) -> UIViewController? {
            guard pageIndex >= 0, pageIndex < parent.pages.count else { return nil }

            let content = PageContentView(
                paragraphs: parent.paragraphs,
                paragraphIndices: parent.pages[pageIndex],
                theme: parent.theme,
                fontSize: parent.fontSize,
                lineSpacing: parent.lineSpacing,
                fontFamily: parent.fontFamily,
                highlightedParagraphIndex: parent.highlightedParagraphIndex,
                pageNumber: pageIndex + 1,
                totalPages: parent.pages.count
            )

            let vc = UIHostingController(rootView: content)
            vc.view.backgroundColor = UIColor(parent.theme.backgroundColor)
            vc.view.tag = pageIndex
            return vc
        }

        // MARK: Tap（三區）

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let location = gesture.location(in: gesture.view)
            let width = gesture.view?.bounds.width ?? 0
            let third = width / 3

            if location.x < third {
                goToPreviousPage()
            } else if location.x > third * 2 {
                goToNextPage()
            } else {
                parent.onTap()
            }
        }

        private func goToPreviousPage() {
            guard let pvc = pageViewController,
                  currentPageIndex > 0,
                  let vc = makeHostingVC(at: currentPageIndex - 1) else { return }
            pvc.setViewControllers([vc], direction: .reverse, animated: true)
            currentPageIndex -= 1
            parent.visibleParagraphIndex = parent.pages[currentPageIndex].first ?? 0
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        private func goToNextPage() {
            guard let pvc = pageViewController,
                  currentPageIndex < parent.pages.count - 1,
                  let vc = makeHostingVC(at: currentPageIndex + 1) else { return }
            pvc.setViewControllers([vc], direction: .forward, animated: true)
            currentPageIndex += 1
            parent.visibleParagraphIndex = parent.pages[currentPageIndex].first ?? 0
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        // MARK: DataSource

        func pageViewController(
            _ pvc: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            makeHostingVC(at: viewController.view.tag - 1)
        }

        func pageViewController(
            _ pvc: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            makeHostingVC(at: viewController.view.tag + 1)
        }

        // MARK: Delegate

        func pageViewController(
            _ pvc: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            guard completed,
                  let currentVC = pvc.viewControllers?.first else { return }
            let pageIndex = currentVC.view.tag
            currentPageIndex = pageIndex

            if pageIndex >= 0 && pageIndex < parent.pages.count {
                parent.visibleParagraphIndex = parent.pages[pageIndex].first ?? 0
            }

            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

// MARK: - Page Content View

/// 單頁內容：顯示該頁的段落文字、TTS 高亮、頁碼
private struct PageContentView: View {
    let paragraphs: [String]
    let paragraphIndices: [Int]
    let theme: ReadingTheme
    let fontSize: Double
    let lineSpacing: Double
    let fontFamily: String
    let highlightedParagraphIndex: Int?
    let pageNumber: Int
    let totalPages: Int

    var body: some View {
        VStack(spacing: 0) {
            // 頂部工具列淨空
            Color.clear
                .frame(height: NNSpacing.toolbarHeight + 28 + NNSpacing.md)

            // 段落文字
            VStack(alignment: .leading, spacing: paragraphSpacing) {
                ForEach(paragraphIndices, id: \.self) { index in
                    paragraphView(index: index)
                }
            }
            .padding(.horizontal, NNSpacing.readerHorizontal)

            Spacer(minLength: 0)

            // 頁碼
            Text("\(pageNumber) / \(totalPages)")
                .font(NNFont.uiCaption2)
                .foregroundStyle(theme.secondaryTextColor)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, NNSpacing.xs)

            // 底部工具列淨空
            Color.clear
                .frame(height: NNSpacing.bottomToolbarHeight + 32 + NNSpacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.backgroundColor)
    }

    @ViewBuilder
    private func paragraphView(index: Int) -> some View {
        let isHighlighted = index == highlightedParagraphIndex

        Text(paragraphs[index])
            .font(readerFont)
            .foregroundStyle(theme.textColor)
            .lineSpacing(lineSpacingPoints)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, NNSpacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isHighlighted ? theme.highlightColor : Color.clear)
                    .padding(.horizontal, -6)
            )
    }

    // MARK: - Computed

    private var paragraphSpacing: CGFloat {
        CGFloat(fontSize) * 0.55 + 4
    }

    private var lineSpacingPoints: CGFloat {
        CGFloat(fontSize) * CGFloat(lineSpacing - 1.0)
    }

    private var readerFont: Font {
        NNFont.readerBody(
            size: CGFloat(fontSize),
            family: NNFont.ReadingFamily(rawValue: fontFamily) ?? .system
        )
    }
}
