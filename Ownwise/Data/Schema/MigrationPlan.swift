import SwiftData

enum MigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    /// v2 only adds an optional attribute, so the migration is lightweight:
    /// SwiftData fills `reminderLeadDays` with nil and nothing else changes.
    static var stages: [MigrationStage] { [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)] }
}
