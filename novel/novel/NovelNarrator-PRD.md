# 小說說書器 NovelNarrator — Product Requirements Document

## 1. 產品概述

### 1.1 一句話描述
一款 iOS 原生 App，讓使用者匯入 `.txt` 小說文字檔，以沉浸式閱讀介面瀏覽內容，並透過繁體中文語音合成（TTS）在前景或背景朗讀小說，如同一位隨身說書人。

### 1.2 核心價值
解決「想讀小說但沒空看螢幕」的場景——通勤、做家事、運動時，App 能在背景持續唸書，同時保留完整的視覺閱讀體驗供靜態閱讀使用。

### 1.3 目標使用者
繁體中文讀者，有大量 `.txt` 格式網路小說或電子書，希望在 iPhone/iPad 上閱讀與聆聽。

### 1.4 技術棧
- 語言：Swift 5.9+
- UI 框架：SwiftUI（iOS 17+）
- 語音合成：AVSpeechSynthesizer（系統內建，支援 zh-TW 繁體中文語音）
- 背景播放：AVAudioSession（.playback category）+ Background Modes
- 資料層：SwiftData（或 Core Data）持久化閱讀進度與書庫
- 文件匯入：UIDocumentPickerViewController / .fileImporter SwiftUI modifier
- 建構工具：Xcode 15+

---

## 2. 功能規格

### 2.1 書庫管理（Library）

**匯入**
- 支援透過「檔案」App 選取 `.txt` 檔匯入，使用 SwiftUI `.fileImporter` modifier，過濾 UTType 為 `.plainText`。
- 匯入時自動偵測編碼（優先嘗試 UTF-8，fallback 至 Big5、GBK），避免亂碼。
- 匯入後將檔案內容複製至 App sandbox，原始檔案不再依賴。

**書庫列表**
- 以卡片或列表形式顯示所有已匯入書籍，每本顯示：書名（預設取檔名去掉副檔名，可手動修改）、最後閱讀日期、閱讀進度百分比。
- 支援左滑刪除書籍（含確認 alert）。
- 長按可重新命名書名。

**章節解析**
- 匯入後背景執行章節解析：依照常見小說分章規則自動切割章節。正則建議涵蓋以下模式：
  - `第X章`、`第X回`、`第X節`（X 為中文數字或阿拉伯數字）
  - `Chapter X`
  - 連續空行（≥2 行空行）作為 fallback 分段
- 若完全無法辨識章節，則依固定字元數（如每 3000 字）分頁。
- 章節列表可在閱讀介面側欄（目錄 drawer）中瀏覽跳轉。

---

### 2.2 閱讀器（Reader）

**排版**
- 全螢幕沉浸式閱讀，點擊畫面中央呼叫/隱藏上下工具列。
- 上方工具列：返回按鈕、書名、目錄按鈕。
- 下方工具列：進度滑桿（SeekBar）、TTS 播放控制、設定齒輪。
- 文字排版使用 `AttributedString` 渲染於 ScrollView 或分頁 TabView 內。

**翻頁模式（使用者可切換）**
- 捲動模式（Scroll）：連續捲動，如同網頁閱讀。
- 分頁模式（Pagination）：左右滑動翻頁，模擬實體書翻頁體驗。分頁使用 `UIPageViewController` 包裝或 SwiftUI TabView with `.page` style。每頁根據當前字型大小動態計算可容納字數，使用 `NSLayoutManager` 或 `CTFramesetter` 做文字分頁計算。

**閱讀設定（Settings Sheet）**
- 字型大小：滑桿調整，範圍 14pt ~ 32pt，預設 18pt。
- 行距：1.2x / 1.5x / 1.8x / 2.0x。
- 背景主題：至少提供四種——白底黑字、淺黃底（護眼）、淺灰底、純黑底白字（夜間模式）。
- 字體選擇：系統預設、PingFang TC、Noto Sans TC（若有安裝）。
- TTS 語速：滑桿 0.3 ~ 0.7（AVSpeechUtterance.rate 範圍），預設 0.5。
- TTS 語音選擇：列出裝置上所有 zh-TW locale 的 AVSpeechSynthesisVoice，讓使用者挑選偏好語音。

**閱讀進度**
- 自動記錄當前閱讀位置（章節 index + 段落 offset），退出後下次開啟自動回到上次位置。
- 進度以 SwiftData model 持久化。

---

### 2.3 TTS 說書（Text-to-Speech Narrator）

**核心引擎**
- 使用 `AVSpeechSynthesizer`，語言設定為 `zh-TW`。
- 每次餵入一個段落作為一個 `AVSpeechUtterance`，朗讀完畢後自動排入下一段，實作 `AVSpeechSynthesizerDelegate` 的 `didFinish` callback 來驅動連續朗讀。

**播放控制**
- 播放 / 暫停按鈕。
- 上一段 / 下一段跳轉。
- 語速即時調整（暫停後以新 rate 重新開始當前段落）。

**視覺同步**
- TTS 朗讀時，閱讀器自動捲動至當前朗讀段落，並以高亮色標記正在朗讀的段落。
- 使用 `AVSpeechSynthesizerDelegate.willSpeakRangeOfSpeechString` 回調實現逐字或逐句高亮（MVP 階段可先做段落級高亮，後續迭代加入逐句高亮）。

**背景播放**
- 在 Xcode project 的 Signing & Capabilities 中啟用 Background Modes → Audio, AirPlay, and Picture in Picture。
- 設定 `AVAudioSession.sharedInstance()` 的 category 為 `.playback`，確保 App 進入背景後 TTS 持續朗讀。
- 在 AppDelegate 或 SceneDelegate 的 `sceneDidEnterBackground` 中確認 audio session 仍為 active。

**鎖定畫面 / 控制中心整合**
- 使用 `MPNowPlayingInfoCenter` 顯示當前書名、章節名稱於鎖定畫面。
- 使用 `MPRemoteCommandCenter` 支援鎖定畫面的播放/暫停、上一段/下一段控制。
- 這是背景說書體驗的關鍵，讓使用者不需解鎖就能控制朗讀。

**AVSpeechSynthesizer 背景播放注意事項**
- `AVSpeechSynthesizer` 本身並不直接產生 audio session output，在某些 iOS 版本中背景播放可能被系統中斷。若遇到此問題，備案方案是：使用 `AVSpeechSynthesizer.write()` 方法將語音寫入 `AVAudioBuffer`，再透過 `AVAudioEngine` 或 `AVAudioPlayer` 播放，這樣可以獲得更穩定的背景播放支援。
- 建議在 MVP 先試 `AVSpeechSynthesizer` 直接播放 + background mode，若不穩定再切換至 `write()` + `AVAudioEngine` 方案。

---

### 2.4 資料模型（SwiftData）

```swift
@Model
class Book {
    var id: UUID
    var title: String
    var fileName: String
    var content: String          // 完整文字內容
    var chapters: [Chapter]      // 解析後的章節
    var lastReadChapter: Int     // 上次閱讀章節 index
    var lastReadOffset: Int      // 上次閱讀段落 offset
    var dateAdded: Date
    var dateLastRead: Date
    var readingProgress: Double  // 0.0 ~ 1.0
}

@Model
class Chapter {
    var index: Int
    var title: String
    var startOffset: Int         // 在完整 content 中的起始位置
    var endOffset: Int           // 結束位置
}

@Model  
class UserSettings {
    var fontSize: CGFloat        // 14 ~ 32
    var lineSpacing: CGFloat     // 1.2 ~ 2.0
    var theme: String            // "light" | "sepia" | "gray" | "dark"
    var fontFamily: String
    var ttsRate: Float           // 0.3 ~ 0.7
    var ttsVoiceIdentifier: String?
    var pageMode: String         // "scroll" | "page"
}
```

---

## 3. 畫面架構（Screen Flow）

```
App Launch
  └── LibraryView（書庫主頁）
        ├── [+] 匯入按鈕 → fileImporter
        ├── BookCard tap → ReaderView（閱讀器）
        │     ├── 上方工具列
        │     │     └── 目錄按鈕 → ChapterListSheet
        │     ├── 閱讀內容區域（ScrollView 或 PageView）
        │     ├── 下方工具列
        │     │     ├── 進度 Slider
        │     │     ├── TTS 控制列（上一段 | 播放/暫停 | 下一段）
        │     │     └── 設定齒輪 → SettingsSheet
        │     └── SettingsSheet
        │           ├── 字型大小 Slider
        │           ├── 行距選擇
        │           ├── 背景主題切換
        │           ├── 字體選擇
        │           ├── TTS 語速 Slider
        │           ├── TTS 語音選擇
        │           └── 翻頁模式切換
        └── 長按 BookCard → Rename / Delete
```

---

## 4. Xcode 專案結構建議

```
NovelNarrator/
├── NovelNarratorApp.swift          // @main App entry
├── Models/
│   ├── Book.swift
│   ├── Chapter.swift
│   └── UserSettings.swift
├── Views/
│   ├── Library/
│   │   ├── LibraryView.swift
│   │   └── BookCardView.swift
│   ├── Reader/
│   │   ├── ReaderView.swift
│   │   ├── ReaderContentView.swift   // 捲動/分頁切換
│   │   ├── PagedReaderView.swift     // 分頁模式
│   │   └── ScrollReaderView.swift    // 捲動模式
│   ├── Settings/
│   │   └── SettingsSheet.swift
│   └── Chapters/
│       └── ChapterListSheet.swift
├── Services/
│   ├── TTSService.swift              // AVSpeechSynthesizer 封裝
│   ├── NowPlayingService.swift       // MPNowPlayingInfoCenter 封裝
│   ├── ChapterParser.swift           // 章節解析邏輯
│   ├── EncodingDetector.swift        // 文字編碼偵測
│   └── TextPaginator.swift           // 分頁計算引擎
├── Extensions/
│   └── String+ChunkSplit.swift
├── Resources/
│   └── Assets.xcassets
└── Info.plist                        // 需配置 UIBackgroundModes: audio
```

---

## 5. 關鍵技術實作提示

### 5.1 編碼偵測
```swift
func detectEncoding(data: Data) -> String.Encoding {
    // 優先嘗試 UTF-8
    if let _ = String(data: data, encoding: .utf8) { return .utf8 }
    // 嘗試 Big5（繁體中文常見）
    let big5 = CFStringEncoding(CFStringEncodings.big5.rawValue)
    let nsBig5 = CFStringConvertEncodingToNSStringEncoding(big5)
    if let _ = String(data: data, encoding: String.Encoding(rawValue: nsBig5)) {
        return String.Encoding(rawValue: nsBig5)
    }
    // Fallback: GBK
    let gbk = CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
    let nsGBK = CFStringConvertEncodingToNSStringEncoding(gbk)
    return String.Encoding(rawValue: nsGBK)
}
```

### 5.2 TTS 背景播放核心設定
```swift
// 在 App 啟動時設定
try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenContent)
try AVAudioSession.sharedInstance().setActive(true)
```

### 5.3 鎖定畫面控制
```swift
func setupRemoteCommands() {
    let center = MPRemoteCommandCenter.shared()
    center.playCommand.addTarget { _ in /* resume TTS */ return .success }
    center.pauseCommand.addTarget { _ in /* pause TTS */ return .success }
    center.nextTrackCommand.addTarget { _ in /* next paragraph */ return .success }
    center.previousTrackCommand.addTarget { _ in /* prev paragraph */ return .success }
}

func updateNowPlaying(bookTitle: String, chapter: String) {
    var info = [String: Any]()
    info[MPMediaItemPropertyTitle] = chapter
    info[MPMediaItemPropertyArtist] = bookTitle
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
}
```

### 5.4 章節解析正則
```swift
let patterns = [
    #"^第[零一二三四五六七八九十百千\d]+[章回節卷集篇]"#,
    #"^Chapter\s+\d+"#,
    #"^卷[零一二三四五六七八九十百千\d]+"#
]
```

---

## 6. MVP 範圍與迭代計畫

### Phase 1 — MVP（建議 2~3 週）
- 書庫匯入 / 列表 / 刪除
- 基本捲動式閱讀器 + 字型大小調整 + 日夜主題
- TTS 播放/暫停 + 段落級高亮 + 語速調整
- 背景播放（Background Audio Mode）
- 鎖定畫面播放控制
- 閱讀進度自動存檔

### Phase 2 — 體驗優化
- 分頁翻頁模式（含翻頁動畫）
- 章節自動解析 + 目錄側欄
- 逐句高亮同步
- 更多背景主題與字體選項
- 書籍搜尋與排序

### Phase 3 — 進階功能
- 書籤功能（加入 / 管理 / 跳轉）
- TTS 寫入 AVAudioBuffer 方案（穩定性提升）
- 匯入 .epub 支援
- 睡眠定時器（朗讀 N 分鐘後自動暫停）
- iPad 適配（多欄佈局）
- Widget：顯示當前閱讀書籍與進度

---

## 7. 非功能需求

- 效能：開啟一本 5MB 的 txt 檔不應超過 2 秒，章節解析在背景執行不阻塞 UI。
- 無障礙：所有按鈕需有 accessibility label，支援 Dynamic Type。
- 國際化：介面文字以繁體中文為主，架構上使用 `LocalizedStringKey` 預留多語系擴充空間。
- 最低版本：iOS 17.0。
- 隱私：App 不連網，所有資料存在本地，不需要任何隱私權限（除檔案存取）。

---

## 8. 開發注意事項

### 給 Claude / AI 助手的指引
- 本專案使用純 SwiftUI + Swift Concurrency（async/await），不使用 Combine 除非必要。
- Model 層使用 SwiftData，不使用 Core Data。
- 所有 TTS 相關邏輯封裝在 `TTSService` 中，作為 `@Observable` class 注入 environment。
- 分頁計算是技術難點，使用 Core Text 的 `CTFramesetterSuggestFrameSizeWithConstraints` 計算每頁能容納的文字範圍。
- 請為每個 View 和 Service 撰寫清晰的 MARK 分區和內聯註解。
- 所有使用者可見的中文字串放在 `Localizable.strings`，key 使用英文。
