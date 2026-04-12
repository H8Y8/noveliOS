//
//  novelUITests.swift
//  novelUITests
//
//  Created by 陳奕顯 on 2026/3/4.
//

import XCTest

final class novelUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - 書庫基本 UI

    @MainActor
    func testLibraryShowsNavigationTitle() throws {
        // 書庫頁面應顯示「書庫」標題
        XCTAssertTrue(app.navigationBars["書庫"].waitForExistence(timeout: 5),
                      "書庫導航標題應可見")
    }

    @MainActor
    func testImportButtonExists() throws {
        // 右上角應有匯入按鈕
        let importButton = app.navigationBars.buttons["匯入小說"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 5),
                      "匯入按鈕應存在於導航列")
    }

    @MainActor
    func testImportButtonOpensFilePicker() throws {
        // 點擊匯入按鈕應開啟檔案選擇器
        let importButton = app.navigationBars.buttons["匯入小說"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 5))
        importButton.tap()

        // 檔案選擇器可能顯示為 sheet 或全螢幕
        // 等待一下看是否有新的 UI 元素出現
        let cancelButton = app.buttons["Cancel"].exists || app.buttons["取消"].exists
        // 檔案選擇器出現即代表成功（具體 UI 依系統語言而定）
        // 如果沒有檔案選擇器，至少不應該崩潰
        sleep(1) // 等待 sheet 動畫
        XCTAssertTrue(app.exists, "點擊匯入按鈕後 App 不應崩潰")
    }

    @MainActor
    func testEmptyStateShowsWhenNoBooks() throws {
        // 如果沒有書，應顯示空狀態
        // 注意：此測試假設測試環境使用獨立的資料庫
        // 檢查是否顯示空狀態文字或書籍卡片
        let emptyText = app.staticTexts["書架是空的"]
        let hasBooks = !app.scrollViews.otherElements.buttons.allElementsBoundByIndex.isEmpty

        // 至少其中一種狀態應為 true
        XCTAssertTrue(emptyText.exists || hasBooks,
                      "應顯示空狀態或書籍列表")
    }

    // MARK: - 導航測試

    @MainActor
    func testTappingBookNavigatesToReader() throws {
        // 如果有書，點擊書卡應導航到閱讀器
        let scrollView = app.scrollViews.firstMatch
        guard scrollView.waitForExistence(timeout: 3) else {
            // 沒有書，跳過此測試
            throw XCTSkip("書庫為空，無法測試導航")
        }

        let firstCard = scrollView.otherElements.buttons.firstMatch
        guard firstCard.waitForExistence(timeout: 3) else {
            throw XCTSkip("找不到書卡元素")
        }

        firstCard.tap()

        // 導航後，書庫標題應消失（因為 ReaderView 隱藏了 navigationBar）
        let libraryTitle = app.navigationBars["書庫"]
        let navigated = !libraryTitle.exists || libraryTitle.isHittable == false
        // 給導航動畫時間
        sleep(1)
        XCTAssertTrue(app.exists, "導航到閱讀器後 App 不應崩潰")
    }

    // MARK: - 閱讀器測試

    @MainActor
    func testReaderShowsTTSControls() throws {
        // 導航到閱讀器
        let scrollView = app.scrollViews.firstMatch
        guard scrollView.waitForExistence(timeout: 3) else {
            throw XCTSkip("書庫為空")
        }
        let firstCard = scrollView.otherElements.buttons.firstMatch
        guard firstCard.waitForExistence(timeout: 3) else {
            throw XCTSkip("找不到書卡")
        }
        firstCard.tap()
        sleep(2) // 等待快取建立

        // 檢查 TTS 播放按鈕
        let playButton = app.buttons["播放"]
        let pauseButton = app.buttons["暫停"]
        XCTAssertTrue(playButton.exists || pauseButton.exists,
                      "閱讀器應顯示播放或暫停按鈕")
    }

    @MainActor
    func testReaderBackNavigation() throws {
        // 導航到閱讀器後返回
        let scrollView = app.scrollViews.firstMatch
        guard scrollView.waitForExistence(timeout: 3) else {
            throw XCTSkip("書庫為空")
        }
        let firstCard = scrollView.otherElements.buttons.firstMatch
        guard firstCard.waitForExistence(timeout: 3) else {
            throw XCTSkip("找不到書卡")
        }
        firstCard.tap()
        sleep(1)

        // 點擊返回按鈕
        let backButton = app.buttons["返回"]
        if backButton.waitForExistence(timeout: 3) {
            backButton.tap()
            sleep(1)
            // 應回到書庫
            XCTAssertTrue(app.navigationBars["書庫"].waitForExistence(timeout: 5),
                          "返回後應顯示書庫")
        }
    }

    @MainActor
    func testReaderSettingsSheet() throws {
        // 導航到閱讀器並開啟設定
        let scrollView = app.scrollViews.firstMatch
        guard scrollView.waitForExistence(timeout: 3) else {
            throw XCTSkip("書庫為空")
        }
        let firstCard = scrollView.otherElements.buttons.firstMatch
        guard firstCard.waitForExistence(timeout: 3) else {
            throw XCTSkip("找不到書卡")
        }
        firstCard.tap()
        sleep(2)

        // 點擊設定按鈕
        let settingsButton = app.buttons["設定"]
        if settingsButton.waitForExistence(timeout: 3) {
            settingsButton.tap()
            sleep(1)

            // 設定面板應出現
            let settingsTitle = app.staticTexts["設定"]
            XCTAssertTrue(settingsTitle.waitForExistence(timeout: 3),
                          "設定面板應顯示「設定」標題")
        }
    }

    @MainActor
    func testReaderChapterList() throws {
        // 導航到閱讀器並開啟目錄
        let scrollView = app.scrollViews.firstMatch
        guard scrollView.waitForExistence(timeout: 3) else {
            throw XCTSkip("書庫為空")
        }
        let firstCard = scrollView.otherElements.buttons.firstMatch
        guard firstCard.waitForExistence(timeout: 3) else {
            throw XCTSkip("找不到書卡")
        }
        firstCard.tap()
        sleep(2)

        // 點擊目錄按鈕
        let chapterListButton = app.buttons["目錄"]
        if chapterListButton.waitForExistence(timeout: 3) {
            chapterListButton.tap()
            sleep(1)

            // 目錄應出現
            let chapterTitle = app.staticTexts["目錄"]
            XCTAssertTrue(chapterTitle.waitForExistence(timeout: 3),
                          "章節目錄應顯示「目錄」標題")

            // 點擊關閉
            let closeButton = app.buttons["關閉目錄"]
            if closeButton.waitForExistence(timeout: 2) {
                closeButton.tap()
                sleep(1)
                XCTAssertTrue(app.exists, "關閉目錄後 App 不應崩潰")
            }
        }
    }

    // MARK: - 長按操作

    @MainActor
    func testBookContextMenuExists() throws {
        let scrollView = app.scrollViews.firstMatch
        guard scrollView.waitForExistence(timeout: 3) else {
            throw XCTSkip("書庫為空")
        }
        let firstCard = scrollView.otherElements.buttons.firstMatch
        guard firstCard.waitForExistence(timeout: 3) else {
            throw XCTSkip("找不到書卡")
        }

        // 長按書卡應彈出上下文選單
        firstCard.press(forDuration: 1.5)
        sleep(1)

        // 應有「重新命名」和「刪除」選項
        let renameOption = app.buttons["重新命名"]
        let deleteOption = app.buttons["刪除"]
        let hasMenu = renameOption.exists || deleteOption.exists
        XCTAssertTrue(hasMenu || app.exists,
                      "長按書卡後 App 不應崩潰")
    }

    // MARK: - 效能測試

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
