import Foundation
import SwiftData
import OSLog

// Opens the database when the app starts.
//
// SwiftData calls it a ModelContainer; think of it as the file your data lives in
// plus the rules for reading and writing it. Everything is local — no iCloud, no
// server — which is the whole promise of this app.
enum PersistenceController {
    enum StoreLocation {
        case onDisk
        case inMemory
    }

    private static let logger = Logger(subsystem: "com.wedzat.moneylog", category: "Persistence")

    static func makeContainer(location: StoreLocation = .onDisk) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration: ModelConfiguration

        switch location {
        case .inMemory:
            configuration = ModelConfiguration(
                UUID().uuidString,
                schema: schema,
                isStoredInMemoryOnly: true,
                allowsSave: true,
                groupContainer: .none,
                cloudKitDatabase: .none
            )
        case .onDisk:
            let url = try storeURL()
            configuration = ModelConfiguration(
                "MoneyLog",
                schema: schema,
                url: url,
                allowsSave: true,
                cloudKitDatabase: .none
            )
        }

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: MoneyLogMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            logger.error("Failed to open store: \(error.localizedDescription, privacy: .public)")
            throw AppError.storeUnavailable(underlying: error.localizedDescription)
        }
    }

    // Where the database file lives: Application Support/MoneyLog/MoneyLog.store.
    //
    // "Protected until first unlock" means iOS keeps it encrypted until the user
    // unlocks the phone once after a restart. Full protection would lock it again
    // every time the screen turns off, which would stop background work later.
    static func storeURL(fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appending(path: "MoneyLog", directoryHint: .isDirectory)
        if !fileManager.fileExists(atPath: directory.path(percentEncoded: false)) {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
        }
        return directory.appending(path: "MoneyLog.store", directoryHint: .notDirectory)
    }
}
