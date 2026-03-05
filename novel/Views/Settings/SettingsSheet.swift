import SwiftUI
import SwiftData
import AVFoundation

/// 閱讀設定面板
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(TTSService.self) private var ttsService
    @Query private var allSettings: [UserSettings]

    private var settings: UserSettings {
        if let existing = allSettings.first {
            return existing
        }
        let newSettings = UserSettings()
        modelContext.insert(newSettings)
        return newSettings
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - 字型設定
                Section("字型") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("字型大小")
                            Spacer()
                            Text("\(Int(settings.fontSize)) pt")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(
                            get: { settings.fontSize },
                            set: { settings.fontSize = $0 }
                        ), in: 14...32, step: 1)
                    }

                    Picker("字體", selection: Binding(
                        get: { settings.fontFamily },
                        set: { settings.fontFamily = $0 }
                    )) {
                        Text("系統預設").tag("System")
                        Text("PingFang TC").tag("PingFang TC")
                    }
                }

                // MARK: - 排版設定
                Section("排版") {
                    Picker("行距", selection: Binding(
                        get: { settings.lineSpacing },
                        set: { settings.lineSpacing = $0 }
                    )) {
                        Text("1.2x").tag(1.2)
                        Text("1.5x").tag(1.5)
                        Text("1.8x").tag(1.8)
                        Text("2.0x").tag(2.0)
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: - 背景主題
                Section("背景主題") {
                    HStack(spacing: 16) {
                        ForEach(ReadingTheme.allCases) { themeOption in
                            ThemeButton(
                                theme: themeOption,
                                isSelected: settings.theme == themeOption.rawValue
                            ) {
                                settings.theme = themeOption.rawValue
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }

                // MARK: - TTS 設定
                Section("語音朗讀") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("語速")
                            Spacer()
                            Text(rateDescription)
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("慢")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Slider(value: Binding(
                                get: { settings.ttsRate },
                                set: {
                                    settings.ttsRate = $0
                                    ttsService.setRate($0)
                                }
                            ), in: 0.3...0.7, step: 0.05)
                            Text("快")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Picker("語音", selection: Binding(
                        get: { settings.ttsVoiceIdentifier ?? "" },
                        set: {
                            settings.ttsVoiceIdentifier = $0.isEmpty ? nil : $0
                            ttsService.setVoice(identifier: $0.isEmpty ? nil : $0)
                        }
                    )) {
                        Text("預設").tag("")
                        ForEach(availableVoices, id: \.identifier) { voice in
                            Text(voice.name).tag(voice.identifier)
                        }
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var rateDescription: String {
        if settings.ttsRate < 0.4 {
            return "較慢"
        } else if settings.ttsRate < 0.55 {
            return "適中"
        } else {
            return "較快"
        }
    }

    /// 取得裝置上所有 zh-TW 語音
    private var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("zh-TW") }
            .sorted { $0.name < $1.name }
    }
}

// MARK: - 主題選擇按鈕
struct ThemeButton: View {
    let theme: ReadingTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Circle()
                    .fill(theme.previewColor)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 3 : 1)
                    )
                    .overlay {
                        if theme.isDark {
                            Circle()
                                .stroke(Color.gray.opacity(0.5), lineWidth: 0.5)
                        }
                    }

                Text(theme.displayName)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.displayName)主題")
    }
}
