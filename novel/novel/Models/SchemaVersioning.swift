import Foundation
import SwiftData

// MARK: - Schema Versioning
// 使用 VersionedSchema 管理 SwiftData 模型變更，確保使用者資料不會因欄位變更而遺失。
// 新增欄位時：
//   1. 建立新的 SchemaVN（如 SchemaV2）定義新結構
//   2. 在 NovelMigrationPlan.stages 加入 MigrationStage
//   3. 更新 novelApp 的 modelContainer 使用 migrationPlan

/// V1：初始版本 — 目前所有已發佈的模型結構
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Book.self, Chapter.self, UserSettings.self, Bookmark.self]
    }
}

/// Migration Plan：定義從 V1 → 未來版本的遷移路徑
enum NovelMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    /// 遷移步驟（目前只有 V1，無需遷移步驟）
    /// 未來新增 V2 時，在此加入 .migrate(from: SchemaV1, to: SchemaV2) { ... }
    static var stages: [MigrationStage] {
        []
    }
}
