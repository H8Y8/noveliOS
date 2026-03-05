# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**NovelNarrator** — iOS app for importing `.txt` novels, reading them in an immersive reader, and narrating them via TTS (Text-to-Speech) with background playback support.

- Language: Swift 5.9+, iOS 17+ minimum
- UI: SwiftUI only (no UIKit unless wrapping is required)
- Persistence: SwiftData (`Book`, `Chapter`, `UserSettings` models)
- TTS: `AVSpeechSynthesizer` with `zh-TW` locale, `AVAudioSession` `.playback` category for background audio
- Lock screen integration: `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter`
- Concurrency: Swift Concurrency (`async/await`), no Combine unless necessary

## Build & Run

Open `novel/novel.xcodeproj` in Xcode 15+ and run on a simulator or device. There is no package manager; all dependencies are system frameworks.

To run tests:
- Unit tests: `novelTests` target (`novel/novelTests/novelTests.swift`)
- UI tests: `novelUITests` target

From command line:
```bash
xcodebuild -project novel/novel.xcodeproj -scheme novel -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -project novel/novel.xcodeproj -scheme novelTests -destination 'platform=iOS Simulator,name=iPhone 16' test
```

## Architecture

### Data Flow
`LibraryView` → user taps a `BookCard` → `ReaderView` (receives `@Bindable Book`) → reads chapter content via `book.chapterContent(at:)` using UTF-16 offsets → passes paragraphs to `ScrollReaderView` + `TTSService`

### Key Services (all in `novel/novel/Services/`)
- **`TTSService`** — `@Observable` class injected via `.environment(ttsService)` at app root. Manages `AVSpeechSynthesizer` state, paragraph-by-paragraph narration, and exposes `onChapterFinished` callback for auto-advance.
- **`NowPlayingService`** — Manages `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` for lock screen controls. Created as `@State` inside `ReaderView`.
- **`ChapterParser`** — Static struct. Parses chapter boundaries via regex (`第X章/回/節`, `Chapter X`, `卷X`). Falls back to 3000-char chunks if no patterns match.
- **`EncodingDetector`** — Detects UTF-8 / Big5 / GBK encoding on import.

### Models (SwiftData, `novel/novel/Models/`)
- `Book` — stores full `content: String`, has cascade-delete `chapters: [Chapter]`. Chapter content is accessed via UTF-16 offset slicing (`chapterContent(at:)`).
- `Chapter` — `startOffset`/`endOffset` are **UTF-16 offsets** into `Book.content`.
- `UserSettings` — singleton pattern: `@Query` fetches all, uses `.first ?? UserSettings()`. Has computed `readingTheme: ReadingTheme` bridging to the `ReadingTheme` enum.

### Views (SwiftUI)
- `ReaderView` — orchestrates toolbars, TTS controls, chapter navigation, progress saving, and NowPlaying setup. Wraps `ScrollReaderView` for content display.
- `ScrollReaderView` — renders paragraphs with highlight support for TTS current paragraph.
- `SettingsSheet`, `ChapterListSheet` — presented as `.sheet` from `ReaderView`.

### Theme
`ReadingTheme` enum (`novel/novel/Theme/ReadingTheme.swift`) — four themes: `.light`, `.sepia`, `.gray`, `.dark`. Provides `backgroundColor`, `textColor`, `highlightColor`, `toolbarStyle` (Material).

## UI/UX 設計規範

- 本專案使用 uiux pro max skill 進行 UI 設計
- 設計簡報見 DESIGN_BRIEF.md
- 所有 UI 元件必須支援四套閱讀主題色彩切換
- 閱讀器是核心畫面，任何 UI 變更都要確保不影響閱讀體驗
- 動畫使用 SwiftUI 原生 animation，不引入 Lottie 等第三方動畫庫
- 圖標統一使用 SF Symbols
- 所有中文介面字串用 LocalizedStringKey

## Important Conventions

- `TTSService` is instantiated once in `novelApp` and passed as environment object — never instantiate it inside views.
- Chapter offsets use **UTF-16 units** throughout — be careful when slicing `String` content.
- `UserSettings` is a SwiftData singleton: always use `allSettings.first ?? UserSettings()` pattern; insert a new one if `allSettings.isEmpty`.
- All user-visible Chinese strings should use `LocalizedStringKey` to preserve future localization support.
- Background audio requires `UIBackgroundModes: audio` in `Info.plist` and `AVAudioSession` category `.playback` set at app launch (`novelApp.init()`).
- `AVSpeechSynthesizerDelegate` callbacks come off the main actor — use `Task { @MainActor in ... }` to update `@Observable` state.
