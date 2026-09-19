import Foundation
import SwiftData

// The shape of the database as it is today — version 1.
//
// Why bother naming a version at all? Because one day you'll add a field, and
// people will already have data on their phones. Numbered versions plus a
// migration plan are how you change the shape without throwing their data away.
//
// When that day comes: copy today's models into this enum so version 1 stays
// frozen, write SchemaV2 with the change, and add a stage to the plan below.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            Account.self,
            TransactionCategory.self,
            TransactionRecord.self,
            RecurringTransaction.self,
            Budget.self,
            SavingsGoal.self,
            GoalContribution.self,
        ]
    }
}

enum MoneyLogMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
