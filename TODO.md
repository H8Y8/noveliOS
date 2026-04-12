# NovelNarrator 待辦事項

## 高優先
- [ ] **Azure TTS 實作** — 完成 AzureTTSProvider.synthesize()，串接 Azure Cognitive Services REST API，並在 SettingsSheet 加入 Key/Region 設定欄位
- [ ] **音訊中斷處理** — 在 TTSService 或 novelApp 監聽 AVAudioSession.interruptionNotification，來電/鬧鐘時自動暫停，中斷結束後視 shouldResume flag 決定是否恢復
- [ ] **Edge TTS retry 機制** — EdgeTTSProvider.synthesize() 加入 exponential backoff retry（最多 3 次，延遲 1s/2s/4s）

## 中優先
- [ ] **單元測試** — 為 ChapterParser、UTF-16 offset 切片（Book.chapterContent）、EncodingDetector 撰寫 XCTest 單元測試
- [ ] **Edge server URL 驗證** — SettingsSheet 的伺服器位址欄位加入格式驗證（需有 scheme + host + port），格式錯誤時顯示 inline error
- [ ] **Noto Sans TC 字體選項** — SettingsSheet 的字體 Picker 加入 Noto Sans TC 選項（enum 已定義，UI 未顯示）
- [ ] **章節 slider 觸感回饋** — ReaderView 的章節 slider onChange 加入 UIImpactFeedbackGenerator

## 低優先
- [ ] **LocalizedStringKey 本地化** — 將 Views 中的中文字串字面值改為 LocalizedStringKey，建立 Localizable.strings
