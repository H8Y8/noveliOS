# 墨韻水墨 UI 重寫 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 將 NovelNarrator 全部畫面重寫為中國水墨風格（墨韻設計系統），含水墨互動動效，SwiftData 相容不遷移。

**Architecture:** 方案 A — Token 層置換（`NNColor`/`ReadingTheme` API 不變、色值置換）+ 新增 `InkComponents.swift` 水墨元件庫，逐畫面套用。spec 見 `docs/superpowers/specs/2026-06-13-ink-wash-ui-design.md`。

**Tech Stack:** SwiftUI（iOS 17+）、SwiftData、Canvas、純系統字型（Songti TC / PingFang TC）與 SF Symbols。

**驗證指令（每個 Task 結尾執行）：**
```bash
xcodebuild -project novel/novel.xcodeproj -scheme novel -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

---

### Task 1: Theme tokens 置換（NNColor / NNFont / NNAnimation）

**Files:**
- Modify: `novel/novel/Theme/Theme.swift`

- [ ] **Step 1.1** 置換 `NNColor` 色值（API 名稱不變）：
  - `accent #A63A2E`（dark 模式用 adaptive 至 `#C04A3C`）、`accentLight #C04A3C`、`accentDark #7E2B22`
  - `appBackground` light `#F4EFE6` / dark `#121210`；`cardBackground` `#FBF7EE`/`#1C1C19`；`cardHighlight` `#EFE8DA`/`#26261F`；`separator` `#DDD5C4`/`#2A2A26`
  - `textPrimary` `#2B2B26`/`#D6D4CC`；`textSecondary` `#6E6E64`/`#8A8A82`；`textTertiary` `#A8A498`/`#55554E`
  - `playing`/`progressFill` 改為墨色 adaptive(`#4A4A45`/`#B0AEA4`)；`progressTrack` `#DDD5C4`/`#2A2A26`
  - `coverPalettes` 換 8 組遠山墨色：墨青 (`#2A3438`,`#46565C`)、黛藍 (`#252C3A`,`#3E4A60`)、赭墨 (`#352A22`,`#54453A`)、茶墨 (`#2E2A20`,`#4A4434`)、灰墨 (`#2C2C28`,`#4A4A44`)、青碧 (`#243430`,`#3C544E`)、紫墨 (`#2E2832`,`#4A4252`)、焦墨 (`#262420`,`#403C34`)
  - 檔頭註解改為「水墨風（墨韻）：墨分五色、朱砂一點」並更新禁則說明
- [ ] **Step 1.2** `NNFont` 新增宋體標題系列與閱讀字型 case：

```swift
// ReadingFamily 內新增（System case 之後）：
case songti = "Songti TC"
// font(size:weight:) switch 新增：
case .songti:
    return .custom("STSongti-TC-Regular", size: size)

// NNFont 內新增：
/// 水墨標題字型（宋體，iOS 內建），用於畫面標題/書名/章節名/主題名
static func inkTitle(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
    let name = weight == .bold || weight == .semibold ? "STSongti-TC-Bold" : "STSongti-TC-Regular"
    if UIFont(name: name, size: size) != nil {
        return .custom(name, size: size)
    }
    return .system(size: size, weight: weight, design: .serif)
}
```

- [ ] **Step 1.3** `NNAnimation` 新增：

```swift
/// 墨暈按壓擴散
static let inkSpread = Animation.easeOut(duration: 0.35)
/// 書卡墨滴暈開入場
static let inkDropAppear = Animation.easeOut(duration: 0.45)
static func inkDrop(index: Int) -> Animation { inkDropAppear.delay(Double(index) * 0.06) }
```

- [ ] **Step 1.4** Build 驗證 + commit `feat(theme): 墨韻色彩/字型/動畫 tokens`

### Task 2: ReadingTheme 水墨四境

**Files:**
- Modify: `novel/novel/Theme/ReadingTheme.swift`

- [ ] **Step 2.1** rawValue 不動，置換顯示名與色值：
  - `dark`「夜墨」bg `#000000`、text `#D4D2CA`、secondary `#7C7A74`、highlight 墨青 `#5C7A78` 0.22、separator `#2A2A26`
  - `sepia`「茶褐」bg `#221A10`、text `#E2D2AE`、secondary `#9C8B6E`、highlight 暖赭 `#9C7A45` 0.25、separator `#322818`
  - `light`「宣紙」bg `#F4EFE6`、text `#2B2B26`、secondary `#6E6E64`、highlight 朱砂 `#A63A2E` 0.08、separator `#DDD5C4`
  - `gray`「黛青」bg `#1B1F22`、text `#B4BCC0`、secondary `#7E8A90`、highlight 青墨 `#5C7A88` 0.20、separator `#2A3034`
  - `displayDescription` 同步更新（夜墨：OLED 省電・暗房首選 / 茶褐：暖茶質感・睡前閱讀 / 宣紙：仿宣紙感・日間閱讀 / 黛青：低對比・長時間護眼）
- [ ] **Step 2.2** 確認對比：secondary text 皆 ≥4.5:1（已用對比公式抽查）
- [ ] **Step 2.3** Build + 跑 novelTests（rawValue 相容性）+ commit `feat(theme): 水墨四境閱讀主題`

### Task 3: 水墨元件庫 InkComponents

**Files:**
- Create: `novel/novel/Theme/InkComponents.swift`

- [ ] **Step 3.1** 實作六個元件（完整程式碼見 spec §四；要點如下）：
  - `InkPaperTexture`：以 `SystemRandomNumberGenerator` 替代品——用固定種子 LCG 偽隨機產生 ~600 噪點，`UIGraphicsImageRenderer` 畫一次存 `static let sharedImage`，`.inkPaper()` modifier 以 `Image(uiImage:).resizable(resizingMode: .tile)` + `.opacity(0.04)` overlay
  - `InkButtonStyle: ButtonStyle`：`configuration.isPressed` 時疊加 `Circle().fill(NNColor.textPrimary.opacity(0.12))` scale 0.4→1.2 + opacity 漸出（`NNAnimation.inkSpread`）；`reduceMotion` 時僅 `opacity(0.85)`；另提供 `InkScaleButtonStyle`（scale 0.97）給卡片
  - `InkCoverView(title: String, palette: (Color, Color))`：Canvas 畫 2–3 層遠山（以 title hash 決定 LCG 種子 → 山峰數/高度/曲率，`Path` quadCurve），上層留白、山色用 palette 漸層；右側直排書名（`title.prefix(6)` 逐字 VStack，宋體）
  - `SealView(text: String)`：RoundedRectangle(cornerRadius: 4) 朱砂底 + 宣紙色宋體字 + 1pt 內框
  - `InkProgressBar(progress: Double)`：GeometryReader + Capsule 軌道（progressTrack）+ 筆觸填充（前端 Capsule、尾端小圓點朱砂，progress>0.02 才顯示）；高度參數化（預設 3）
  - `InkWaveform(isAnimating: Bool)`：5 根墨色豎條 `Capsule`，相位錯開的 scaleY 呼吸動畫（`repeatForever`），`reduceMotion`/`!isAnimating` 時靜止
- [ ] **Step 3.2** Build + commit `feat(theme): 水墨元件庫（紋理/墨暈/封面/印章/筆觸進度/墨波）`

### Task 4: 書庫（LibraryView + BookCardView + OnboardingView + DatabaseErrorView）

**Files:**
- Modify: `novel/novel/Views/Library/BookCardView.swift`
- Modify: `novel/novel/Views/Library/LibraryView.swift`
- Modify: `novel/novel/Views/Library/OnboardingView.swift`
- Modify: `novel/novel/Views/Library/DatabaseErrorView.swift`

- [ ] **Step 4.1** BookCardView：`coverArea` 換 `InkCoverView`（直排書名取代首字 monogram）；朗讀中徽章換 `SealView(text: "聽")` + `InkWaveform`；進度條換 `InkProgressBar(progress:)`；入場動畫加 blur 消散（`.blur(radius: appeared ? 0 : 4)`、`NNAnimation.inkDrop(index:)`）；書名字型 `NNFont.inkTitle(size: 14)`
- [ ] **Step 4.2** LibraryView：ZStack 底色後加 `.inkPaper()`；navigationTitle 維持（large title 已夠）；匯入按鈕/空狀態按鈕套 `InkButtonStyle`；空狀態改留白構圖：`SealView(text: "書")` 60pt + 標題宋體 + 引導文字；卡片 Button 換 `.buttonStyle(InkScaleButtonStyle())`
- [ ] **Step 4.3** OnboardingView / DatabaseErrorView：底色 + `.inkPaper()` + 標題宋體 + 按鈕 InkButtonStyle + 印章元素
- [ ] **Step 4.4** Build + commit `feat(library): 書庫水墨化（遠山封面/印章/墨波/墨滴入場）`

### Task 5: 閱讀器（ReaderView + Scroll/PageReaderView）

**Files:**
- Modify: `novel/novel/Views/Reader/ReaderView.swift`（topToolbar :252、bottomToolbar :375、chapterSlider :408）
- Modify: `novel/novel/Views/Reader/ScrollReaderView.swift`、`PageReaderView.swift`（僅高亮/輔助色微調，如有 hardcode）

- [ ] **Step 5.1** topToolbar：書名/章節名改 `NNFont.inkTitle(size: 16)`；按鈕套 InkButtonStyle；章節資訊標籤改卷軸式（橫向 capsule、左右各一條 1pt 豎線裝飾、separator 色）
- [ ] **Step 5.2** bottomToolbar：chapterSlider 的進度視覺融合 `InkProgressBar` 樣式（Slider 保留拖拽、tint 改墨色、thumb 預設）；TTS 迷你控制按鈕套 InkButtonStyle、播放鍵 `NNColor.accent`（朱砂）
- [ ] **Step 5.3** 確認 toolbarGradient/Material 在四境下視覺正常（色值已由 Task 2 帶入）
- [ ] **Step 5.4** Build + commit `feat(reader): 閱讀器工具列與進度水墨化`

### Task 6: TTS 播放器（NarratorPlayerView）

**Files:**
- Modify: `novel/novel/Views/Reader/NarratorPlayerView.swift`

- [ ] **Step 6.1** 段落預覽區加 `.inkPaper()` 與卡片墨色層次；播放/暫停主鍵朱砂底圓鈕（白字）+ InkButtonStyle；上一段/下一段墨色
- [ ] **Step 6.2** 語速滑桿 tint 墨色、速度標籤宋體數字區 `monospacedDigit()`；睡眠計時器選項 chips 統一墨色、選中態朱砂描邊；語音/引擎選擇列表選中朱砂點
- [ ] **Step 6.3** Build + commit `feat(player): TTS 播放器水墨化`

### Task 7: 設定（SettingsSheet）

**Files:**
- Modify: `novel/novel/Views/Settings/SettingsSheet.swift`（主題選擇器 :103-143、字型選單含新 songti case 自動出現）

- [ ] **Step 7.1** 主題選擇器：色票改水墨四境（previewColor 已新色），主題名 `NNFont.inkTitle(size: 13)`，選中態朱砂描邊 1.5pt
- [ ] **Step 7.2** 區段標題改宋體；各控件（segment/chips/buttons）套墨色與 InkButtonStyle；確認 `ReadingFamily.songti` 在字型選單顯示並可選存
- [ ] **Step 7.3** Build + commit `feat(settings): 設定面板水墨化 + 宋體閱讀字型`

### Task 8: 目錄/書籤/搜尋 sheets

**Files:**
- Modify: `novel/novel/Views/Chapters/ChapterListSheet.swift`
- Modify: `novel/novel/Views/Reader/BookmarkListSheet.swift`
- Modify: `novel/novel/Views/Reader/SearchSheet.swift`

- [ ] **Step 8.1** ChapterListSheet：當前章節列前綴朱砂圓點（6pt）+ 章節名宋體；列表底色/分隔線墨色
- [ ] **Step 8.2** BookmarkListSheet / SearchSheet：標題宋體、強調色朱砂、底色 inkPaper
- [ ] **Step 8.3** Build + commit `feat(sheets): 目錄/書籤/搜尋水墨化`

### Task 9: 總驗證

- [ ] **Step 9.1** 全量 build + `xcodebuild -scheme novel -destination ... test`（novelTests）
- [ ] **Step 9.2** 對照 spec §六 無障礙清單自查（reduceMotion 降級、44pt、AA 對比、LocalizedStringKey）
- [ ] **Step 9.3** commit 殘餘 + 總結報告

## Self-Review 紀錄

- Spec 覆蓋：§一→Task1、§二→Task2、§三→Task1/7、§四→Task3、§五→Task4-8、§六→各 task 內建+Task9、§七→流程本身。無缺口。
- 型別一致：`InkCoverView(title:palette:)`、`InkProgressBar(progress:)`、`SealView(text:)`、`InkButtonStyle`/`InkScaleButtonStyle`、`NNFont.inkTitle(size:weight:)`、`NNAnimation.inkDrop(index:)` 全文一致。
- UI 視覺工作以 build 驗證 + 既有測試回歸為主（SwiftUI 視覺無法單元測試），符合專案現有測試慣例。
