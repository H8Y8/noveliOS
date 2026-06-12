# 「墨韻」水墨風 UI/UX 重寫設計文件

日期：2026-06-13
分支：`feature/ink-wash-ui`
狀態：已核准（使用者選定：全部畫面 / 重塑水墨四境 / 朱砂印泥紅點綴 / 適度水墨動效）

## 背景與目標

NovelNarrator 現有設計系統為「台灣日系簡潔」風格（霧鋼藍主色）。本次依使用者要求，
將全 app UI/UX 重寫為**中國水墨風格**，含互動式水墨動效與 UX 最佳化。
這是對原 DESIGN_BRIEF.md「避免紅金配色」原則的刻意方向轉變，但保留其核心精神：
閱讀優先、單手操作、暗色為主、TTS 一等公民。

## 實作策略（方案 A）

Token 層置換 + 元件庫注入：

- 保留 `Theme.swift`（`NNColor`/`NNFont`/`NNSpacing`/`NNAnimation`/`NNSymbol`）與
  `ReadingTheme.swift` 的 **API 名稱不變**，置換內部色值與動畫參數。
- 新增 `Theme/InkComponents.swift`（與必要的拆分檔案）承載水墨元件。
- 逐畫面套用元件並調整版面，分階段 commit，每階段 `xcodebuild` 驗證可編譯。
- `ReadingTheme` 的 SwiftData rawValue（`dark`/`sepia`/`light`/`gray`）**完全不變**，無資料遷移。

## 一、色彩系統（墨分五色 + 朱砂一點）

| 角色 | Light（宣紙） | Dark（夜宣） |
|---|---|---|
| App 底色 `appBackground` | `#F4EFE6` 宣紙米 | `#121210` 夜宣黑 |
| 卡片 `cardBackground` | `#FBF7EE` | `#1C1C19` |
| 卡片選中 `cardHighlight` | `#EFE8DA` | `#26261F` |
| 分隔線 `separator` | `#DDD5C4` | `#2A2A26` |
| 主文字 `textPrimary` | `#2B2B26` 濃墨 | `#D6D4CC` 淡墨 |
| 次文字 `textSecondary` | `#6E6E64` 重墨 | `#8A8A82` 灰墨 |
| 三級文字 `textTertiary` | `#A8A498` | `#55554E` |
| 點綴 `accent` | `#A63A2E` 朱砂印泥 | `#C04A3C` |

原則：

- 墨色全部偏暖灰（帶宣紙米調），不用純中性灰。
- 朱砂只用於小面積點綴：播放鍵、當前章節標記、印章元素、選中態，面積 < 5%。
- 所有文字/背景對比 ≥ WCAG AA 4.5:1（次文字 ≥ 4.5:1，三級裝飾文字 ≥ 3:1）。
- `playing`/`progressFill` 改為墨色系，完成端帶朱砂。
- 書封調色盤 `coverPalettes` 改為 8 組「遠山墨色」漸層（墨青、黛、赭墨、茶墨等低飽和山色）。

## 二、閱讀主題「水墨四境」

rawValue 不變，僅重新調色與命名：

| rawValue | 新名 | 背景 | 主文字 | 定位 |
|---|---|---|---|---|
| `light` | 宣紙 | `#F4EFE6` | `#2B2B26` | 日間，仿宣紙 |
| `sepia` | 茶褐 | `#221A10` | `#E2D2AE` | 睡前暖調 |
| `dark` | 夜墨 | `#000000` | `#D4D2CA` | OLED 省電 |
| `gray` | 黛青 | `#1B1F22` | `#B4BCC0` | 低對比護眼 |

- TTS 高亮：dark 系用「墨青暈」（低飽和青墨 18–22% 透明度），宣紙用極淡朱砂暈（8%）。
- 次文字、分隔線、工具列漸層對應微調，全部維持 AA 對比。
- `displayName`/`displayDescription` 更新為新主題名與描述。

## 三、字型

- 標題／書名／章節名／主題名：**Songti TC**（iOS 內建宋體，`STSongti-TC-Bold` 等），
  fallback `.system(design: .serif)`。新增 `NNFont.inkTitle(size:weight:)` 系列。
- UI 與正文預設維持 PingFang TC／系統字型（長文閱讀舒適度優先）。
- 閱讀字型選項 `ReadingFamily` 新增 `songti` case（宋體閱讀）。
- 書卡封面書名採直排（傳統書冊式，逐字 VStack 排列）。

## 四、水墨元件庫（`Theme/InkComponents.swift` 等新檔案）

1. **宣紙紋理 `InkPaperTexture`** — Canvas 程序化生成細微噪點纖維（以固定種子的偽隨機，
   不用 `Math.random`/`Date`），渲染一次快取為 `UIImage`，以 3–5% 透明度鋪在底色上。
   提供 `.inkPaper()` view modifier。
2. **墨暈按壓 `InkButtonStyle`** — 按下時從中心暈開一圈淡墨（圓形 scale 0.4→1.2 +
   opacity 0.35→0，0.35s easeOut），`reduceMotion` 時降級為透明度變化。全 app 按鈕統一採用。
3. **水墨封面 `InkCoverView`** — 依書名 hash 以 Canvas 繪製 2–3 層「遠山」貝茲曲線剪影 +
   墨色漸層 + 留白，每本書山形獨特。取代 BookCardView 現有純色漸層封面。
4. **朱砂印章 `SealView`** — 圓角方印（朱砂底、宣紙色字、細邊框），支援 1–2 字
   （如「聽」「書」）。用於空狀態、Onboarding、聽書中徽記。
5. **毛筆進度條 `InkProgressBar`** — 兩端略尖的筆觸形填充（Capsule 變體 + 端點漸細），
   墨色填充、完成端一點朱砂。取代閱讀進度條與書卡進度條。
6. **墨波聲紋 `InkWaveform`** — TTS 播放中的波形動畫，墨色筆畫粗細呼吸變化。

## 五、各畫面改造

1. **LibraryView**：頂部極淡遠山水墨橫幅（Canvas、隨捲動微視差可省略）；書卡「墨滴暈開」
   交錯入場（scale 0.92→1 + opacity + blur 4→0 消散）；聽書中卡片右上朱砂「聽」印 +
   墨波聲紋；空狀態留白構圖 + 印章 + 引導匯入。
2. **ReaderView**：工具列墨色漸層淡入淡出（沿用 toolbarGradient 機制換色）；章節資訊改
   卷軸標籤式樣；進度條換毛筆筆觸；翻頁保留現有物理動畫。
3. **NarratorPlayerView**：段落預覽區宣紙質感；語速滑桿墨滴拇指；播放鍵朱砂；
   睡眠計時器選項統一墨色。
4. **SettingsSheet**：主題選擇器改水墨四境色票（主題名宋體呈現）；區段標題宋體；
   控件統一 InkButtonStyle。
5. **ChapterListSheet / BookmarkListSheet / SearchSheet**：當前章節朱砂點標記；
   統一墨色層次與宋體標題。
6. **OnboardingView / DatabaseErrorView**：留白構圖 + 印章 + 墨色插畫感。

## 六、互動與無障礙

- 動畫 150–400ms、全 SwiftUI 原生；`accessibilityReduceMotion` 時墨暈/暈開降級為淡入。
- 觸控目標 ≥ 44pt 不變；TTS 主按鈕 52pt 不變。
- 閱讀區域只動主題色與紋理，閱讀時 UI 仍然「消失」。
- 所有中文字串維持 LocalizedStringKey；SF Symbols 不變、不引入第三方資源。

## 七、Git 與驗證

- 分支 `feature/ink-wash-ui`（已建立，含基線 WIP commit）。
- 分階段 commit：設計系統 → 元件庫 → 書庫 → 閱讀器 → TTS 播放器 → 設定/其餘 sheet。
- 每階段 `xcodebuild -project novel/novel.xcodeproj -scheme novel -destination
  'platform=iOS Simulator,name=iPhone 16' build`；完成後跑 `novelTests`。

## 不做的事（YAGNI）

- 不引入第三方動畫/圖標/字型資源。
- 不改 SwiftData schema、不做資料遷移。
- 不重寫 PaginationEngine、TTS 服務層、UTF-16 偏移邏輯。
- 不做 Canvas 墨流粒子、毛筆筆觸過場等「豐富沉浸動效」（使用者選了適度動效）。
