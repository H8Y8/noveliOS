# NovelNarrator 待辦事項

## 已完成
- [x] **音訊中斷處理** — TTSService.init() 監聯 interruptionNotification，來電/鬧鐘自動暫停恢復
- [x] **Edge TTS retry 機制** — EdgeTTSProvider exponential backoff（1s/2s/4s，最多 3 次）
- [x] **單元測試** — ChapterParser、UTF-16 offset、EncodingDetector、TTSService、PaginationEngine 等完整覆蓋
- [x] **Edge server URL 驗證** — SettingsSheet 即時驗證 scheme + host + port，支援多 URL 逗號分隔
- [x] **Noto Sans TC 字體選項** — SettingsSheet 字體 Picker 已顯示 System / PingFang / Noto Sans TC
- [x] **章節 slider 觸感回饋** — ReaderView 章節 slider 使用 .sensoryFeedback(.impact)

## 低優先
- [ ] **LocalizedStringKey 本地化** — 將 Views 中的中文字串字面值改為 LocalizedStringKey，建立 Localizable.strings
